#!/usr/bin/env sh

set -eu

cd "$(dirname "$0")/../"

echo "Running prove6 in quiet mode"

prove6 -q --jobs 8  --lib t/ xt/
