#!/usr/bin/env perl6

use lib 'modules';
use JSON::Fast;
use Config::INI;

my %headers;

my %config = Config::INI::parse_file('refs.ini');

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
        say "Done reading headers";
        last;
    }
}

my $body = $*IN.read(%headers<content-length>);

my %json = from-json $body.decode;

my $repository = %json<repository><full_name>;

my $ref = %json<ref>;

unless (%config{$repository}:exists) {
    put "HTTP/1.1 422 Unknown repository\r\n";
    exit;
}

my @matchedRefs = %config{$repository}.pairs.grep: {
    "refs/{$_.key}".starts-with($ref)
};

unless (@matchedRefs) {
    put "HTTP/1.1 422 Unknown ref\r\n";
    exit;
}

if (@matchedRefs.elems > 1) {
    put "HTTP/1.1 422 Multiple matches for this ref\r\n";
    exit;
}

my ($matchedRef, $buildCommand) = @matchedRefs.first.kv;

spurt "INBOX/{(roll 12, 'a'..'z').join}.ini", qq:to/END/;
[job]
checkout_url = {%json<repository><ssh_url>}
ref = $ref
commit = {%json<after>}
build_command = $buildCommand
view_url = {%json<compare_url>}
END

put "HTTP/1.1 204 No Content\r\n";
put "Connection: close\r\n";

CATCH {
    put "HTTP/1.0 400 Bad Request\r\n";
}
