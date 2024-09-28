unit package Command;

use Filesystem;
use Console;

our sub setup(IO::Path $root, Bool $force) is export {
    unless $root.d {
        mkdir($root);
        success-message("Created $root");
    }

    for (inbox-path($root), archive-path($root)) {
        unless ($_.d) {
            mkdir($_);
            success-message("Created $_");
        }
    }

    my $config = config-path($root);
    unless ($config.f or $force) {
        create-config($config);
        success-message("Populated {$config} with  default configuration.")
    }
}
