unit package Command;

use Filesystem;
use Console;

our sub service(IO::Path $root, Bool $force) is export {
    for systemd-service-paths() {
        next if $_.f and not $force;
        create-systemd-service($_, $root);
        success-message("Created {$_}.");
    }
}
