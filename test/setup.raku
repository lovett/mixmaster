#!/usr/bin/env rakudo

use Test;

my $mixmaster = $*PROGRAM.IO.parent(2).add('bin/mixmaster');
my $root = "/tmp/mixmaster";

sub MAIN() is test-assertion {
    run 'rm', <-r -f>, $root if $root.IO.d;

    run $mixmaster, qqw{--root $root setup};

    is $root.IO.d, True, "Root created at $root";
    is $root.IO.add("INBOX").d, True, "INBOX was created in root";
    is $root.IO.add("ARCHIVE").d, True, "ARCHIVE was created in root";
    is $root.IO.add("mixmaster.ini").f, True, "mixmaster.ini was created in root";
}
