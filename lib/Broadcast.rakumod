unit module Broadcast;

use Mailer;
use Filesystem;

enum HookEvent <Start End>;

sub broadcast-start(%job) is export {
    log(%job, '#', "Build started for {%job<context><jobfile>}");
    log(%job, '#', "Building in {%job<context><workspace>}");
    log(%job, '#', "Logging to {%job<context><log-path>}");

    if %job<context><mailable> {
        my ($subject, $body) = job-start-email(%job);
        mail(%job<config>, $subject, $body);
    } else {
        log(%job, '#', "Email notifications will not be sent");
    }

    broadcast-hook(%job, Start);
}

sub broadcast-hook(%job, HookEvent $hook) {
    my Str $hookName;
    given $hook {
        when Start {
            $hookName = "job-start";
        }

        when End {
            $hookName = "job-end";
        }
    }

    my $hookScript = %job<context><config><_><hook>;
    return unless $hookScript;

    $hookScript = resolve-tilde($hookScript);

    log(%job, 'H', "Calling hook script for $hookName event");

    my $proc = run $hookScript, :in, :out, :err;

    my $project = %job<context><project>;
    my $log-path = %job<context><log-path>;
    my $job-file = %job<context><jobfile>;

    $proc.in.print: qq:to/END/;
    MixmasterEvent: $hookName
    MixmasterProject: $project
    MixmasterLog: $log-path;
    END

    $proc.in.close;

    my $stdout = $proc.out.slurp: :close;
    for $stdout.lines {
        log(%job, 'H', "out: $_");
    }

    my $stderr = $proc.err.slurp: :close;
    if $stderr {
        log(%job, 'H', "err: $stdout");
    }

    log(%job, 'H', "exit: {$proc.exitcode}");
}


sub broadcast-command(%job, Str $message) is export {
    log(%job, '$', $message);
}

sub broadcast-stdout(%job, Str $message) is export {
    log(%job, 'O', $message);
}

sub broadcast-stderr(%job, Str $message) is export {
    log(%job, '!', $message);
}

sub broadcast-end(%job) is export {
    log(%job, '#', "End of build");
    if (%job<context><mailable>) {
        my ($subject, $body) = job-end-email(%job);
        mail(%job<config>, $subject, $body);
    }

    broadcast-hook(%job, End);

}

sub broadcast-fail(%job, Str $message) is export {
    log(%job, '#', "Build failed: {$message}");

    if (%job<context><mailable>) {
        my ($subject, $body) = job-end-email(%job);
        mail(%job<config>, $subject, $body);
    }
}

sub log(%job, Str $prefix, Str $message) {
    my $handle = %job<context><log>;
    for $message.trim.split("\n") {
        try $handle.say("{DateTime.now.hh-mm-ss} {$prefix} $_");
    }
    try $handle.flush();
}
