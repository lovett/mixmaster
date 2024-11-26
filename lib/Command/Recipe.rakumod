unit package Command;

=begin pod

The recipe command shows the commands that would be run during a build.

=end pod

use Job;

our sub recipe(IO::Path $path where *.f) is export {
    my %job = load-job($path);

    for %job<context><recipe>.list {
        .say;
    }
}
