unit module Config;

use Config::INI;

sub load-config(IO::Path $path --> Hash) is export {
    return Config::INI::parse_file($path);
}

sub get-job-config(IO::Path $jobFile) is export {
    return Config::INI::parse_file($jobFile.path);
}
