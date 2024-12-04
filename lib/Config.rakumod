unit module Config;

use Config::INI;
use Filesystem;

sub load-config(IO::Path $buildroot --> Hash) is export {
    my $path = config-path($buildroot);
    my $ini = Config::INI::parse_file($path.absolute);
    return $ini if $ini;
    return %{};
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

    ; The command for sending email.
    mailcommand = /usr/sbin/sendmail -t

    ; Sample project configuration.
    [example-org/example-repo]
    production = make deploy
    staging = make deploy-to-staging
    master/my-task = make my-task

    END
}
