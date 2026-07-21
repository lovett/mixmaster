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
            respond-success("job received\n");

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
                    respond-success(%?RESOURCES<mixmaster.svg>.IO.slurp);
                    exit;
                }

                when /^ '/log/' (.*) '/' (.*) '.log' $/ {
                    my $path = log-path($buildroot, ~$0, ~$1);

                    unless $path.f {
                        respond-notfound();
                        exit;
                    }


                    my $template = %?RESOURCES<log.template.html>.IO.slurp;

                    my @lines = $path.slurp.lines.map: { '<div class="line">' ~ $_ ~ '</div>' };

                    my $html = $template.subst('@@TITLE@@', $path.basename);
                    $html = $html.subst('@@LOG@@', @lines.join("\n"));

                    my $job-file = job-path($buildroot, ~$1);

                    my Str $diff-link;
                    if $job-file.f {
                        my %job = load-job($job-file);
                        my $url = job-diff-url(%job);
                        if $url {
                            $diff-link = qq|<a target="_blank" href="$url">View Diff</a>|;
                        }
                    }

                    $html = $html.subst('@@DIFF_LINK@@', $diff-link);

                    respond-success($html);
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

sub respond-success(Str $body='') {
    my $contentType = "text/plain";

    if $body.contains("<html") {
       $contentType = "text/html";
    } elsif $body.contains("<svg") {
        $contentType = "image/svg+xml";
    }

    print "HTTP/1.1 200 OK\r\n";
    print "Connection: close\r\n";
    print "Content-Length: {$body.chars}\r\n";
    print "Content-Type: $contentType; charset=utf-8\r\n";
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
