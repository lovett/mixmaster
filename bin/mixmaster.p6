#!/usr/bin/env perl6

use Config::INI;

constant INPROGRESS_FOLDER = 'INPROGRESS';
constant INBOX_FOLDER = 'INBOX';
constant BUILDS_FOLDER = 'BUILDS';

sub run($buildRoot, $command, $log) {
    indir($buildRoot, {
        react {
            with Proc::Async.new(«$command») {
                whenever .stdout.lines {
                    $log.say('OUT ', $_);
                }

                whenever .stderr {
                    $log.say('ERR ', $_);
                }

                whenever .start {
                    done;
                }
            }
        }
    });
}

sub checkoutCommand($buildRoot, %pairs) {
    my $command;

    if (%pairs<scm>.lc eq "git") {
        $command = "git clone {%pairs<repositoryUrl>} --quiet --depth 1 --branch {%pairs<target>} .";

        if ($buildRoot.add(".git").d) {
            $command = "git pull";
        }
    }

    return $command;
}

sub build($buildRoot, %pairs, $log) {
    say "Invoking {%pairs<build_command>}";
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
    say "Processing $inboxJob";

    my %job = Config::INI::parse_file($inboxJob.path);

    my $workspace = BUILDS_FOLDER.IO.add(%job<job><repositoryName>);

    my $archive = $workspace.add('ARCHIVE');
    unless ($archive.IO.d) {
        mkdir($archive);
    }

    my $buildRoot = $workspace.add(%job<job><target>);
    unless ($buildRoot.IO.d) {
        mkdir($buildRoot);
    }

    my $archivedJob = $archive.add($inboxJob.basename);
    rename($inboxJob, $archivedJob);

    unless INPROGRESS_FOLDER.IO.d {
        mkdir(INPROGRESS_FOLDER);
    }

    my $progressSymlink = INPROGRESS_FOLDER.IO.add($archivedJob.basename);
    symlink($archivedJob, $progressSymlink);

    my $log = $archive.add(($archivedJob.extension: 'out').basename).open(:w);

    say "Build {$archivedJob.basename} begins";

    my $checkoutCommand = checkoutCommand($buildRoot, %job<job>);

    run($buildRoot, $checkoutCommand, $log);

    say "Build {$archivedJob.basename} finished";

    CATCH {
        default {
            say "Build {$archivedJob.basename} fizzled";

            spurt $archivedJob, :append, qq:to/END/;

            [build]
            message = {.message}
            exitcode = -1
            END
        }
    }

    LEAVE {
        unlink($progressSymlink);
    }
}
