unit package Command;

=begin pod

The build command takes JSON files out of the inbox and starts a build
based on their contents.

It is normally invoked by a systemd path service that watches
for changes to the inbox.

Building continues recursively until the inbox is empty.

=end pod

use JSON::Fast;
use Config;
use Job;
use Filesystem;

enum JobState <job-start job-end job-fail>;

my IO::Handle $log;

signal(SIGTERM).tap: {
    log-to-file('X', 'Killed by SIGTERM');
    try close $log;
    exit;
}

sub log-handle(Str $filename, IO::Path $workspace --> IO::Handle) {
    my $file = $filename.IO.extension: 'log';
    my $path = archive-path($workspace).add($file);
    open $path, :a;
}

sub log-to-file(Str $prefix, Str $message) {
    for $message.split("\n") {
        try $log.say("{DateTime.now.hh-mm-ss} {$prefix} $_");
        try $log.flush();
    }
}

# Dispatcher for tracking job progress in local logs and external proceesses.
sub broadcast(JobState $state, %job, Str $message?) {
    # my $sendEmail = %job<mailto> && (%job<notifications> eq "all" || %job<notifications> ~~ "email");

    given $state {
        when job-start {
            log-to-file('#', "Build started for {%job<_mixmaster_jobfile>}");
            log-to-file('#', "Building in {%job<_mixmaster_workspace>}");
            log-to-file('#', "Logging to {$log.path()}");

            # if ($sendEmail) {
            #     use Broadcast::Email;
            #     mail-job-start(%job<mailto>, %job);
            # }
        }

        when job-end {
            log-to-file('#', "Build complete");

            # if ($sendEmail) {
            #     use Broadcast::Email;
            #     mail-job-end(%job<mailto>, %job);
            # }
        }

        when job-fail {
            log-to-file('#', "Build failed: {$message}");

            # if (%job<mailto>) {
            #     use Broadcast::Email;
            #     mail-job-fail(%job<mailto>, %job);
            # }
        }
    }
}

sub doCommand(IO::Path $workspace, Str $command, IO::Handle $log) {
    log-to-file('$', $command.trim);

    indir($workspace, {
        my $proc = Proc::Async.new(«$command»);

        react {
            whenever $proc.stdout.lines {
                log-to-file('O', $_.trim);
            }

            whenever $proc.stderr {
                log-to-file('!', $_.trim);
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

    $log = log-handle($path.basename, %job<mixmaster><workspace>);

    my Str @recipe = job-recipe(%job);

    broadcast(job-start, %job);

    for @recipe {
        doCommand(%job<mixmaster><workspace>, $_, $log);
    }

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
        try close $log;
    }
}

multi sub build(IO::Path $root where *.d) {
    my $inbox = inbox-path($root);
    my IO::Path $job = $inbox.dir(test => /'.' json $/).first();

    return unless $job;

    build($job);
    build($root);
}
