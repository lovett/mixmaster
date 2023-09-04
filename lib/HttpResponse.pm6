unit module HttpResponse;

sub send-success-response(Str $body='') is export {
    print "HTTP/1.1 200 OK\r\n";
    print "Connection: close\r\n";
    print "Content-Length: {$body.chars}\r\n";
    print "Content-Type: text/plain; charset=utf-8\r\n";
    print "\r\n";
    print $body;
}

sub send-failure-response() is export {
    print "HTTP/1.0 400 Bad Request\r\n";
    print "Connection: close\r\n";
    print "\r\n";
}

sub send-error-response(Str $message) is export {
    print "HTTP/1.1 422 Unprocessable Entity\r\n";
    print "Connection: close\r\n";
    print "Content-Length: {$message.chars}\r\n";
    print "Content-Type: text/plain; charset=utf-8\r\n";
    print "\r\n";
    print $message;
}

sub send-notfound-response() is export {
    print "HTTP/1.1 404 Not Found\r\n";
    print "Connection: close\r\n";
    print "\r\n";
}

sub send-notallowed-response() is export {
    print "HTTP/1.1 405 Method Not Allowed\r\n";
    print "Connection: close\r\n";
}
