unit module Filesystem;

sub systemd-service-paths(--> Seq) is export {
    my $filenames = <
        mixmaster.service
        mixmaster-bridge.socket
        mixmaster-bridge@.service
        mixmaster.path
    >;

    return $filenames.map: { "{$*HOME}/.config/systemd/user/".IO.add($_) };
}

sub inbox-path(IO::Path $root --> IO::Path) is export {
    return $root.add("INBOX");
}

sub archive-path(IO::Path $root --> IO::Path) is export {
    return $root.add("ARCHIVE");
}

sub archive-job(IO::Path $path where *.f) is export {
    my $root = nearest-root($path);
    my $archive = archive-path($root);
    rename($path, $archive.add($path.basename));
}

sub nearest-root(IO::Path $origin --> IO::Path) is export {
    my $path = $origin.d ?? $origin !! $origin.parent();
    repeat {
        last if inbox-path($path).d;
        $path = $path.parent();
    } while ($path);

    return $path;
}

sub config-path(IO::Path $root --> IO::Path) is export {
    return $root.add("mixmaster.ini");
}

sub job-path(IO::Path $root --> IO::Path) is export {
    my $inbox = inbox-path($root);
    my $filename = DateTime.now(
        formatter => sub ($self) {
            sprintf "%04d%02d%02d-%02d%02d%02d.json",
            .year, .month, .day, .hour, .minute, .whole-second given $self;
        }
    );

    return $inbox.add($filename);
}

sub filesystem-friendly(Str $value) is export {
    return $value.lc.subst(/\W/, "-", :g);
}

sub create-job(IO::Path $root, Buf $body) is export {
    my IO::Path $job = job-path($root);
    spurt $job, $body;
}

sub create-directory(IO::Path $path) is export {
    try {
        mkdir($path);

        CATCH {
            when X::IO::Mkdir {
                die("Unable to create {$path}");
            }
        }
    }
}

# Local Variables:
# mode: raku
# End:
