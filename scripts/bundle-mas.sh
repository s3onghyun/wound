#!/bin/sh
# Build build/mas/Wound.app for the Mac App Store: compiled with -D MAS (no command-line modes),
# App Sandbox entitlement, privacy manifest, store Info.plist keys, and an integer build number.
# The GitHub release keeps using scripts/bundle.sh; see appstore/RUNBOOK.md for the whole submission.
#
#   MAS_BUILD               integer CFBundleVersion, raised for every upload (default 1)
#   VERSION                 CFBundleShortVersionString (default: the VERSION file)
#   WOUND_BUNDLE_IDENTIFIER bundle id (default com.s3onghyun.wound; use a test id for local rehearsals)
#   MAS_SIGN_IDENTITY       codesign identity, e.g. "Apple Distribution: <name> (<team>)" (default "-", ad hoc)
#   MAS_INSTALLER_IDENTITY  when set, also writes build/mas/Wound-<version>-<build>.pkg signed with it,
#                           e.g. "3rd Party Mac Developer Installer: <name> (<team>)"
#   ARCHS                   universal (default), arm64 or x86_64
#   SWIFT_BUILD_FLAGS       extra `swift build` flags, e.g. "--build-system native"
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
version=${VERSION:-$(tr -d '\r\n' < "$root/VERSION")}
build=${MAS_BUILD:-1}
bundle_identifier=${WOUND_BUNDLE_IDENTIFIER:-com.s3onghyun.wound}
sign_identity=${MAS_SIGN_IDENTITY:--}
out="$root/build/mas"
app="$out/Wound.app"

case $build in
  ''|*[!0-9]*) echo "MAS_BUILD must be a positive integer" >&2; exit 2 ;;
esac

case ${ARCHS:-universal} in
  universal) architectures="arm64 x86_64" ;;
  arm64|x86_64) architectures=${ARCHS} ;;
  *) echo "ARCHS must be universal, arm64, or x86_64" >&2; exit 2 ;;
esac

bins=""
resource_bundle=""
for architecture in $architectures; do
  # A scratch path of its own, so MAS objects never mix with the GitHub build's.
  scratch="$root/.build/mas-$architecture-release"
  swift build --package-path "$root" --scratch-path "$scratch" -c release \
    --triple "$architecture-apple-macosx14.0" --product Wound -Xswiftc -DMAS ${SWIFT_BUILD_FLAGS:-}
  bin_path=$(swift build --package-path "$root" --scratch-path "$scratch" -c release \
    --triple "$architecture-apple-macosx14.0" --show-bin-path -Xswiftc -DMAS ${SWIFT_BUILD_FLAGS:-})
  bins="$bins $bin_path/Wound"
  if [ -z "$resource_bundle" ]; then resource_bundle="$bin_path/Wound_Wound.bundle"; fi
done

set -- $bins
mkdir -p "$out"
if [ "$#" -eq 1 ]; then
  bin=$1
else
  bin="$out/Wound-universal"
  lipo -create "$@" -output "$bin"
fi

# Guideline 2.5.19: the store binary must not carry the developer command-line modes.
for flag in --self-test --render-demo --render-explain --render-icon; do
  if strings "$bin" | grep -q -- "$flag"; then
    echo "$flag is still in the MAS binary; was it built without -D MAS?" >&2
    exit 1
  fi
done

rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin" "$app/Contents/MacOS/Wound"
cp -R "$resource_bundle" "$app/Contents/Resources/"
cp -R "$root/Resources/en.lproj" "$root/Resources/ko.lproj" "$root/Resources/Wound.icns" \
  "$root/Resources/MAS/PrivacyInfo.xcprivacy" "$app/Contents/Resources/"

# The SDK that built the binary, recorded the way Xcode records it.
sdk=${SDKROOT:-$(xcrun --sdk macosx --show-sdk-path)}
sdk_version=$(plutil -extract ProductVersion raw "$sdk/System/Library/CoreServices/SystemVersion.plist")
sdk_build=$(plutil -extract ProductBuildVersion raw "$sdk/System/Library/CoreServices/SystemVersion.plist")

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
  <key>CFBundleVersion</key><string>$build</string>
  <key>CFBundleSupportedPlatforms</key><array><string>MacOSX</string></array>
  <key>DTPlatformName</key><string>macosx</string>
  <key>DTPlatformVersion</key><string>$sdk_version</string>
  <key>DTPlatformBuild</key><string>$sdk_build</string>
  <key>DTSDKName</key><string>macosx$sdk_version</string>
  <key>DTSDKBuild</key><string>$sdk_build</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.lifestyle</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>ITSAppUsesNonExemptEncryption</key><false/>
  <key>NSHumanReadableCopyright</key><string>MIT</string>
</dict>
</plist>
PLIST
plutil -lint "$app/Contents/Info.plist" >/dev/null

# Uploads must not carry quarantine or other extended attributes.
xattr -cr "$app"
codesign --force --timestamp=none --options runtime --sign "$sign_identity" \
  --entitlements "$root/Resources/MAS/Wound.entitlements" "$app"
codesign --verify --strict "$app"

if [ -n "${MAS_INSTALLER_IDENTITY:-}" ]; then
  pkg="$out/Wound-$version-$build.pkg"
  productbuild --sign "$MAS_INSTALLER_IDENTITY" --component "$app" /Applications "$pkg"
  printf '%s\n' "$pkg"
fi
printf '%s\n' "$app"
