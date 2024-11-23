unit module Console;

sub success-message(Str $message) is export {
    say "✓ $message";
}

sub info-message(Str $message) is export {
    say "👀 $message";
}
