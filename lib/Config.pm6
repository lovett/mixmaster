unit module Config;

use Config::INI;

our IO::Path constant CONFIG = $*HOME.add(".config/mixmaster.ini");

sub has-config() is export {
    return CONFIG.f
}

sub get-config() is export {
    return Config::INI::parse_file(Str(CONFIG));
}

sub get-job-config(IO::Path $jobFile) is export {
    return Config::INI::parse_file($jobFile.path);
}

sub create-initial-config(
    IO::Path $configPath,
    IO::Path $buildRoot,
    IO::Path $spool,
    Str $email,
    Str $sshKey
) is export {
    spurt $configPath, qq:to/END/;
    ; This is the configuration file for mixmaster. It maps project repositories
    ; to build commands and defines application settings.

    [_]

    ; The directory that will store builds.
    buildRoot = {$buildRoot}

    ; The SSH key that should be loaded at the start of each build.
    sshKey = {$sshKey}

    ; The directory that stores job files.
    spool = {$spool}

    ; Use "dryrun" to echo build commands for testing purposes.
    ; Use "normal" to have build commands executed.
    mode = normal

    ; The email address that should receive build updates.
    mailto = {$email}

    ; Sample project configuration.
    [example-org/example-repo]
    production = make deploy
    staging = make deploy-to-staging
    master/my-task = make my-task

    END

    say "Populated {$configPath} with  default configuration."
}
