unit module Config;

use Config::INI;
use Filesystem;

sub load-config(IO::Path $root --> Hash) is export {
    my $path = config-path($root);
    my $ini = Config::INI::parse_file($path.absolute);
    return $ini if $ini;
    return %{};
}
