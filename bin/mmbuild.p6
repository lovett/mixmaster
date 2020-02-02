#!/usr/bin/env rakudo

use lib '/usr/local/share/mixmaster/lib';
use lib 'lib';

use Config::INI;

our Str constant SCRIPT_VERSION = "2020.01.31";

our IO::Path constant CONFIG = $*HOME.add(".config/mixmaster.ini");

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
    try $logHandle.flush();
}

# Dispatcher for tracking job progress in local logs and external proceesses.
sub broadcast(JobState $state, %job, Str $message?) {
    given $state {
        when job-start {
            log-to-file('#', 'Build started');

            log-to-journal(%job<path>.basename, 'Build started');

            if (%job<mailto>) {
                use Broadcast::Email;
                mail-job-start(%job<mailto>, %job);
            }
        }

        when job-end {
            my $success = 'Build finished';
            log-to-file('#', $success);
            log-to-journal(%job<path>.basename, $success);

            if (%job<mailto>) {
                use Broadcast::Email;
                mail-job-end(%job<mailto>, %job);
            }
        }

        when job-fail {
            log-to-file('#', "Build failed: {$message}");
            log-to-journal(%job<path>.basename, 'Build failed.');

            if (%job<mailto>) {
                use Broadcast::Email;
                mail-job-fail(%job<mailto>, %job);
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
                    die "Command exited non-zero ({.exitcode})";
                }

                done;
            }
        }
    });
}

sub gitRecipe(IO::Path $buildRoot, %pairs) {
    my Str @commands;

    unless ($buildRoot.add('.git').d) {
        @commands.push: "git clone --quiet --branch {%pairs<branch>} {%pairs<repositoryUrl>} .";
    }

    @commands.push: "git checkout --quiet {%pairs<commit>}";
    @commands.push: %pairs<buildCommand>;

    if (%pairs<mode> ~~ "dryrun") {
        return ("echo $_" for @commands);
    }

    return @commands;
}

multi sub MAIN(Bool :$version) {
    if ($version) {
        say SCRIPT_VERSION;
        exit;
    }

    my %config{Str} = Config::INI::parse_file(Str(CONFIG));

    my IO::Path @jobs = dir(%config<_><spool>, test => /'.' ini $/).sort: { .changed };

    unless (@jobs) {
        say 'No jobs found.';
        exit;
    }

    MAIN(@jobs.first);
}

multi sub MAIN(IO::Path $jobFile) {
    my %config{Str} = Config::INI::parse_file(Str(CONFIG));

    my %job{Str} = Config::INI::parse_file($jobFile.path);

    unless (%job<job>:exists) {
        try unlink($jobFile);
        say "No job details in {$jobFile.basename}. File deleted.";
        return;
    }

    %job = %job<job>;
    %job<path> = $jobFile.IO;

    my $fsFriendlyRepositoryName = %job<repositoryName>.lc;
    $fsFriendlyRepositoryName ~~ s:global/\W/-/;

    my $fsFriendlyBranch = %job<branch>.lc;
    $fsFriendlyBranch ~~ s:global/\W/-/;


    my IO::Path $workspace = %config<_><buildRoot>.IO.add($fsFriendlyRepositoryName);

    my IO::Path $jobArchive = $workspace.add('JOBS');

    my IO::Path $buildRoot = $workspace.add($fsFriendlyBranch);

    my IO::Path $logFile = $jobArchive.add(($jobFile.extension: 'log').basename);

    unless ($jobArchive.d) {
        mkdir($jobArchive);
    }

    unless ($buildRoot.d) {
        mkdir($buildRoot);
    }

    $jobFile.move($logFile);
    %job<path> = $logFile.IO;

    $logHandle = $logFile.open(:a);
    $logHandle.say("pid = {$*PID}");
    $logHandle.say("\n\n[log]");
    say $logHandle.^name;

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
        when X::AdHoc {
            broadcast(job-fail, %job, .payload);
        }

        default {
            broadcast(job-fail, %job, .Str);
        }
    }

    LEAVE {
        try close $logHandle;
    }
}
