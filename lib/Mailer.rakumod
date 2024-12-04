unit module Mailer;

use Email::Simple;

our Str constant PREFIX = '[mixmaster]';

sub job-start-email(%job) is export {
    my Str $body = "Mixmaster has started building ";

    # if (%job<task>) {
    #     $body = "Mixmaster has started the {%job<task>} task on ";
    # }

    if (%job<commit>) {
        $body ~= short-commit(%job<commit>) ~ " on ";
    }

    $body ~= %job<context><branch> ~ ".";

    if (%job<viewUrl>) {
        $body ~= "\n\n{%job<viewUrl>}";
    }

    $body ~= "\n\n";

    for %job.kv -> $key, $value {
        if $key.starts-with('commit-') {
            my ($timestamp, $id) = $key.subst(/commit\-/, '').split(',');
            my $shortId = short-commit($id);
            my $message = $value.subst(
                /(\w)\n(\w)/,
                { "$0 $1" },
                :g
            );

            $body ~= "Commit {$shortId} on {$timestamp}\n{$message}\n\n\n";
        }
    }

    return ("{PREFIX} Building {%job<context><project>}", $body);
}

sub job-end-email(%job) is export {
    my Str $body = "Mixmaster has finished building ";
    if (%job<context><failed>) {
        $body = "Mixmaster was unable to build ";
    }

    if (%job<commit>) {
        $body ~= short-commit(%job<commit>) ~ " on ";
    }

    $body ~= %job<context><branch> ~ ".";

    $body ~= "\n\n" ~ %job<context><log-path>.slurp;

    return ("Re: {PREFIX} Building {%job<context><project>}", $body);
}

sub mail(%config, Str $subject, Str $body) is export {
    my $recipient = %config<mailto>;
    my $mailcommand = %config<mailcommand>;

    my $message = Email::Simple.create(
        :header[
                 ['To', $recipient],
                 ['Subject', $subject]
             ],
        :body($body)
    );

    my $proc = Proc::Async.new(:w, $mailcommand);
    react {
        whenever $proc.start {
            done
        }

        whenever $proc.print: $message {
            $proc.close-stdin;
        }
    }
}

sub short-commit(Str $commit) {
    return substr($commit, 0..7);
}
