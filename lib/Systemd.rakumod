unit module Systemd;

sub systemd-setup(IO::Path $root, IO::Path $buildRoot, Int $port) is export {
    my $proc = run <which mmbuild>, :out;
    my $mmbuild = $proc.out.get;

    $proc = run <which mmbridge>, :out;
    my $mmbridge = $proc.out.get;

    $proc = run <which mmcleanup>, :out;
    my $mmcleanup = $proc.out.get;

    $proc = run <which rakudo>, :out;
    my $rakudo = $proc.out.get;

    $proc = run <which ssh-agent>, :out;
    my $sshAgent = $proc.out.get;

    $proc.out.close();

    # Bridge socket
    my $bridgeSocket = $root.add("mixmaster-bridge.socket");
    spurt $bridgeSocket, qq:to/END/;
    [Unit]
    Description=Mixmaster Bridge Socket

    [Socket]
    ListenStream={$port}
    Accept=yes
    ReusePort=true

    [Install]
    WantedBy = sockets.target

    # Local Variables:
    # mode: conf
    # End:

    END

    say("Populated {$bridgeSocket}.");

    # Bridge service
    my $bridgeService = $root.add('mixmaster-bridge@.service');

    spurt $bridgeService, qq:to/END/;
    [Unit]
    Description=Mixmaster Bridge

    [Service]
    StandardInput=socket
    StandardError=journal
    ExecStart={$rakudo} {$mmbridge}

    # Local Variables:
    # mode: conf
    # End:

    END
    say ("Populated {$bridgeService}.");

    # Spool watcher.
    my $watcher = $root.add("mixmaster.path");

    spurt $watcher, qq:to/END/;
    [Unit]
    Description=Mixmaster

    [Path]
    DirectoryNotEmpty=/var/spool/mixmaster/{$*USER}
    MakeDirectory=true
    DirectoryMode=0700

    [Install]
    WantedBy=default.target

    # Local Variables:
    # mode: conf
    # End:

    END
    say ("Populated {$watcher}.");

    # Path service
    my $pathService = $root.add("mixmaster.service");

    spurt $pathService, qq:to/END/;
    [Unit]
    Description=Mixmaster

    [Service]
    WorkingDirectory={$buildRoot}
    ExecStart={$sshAgent} {$rakudo} {$mmbuild}
    ExecStopPost={$rakudo} {$mmcleanup}

    # Local Variables:
    # mode: conf
    # End:

    END

    say("Populated {$pathService}.");

    run <systemctl --user --quiet enable --now mixmaster-bridge.socket>;
    say("Started {$bridgeSocket}.");

    run <systemctl --user --quiet enable --now mixmaster.path>;
    say("Started {$watcher}.");

}

sub systemd-teardown(
    IO::Path $configPath,
    IO::Path $buildRoot,
    IO::Path $spool,
    IO::Path $systemdRoot
) is export {
    try {
        run <systemctl --user --quiet disable --now mixmaster.socket>, :err;
        say("✓ Stopped bridge service.");
    }

    try {
        run <systemctl --user --quiet disable --now mixmaster.path>, :err;
        say("✓ Stopped path service.");
    }

    my @fileTargets = [
        $configPath,
        $systemdRoot.add('mixmaster.service'),
        $systemdRoot.add('mixmaster-bridge.socket'),
        $systemdRoot.add('mixmaster-bridge@.service'),
        $systemdRoot.add('mixmaster.path'),
    ];

    for @fileTargets {
        if $_.f {
            $_.unlink();
            say "✓ Deleted {$_}.";
        }
    }

    for [$buildRoot, $spool] {
        if $_.d {
            say "❗ Kept {$_}.";
        }
    }
}
