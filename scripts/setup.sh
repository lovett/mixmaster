#!/usr/bin/env sh

set -eu

cd "$(dirname "$0")/../"

PACKAGES="jq ShellCheck"

# shellcheck disable=SC2086 # because splitting of PACKAGES is intentional.
if ! rpm -q $PACKAGES >/dev/null 2>&1; then
    echo "Installing packages..."
    sudo dnf --assumeyes install $PACKAGES
fi

if ! command -v prove6 >/dev/null 2>&1; then
    zef install App::Prove6
fi
