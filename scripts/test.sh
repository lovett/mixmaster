#!/usr/bin/env sh

set -eu

cd "$(dirname "$0")/../"

case "${1:-default}" in
    --help)
        echo "Run unit and integration tests"
        ;;
    default)
        prove6 --jobs 8 --lib t/ xt/
        ;;
    *)
        echo "Unknown argument." >&2
        ;;
esac
