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
        .mkdir;
        my $tildePath = with-tilde($_);
        say "Created $tildePath";
    }

    my $config = config-path($buildroot);

    if ($config.f) {
        my $tildePath = with-tilde($config);
        say "$tildePath already exists, leaving as-is";
    } else {
        create-config($config);
        say "Populated {$config} with  default configuration.";
    }
}

sub create-config(IO::Path $path) {
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

    ; The command for sending email.
    mailcommand = /usr/sbin/sendmail -t

    ; Sample project configuration.
    [example-org/example-repo]
    production = make deploy
    staging = make deploy-to-staging
    master/my-task = make my-task

    END
}
