#!/usr/bin/env perl6

use lib '.local/lib';
use lib 'lib';

use Config::INI;

our IO::Path constant BUILDS_FOLDER = IO::Path.new('Builds');
our IO::Path constant INBOX_FOLDER = IO::Path.new('Builds/INBOX');

my IO::Handle $logHandle;

enum JobState <job-start job-end job-fail>;

signal(SIGTERM).tap: {
    log-to-file('X', 'Killed by SIGTERM');
    try close $logHandle;
    exit;
}

# Write a message to the systemd journal.
#
# This is for tracking job status. Build-specific information should
# be writen to a job-specific log file via log().
sub log-to-journal(Str $prefix, Str $message) {
    say("[{$prefix}] $message");
}

# Write a message to a job-specific log file.
#
# This is the job-centric counterpart to log-to-journal().
sub log-to-file(Str $prefix, Str $message) {
    try $logHandle.say("{DateTime.now.hh-mm-ss} {$prefix} $_")
    for $message.split("\n");
    $logHandle.flush();
}

# Dispatcher for tracking job progress in local logs and external proceesses.
sub broadcast(JobState $state, %job, Str $message?) {
    given $state {
        when job-start {
            log-to-file('#', 'Build started');
            log-to-journal($logHandle.path.basename, "Starting {$logHandle.path}");

            if (%job<mailto>) {
                use Broadcast::Email;
                mail-job-start(%job<mailto>, %job);
            }
        }

        when job-end {
            my $success = 'Build finished';
            log-to-file('#', $success);
            log-to-journal($logHandle.path.basename, $success);

            if (%job<mailto>) {
                use Broadcast::Email;
                mail-job-end(%job<mailto>, %job);
            }
        }

        when job-fail {
            log-to-file('#', "Build failed: {$message}");
            log-to-journal($logHandle.path.basename, 'Build failed');

            if (%job<mailto>) {
                use Broadcast::Email;
                mail-job-fail(%job<mailto>, %job, $logHandle.path);
            }
        }
    }
}

sub doCommand(IO::Path $buildRoot, Str $command, IO::Handle $logHandle) {
    indir($buildRoot, {
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
                    die "command exited non-zero ({.exitcode})";
                }

                done;
            }
        }
    });
}

sub gitRecipe(IO::Path $buildRoot, %pairs) {
    my Str @commands;

    unless ($buildRoot.add('.git').d) {
        @commands.push: "git clone {%pairs<repositoryUrl>} --quiet --branch {%pairs<branch>} .";
    }

    @commands.push: "git checkout --quiet {%pairs<commit>}";
    @commands.push: %pairs<buildCommand>;

    if (%pairs<mode> ~~ "dryrun") {
        return ("echo $_" for @commands);
    }

    return @commands;
}

multi sub MAIN() {
    my IO::Path @jobs = dir(INBOX_FOLDER, test => /'.' ini $/).sort: { .changed };;

    unless (@jobs) {
        say 'No jobs found.';
        exit;
    }

    MAIN(@jobs.first);
}

multi sub MAIN(IO::Path $jobFile) {
    my Hash %job{Str} = Config::INI::parse_file($jobFile.path);

    unless (%job<job>:exists) {
        try unlink($jobFile);
        say "No job details in {$jobFile.basename}. File deleted.";
        return;
    }

    %job = %job<job>;

    my $fsFriendlyRepositoryName = %job<repositoryName>.lc;
    $fsFriendlyRepositoryName ~~ s:global/\W/-/;

    my $fsFriendlyBranch = %job<branch>.lc;
    $fsFriendlyBranch ~~ s:global/\W/-/;

    my IO::Path $workspace = BUILDS_FOLDER.add($fsFriendlyRepositoryName);

    my IO::Path $jobArchive = $workspace.add('JOBS');

    my IO::Path $buildRoot = $workspace.add($fsFriendlyBranch);

    my IO::Path $logFile = $jobArchive.add(($jobFile.extension: 'log').basename);

    unless ($jobArchive.d) {
        mkdir($jobArchive);
    }

    unless ($buildRoot.d) {
        mkdir($buildRoot);
    }

    $jobFile.rename($logFile);

    $logHandle = $logFile.open(:a);
    $logHandle.say("pid = {$*PID}");
    $logHandle.say("\n\n[log]");

    broadcast(job-start, %job);

    my Str @buildRecipe;
    given %job<scm>.lc {
        when "git" { @buildRecipe = gitRecipe($buildRoot, %job) }
    }

    for @buildRecipe {
        log-to-file('$', $_);
        doCommand($buildRoot, $_, $logHandle);
    }

    broadcast(job-end, %job);

    CATCH {
        default {
            broadcast(job-fail, %job, .payload);
        }
    }

    LEAVE {
        try close $logHandle;
    }
}
