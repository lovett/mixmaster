#!/usr/bin/env perl6

use lib 'lib';

use Config::INI;
use Bridge;

our Str constant REFMAP_PATH = 'refs.ini';

sub MAIN() {
    my Str %headers{Str};

    my Hash %refMap{Str} = Config::INI::parse_file(REFMAP_PATH);

    for lines() {
        parse-headers($_, &%headers);

        unless ($_.trim) {
            last;
        }
    }

    my %json{Str} = parse-json-body(%headers<content-length>);

    for <scm repositoryUrl repositoryName commit branch> {
        unless (%json{$_}) {
            send-error-response("$_ not specified");
            exit;
        }
    }

    my Str $repositoryName = %json<repositoryName>;

    unless (%refMap{$repositoryName}:exists) {
        send-error-response("Unknown repository");
        exit;
    }

    my Pair @matchedBranches = %refMap{$repositoryName}.pairs.grep: {
        .key.starts-with(%json<branch>)
    };

    unless (@matchedBranches) {
        send-error-response("Unknown branch");
        exit;
    }

    if (@matchedBranches.elems > 1) {
        send-error-response("Multiple matches for this branch");
        exit;
    }

    my (Str $matchedBranch, Str $buildCommand) = @matchedBranchs.first.kv;

    my $jobFileName = generate-job-file-name();

    spurt "INBOX/{$jobFileName}", qq:to/END/;
    [job]
    scm = {%json<scm>}
    repositoryName = $repositoryName
    repositoryUrl = {%json<repositoryUrl>}
    commit = {%json<commit>}
    branch = $matchedBranch
    buildCommand = $buildCommand
    viewUrl = {%json<viewUrl>}
    END

    send-success-response();

    CATCH {
        send-failure-response();
    }
}
