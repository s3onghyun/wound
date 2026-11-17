#!/bin/sh
# Redraw Resources/AppIcon-1024.png with the app's own Core Graphics code and pack Resources/Wound.icns.
# iconutil ships with macOS, so no Xcode asset catalog (actool) is needed.
# SWIFT_BUILD_FLAGS is passed to `swift build`, as in scripts/bundle.sh.
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

swift build --package-path "$root" --product Wound ${SWIFT_BUILD_FLAGS:-}
bin_path=$(swift build --package-path "$root" --show-bin-path ${SWIFT_BUILD_FLAGS:-})
"$bin_path/Wound" --render-icon "$root/Resources/AppIcon-1024.png"

iconset="$work/Wound.iconset"
mkdir -p "$iconset"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$root/Resources/AppIcon-1024.png" --out "$iconset/icon_${size}x${size}.png" >/dev/null
  double=$((size * 2))
  sips -z "$double" "$double" "$root/Resources/AppIcon-1024.png" --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$iconset" -o "$root/Resources/Wound.icns"
printf '%s\n' "$root/Resources/Wound.icns"
