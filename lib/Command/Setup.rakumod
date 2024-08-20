unit package Command;

use Filesystem;
use Console;

our sub setup(IO::Path $root, Bool $force) is export {
    unless $root.d {
        mkdir($root);
        success-message("Created $root");
    }

    my $inbox = inbox-path($root);
    unless ($inbox.d) {
        mkdir($inbox);
        success-message("Created $inbox");
    }

    my $config = config-path($root);
    unless ($config.f or $force) {
        create-config($config);
        success-message("Populated {$config} with  default configuration.")
    }

    for systemd-service-paths() {
        next if $_.f and not $force;
        create-systemd-service($_, $root);
        success-message("Created {$_}.");
    }
}
