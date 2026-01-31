unit module Command::Recipe;

=begin pod

The recipe command shows the commands that would run during a build.

=end pod

use Filesystem;
use Job;

my sub make-it-so(IO::Path $path) is export {
    my $resolvedPath = resolve-tilde($path);
    unless $resolvedPath.r {
        die "Job path $path is not readable";
    }

    my %job;

    try {
        %job = load-job($resolvedPath);
        CATCH {
            die "Job file could not be parsed";
        }
    }

    for %job<context><recipe>.list {
        .say;
    }
}
