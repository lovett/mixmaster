#!/usr/bin/env rakudo

use Test;

my $mixmaster = $*PROGRAM.IO.parent(2).add('bin/mixmaster');
my $job-fixture = $*PROGRAM.IO.parent().add('fixture/gitea.json');
my $recipe-fixture = $*PROGRAM.IO.parent().add('fixture/gitea.recipe');
my $root = "/tmp/mixmaster";

sub MAIN() is test-assertion {
    run $mixmaster, qqw{--root $root setup} unless $root.IO.d;

    my $job-file = $root.IO.add("INBOX").add($job-fixture.basename);

    copy($job-fixture, $job-file);

    my $proc = run $mixmaster, qqw{--job $job-file recipe}, :out;
    my $recipe = $proc.out.slurp: :close;

    my $expected-recipe = $recipe-fixture.IO.slurp;

    for $expected-recipe.lines.kv -> $i, $_ {
        is $recipe.lines[$i] eq $_, True, "Line {$i+1} of recipe matches fixture";
    }
}
