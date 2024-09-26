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

sub create-config(IO::Path $path) is export {
    spurt $path, qq:to/END/;
    ; This is the configuration file for mixmaster. It maps project repositories
    ; to build commands and defines application settings.

    [_]

    ; The SSH key that should be loaded at the start of each build.
    sshKey =

    ; Use "dryrun" to echo build commands for testing purposes.
    ; Use "normal" to have build commands executed.
    mode = normal

    ; The email address that should receive build updates.
    mailto =

    ; Sample project configuration.
    [example-org/example-repo]
    production = make deploy
    staging = make deploy-to-staging
    master/my-task = make my-task

    END
}

multi sub create-systemd-service(
    IO::Path $path where *.basename eq "mixmaster.service",
    IO::Path $root
) is export {
    my $proc = run <which ssh-agent>, :out;
    my $sshAgent = $proc.out.get;
    $proc.out.close();

    spurt $path, qq:to/END/;
    [Unit]
    Description=Mixmaster

    [Service]
    WorkingDirectory={$root}
    ExecStart={$sshAgent} {$*PROGRAM.absolute} --root {$root.absolute} build

    # Local Variables:
    # mode: conf
    # End:

    END
}

multi sub create-systemd-service(
    IO::Path $path where *.basename eq "mixmaster-bridge.socket",
    IO::Path $root
) is export {
    spurt $path, qq:to/END/;
    [Unit]
    Description=Mixmaster Bridge Socket

    [Socket]
    ListenStream=8585
    Accept=yes
    ReusePort=true

    [Install]
    WantedBy = sockets.target

    # Local Variables:
    # mode: conf
    # End:

    END
}

multi sub create-systemd-service(
    IO::Path $path where *.basename eq 'mixmaster-bridge@.service',
    IO::Path $root
) is export {
    spurt $path, qq:to/END/;
    [Unit]
    Description=Mixmaster Bridge

    [Service]
    StandardInput=socket
    StandardError=journal
    ExecStart={$*PROGRAM.absolute} --root {$root.absolute} bridge

    # Local Variables:
    # mode: conf
    # End:

    END
}

multi sub create-systemd-service(
    IO::Path $path where *.basename eq "mixmaster.path",
    IO::Path $root
) is export {
    spurt $path, qq:to/END/;
    [Unit]
    Description=Mixmaster

    [Path]
    DirectoryNotEmpty={inbox-path($root)}
    MakeDirectory=true
    DirectoryMode=0700

    [Install]
    WantedBy=default.target

    # Local Variables:
    # mode: conf
    # End:

    END
}

# Local Variables:
# mode: raku
# End:
