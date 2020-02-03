#!/usr/bin/env rakudo

use lib '/usr/local/share/mixmaster/lib';
use lib 'lib';

use Config::INI;
use JSON::Fast;

our Str constant SCRIPT_VERSION = "2020.02.01";

our IO::Path constant CONFIG = $*HOME.add(".config/mixmaster.ini");

sub generate-job-file-name() {
    DateTime.now(
        formatter => sub ($self) {
            sprintf "%04d%02d%02d-%02d%02d%02d.ini",
            .year, .month, .day, .hour, .minute, .whole-second given $self;
        }
    );
}

sub send-success-response() {
    put "HTTP/1.1 200 OK\r\n";
    put "Connection: close\r\n";
}

sub send-failure-response() {
    put "HTTP/1.0 400 Bad Request\r\n";
    put "Connection: close\r\n";
}

sub send-error-response(Str $message) {
    put "HTTP/1.1 422 {$message}\r\n";
    put "Connection: close\r\n";
}

sub MAIN(
    Bool :$version  #= Display version information.
) {
    if ($version) {
        say SCRIPT_VERSION;
        exit;
    }

    unless (CONFIG.f) {
        send-error-response("Configuration file not found.");
        exit;
    }

    my Hash %config{Str} = Config::INI::parse_file(Str(CONFIG));

    my Str %headers{Str};

    for lines() {
        unless %headers<method>:exists {
            my (Str $method, Str $uri, Str $version) = $_.split(' ', 3);
            %headers.append('method', $method);
            %headers.append('uri', $uri);
            %headers.append('version', $version);
        }

        if ($_.contains(':')) {
            my (Str $key, Str $value) = $_.split(':', 2);
            %headers{$key.lc.trim} = val($value);
        }

        unless ($_.trim) {
            last;
        }
    }

    my Buf $body = $*IN.read(%headers<content-length>);
    my %json{Str} = from-json $body.decode;

    my Str $scm = "";
    my Str $repositoryUrl = "";
    my Str $repositoryName = "";
    my Str $repositoryBranch = "";
    my Str $commit = "";
    my Str $viewUrl = "";

    if (%headers<uri> eq "/freestyle") {
        $scm = "freestyle";
        $repositoryName = %json<project>;
        $repositoryBranch = %json<target>;
    }

    if (%headers<uri> eq "/gitea") {
        $scm = "git";
        $repositoryUrl = %json<repository><ssh_url>;
        $repositoryName = %json<repository><full_name>;
        $repositoryBranch = %json<ref>.subst("refs/heads/", "", :nth(1));
        $commit = %json<after>;
        $viewUrl = %json<compare_url>;
    }

    if (%headers<uri> eq "/adhoc") {
        for <scm repositoryUrl repositoryName commit branch> {
            unless (%json{$_}) {
                send-error-response("$_ not specified");
                exit;
            }
        }

        $scm = %json<scm>;
        $repositoryUrl = %json<repositoryUrl>;
        $repositoryName = %json<repositoryName>;
        $repositoryBranch = %json<branch>;
        $commit = %json<commit>;
        $viewUrl = %json<viewUrl>;
    }

    unless (%config{$repositoryName}:exists) {
        send-error-response("Unknown repository");
        exit;
    }

    my Pair @matchedBranchs = %config{$repositoryName}.pairs.grep: {
        .key.starts-with($repositoryBranch)
    };

    unless (@matchedBranchs) {
        send-error-response("Unknown branch");
        exit;
    }

    if (@matchedBranchs.elems > 1) {
        send-error-response("Multiple matches for this branch");
        exit;
    }

    my (Str $matchedBranch, Str $buildCommand) = @matchedBranchs.first.kv;

    my $jobFileName = generate-job-file-name();

    spurt "{%config<_><spool>}/{$jobFileName}", qq:to/END/;
    [job]
    scm = $scm
    repositoryName = $repositoryName
    repositoryUrl = $repositoryUrl
    commit = $commit
    branch = $matchedBranch
    buildCommand = $buildCommand
    viewUrl = $viewUrl
    mailto = {%config<_><mailto> or ''}
    mode = {%config<_><mode> or 'normal'}
    END

    send-success-response();

    CATCH {
        send-failure-response();
    }
}
