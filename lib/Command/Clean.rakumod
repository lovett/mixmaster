unit package Command;

use Filesystem;

our sub clean(IO::Path $root) {
    say "this is the stub for the clean command";
    # my $path = inbox-path($root);

    # exit unless $path.d;

    # # See https://www.freedesktop.org/software/systemd/man/systemd.exec.html
    # given %*ENV<SERVICE_RESULT> {
    #     when "success" {
    #         exit;
    #     }

    #     default {
    #         my IO::Path @jobs = dir($path, test => /'.' ini $/);

    #         for (@jobs) {
    #             try unlink($_);
    #             say "Deleted {$_}";
    #         }
    #     }
    # }
}
