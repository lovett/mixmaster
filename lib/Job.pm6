unit module Job;

use Config;
use IniEncode;
use HttpResponse;
use JSON::Fast;

sub generate-job-file-name() is export {
    DateTime.now(
        formatter => sub ($self) {
            sprintf "%04d%02d%02d-%02d%02d%02d.ini",
            .year, .month, .day, .hour, .minute, .whole-second given $self;
        }
    );
}

sub accept-job(Buf $body, Str $endpoint) is export {
    my Hash %config{Str} = get-config();

    my %json{Str} = from-json $body.decode;

    my Str $scm = "";
    my Str $repositoryUrl = "";
    my Str $project = "";
    my Str $target = "";
    my Str $commit = "";
    my Str $task = "";
    my Str $notifications = "all";
    my Str $viewUrl = "";
    my %messages;

    given $endpoint {
        when "/gitea" {
            $scm = "git";
            $repositoryUrl = %json<repository><ssh_url>;
            $project = %json<repository><full_name>;
            $target = %json<ref>.subst("refs/heads/", "", :nth(1));
            $commit = %json<after>;
            $viewUrl = %json<compare_url>;

            for |%json<commits> -> %commit {
                say %commit<id>;
            }

            if (%json<commits>:exists) {
                for |%json<commits> -> %commit {
                    %messages{"{%commit<timestamp>},{%commit<id>}"} = %commit<message>;
                }

                unless ($viewUrl) {
                    $viewUrl = %json<commits>.first<url>;
                }
            }
        }

        when "/" {
            for <scm repositoryUrl project target> {
                unless (%json{$_}:exists) {
                    send-error-response("$_ not specified");
                    exit;
                }
            }

            $scm = %json<scm>;
            $repositoryUrl = %json<repositoryUrl>;
            $project = %json<project>;
            $target = %json<target>;

            if (%json<notifications>:exists) {
                $notifications = %json<notifications>;
            }

            if (%json<viewUrl>:exists) {
                $viewUrl = %json<viewUrl>;
            }

            if (%json<commit>:exists) {
                $commit = %json<commit>;
            }

            if (%json<task>:exists) {
                $task = %json<task>;
            }

            if (%json<message>:exists) {
                %messages{$commit} = %json<message>;
            }
        }

        default {
            send-notfound-response();
            exit;
        }
    }

    unless (%config{$project}:exists) {
        send-error-response("Unknown project");
        exit;
    }

    my Pair @matchedTargets = %config{$project}.pairs.grep: {
        .key.starts-with($target)
    };

    unless (@matchedTargets) {
        send-error-response("Not set up to build {$target}");
        exit;
    }

    if ($task) {
        @matchedTargets = @matchedTargets.grep: {
            .key.starts-with("{$target}/{$task}");
        };
    }

    unless (@matchedTargets) {
        send-error-response("Not set up for {$task} task.");
        exit;
    }

    if (@matchedTargets.elems > 1) {
        my @keys = (.key for @matchedTargets);
        send-error-response("Configuration for {$target} is ambiguous. Could be {@keys.join(' or ')}.");
        exit;
    }

    my (Str $matchedTarget, Str $buildCommand) = @matchedTargets.first.kv;

    my $jobFileName = generate-job-file-name();

    my $commitSection = '';
    for %messages.kv -> $key, $message {
        $commitSection ~= "commit-{$key} = {encode-ini-value($message)}\n";
    }

    spurt "{%config<_><spool>}/{$jobFileName}", qq:to/END/;
    [job]
    scm = $scm
    project = $project
    repositoryUrl = $repositoryUrl
    commit = $commit
    task = $task
    target = $target
    buildCommand = $buildCommand
    viewUrl = $viewUrl
    mailto = {%config<_><mailto> or ''}
    mode = {%config<_><mode> or 'normal'}
    notifications = $notifications
    {$commitSection}
    END

    send-success-response();

    CATCH {
        send-failure-response();
    }
}
