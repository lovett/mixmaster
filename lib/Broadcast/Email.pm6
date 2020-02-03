unit module Broadcast::Email;

use Email::Simple;

our Str constant PREFIX = '[mixmaster]';

sub mail-job-start(Str $recipient, %job) is export {
    my Str $project = %job<project>;
    my Str $subject = "{PREFIX} Building {$project}";
    my Str $body = "Mixmaster has started building {%job<target>} in {$project}.";

    if (%job<viewUrl>) {
        $body ~= "\n\n{%job<viewUrl>}";
    }

    $body ~= "\n\nAnother message will be sent when the build has finished.";

    send($recipient, $subject, $body);
}

sub mail-job-end(Str $recipient, %job) is export {
    my Str $project = %job<project>;
    my Str $subject = "Re: {PREFIX} Building {$project}";
    my Str $body = "Mixmaster has finished building {%job<target>} in {$project}.";

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
