#!/usr/bin/env sh

set -eu

cd "$(dirname "$0")/../"

case "${1:-default}" in
    --help)
        echo "Installs the application to ~/.raku/bin"
        ;;
    default)
        VERSION=$(date +"%Y%m.%d.%H%M")

        sed -i "s/\"version-placeholder\"/\"$VERSION\"/" META6.json

        zef --to=home install .

        git restore META6.json
        ;;
    *)
        echo "Unknown argument." >&2
        ;;
esac
