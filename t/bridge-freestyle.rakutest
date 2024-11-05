#!/usr/bin/env rakudo

use Test;
use JSON::Fast;

my $mixmaster = $*PROGRAM.IO.parent(2).add('bin/mixmaster');
my $fixture = $*PROGRAM.IO.parent().add('fixture/freestyle.json');
my $root = "/tmp/mixmaster";

sub MAIN() is test-assertion {
    run $mixmaster, qqw{--root $root setup} unless $root.IO.d;

    my $job = $fixture.IO.slurp;

    my $proc = run $mixmaster, qqw{--root $root bridge}, :in;
    $proc.in.print: qq:to/HEADERS/;
    POST / HTTP/1.0
    Content-Type: application/json
    Remote-Addr: 127.0.0.1
    Connection: close
    Content-Length: {$job.chars}

    {$job}
    HEADERS

    $proc.in.close();

    my IO::Path @jobs = $root.IO.add("INBOX").dir(test => /'.' json $/);

    is @jobs.tail.IO.f, True, "Job file was created in INBOX";

    my %job = from-json(@jobs.tail.IO.slurp // "\{}");

    is %job<scm>, "freestyle", "Job file matches freestyle fixture";
}
