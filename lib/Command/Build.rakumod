unit module Command::Build;

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
use Broadcast;


# signal(SIGTERM).tap: {
#     log-to-file('X', 'Killed by SIGTERM');
#     try close $log;
#     exit;
# }


our proto make-it-so(IO::Path $path) {*}

multi sub make-it-so(IO::Path $path where *.f) {
    my %job = load-job($path);

    my IO::Path $archive = archive-path(%job<context><buildroot>);
    rename($path, $archive.add($path.basename));

    broadcast-start(%job);

    indir(%job<context><checkout>, {
        for %job<context><recipe>.list {
            my $command = $_;
            broadcast-command(%job, $command);

            my $proc = Proc::Async.new(«$command»);

            react {
                whenever $proc.stdout.lines {
                    broadcast-stdout(%job, $_);
                }

                whenever $proc.stderr {
                    broadcast-stderr(%job, $_);
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

    CATCH {
        when X::AdHoc {
            %job<context><failed> = True;
            broadcast-fail(%job, .payload);
        }

        default {
            %job<context><failed> = True;
            broadcast-fail(%job, .Str);
        }
    }

    LEAVE {
        broadcast-end(%job);
    }
}

multi sub make-it-so(IO::Path $buildroot where *.d) {
    my $inbox = inbox-path($buildroot);
    my IO::Path $job = $inbox.dir(test => /'.' json $/).first();

    return unless $job;

    make-it-so($job);
    make-it-so($buildroot);
}
