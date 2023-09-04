unit module Broadcast::Email;

use Email::Simple;
use IniEncode;

our Str constant PREFIX = '[mixmaster]';

sub short-commit(Str $commit) {
    return substr($commit, 0..7);
}

sub slurp-log(IO::Path $path) {
    my $inLogSection = False;
    my $log = '';

    for $path.lines -> $line {
        given $line {
            when "[log]" {
                $inLogSection = True;
                $log ~= $line ~ "\n";
            }

            when $inLogSection {
                $log ~= $line ~ "\n";
            }
        }
    }

    return $log;
}

sub mail-job-start(Str $recipient, %job) is export {
    my Str $project = %job<project>;
    my Str $subject = "{PREFIX} Building {$project}";
    my Str $body = "Mixmaster has started building ";

    if (%job<task>) {
        $body = "Mixmaster has started the {%job<task>} task on ";
    }

    if (%job<commit>) {
        $body ~= short-commit(%job<commit>) ~ " on ";
    }

    $body ~= %job<target> ~ ".";

    if (%job<viewUrl>) {
        $body ~= "\n\n{%job<viewUrl>}";
    }

    $body ~= "\n\n";

    for %job.kv -> $key, $value {
        if $key.starts-with('commit-') {
            my ($timestamp, $id) = $key.subst(/commit\-/, '').split(',');
            my $shortId = short-commit($id);
            my $message = decode-ini-value($value).subst(
                /(\w)\n(\w)/,
                { "$0 $1" },
                :g
            );

            $body ~= "Commit {$shortId} on {$timestamp}\n{$message}\n\n\n";
        }
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

    $body ~= "\n\n" ~ slurp-log(%job<path>);

    send($recipient, $subject, $body);
}

sub mail-job-fail(Str $recipient, %job) is export {
    my Str $project = %job<project>;
    my Str $subject = "Re: {PREFIX} Building {$project}";
    my Str $body = "Mixmaster was unable to build ";

    if (%job<commit>) {
        $body ~= short-commit(%job<commit>) ~ " on ";
    }

    $body ~= %job<target> ~ ".";

    $body ~= "\n\n" ~ slurp-log(%job<path>);

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
