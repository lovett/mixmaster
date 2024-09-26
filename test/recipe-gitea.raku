#!/usr/bin/env rakudo

use Test;

my $mixmaster = $*PROGRAM.IO.parent(2).add('bin/mixmaster');
my $fixture = $*PROGRAM.IO.parent().add('fixture/gitea.http');
my $root = "/tmp/mixmaster";

sub MAIN() is test-assertion {
    run $mixmaster, qqw{--root $root setup} unless $root.IO.d;

    my $proc = run $mixmaster, qqw{--root $root bridge}, :in;
    $proc.in.print($fixture.IO.slurp);
    $proc.in.close();

    my IO::Path $job = $root.IO.add("INBOX").dir(test => /'.' json $/).tail;

    run $mixmaster, qqw{--job $job recipe};
}
