unit package Command;

use Filesystem;
use Console;

our sub service(IO::Path $buildroot) is export {
    for systemd-service-paths() {
        mkdir($_.parent);
        create-systemd-service($_, $buildroot);
        success-message("Created {$_}.");
    }
}

multi sub create-systemd-service(
    IO::Path $path where *.basename eq "mixmaster.service",
    IO::Path $buildroot
) is export {
    my $proc = run <which ssh-agent>, :out;
    my $sshAgent = $proc.out.get;
    $proc.out.close();

    spurt $path, qq:to/END/;
    [Unit]
    Description=Mixmaster

    [Service]
    WorkingDirectory={$buildroot}
    ExecStart={$sshAgent} {$*PROGRAM.absolute} --buildroot {$buildroot.absolute} build

    # Local Variables:
    # mode: conf
    # End:

    END
}

multi sub create-systemd-service(
    IO::Path $path where *.basename eq "mixmaster-bridge.socket",
    IO::Path $buildroot
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
    IO::Path $buildroot
) is export {
    spurt $path, qq:to/END/;
    [Unit]
    Description=Mixmaster Bridge

    [Service]
    StandardInput=socket
    StandardError=journal
    ExecStart={$*PROGRAM.absolute} --buildroot {$buildroot.absolute} bridge

    # Local Variables:
    # mode: conf
    # End:

    END
}

multi sub create-systemd-service(
    IO::Path $path where *.basename eq "mixmaster.path",
    IO::Path $buildroot
) is export {
    spurt $path, qq:to/END/;
    [Unit]
    Description=Mixmaster

    [Path]
    DirectoryNotEmpty={inbox-path($buildroot)}
    MakeDirectory=true
    DirectoryMode=0700

    [Install]
    WantedBy=default.target

    # Local Variables:
    # mode: conf
    # End:

    END
}
