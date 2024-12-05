unit module Mailer;

use Email::Simple;

our Str constant PREFIX = '[mixmaster]';

sub job-start-email(%job) is export {
    my Str $body = "Mixmaster has started building ";

    # if (%job<task>) {
    #     $body = "Mixmaster has started the {%job<task>} task on ";
    # }

    if (%job<after>) {
        $body ~= short-commit(%job<after>) ~ " on ";
    }

    $body ~= %job<context><branch> ~ ".";

    # if (%job<commits>) {
    #     $body ~= "\n\n{%job<viewUrl>}";
    # }

    $body ~= "\n\n";

    if (%job<commits>:exists) {
        for %job<commits>.list -> %commit {
            my $timestamp = %commit<timestamp>.trim;
            my $id = short-commit(%commit<id>);
            my $message = %commit<message>.trim.subst(
                /(\w)\n(\w)/,
                { "$0 $1" },
                :g
            );

            $body ~= "Commit {$id} on {$timestamp}\n{$message}\n\n";
        }
    }

    return ("{PREFIX} Building {%job<context><project>}", $body);
}

sub job-end-email(%job) is export {
    my Str $body = "Mixmaster has finished building ";
    if (%job<context><failed>) {
        $body = "Mixmaster was unable to build ";
    }

    if (%job<after>) {
        $body ~= short-commit(%job<after>) ~ " on ";
    }

    $body ~= %job<context><branch> ~ ".";

    $body ~= "\n\nBuild log:\n";
    $body ~= %job<context><log-path>.slurp;

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
