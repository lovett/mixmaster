#!/usr/bin/env sh

set -eu

cd "$(dirname "$0")/../"

case "${1:-default}" in
    --help)
        echo "Run unit and integration tests"
        ;;
    default)
        echo "Running prove6 in quiet mode"
        prove6 -q --jobs 8  --lib t/ xt/
        ;;
    *)
        echo "Unknown argument." >&2
        ;;
esac
