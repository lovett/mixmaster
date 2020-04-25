unit module Broadcast::Email;

use Email::Simple;

our Str constant PREFIX = '[mixmaster]';

sub short-commit(Str $commit) {
    return substr($commit, 0..7);
}

sub mail-job-start(Str $recipient, %job) is export {
    my Str $project = %job<project>;
    my Str $subject = "{PREFIX} Building {$project}";

    my Str $body = "Mixmaster has started building ";

    if (%job<commit>) {
        $body ~= short-commit(%job<commit>) ~ " on ";
    }

    $body ~= %job<target> ~ ".";

    if (%job<viewUrl>) {
        $body ~= "\n\n{%job<viewUrl>}";
    }

    if (%job<message>) {
        $body ~= "\n\n{%job<message>}";
    }

    send($recipient, $subject, $body);
}

sub mail-job-end(Str $recipient, %job) is export {
    my Str $project = %job<project>;
    my Str $subject = "Re: {PREFIX} Building {$project}";
    my Str $body = "Mixmaster has finished building ";

    if (%job<commit>) {
        $body ~= short-commit(%job<commit>) ~ " on ";
    }

    $body ~= %job<target> ~ ".";

    $body ~= "\n\nJob: {%job<path>}";

    send($recipient, $subject, $body);
}

sub mail-job-fail(Str $recipient, %job) is export {
    my Str $project = %job<project>;
    my Str $subject = "Re: {PREFIX} Building {$project}";
    my Str $body = "Mixmaster was unable to build {%job<target>} in {$project}.\n\n";

    $body ~= slurp %job<path>;

    send($recipient, $subject, $body);
}

sub send(Str $recipient, Str $subject, Str $body) {
    my $message = Email::Simple.create(
        :header[
                 ['To', $recipient],
                 ['Subject', $subject]
             ],
        :body($body)
    );

    my $proc = Proc::Async.new(:w, «/usr/sbin/sendmail -t»);
    react {
        whenever $proc.start {
            done
        }

        whenever $proc.print: $message {
            $proc.close-stdin;
        }
    }
}
