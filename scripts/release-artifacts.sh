#!/bin/sh
# Produce an ad-hoc-signed, unnotarized archive and its SHA-256 sidecar for local testing.
# The Release workflow signs and notarizes the app instead (.github/RELEASING.md).
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
version=$(tr -d '\r\n' < "$root/VERSION")
dist="$root/dist"

rm -rf "$dist"
mkdir -p "$dist"
VERSION="$version" ARCHS=universal "$root/scripts/bundle.sh"
archive="$dist/Wound-$version-macos-universal.zip"
ditto -c -k --sequesterRsrc --keepParent "$root/build/Wound.app" "$archive"
(cd "$dist" && shasum -a 256 "$(basename "$archive")" > "$(basename "$archive").sha256")
printf '%s\n' "$archive"
