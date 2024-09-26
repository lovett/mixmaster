unit package Command;

use Filesystem;

our sub dump(IO::Path $root) is export {
    my $path = config-path($root);

    if ($path.f) {
        .say for $path.lines;
    } else {
        say "$path does not exist";
        exit 1;
    }
}
