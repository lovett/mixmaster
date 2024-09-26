#!/usr/bin/env rakudo

use Test;

my $mixmaster = $*PROGRAM.IO.parent(2).add('bin/mixmaster');
my $fixture = $*PROGRAM.IO.parent().add('fixture/gitea.http');
my $root = "/tmp/mixmaster";
my $workspace = $root.IO.add("example-org-example-repo");

sub MAIN() is test-assertion {
    run $mixmaster, qqw{--root $root setup} unless $root.IO.d;

    for dir($root.IO.add("INBOX")) -> $file {
        $file.unlink if $file.IO.f;
    }

    for dir($root.IO.add("ARCHIVE")) -> $file {
        $file.unlink if $file.IO.f;
    }

    for dir($workspace.add("ARCHIVE")) -> $file {
        $file.unlink if $file.IO.f;
    }

    my $proc = run $mixmaster, qqw{--root $root bridge}, :in;
    $proc.in.print($fixture.IO.slurp);
    $proc.in.close();


    run $mixmaster, qqw{--root $root build}, :in;

    is dir($root.IO.add("INBOX")).elems, 0, "Job file was moved out of INBOX";
    is dir($root.IO.add("ARCHIVE")).elems, 1, "Job file was moved into ARCHIVE";

    is $workspace.d, True, "Workspace was created";
    is $workspace.add("ARCHIVE").d, True, "Workspace archive was created";
    is $workspace.add("production").d, True, "Workspace target directory was created";
    is dir($workspace.add("ARCHIVE")).elems, 1, "Workspace log was created";

}
