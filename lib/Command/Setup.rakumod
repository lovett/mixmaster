unit package Command;

use Filesystem;
use Config;
use Console;

our sub setup(IO::Path $buildroot) is export {
    for $buildroot, inbox-path($buildroot), archive-path($buildroot) {
        .mkdir;
        success-message("Created $_");
    }

    my $path = config-path($buildroot);

    if ($path.f) {
        info-message("$path already exists, leaving as-is");
    } else {
        create-config($path);
        success-message("Populated {$path} with  default configuration.")
    }
}
