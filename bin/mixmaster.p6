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
    try $handle.say("{DateTime.now.hh-mm-ss} {$prefix} $message");
}

sub doCommand($buildRoot, $command, $logHandle) {
    indir($buildRoot, {
        react {
            with Proc::Async.new(«$command») {
                whenever .stdout.lines {
                    log($logHandle, 'O', $_);
                }

                whenever .stderr {
                    log($logHandle, '!', $_);
                }

                whenever .start {
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
    my $jobName = $jobFile.basename;


    my %job = Config::INI::parse_file($jobFile.path);

    my $workspace = BUILDS_FOLDER.IO.add(%job<job><repositoryName>);

    my $archive = $workspace.add('ARCHIVE');

    my $buildRoot = $workspace.add(%job<job><target>);

    my $archiveFile = $archive.add($jobName);

    my $logFile = $archive.add(($jobFile.extension: 'log').basename);

    unless ($archive.IO.d) {
        mkdir($archive);
    }

    unless ($buildRoot.IO.d) {
        mkdir($buildRoot);
    }

    $logSymlink = INPROGRESS_FOLDER.IO.add($logFile.basename);

    $logHandle = $logFile.open(:w);


    $jobFile.rename($archiveFile);

    journal($jobName, "Starting build, logging to {$logHandle.path}");
    log($logHandle, '#', 'Build start');

    $logFile.symlink($logSymlink);

    my @buildRecipe;
    given %job<job><scm>.lc {
        when "git" { @buildRecipe = gitRecipe($buildRoot, %job<job>) }
    }

    for @buildRecipe {
        log($logHandle, '$', $_);
        doCommand($buildRoot, $_, $logHandle);
    }

    CATCH {
        default {
            journal($jobName, 'Build failed');
            log($logHandle, '#', "Build {$jobFile.basename} failed");
            log($logHandle, '#', .message);
        }
    }

    LEAVE {
        journal($jobName, 'Finished');
        unlink($logSymlink);
        log($logHandle, '#', 'Build finished');
        try close $logHandle;
    }
}
