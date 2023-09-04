unit module Config;

use Config::INI;

our IO::Path constant CONFIG = $*HOME.add(".config/mixmaster.ini");

sub has-config() is export {
    return CONFIG.f
}

sub get-config() is export {
    return Config::INI::parse_file(Str(CONFIG));
}
