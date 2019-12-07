#!/usr/bin/env perl6

use lib 'lib';

use Config::INI;

our IO::Path constant INPROGRESS_FOLDER = IO::Path.new('INPROGRESS');
our IO::Path constant INBOX_FOLDER = IO::Path.new('INBOX');
our IO::Path constant BUILDS_FOLDER = IO::Path.new('BUILDS');

my IO::Path $logSymlink;
my IO::Handle $logHandle;

enum JobState <job-start job-end job-fail>;

INIT {
    unless INPROGRESS_FOLDER.d {
        mkdir(INPROGRESS_FOLDER);
    }
}

signal(SIGTERM).tap: {
    log-to-file('X', 'Killed by SIGTERM');
    try unlink($logSymlink);
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
    my $email-recipient = %*ENV<MIXMASTER_BROADCAST_EMAIL>;

    given $state {
        when job-start {
            log-to-file('#', 'Build started');
            log-to-journal($logHandle.path.basename, "Starting {$logHandle.path}");

            if ($email-recipient) {
                use Broadcast::Email;
                mail-job-start($email-recipient, %job);
            }
        }

        when job-end {
            my $success = 'Build finished';
            log-to-file('#', $success);
            log-to-journal($logHandle.path.basename, $success);

            if ($email-recipient) {
                use Broadcast::Email;
                mail-job-end($email-recipient, %job);
            }
        }

        when job-fail {
            log-to-file('#', "Build failed: {$message}");
            log-to-journal($logHandle.path.basename, 'Build failed');

            if ($email-recipient) {
                use Broadcast::Email;
                mail-job-fail($email-recipient, %job, $logHandle.path);
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

    if (%*ENV<MIXMASTER_ENVIRONMENT> ~~ "dev") {
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

    my $fsFriendlyRepositoryName = %job<job><repositoryName>.lc;
    $fsFriendlyRepositoryName ~~ s:global/\W/-/;

    my $fsFriendlyBranch = %job<job><branch>.lc;
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

    $logSymlink = INPROGRESS_FOLDER.add($logFile.basename).IO;

    $jobFile.rename($logFile);

    $logHandle = $logFile.open(:a);
    $logHandle.say("pid = {$*PID}");
    $logHandle.say("\n\n[log]");

    broadcast(job-start, %job);

    $logFile.symlink($logSymlink);

    my Str @buildRecipe;
    given %job<job><scm>.lc {
        when "git" { @buildRecipe = gitRecipe($buildRoot, %job<job>) }
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
        try unlink($logSymlink);
        try close $logHandle;
    }
}
