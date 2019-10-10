#!/usr/bin/env perl6

use JSON::Fast;
use Config::INI;

our Str constant REFMAP_PATH = 'refs.ini';

sub MAIN() {
    my Str %headers{Str};

    my Hash %refMap{Str} = Config::INI::parse_file(REFMAP_PATH);

    for lines() {
        unless %headers<method>:exists {
            my (Str $method, Str $uri, Str $version) = $_.split(' ', 3);
            %headers.append('method', $method);
            %headers.append('uri', $uri);
            %headers.append('version', $version);
            next;
        }

        if ($_.contains(':')) {
            my (Str $key, Str $value) = $_.split(':', 2);
            %headers{$key.lc.trim} = val($value);
            next;
        }

        unless ($_.trim) {
            last;
        }
    }

    my Buf $body = $*IN.read(%headers<content-length>);

    my %json{Str} = from-json $body.decode;

    my Str $repositoryName = %json<repository><full_name>;

    my Str $repositoryTarget = %json<ref>.subst("refs/heads/", "", :nth(1));

    unless (%refMap{$repositoryName}:exists) {
        put "HTTP/1.1 422 Unknown repository\r\n";
        exit;
    }

    my Pair @matchedTargets = %refMap{$repositoryName}.pairs.grep: {
        .key.starts-with($repositoryTarget)
    };

    unless (@matchedTargets) {
        put "HTTP/1.1 422 Unknown target\r\n";
        exit;
    }

    if (@matchedTargets.elems > 1) {
        put "HTTP/1.1 422 Multiple matches for this target\r\n";
        exit;
    }

    my (Str $matchedTarget, Str $buildCommand) = @matchedTargets.first.kv;

    spurt "INBOX/{(roll 12, 'a'..'z').join}.ini", qq:to/END/;
    [job]
    scm = git
    repositoryName = $repositoryName
    repositoryUrl = {%json<repository><ssh_url>}
    commit = {%json<after>}
    target = $matchedTarget
    build_command = $buildCommand
    view_url = {%json<compare_url>}
    END

    put "HTTP/1.1 204 No Content\r\n";
    put "Connection: close\r\n";

    CATCH {
        put "HTTP/1.0 400 Bad Request\r\n";
    }
}
