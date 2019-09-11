#!/usr/bin/env perl6

use JSON::Fast;
use Config::INI;

constant REFMAP_PATH = 'refs.ini';

sub MAIN() {
    my %headers;

    my %refMap = Config::INI::parse_file(REFMAP_PATH);

    for lines() {
        unless %headers<method>:exists {
            my ($method, $uri, $version) = $_.split(' ', 3);
            %headers.append('method', $method);
            %headers.append('uri', $uri);
            %headers.append('version', $version);
            next;
        }

        if ($_.contains(':')) {
            my ($key, $value) = $_.split(':', 2);
            %headers{$key.lc.trim} = val($value);
            next;
        }

        unless ($_.trim) {
            last;
        }
    }

    my $body = $*IN.read(%headers<content-length>);

    my %json = from-json $body.decode;

    my $repositoryName = %json<repository><full_name>;

    my $repositoryTarget = %json<ref>.subst("refs/heads/", "", :nth(1));

    unless (%refMap{$repositoryName}:exists) {
        put "HTTP/1.1 422 Unknown repository\r\n";
        exit;
    }

    my @matchedTargets = %refMap{$repositoryName}.pairs.grep: {
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

    my ($matchedTarget, $buildCommand) = @matchedTargets.first.kv;

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
