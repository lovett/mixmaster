unit module Command::Version;

my sub Version() is export {
    say $?DISTRIBUTION.meta<version> || "dev"
}
