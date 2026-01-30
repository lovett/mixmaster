#!/usr/bin/env sh

set -eu

cd "$(dirname "$0")/../"

case "${1:-default}" in
    --help)
        echo "Installs the application to ~/.raku/bin"
        ;;
    default)
        zef --to=home install .
        ;;
    *)
        echo "Unknown argument." >&2
        ;;
esac
