unit module Broadcast;

sub broadcast-start(%job, Str $message?) is export {
    # my $sendEmail = %job<mailto> && (%job<notifications> eq "all" || %job<notifications> ~~ "email");
    log(%job, '#', "Build started for {%job<context><jobfile>}");
    log(%job, '#', "Building in {%job<context><workspace>}");
    log(%job, '#', "Logging to {%job<context><log-path>}");

    # if ($sendEmail) {
    #     use Broadcast::Email;
    #     mail-job-start(%job<mailto>, %job);
    # }
}

sub broadcast-command(%job, Str $message) is export {
    log(%job, '$', $message);
}

sub broadcast-stdout(%job, Str $message) is export {
    log(%job, 'O', $message);
}

sub broadcast-stderr(%job, Str $message) is export {
    log(%job, '!', $message);
    say "STDERR: " ~ $message.trim;
}

sub broadcast-end(%job) is export {
    my $sendEmail = %job<mailto> && (%job<notifications> eq "all" || %job<notifications> ~~ "email");

    log(%job, '#', "End of build");

    try close %job<context><log>;

    # if ($sendEmail) {
    #     use Broadcast::Email;
    #     mail-job-end(%job<mailto>, %job);
    # }
}

sub broadcast-fail(%job, Str $message) is export {
    my $sendEmail = %job<mailto> && (%job<notifications> eq "all" || %job<notifications> ~~ "email");

    log(%job, '#', "Build failed: {$message}");

    # if (%job<mailto>) {
    #     use Broadcast::Email;
    #     mail-job-fail(%job<mailto>, %job);
    # }
}

sub log(%job, Str $prefix, Str $message) {
    my $handle = %job<context><log>;
    for $message.trim.split("\n") {
        try $handle.say("{DateTime.now.hh-mm-ss} {$prefix} $_");
    }
    try $handle.flush();
}
