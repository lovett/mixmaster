#!/usr/bin/env rakudo

use Test;
use JSON::Fast;

my $mixmaster = $*PROGRAM.IO.parent(2).add('bin/mixmaster');
my $fixture = $*PROGRAM.IO.parent().add('fixture/freestyle.http');
my $root = "/tmp/mixmaster";

sub MAIN() is test-assertion {
    run $mixmaster, qqw{--root $root setup} unless $root.IO.d;

    my $proc = run $mixmaster, qqw{--root $root bridge}, :in;
    $proc.in.print($fixture.IO.slurp);
    $proc.in.close();

    my IO::Path @jobs = $root.IO.add("INBOX").dir(test => /'.' json $/);

    is @jobs.tail.IO.f, True, "Job file was created in INBOX";

    my %job = from-json(@jobs.tail.IO.slurp // "\{}");

    is %job<scm>, "freestyle", "Job file matches freestyle fixture";
}
