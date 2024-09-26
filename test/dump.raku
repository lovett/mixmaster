#!/usr/bin/env rakudo

use Test;

my $mixmaster = $*PROGRAM.IO.parent(2).add('bin/mixmaster');
my $root = "/tmp/mixmaster";

sub MAIN() is test-assertion {
    run $mixmaster, qqw{--root $root dump};
}
