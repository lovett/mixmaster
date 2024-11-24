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

enum JobState <job-start job-end job-fail>;

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

# Dispatcher for tracking job progress in local logs and external proceesses.
sub broadcast(JobState $state, %job, Str $message?) {
    my $log = %job<mixmaster><log>;
    # my $sendEmail = %job<mailto> && (%job<notifications> eq "all" || %job<notifications> ~~ "email");

    given $state {
        when job-start {
            log-to-file($log, '#', "Build started for {%job<_mixmaster_jobfile>}");
            log-to-file($log, '#', "Building in {%job<_mixmaster_workspace>}");
            log-to-file($log, '#', "Logging to {$log.path()}");

            # if ($sendEmail) {
            #     use Broadcast::Email;
            #     mail-job-start(%job<mailto>, %job);
            # }
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

sub doCommand(%job, Str $command) {
    my $log = %job<mixmaster><log>;
    log-to-file($log, '$', $command.trim);

    indir(%job<mixmaster><checkout>, {
        my $proc = Proc::Async.new(«$command»);

        react {
            whenever $proc.stdout.lines {
                log-to-file($log, 'O', $_.trim);
            }

            whenever $proc.stderr {
                log-to-file($log, '!', $_.trim);
                say "STDERR: " ~ $_.trim;
            }

            whenever $proc.start {
                if (.exitcode !== 0) {
                    die "Command exited non-zero ({.exitcode})";
                }

                done;
            }
        }
    });
}

our proto build(IO::Path $path) {*}

multi sub build(IO::Path $path where *.f) {
    my %job = load-job($path);

    archive-job($path);

    %job = job-recipe(%job);

    my $log-filename = %job<mixmaster><jobfile>.IO.extension: 'log';
    my $log-path = %job<mixmaster><archive>.add($log-filename.basename);
    %job<mixmaster><log> = open $log-path, :a;

    # broadcast(job-start, %job);

    for %job<mixmaster><recipe>.list {
        doCommand(%job, $_);
    }

    # broadcast(job-end, %job);

    # CATCH {
    #     when X::AdHoc {
    #         broadcast(job-fail, %job, .payload);
    #     }

    #     default {
    #         broadcast(job-fail, %job, .Str);
    #     }
    # }

    LEAVE {
        try close %job<mixmaster><log>;
    }
}

multi sub build(IO::Path $buildroot where *.d) {
    my $inbox = inbox-path($buildroot);
    my IO::Path $job = $inbox.dir(test => /'.' json $/).first();

    return unless $job;

    build($job);
    build($buildroot);
}
