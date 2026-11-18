#!/bin/sh
# Build build/Wound.app with a universal executable, SwiftPM resources, and an ad-hoc signature.
# SWIFT_BUILD_FLAGS is passed to `swift build`, e.g. "--build-system native" for a Command Line Tools
# release whose default build system cannot build the package.
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
version=${VERSION:-$(tr -d '\r\n' < "$root/VERSION")}
bundle_identifier=${WOUND_BUNDLE_IDENTIFIER:-com.s3onghyun.wound}
app="$root/build/Wound.app"

case ${ARCHS:-universal} in
  universal) architectures="arm64 x86_64" ;;
  arm64|x86_64) architectures=${ARCHS} ;;
  *) echo "ARCHS must be universal, arm64, or x86_64" >&2; exit 2 ;;
esac

bins=""
resource_bundle=""
for architecture in $architectures; do
  scratch="$root/.build/$architecture-release"
  swift build --package-path "$root" --scratch-path "$scratch" -c release \
    --triple "$architecture-apple-macosx14.0" --product Wound ${SWIFT_BUILD_FLAGS:-}
  bin_path=$(swift build --package-path "$root" --scratch-path "$scratch" -c release \
    --triple "$architecture-apple-macosx14.0" --show-bin-path ${SWIFT_BUILD_FLAGS:-})
  bins="$bins $bin_path/Wound"
  if [ -z "$resource_bundle" ]; then resource_bundle="$bin_path/Wound_Wound.bundle"; fi
done

set -- $bins
if [ "$#" -eq 1 ]; then
  bin=$1
else
  mkdir -p "$root/build"
  bin="$root/build/Wound-universal"
  lipo -create "$@" -output "$bin"
fi

rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin" "$app/Contents/MacOS/Wound"
cp -R "$resource_bundle" "$app/Contents/Resources/"
cp -R "$root/Resources/en.lproj" "$root/Resources/ko.lproj" "$root/Resources/Wound.icns" "$app/Contents/Resources/"

cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>$bundle_identifier</string>
  <key>CFBundleName</key><string>Wound</string>
  <key>CFBundleDisplayName</key><string>Wound</string>
  <key>CFBundleExecutable</key><string>Wound</string>
  <key>CFBundleIconFile</key><string>Wound</string>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleLocalizations</key><array><string>en</string><string>ko</string></array>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$version</string>
  <key>CFBundleVersion</key><string>$version</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHumanReadableCopyright</key><string>MIT</string>
</dict>
</plist>
PLIST

codesign --force --sign - "$app"
printf '%s\n' "$app"
