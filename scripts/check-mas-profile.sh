#!/bin/sh
# Check that a provisioning profile can be embedded in the Mac App Store build, and print its team id.
# Fails, saying why, unless the profile is a Mac App Store distribution profile (macOS, no device list,
# no get-task-allow) that has not expired, whose App ID is <team>.<bundle id>, and which contains the
# certificate of the codesign identity. scripts/bundle-mas.sh runs it before signing; see appstore/RUNBOOK.md §6.
#
#   scripts/check-mas-profile.sh <profile> <bundle id> <codesign identity: name or SHA-1>
set -eu

if [ "$#" -ne 3 ]; then
  echo "usage: $0 <profile> <bundle id> <codesign identity>" >&2
  exit 2
fi
profile=$1
bundle_identifier=$2
sign_identity=$3

fail() {
  echo "provisioning profile $profile: $*" >&2
  exit 1
}

[ -f "$profile" ] || fail "no such file (set MAS_PROVISIONING_PROFILE to the downloaded .provisionprofile)"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
plist="$work/profile.plist"
security cms -D -i "$profile" > "$plist" 2>/dev/null || fail "not a signed provisioning profile"
plutil -lint "$plist" >/dev/null 2>&1 || fail "not a signed provisioning profile"

value() { plutil -extract "$1" raw -o - "$plist" 2>/dev/null; }
has() { plutil -extract "$1" xml1 -o /dev/null "$plist" 2>/dev/null; }

value Platform.0 | grep -qx OSX || fail "not a macOS profile"
has ProvisionedDevices && fail "lists devices, so it is a development profile, not Mac App Store distribution"
has ProvisionsAllDevices && fail "provisions all devices, so it is a Developer ID profile, not Mac App Store distribution"
[ "$(value Entitlements.com\\.apple\\.security\\.get-task-allow || true)" != true ] ||
  fail "allows get-task-allow, so it is a development profile"

now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
expires=$(value ExpirationDate) || fail "has no ExpirationDate"
[ "$expires" \> "$now" ] || fail "expired on $expires"

team=$(value TeamIdentifier.0) || fail "has no TeamIdentifier"
expected="$team.$bundle_identifier"
application_identifier=$(value Entitlements.com\\.apple\\.application-identifier || true)
[ "$application_identifier" = "$expected" ] ||
  fail "App ID is '$application_identifier', not '$expected'"
[ "$(value Entitlements.com\\.apple\\.developer\\.team-identifier || true)" = "$team" ] ||
  fail "team identifier entitlement is not $team"

# SHA-1 of the identity's certificate, from the same keychain search list codesign uses.
identity_sha1=$(security find-identity -v -p codesigning | awk -v id="$sign_identity" '
  $2 ~ /^[0-9A-F]+$/ {
    name = $0; sub(/^[^"]*"/, "", name); sub(/"[^"]*$/, "", name)
    if (name == id || $2 == toupper(id)) { print $2; exit }
  }')
[ -n "$identity_sha1" ] || fail "codesign identity '$sign_identity' is not in the keychain search list (is the keychain unlocked?)"

index=0
while value "DeveloperCertificates.$index" > "$work/cert.b64"; do
  certificate_sha1=$(base64 -D -i "$work/cert.b64" | shasum -a 1 | awk '{ print toupper($1) }')
  if [ "$certificate_sha1" = "$identity_sha1" ]; then
    printf '%s\n' "$team"
    exit 0
  fi
  index=$((index + 1))
done
fail "does not contain the certificate of '$sign_identity' (SHA-1 $identity_sha1); regenerate it with that certificate"
