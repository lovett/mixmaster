unit module Broadcast::Email;

use Email::Simple;

our Str constant PREFIX = '[mixmaster]';

sub mail-job-start(Str $recipient, %job) is export {
    my $repositoryName = %job<job><repositoryName>;
    my $subject = "Starting build for {$repositoryName}";
    my $body = "Mixmaster has started a build for {$repositoryName}";

    if (%job<job><viewUrl>) {
        $body ~= "\n\n{%job<job><viewUrl>}";
    }

    send($recipient, $subject, $body);
}

sub mail-job-end(Str $recipient, %job) is export {
    my $repositoryName = %job<job><repositoryName>;
    my $subject = "Finished building {$repositoryName}";
    my $body = "Mixmaster has finished building {$repositoryName}";
    send($recipient, $subject, $body);
}

sub mail-job-fail(Str $recipient, %job, IO::Path $logFile) is export {
    my $repositoryName = %job<job><repositoryName>;
    my $subject = "Error building {$repositoryName}";

    my $body = "Mixmaster was unable to build {$repositoryName}\n\n";
    $body ~= slurp $logFile;

    send($recipient, $subject, $body);
}

sub send($recipient, $subject, $body) {
    my $message = Email::Simple.create(
        :header[
                 ['To', $recipient],
                 ['Subject', "{PREFIX} $subject"],
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
