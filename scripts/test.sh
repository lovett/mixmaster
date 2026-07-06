#!/usr/bin/env sh

set -eu

cd "$(dirname "$0")/../"

if [ ! -f "$HOME/.raku/bin/prove6" ]; then
    zef install App::Prove6
fi

echo "Running prove6 in quiet mode"

prove6 -q --jobs 8  --lib t/ xt/
