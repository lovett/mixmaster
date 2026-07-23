unit module Filesystem;

sub inbox-path(IO::Path $path --> IO::Path) is export {
    return $path.add("INBOX");
}

sub archive-path(IO::Path $path --> IO::Path) is export {
    return $path.add("ARCHIVE");
}

sub trash-path(IO::Path $path --> IO::Path) is export {
    return $path.add("TRASH");
}

sub config-path(IO::Path $buildroot --> IO::Path) is export {
    return $buildroot.add("config.ini");
}

sub nearest-root(IO::Path $path --> IO::Path) is export {
    given $path {
        when $path.d and config-path($path).e { return $path };
        when $path eq "/" { return Nil };
        default { return nearest-root($path.parent) };
    }
}

sub filesystem-friendly(Str $value) is export {
    return $value.lc.subst(/\W+/, "-", :g);
}

multi sub resolve-tilde(IO::Path $path --> IO::Path) is export {
    return $path.subst(/^ '~'/, $*HOME).IO;
}

multi sub resolve-tilde(Str $path --> Str) is export {
    return $path.subst(/'~'/, $*HOME, :g);
}

sub with-tilde(IO::Path $path --> IO::Path) is export {
    return $path.subst(/^ $*HOME /, "~").IO;
}

sub log-path(IO::Path $path, Str $project, Str $log --> IO::Path) is export {
    my $repo = $path.add($project);
    my $archive = archive-path($repo);
    return $archive.add($log ~ '.log');
}

sub job-path(IO::Path $buildroot, Str $path --> IO::Path) is export {
    my $archive = archive-path($buildroot);
    return $archive.add($path.IO.basename).extension("json");
}

sub logs(IO::Path $buildroot, Str $project --> Seq) is export {
    my $projectDir = $buildroot.add($project);
    my $archiveDir = archive-path($projectDir);

    return dir($archiveDir).grep(*.extension eq 'log');
}
