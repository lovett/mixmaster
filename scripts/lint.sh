#!/usr/bin/env sh

set -eu

# Run from repository root
cd "$(dirname "$0")/../"

lint_sh() {
    if command -v "shellcheck" > /dev/null 2>&1; then
        shellcheck scripts/*
    else
        echo "ShellCheck is not installed"
        exit 1
    fi
}

lint_json() {
    if command -v "jq" > /dev/null 2>&1; then
        jq empty < META6.json
    else
        echo "jq is not installed"
        exit 1
    fi
}

ARG="${1:-}"

if [ "$ARG" = "--help" ]; then
    NAME=$(basename "$0")
    echo "Run language-specific linters to check code quality."
    echo ""
    echo "Usage:"
    echo "$NAME sh   Runs shellcheck"
    echo "$NAME json Runs jq on META6.json"
    echo "$NAME      Runs all linters"
    exit 0
fi

case "$ARG" in
    sh)
        lint_sh
        ;;
    json)
        lint_json
        ;;
    "")
        lint_sh
        lint_json
        ;;
    *)
        echo "Unknown argument." >&2
        exit 1
        ;;
esac
