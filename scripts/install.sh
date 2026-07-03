#!/usr/bin/env sh

set -eu

cd "$(dirname "$0")/../"

VERSION=$(date +"%Y%m.%d.%H%M")

sed -i "s/\"version-placeholder\"/\"$VERSION\"/" META6.json

zef --to=home install .

git restore META6.json
