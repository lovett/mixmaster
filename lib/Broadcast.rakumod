unit module Broadcast;

use Mailer;

sub broadcast-start(%job) is export {
    log(%job, '#', "Build started for {%job<context><jobfile>}");
    log(%job, '#', "Building in {%job<context><workspace>}");
    log(%job, '#', "Logging to {%job<context><log-path>}");

    if (%job<context><mailable>) {
        my ($subject, $body) = job-start-email(%job);
        mail(%job<config>, $subject, $body);
    } else {
        log(%job, '#', "Email notifications will not be sent");
    }
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
