unit package Command;

=begin pod

The build command takes a JSON file out of the inbox and starts a build
based on its contents.

It is normally invoked by a systemd path service that watches
for changes to the inbox.

Building continues recursively until the inbox is empty.

=end pod

use JSON::Fast;
use Config;
use Job;
use Filesystem;

enum JobState <job-start progress-command progress-stdout progress-stderr job-end job-fail>;

# signal(SIGTERM).tap: {
#     log-to-file('X', 'Killed by SIGTERM');
#     try close $log;
#     exit;
# }

sub log-to-file(IO::Handle $handle, Str $prefix, Str $message) {
    for $message.split("\n") {
        try $handle.say("{DateTime.now.hh-mm-ss} {$prefix} $_");
        try $handle.flush();
    }
}

sub broadcast(JobState $state, %job, Str $message?) {
    my $log = open-job-log(%job);
    # my $sendEmail = %job<mailto> && (%job<notifications> eq "all" || %job<notifications> ~~ "email");

    given $state {
        when job-start {
            log-to-file($log, '#', "Build started for {%job<context><jobfile>}");
            log-to-file($log, '#', "Building in {%job<context><workspace>}");
            log-to-file($log, '#', "Logging to {%job<context><log-path>}");

            # if ($sendEmail) {
            #     use Broadcast::Email;
            #     mail-job-start(%job<mailto>, %job);
            # }
        }

        when progress-command {
            log-to-file($log, '$', $message.trim);
        }

        when progress-stdout {
            log-to-file($log, 'O', $message.trim);
        }

        when progress-stderr {
            log-to-file($log, '!', $message.trim);
            say "STDERR: " ~ $message.trim;
        }

        when job-end {
            log-to-file($log, '#', "Build complete");

            # if ($sendEmail) {
            #     use Broadcast::Email;
            #     mail-job-end(%job<mailto>, %job);
            # }
        }

        when job-fail {
            log-to-file($log, '#', "Build failed: {$message}");

            # if (%job<mailto>) {
            #     use Broadcast::Email;
            #     mail-job-fail(%job<mailto>, %job);
            # }
        }
    }
}

sub do-command(%job, Str $command) {
}

our proto build(IO::Path $path) {*}

multi sub build(IO::Path $path where *.f) {
    my %job = load-job($path);

    my IO::Path $archive = archive-path(%job<context><buildroot>);
    rename($path, $archive.add($path.basename));

    broadcast(job-start, %job);

    indir(%job<context><checkout>, {
        for %job<context><recipe>.list {
            my $command = $_;
            broadcast(progress-command, %job, $command);

            my $proc = Proc::Async.new(«$command»);

            react {
                whenever $proc.stdout.lines {
                    broadcast(progress-stdout, %job, $_);
                }

                whenever $proc.stderr {
                    broadcast(progress-stderr, %job, $_);
                }

                whenever $proc.start {
                    if (.exitcode !== 0) {
                        die "Command exited non-zero ({.exitcode})";
                    }

                    done;
                }
            }
        }
    });

    broadcast(job-end, %job);

    CATCH {
        when X::AdHoc {
            broadcast(job-fail, %job, .payload);
        }

        default {
            broadcast(job-fail, %job, .Str);
        }
    }

    LEAVE {
        try close-job-log(%job);
    }
}

multi sub build(IO::Path $buildroot where *.d) {
    my $inbox = inbox-path($buildroot);
    my IO::Path $job = $inbox.dir(test => /'.' json $/).first();

    return unless $job;

    build($job);
    build($buildroot);
}
