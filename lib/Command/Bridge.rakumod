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

use HttpResponse;
use Filesystem;

our sub bridge(IO::Path $root) {
    unless ($root.d) {
        send-notfound-response();
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

            try {
                create-job($root, $body);
                send-success-response();

                CATCH {
                    send-failure-response();
                }
            }
        }

        default {
            send-notallowed-response();
            exit;
        }
    }
}
