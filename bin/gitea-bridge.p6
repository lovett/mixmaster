#!/usr/bin/env perl6

use lib 'lib';

use Config::INI;
use Bridge;

our Str constant REFMAP_PATH = 'refs.ini';

sub MAIN() {
    my Hash %refMap{Str} = Config::INI::parse_file(REFMAP_PATH);

    my Str %headers{Str};

    for lines() {
        parse-headers($_, &%headers);

        unless ($_.trim) {
            last;
        }
    }

    my %json{Str} = parse-json-body(%headers<content-length>);

    my Str $repositoryName = %json<repository><full_name>;

    my Str $repositoryBranch = %json<ref>.subst("refs/heads/", "", :nth(1));

    unless (%refMap{$repositoryName}:exists) {
        send-error-response("Unknown repository");
        exit;
    }

    my Pair @matchedBranchs = %refMap{$repositoryName}.pairs.grep: {
        .key.starts-with($repositoryBranch)
    };

    unless (@matchedBranchs) {
        send-error-response("Unknown branch");
        exit;
    }

    if (@matchedBranchs.elems > 1) {
        send-error-response("Multiple matches for this branch");
        exit;
    }

    my (Str $matchedBranch, Str $buildCommand) = @matchedBranchs.first.kv;

    my $jobFileName = generate-job-file-name();

    spurt "INBOX/{$jobFileName}", qq:to/END/;
    [job]
    scm = git
    repositoryName = $repositoryName
    repositoryUrl = {%json<repository><ssh_url>}
    commit = {%json<after>}
    branch = $matchedBranch
    build_command = $buildCommand
    view_url = {%json<compare_url>}
    END

    send-success-response();

    CATCH {
        send-failure-response();
    }
}
