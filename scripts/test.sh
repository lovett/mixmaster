#!/usr/bin/env sh

set -eu

PATH="$HOME/.raku/bin:$PATH"

cd "$(dirname "$0")/../"

if ! command -v prove6 >/dev/null 2>&1; then
    zef install App::Prove6
fi

echo "Running prove6 in quiet mode"

prove6 -q --jobs 8  --lib t/ xt/
