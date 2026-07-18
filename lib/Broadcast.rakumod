unit module Broadcast;

use Filesystem;

enum HookEvent <Start End Fail>;

sub broadcast-start(%job) is export {
    my $start = %job<context><start>.now.hh-mm-ss;
    my $jobfile = %job<context><jobfile>.IO.basename;
    my $workspace = with-tilde(%job<context><workspace>);
    my $log = with-tilde(%job<context><log-path>);

    log(%job, '#', "Build started at $start for $jobfile");
    log(%job, '#', "Building in $workspace");

    broadcast-hook(%job, Start);
}

sub broadcast-hook(%job, HookEvent $hook) {
    my Str $hookName;
    given $hook {
        when Start {
            $hookName = "job-start";
        }

        when Fail {
            $hookName = "job-fail";
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
    my $projectDirectory = %job<context><project-dir>;
    my $branch = %job<context><branch>;
    my $log = with-tilde(%job<context><log-path>);

    $proc.in.print: qq:to/END/;
    MixmasterEvent: $hookName
    MixmasterProject: $project
    MixmasterProjectDirectory: $projectDirectory
    MixmasterBranch: $branch
    MixmasterLog: $log
    END

    $proc.in.close;

    for $proc.out.slurp.lines {
        log(%job, 'H', $_);
    }

    CATCH {
        log(%job, 'H', "Hook failed (exit code {$proc.exitcode})");
        for $proc.err.slurp.lines {
            log(%job, 'H', $_);
        }
        .resume;
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
    log(%job, '#', "Build ended at {DateTime.now.hh-mm-ss}");
    broadcast-hook(%job, End);

}

sub broadcast-fail(%job, Str $message) is export {
    log(%job, '#', "Build failed at {DateTime.now.hh-mm-ss}");
    log(%job, '#', $message);

    broadcast-hook(%job, Fail);
}

sub log(%job, Str $prefix, Str $message) {
    my $handle = %job<context><log>;
    for $message.trim.split("\n") {
        try $handle.say("{$prefix} $_");
    }
    try $handle.flush();
}
