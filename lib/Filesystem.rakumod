unit module Filesystem;

sub inbox-path(IO::Path $path --> IO::Path) is export {
    return $path.add("INBOX");
}

sub archive-path(IO::Path $path --> IO::Path) is export {
    return $path.add("ARCHIVE");
}

sub config-path(IO::Path $buildroot --> IO::Path) is export {
    return $buildroot.add("mixmaster.ini");
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
