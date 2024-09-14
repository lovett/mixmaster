#!/usr/bin/env rakudo

use Test;

my $mixmaster = $*PROGRAM.IO.parent(3).add('bin/mixmaster');
my $root = "/tmp/mixmaster";

sub MAIN() is test-assertion {
    run 'rm', <-r -f>, $root if $root.IO.d;

    run $mixmaster, qqw{--root $root setup};

    is $root.IO.d, True, "Root $root was created";
    is $root.IO.add("INBOX").d, True, "INBOX was created";
    is $root.IO.add("ARCHIVE").d, True, "ARCHIVE was created";
    is $root.IO.add("mixmaster.ini").f, True, "mixmaster.ini was created";
}
