unit module Format;

my @months = <
  January February March April May June
  July August September October November December
>;

sub format-datetime(DateTime $dt --> Str) is export {
    my $month = @months[$dt.month - 1];
    my $hour = (($dt.hour + 11) % 12) + 1;
    my $meridiem = $dt.hour < 12 ?? 'AM' !! 'PM';

    return sprintf(
        "%s %d, %d at %d:%02d %s",
        $month,
        $dt.day,
        $dt.year,
        $hour,
        $dt.minute,
        $meridiem
    );
}
