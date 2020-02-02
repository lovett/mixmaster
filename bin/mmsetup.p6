#!/usr/bin/env rakudo

# This is the setup script for mixmaster, responsible for setting up
# expected directory paths and configuration.

our Str constant SCRIPT_VERSION = "2020.02.01";

sub createBuildRoot(IO::Path $path) {
    try {
        mkdir($path);
        say "Created {$path} directory.";

        CATCH {
            when X::IO::Mkdir {
                die("Unable to create {$path}");
            }
        }
    }
}

sub createConfigurationFile(
    IO::Path $configPath,
    IO::Path $buildRoot,
    IO::Path $spool,
    Str $email
) {
    spurt $configPath, qq:to/END/;
    ; This is the configuration file for mixmaster. It maps project repositories
    ; to build commands and defines application settings.

    [_]

    ; The filesystem path to the directory that will store builds.
    buildRoot = {$buildRoot}

    ; The filesystem path to the directory that stores incoming build requests.
    ; The mmbridge script will write files here, and the systemd path service
    ; will watch it for changes.
    spool = {$spool}

    ; Use "dryrun" to have mixmaster echo build commands for testing purposes.
    ; Use "normal" to have build commands executed.
    mode = normal

    ; The email address to send notifications of build progress.
    mailto = {$email}

    ; Example project configuration for a repository with two buildable branches.
    ; The production branch is built by invoking the command "make deploy".
    ; The build command for the hello-world branch is "echo Hello World"
    ; There should be one such section in this file per buildable repository.
    [example-org/example-repo]
    production = make deploy
    hello-world = echo Hello world

    END

    say "Populated {$configPath} with  default configuration."
}

sub createSystemdServices(IO::Path $root, IO::Path $buildRoot) {
    # Bridge socket
    my $bridgeSocket = $root.add("mixmaster-bridge.socket");

    spurt $bridgeSocket, qq:to/END/;
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

    say("Populated {$bridgeSocket}.");

    # Bridge service
    my $bridgeService = $root.add('mixmaster-bridge@.service');

    spurt $bridgeService, qq:to/END/;
    [Unit]
    Description=Mixmaster Bridge Service

    [Service]
    StandardInput=socket
    StandardError=journal
    ExecStart=/usr/bin/rakudo /usr/local/bin/mmbridge.p6

    # Local Variables:
    # mode: conf
    # End:

    END
    say ("Populated {$bridgeService}.");

    # Path watcher
    my $pathWatcher = $root.add("mixmaster-watcher.path");

    spurt $pathWatcher, qq:to/END/;
    [Unit]
    Description=Mixmaster inbox path watcher

    [Path]
    DirectoryNotEmpty=/var/spool/mixmaster/{$*USER}
    MakeDirectory=true
    DirectoryMode=0700

    [Install]
    WantedBy=multi-user.target

    # Local Variables:
    # mode: conf
    # End:

    END
    say ("Populated {$pathWatcher}.");

    # Path service
    my $pathService = $root.add("mixmaster-watcher.service");

    spurt $pathService, qq:to/END/;
    [Unit]
    Description=Mixmaster inbox path service

    [Service]
    WorkingDirectory={$buildRoot}
    ExecStart=/usr/bin/rakudo /usr/local/bin/mmbuild.p6

    # Local Variables:
    # mode: conf
    # End:

    END

    say("Populated {$pathService}.");

}

multi sub MAIN(
    Str  :$buildRoot = "{$*HOME}/Builds", #= Filesystem path for storing builds.
    Str  :$spool = "/var/spool/mixmaster/{$*USER}", #= Filesystem path for storing jobs.
    Str  :$email = '',                    #= Email address to use for notifiations.
    Bool :$dump,                          #= Display the configuration file.
    Bool :$version,                       #= Display version information.
    Bool :$force,                         #= Overwrite existing files.
    Bool :y(:$yes)                        #= Skip confirmation.
) {
    my IO::Path $configPath = $*HOME.IO.add(".config/mixmaster.ini");
    my IO::Path $resolvedBuildRoot = $buildRoot.IO.resolve;
    my IO::Path $resolvedSpool = $spool.IO.resolve;
    my IO::Path $systemdRoot = IO::Path.new("{$*HOME}/.config/systemd/user");

    if ($version) {
        say SCRIPT_VERSION;
        exit;
    }

    if ($dump) {
        say("Dumping {$configPath}");
        say("-" x 72 ~ "\n");

        .say for $configPath.lines;
        exit;
    }

    my @tasks = ();


    # Build root
    if ($resolvedBuildRoot.d) {
        say "Build root {$resolvedBuildRoot} already exists.";
    } else {
        unless ($resolvedBuildRoot.parent.w) {
            die("The parent of {$resolvedBuildRoot} is not writable.\n")
        }

        say("Builds will be stored in {$resolvedBuildRoot}");
        @tasks.push("buildRoot");
    }

    # Config
    if ($configPath.f and not $force) {
        say "Configuration file {$configPath} already exists.";
    } else {
        say("The configuration file will be written to {$configPath}");
        @tasks.push("configurationFile");
    }

    # Spool
    unless ($resolvedSpool.d) {
        say("The directory {$resolvedSpool} needs to be created manually. For example:");
        say("    sudo mkdir -p {$resolvedSpool}");
        say("    sudo chown {$*USER} {$resolvedSpool}");
    }

    # Systemd
    if ($systemdRoot.add("mixmaster-bridge.socket").e and not $force) {
        say "Systemd services already exist under {$systemdRoot}.";
    } else {
        say("Systemd services wil be written to {$systemdRoot}");
        @tasks.push("systemdServices");
    }


    unless (@tasks) {
        say "Nothing else to be done.";
        exit;
    }

    unless ($yes) {
        my Str $confirmation = prompt("Proceed? [y/N] ");
        exit unless $confirmation.lc eq "y";
    }

    if (@tasks.contains("buildRoot")) {
        createBuildRoot($resolvedBuildRoot);
    }

    if (@tasks.contains("configurationFile")) {
        createConfigurationFile($configPath, $resolvedBuildRoot, $resolvedSpool, $email);
    }

    if (@tasks.contains("systemdServices")) {
        createSystemdServices($systemdRoot, $resolvedBuildRoot);
    }

    CATCH {
        default {
            .payload.say
        }
    }
}