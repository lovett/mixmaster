unit package Command;

use Filesystem;
use Config;
use Console;

our sub setup(IO::Path $root) is export {
    for $root, inbox-path($root), archive-path($root) {
        .mkdir;
        success-message("Created $_");
    }

    my $path = config-path($root);

    if ($path.f) {
        info-message("$path already exists, leaving as-is");
    } else {
        create-config($path);
        success-message("Populated {$path} with  default configuration.")
    }
}
