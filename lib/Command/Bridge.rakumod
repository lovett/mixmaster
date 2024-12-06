unit package Command;

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

our sub bridge(IO::Path $buildroot) {
    unless ($buildroot.d) {
        respond-notfound();
        note "Build request rejected: $buildroot is not a directory.";
        return;
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

            spurt $inbox.add($filename), $body;
            respond-success();

            CATCH {
                default {
                    respond-failure();
                    note("Build request rejected: " ~ .message);
                }
            }
        }

        default {
            respond-notallowed();
            note("Build request rejected: HTTP request was not POST or PUT");
        }
    }
}

sub respond-success(Str $body='') {
    print "HTTP/1.1 200 OK\r\n";
    print "Connection: close\r\n";
    print "Content-Length: {$body.chars}\r\n";
    print "Content-Type: text/plain; charset=utf-8\r\n";
    print "\r\n";
    print $body;
}

sub respond-failure() {
    print "HTTP/1.0 400 Bad Request\r\n";
    print "Connection: close\r\n";
    print "\r\n";
}

sub respond-notfound() {
    print "HTTP/1.1 404 Not Found\r\n";
    print "Connection: close\r\n";
    print "\r\n";
}

sub respond-notallowed() {
    print "HTTP/1.1 405 Method Not Allowed\r\n";
    print "Connection: close\r\n";
}
