unit module Command::Bridge;

=begin pod

The bridge command writes build requests to the inbox as JSON files.

Build requests normally arrive on stdin as HTTP requests from a systemd
socket service. JSON is the primary content type for these requests,
and multiple formats are supported:

=item A comprehensive format used by Gitea
=item A lightweight format specific to mixmaster
=item A minimal format for command execution

The JSON body is not processed here.

=end pod

use JSON::Fast;

use Filesystem;
use Format;
use Job;

my sub Bridge(IO::Path $path) is export {
    my $buildroot = resolve-tilde($path);
    unless ($buildroot.d) {
        respond-internal-error();
        die "Build request rejected because $buildroot is not a directory.";
    }

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

    given %headers<method>.uc {
        when "POST" or "PUT" {
            my Buf $body = $*IN.read(%headers<content-length>);

            my $json = from-json $body.decode;

            my $inbox = inbox-path($buildroot);
            my $filename = DateTime.now(
                formatter => sub ($self) {
                    sprintf "%04d%02d%02d-%02d%02d%02d.json",
                    .year, .month, .day, .hour, .minute, .whole-second given $self;
                }
            );

            my $path = $inbox.add($filename);
            spurt $path, $body;
            respond-success("job received");

            note "New job received: $path";

            CATCH {
                default {
                    respond-failure();
                    die "Build request rejected: " ~ .message;
                }
            }
        }

        when "GET" {
            given %headers<uri>  {
                when "/hello" {
                    respond-success("world");
                    exit;
                }

                when "/favicon.ico" {
                    respond-no-content();
                    exit;
                }

                when "/mixmaster.svg" {
                    respond-success(%?RESOURCES<mixmaster.svg>.IO.slurp, "svg");
                    exit;
                }

                when "/mixmaster.css" {
                    respond-success(%?RESOURCES<mixmaster.css>.IO.slurp, "css");
                    exit;
                }

                when /^ '/job/' (.*) '.json' $/ {
                    my $path = job-path($buildroot, ~$0);

                    unless $path.f {
                        respond-notfound();
                        exit;
                    }

                    respond-success($path.slurp, "json");
                    exit;
                }

                when /^ '/project/' (<-[\/]>+) .* $/ {
                    my $project = ~$0;

                    my $logs = "";
                    for reverse logs($buildroot, $project) {
                        my $date = job-date-from-log($_);
                        my $formatted-date = format-datetime($date);

                        $logs ~= qq|<p><a href="/log/$project/{.basename}">{$formatted-date}</a></p>|;
                    }

                    my $template = %?RESOURCES<index.template.html>.IO.slurp;
                    my $html = $template.subst('@@LOGS@@', $logs);
                    $html = $html.subst('@@PROJECT@@', $project, :g);

                    respond-success($html, 'html');
                    exit;
                }

                when /^ '/log/' (.*) '/' (.*) '.log' $/ {
                    my $project = ~$0;
                    my $log = ~$1;
                    my $path = log-path($buildroot, $project, $log);

                    unless $path.f {
                        respond-notfound();
                        exit;
                    }


                    my $template = %?RESOURCES<log.template.html>.IO.slurp;

                    my @lines = $path.slurp.lines.map: { '<div class="line">' ~ $_ ~ '</div>' };

                    my $html = $template.subst('@@TITLE@@', $path.basename);
                    $html = $html.subst('@@LOG@@', @lines.join("\n"));

                    my $job-file = job-path($buildroot, $log);

                    my $diff-link = "";
                    my $job-link = "";

                    if $job-file.f {
                        my %job = load-job($job-file);
                        my $diff-url = job-diff-url(%job);
                        if $diff-url {
                            $diff-link = qq|<a target="_blank" href="$diff-url">View Diff</a>|;
                        }

                        my $job-url = "/job/{$job-file.basename}";
                        $job-link = qq|<a target="_blank" href="$job-url">View Job</a>|;
                    }

                    my $history-link = qq|<a href="/project/{$project}">Build History</a>|;


                    $html = $html.subst('@@DIFF_LINK@@', $diff-link);
                    $html = $html.subst('@@JOB_LINK@@', $job-link);
                    $html = $html.subst('@@HISTORY_LINK@@', $history-link);

                    respond-success($html, "html");
                    exit;
                }

                default {
                    respond-notfound();
                    exit;
                }
            }
        }

        default {
            respond-notallowed();
            note "Build request rejected. {$%headers<method>} requests are not supported.";
            exit;
        }
    }
}

sub respond-success(Str $body="", Str $type = "text") {
    print "HTTP/1.1 200 OK\r\n";

    given $type {
        when "html" {
            print "Content-Type: text/html; charset=utf-8\r\n";
        }
        when "svg" {
            print "Content-Type: image/svg+xml; charset=utf-8\r\n";
        }
        when "css" {
            print "Content-Type: text/css; charset=utf-8\r\n";
        }
        when "json" {
            print "Content-Type: application/json\r\n";
        }

        default {
            print "Content-Type: text/plain; charset=utf-8\r\n";
        }
    }

    print "Connection: close\r\n";
    print "Content-Length: {$body.chars}\r\n";

    print "\r\n";
    print $body;
    print "\n";
}

sub respond-failure() {
    print "HTTP/1.0 400 Bad Request\r\n";
    print "Connection: close\r\n";
    print "\r\n";
}

sub respond-internal-error() {
    print "HTTP/1.1 500 Internal Server Error\r\n";
    print "Connection: close\r\n";
    print "\r\n";
}

sub respond-notallowed() {
    print "HTTP/1.1 405 Method Not Allowed\r\n";
    print "Connection: close\r\n";
}

sub respond-notfound() {
    print "HTTP/1.1 404 Not Found\r\n";
    print "Connection: close\r\n";
    print "\r\n";
}

sub respond-no-content() {
    print "HTTP/1.1 204 No Content\r\n";
    print "Connection: close\r\n";
    print "\r\n";
}
