unit module Broadcast;

use Mailer;

sub broadcast-start(%job) is export {
    log(%job, '#', "Build started for {%job<context><jobfile>}");
    log(%job, '#', "Building in {%job<context><workspace>}");
    log(%job, '#', "Logging to {%job<context><log-path>}");
    mail-job-start(%job);
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
    mail-job-end(%job);
}

sub broadcast-fail(%job, Str $message) is export {
    log(%job, '#', "Build failed: {$message}");
    mail-job-fail(%job);
}

sub log(%job, Str $prefix, Str $message) {
    my $handle = %job<context><log>;
    for $message.trim.split("\n") {
        try $handle.say("{DateTime.now.hh-mm-ss} {$prefix} $_");
    }
    try $handle.flush();
}
