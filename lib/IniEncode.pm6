unit module IniEncode;

sub encode-ini-value(Str $value='') is export {
    my $result = $value.trim;
    $result ~~ s:g/\n/\\\\newline/;
    $result ~~ s:g/\[/\\\\leftbracket/;
    $result ~~ s:g/\]/\\\\rightbracket/;
    return $result;
}

sub decode-ini-value(Str $message) is export {
    my $result = $message;
    $result ~~ s:g/\\\\newline/\n/;
    $result ~~ s:g/\\\\leftbracket/[/;
    $result ~~ s:g/\\\\rightbracket/]/;
    return $result;

}
