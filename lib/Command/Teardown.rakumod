unit package Command;

use Filesystem;
use Console;

our sub teardown() {
    for systemd-service-paths() {
        next unless $_.f;
        run(<systemctl --user --quiet disable --now $_>, :err).so;
        $_.unlink();
        success-message("Removed {$_}.");
    }
}
