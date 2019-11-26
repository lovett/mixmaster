unit module Bridge;

use JSON::Fast;

sub generate-job-file-name() is export {
    DateTime.now(
        formatter => sub ($self) {
            sprintf "%04d%02d%02d-%02d%02d%02d.ini",
            .year, .month, .day, .hour, .minute, .whole-second given $self;
        }
    );
}

sub parse-headers($line, %headers) is export {
    unless %headers<method>:exists {
        my (Str $method, Str $uri, Str $version) = $line.split(' ', 3);
        %headers.append('method', $method);
        %headers.append('uri', $uri);
        %headers.append('version', $version);
        return;
    }

    if ($line.contains(':')) {
        my (Str $key, Str $value) = $line.split(':', 2);
        %headers{$key.lc.trim} = val($value);
        return;
    }
}

sub parse-json-body($length) is export {
    my Buf $body = $*IN.read($length);
    from-json $body.decode;
}

sub send-success-response() is export {
    put "HTTP/1.1 204 No Content\r\n";
    put "Connection: close\r\n";
}

sub send-failure-response() is export {
    put "HTTP/1.0 400 Bad Request\r\n";
    put "Connection: close\r\n";
}

sub send-error-response(Str $message) is export {
    put "HTTP/1.1 422 {$message}\r\n";
    put "Connection: close\r\n";
}
