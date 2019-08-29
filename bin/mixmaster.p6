#!/usr/bin/env perl6

use Config::INI;

constant ACTIVE_FOLDER = 'ACTIVE';
constant INBOX_FOLDER = 'INBOX';
constant BUILDS_FOLDER = 'BUILDS';


sub checkout($workspace, $repository, $ref) {
    say "Checkout $repository $ref";
}

multi sub MAIN() {
    say 'Scanning the inbox for jobs';

    my @jobs = dir(INBOX_FOLDER, test => /'.' ini $/).sort: { .changed };;

    unless (@jobs) {
        say 'No jobs found.';
        exit;
    }

    MAIN(@jobs.first);
}

multi sub MAIN($inboxJob) {
    my %job = Config::INI::parse_file($inboxJob.path);

    unless ACTIVE_FOLDER.IO.d {
        mkdir(ACTIVE_FOLDER);
    }

    my $workspace = BUILDS_FOLDER.IO.add(%job<job><repository>);
    my $buildRoot = $workspace.add(%job<job><ref>);

    unless ($buildRoot.IO.d) {
        mkdir($buildRoot);
    }

    my $activeJob = ACTIVE_FOLDER.IO.add($inboxJob.basename);
    rename($inboxJob, $activeJob);

    my $log = ACTIVE_FOLDER.IO.add(($activeJob.extension: 'out').basename).open(:w);

    say "Build {$activeJob.basename} begins (%job<job><build_command>)";

    checkout($buildRoot, %job<job><checkout_url>, %job<job><ref>);

    indir($buildRoot, {
        react {
            with Proc::Async.new(«%job<job><build_command>») {
                whenever .stdout.lines {
                    $log.say('OUT ', $_);
                }

                whenever .stderr {
                    $log.say('ERR ', $_);
                }

                whenever .start {
                    spurt $activeJob, :append, qq:to/END/;

                    [build]
                    builroot = {$buildRoot}
                    exitcode = {.exitcode}
                    END

                    done;
                }
            }
        }
    });

    say "Build {$activeJob.basename} finished";

    CATCH {
        default {
            say "Build {$activeJob.basename} fizzled";

            spurt $activeJob, :append, qq:to/END/;

            [build]
            message = {.message}
            exitcode = -1
            END
        }
    }

    LEAVE {
        my $archive = $workspace.add('ARCHIVE');
        unless ($archive.d) {
            mkdir($archive);
        }

        my $archivedJob = $archive.add($activeJob.basename);
        my $archivedLog = $archive.add($log);

        rename($activeJob, $archivedJob);
        rename($log, $archivedLog);
    }
}
