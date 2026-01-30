#!/usr/bin/env sh

set -eu

cd "$(dirname "$0")/../"

case "${1:-default}" in
    --help)
        echo "Removes the application from ~/.raku/bin"
        ;;
    default)
        zef uninstall Mixmaster
        ;;
    *)
        echo "Unknown argument." >&2
        ;;
esac
