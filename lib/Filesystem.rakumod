unit module Filesystem;

sub create-build-root(IO::Path $path) is export {
    try {
        mkdir($path);
        say "Created {$path} directory.";

        CATCH {
            when X::IO::Mkdir {
                die("Unable to create {$path}");
            }
        }
    }
}
