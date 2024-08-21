#!/usr/bin/env rakudo

# Invoke the bridge command using text files to simulate HTTP requests.

my $mixmaster = $*PROGRAM.IO.parent(3).add('bin/mixmaster');
my $root = "/tmp/test";
my @args = qqw{--root $root};

sub MAIN(Str $httpFile where *.IO.f) {
    run $mixmaster, @args, 'setup' unless $root.IO.d;

    my $proc = run $mixmaster, @args, 'bridge', :in;

    $proc.in.print($httpFile.IO.slurp);
    $proc.in.close();
}
