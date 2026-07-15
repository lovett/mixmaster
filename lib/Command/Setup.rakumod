unit module Command::Setup;

=begin pod

The setup command creates a build root in the specified location.

A build root contains:
  - An inbox directory for build requests
  - An archive directory for completed requests
  - A configuration file

=end pod

use Filesystem;

my sub Setup(IO::Path $path) is export {
    my $buildroot = resolve-tilde($path);
    for $buildroot, inbox-path($buildroot), archive-path($buildroot), trash-path($buildroot) {
        my $tildePath = with-tilde($_);
        if .d {
            say "$tildePath already exists";
            next;
        }

        .mkdir;
        say "Created $tildePath";
    }

    my $config = config-path($buildroot);
    my $tildePath = with-tilde($config);
    if ($config.f) {
        say "$tildePath already exists";
    } else {
        create-config($config);
        say "Populated {$tildePath} with default configuration.";
    }
}

sub create-config(IO::Path $path) {
    spurt $path, qq:to/END/;
    ; This is the configuration file for mixmaster.

    ; The SSH key that should be loaded at the start of each build.
    sshKey =

    ; A script to receive hook events.
    hook =

    ; Repository configuration
    [example-org/example-repo]
    production = make deploy
    staging = make deploy-to-staging
    master/my-task = make my-task

    END
}
