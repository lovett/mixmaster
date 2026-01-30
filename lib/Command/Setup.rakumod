unit module Command::Setup;

use Filesystem;
use Console;

my sub make-it-so(IO::Path $buildroot) is export {
    my $path = $buildroot.subst(/^ '~'/, $*HOME).IO;
    for $path, inbox-path($path), archive-path($path) {
        .mkdir;
        success-message("Created $_");
    }

    my $config = config-path($path);

    if ($config.f) {
        info-message("$config already exists, leaving as-is");
    } else {
        create-config($config);
        success-message("Populated {$config} with  default configuration.")
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
