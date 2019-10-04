#!/usr/bin/env perl6

use Config::INI;

constant INPROGRESS_FOLDER = 'INPROGRESS';
constant INBOX_FOLDER = 'INBOX';
constant BUILDS_FOLDER = 'BUILDS';

my $logSymlink;
my $logHandle;

INIT {
    unless INPROGRESS_FOLDER.IO.d {
        mkdir(INPROGRESS_FOLDER);
    }
}

signal(SIGTERM).tap: {
    log($logHandle, 'X', 'Killed by SIGTERM');
    unlink($logSymlink);
    try close $logHandle;
}

# Log a message to the systemd journal.
#
# This is for tracking job status. Build-specific information should
# be writen to a job-specific log file via log().
sub journal($prefix, $message) {
    say("[{$prefix}] $message");
}

# Log a message to a job-specific log file.
#
# This is the job-centric counterpart to journal().
sub log($handle, $prefix, $message) {
    try $handle.say("{DateTime.now.hh-mm-ss} {$prefix} $_")
    for $message.split("\n");
}

sub doCommand($buildRoot, $command, $logHandle) {
    indir($buildRoot, {
        react {
            with Proc::Async.new(«$command») {
                whenever .stdout.lines {
                    log($logHandle, 'O', $_.trim);
                }

                whenever .stderr {
                    log($logHandle, '!', $_.trim);
                }

                whenever .start {
                    if (.exitcode !== 0) {
                        die "command exited non-zero ({.exitcode})";
                    }

                    done;
                }

            }
        }
    });
}

sub gitRecipe($buildRoot, %pairs) {
    my @commands;

    unless ($buildRoot.add('.git').d) {
        @commands.push: "git clone {%pairs<repositoryUrl>} --quiet --branch {%pairs<target>} .";
    }

    @commands.push: "git checkout --quiet {%pairs<commit>}";
    @commands.push: %pairs<build_command>;

    return @commands;
}

multi sub MAIN() {
    my @jobs = dir(INBOX_FOLDER, test => /'.' ini $/).sort: { .changed };;

    unless (@jobs) {
        say 'No jobs found.';
        exit;
    }

    MAIN(@jobs.first);
}

multi sub MAIN($jobFile) {
    my %job = Config::INI::parse_file($jobFile.path);

    my $workspace = BUILDS_FOLDER.IO.add(%job<job><repositoryName>);

    my $jobArchive = $workspace.add('JOBS');

    my $buildRoot = $workspace.add(%job<job><target>);

    my $logFile = $jobArchive.add($jobFile.basename);

    unless ($jobArchive.IO.d) {
        mkdir($jobArchive);
    }

    unless ($buildRoot.IO.d) {
        mkdir($buildRoot);
    }

    $logSymlink = INPROGRESS_FOLDER.IO.add($logFile.basename);

    $jobFile.rename($logFile);

    $logHandle = $logFile.open(:a);

    log($logHandle, '', "\n\n[log]");

    log($logHandle, '#', 'Build started');
    journal($logFile.basename, "Starting {$logFile.path}");

    $logFile.symlink($logSymlink);

    my @buildRecipe;
    given %job<job><scm>.lc {
        when "git" { @buildRecipe = gitRecipe($buildRoot, %job<job>) }
    }


    for @buildRecipe {
        log($logHandle, '$', $_);
        doCommand($buildRoot, $_, $logHandle);
    }

    log($logHandle, '#', 'Build finished');
    journal($logFile.basename, 'Build finished');

    CATCH {
        default {
            log($logHandle, '#', "Build failed: {.payload}");
            journal($logFile.basename, 'Build failed');
        }
    }

    LEAVE {
        unlink($logSymlink);
        try close $logHandle;
    }
}
