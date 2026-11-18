#!/usr/bin/env bash
# Notarize the release app in two phases, so a slow Apple review never throws away the signed app and its
# submission (.github/RELEASING.md).
#
#   notarize-app.sh submit
#     Re-sign build/Wound.app (made by scripts/bundle.sh) with Developer ID and the hardened runtime, zip it,
#     and submit it with notarytool without waiting. Leaves Wound-$VERSION-macos-universal-signed.zip, its
#     .sha256, and submission.json (submission id, version, sha256, commit, time) in dist/notary/, which the
#     Release workflow keeps as an artifact, and prints "Notarization submitted: <id>".
#   notarize-app.sh finish [<submission-id>]
#     Check the zip in dist/notary/ against submission.json, then ask notarytool for the status.
#       Accepted     Unzip it to build/Wound.app, staple, check stapler validate and that spctl reports
#                    "source=Notarized Developer ID", and write dist/Wound-$VERSION-macos-universal.zip and
#                    its .sha256 the same way scripts/release-artifacts.sh does (exit 0).
#       In Progress  Change nothing and exit 75, to run again later.
#       otherwise    Print the notarytool log and exit 1.
#     Without an id it uses the one in submission.json.
#
# Every value comes from the environment and is never printed. Do not turn on set -x.
#   VERSION                          submit only: the version in the archive name. finish reads it from submission.json
#   APPLE_DEVELOPER_ID_P12           submit only: base64 of the Developer ID Application certificate and private key (.p12)
#   APPLE_DEVELOPER_ID_P12_PASSWORD  submit only: the password the .p12 was exported with
#   APPLE_TEAM_ID                    team ID (10 uppercase letters and digits); checked against the app's signature
#   Notarization credentials, one of (the API key wins when any of its values is set):
#     APPLE_API_KEY_ID + APPLE_API_ISSUER_ID + APPLE_API_KEY_P8 (base64 of the .p8)
#     APPLE_ID + APPLE_APP_SPECIFIC_PASSWORD
#   RELEASE_ROOT                     the directory holding build/ and dist/ (default: this script's repository)
set -euo pipefail

usage() { echo "usage: notarize-app.sh submit | finish [<submission-id>]" >&2; exit 2; }
MODE="${1:-}"
case "$MODE" in
  submit) (($# == 1)) || usage ;;
  finish) (($# <= 2)) || usage ;;
  *) usage ;;
esac

cd "${RELEASE_ROOT:-$(dirname "$0")/..}"
APP="build/Wound.app"
NOTARY="dist/notary"
EX_IN_PROGRESS=75

missing=()
need() { local v; for v in "$@"; do [[ -n "${!v:-}" ]] || missing+=("$v"); done; }
[[ "$MODE" == submit ]] && need APPLE_DEVELOPER_ID_P12 APPLE_DEVELOPER_ID_P12_PASSWORD
need APPLE_TEAM_ID
if [[ -n "${APPLE_API_KEY_ID:-}${APPLE_API_ISSUER_ID:-}${APPLE_API_KEY_P8:-}" ]]; then
  AUTH=api-key
  need APPLE_API_KEY_ID APPLE_API_ISSUER_ID APPLE_API_KEY_P8
elif [[ -n "${APPLE_ID:-}${APPLE_APP_SPECIFIC_PASSWORD:-}" ]]; then
  AUTH=apple-id
  need APPLE_ID APPLE_APP_SPECIFIC_PASSWORD
else
  AUTH=none
  missing+=("APPLE_API_KEY_ID/APPLE_API_ISSUER_ID/APPLE_API_KEY_P8 or APPLE_ID/APPLE_APP_SPECIFIC_PASSWORD")
fi
if ((${#missing[@]})); then
  echo "Missing notarization secrets: ${missing[*]}" >&2
  exit 1
fi
[[ "$APPLE_TEAM_ID" =~ ^[A-Z0-9]{10}$ ]] || { echo "APPLE_TEAM_ID must be 10 uppercase letters and digits" >&2; exit 1; }
[[ "$(uname -s)" == Darwin ]] || { echo "notarize-app.sh runs only on macOS" >&2; exit 1; }
echo "Notarization credentials: $AUTH"

is_uuid() { [[ "$1" =~ ^[0-9A-Fa-f]{8}-([0-9A-Fa-f]{4}-){3}[0-9A-Fa-f]{12}$ ]]; }
is_version() { [[ "$1" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$ ]]; }
sha256_of() { shasum -a 256 "$1" | cut -d' ' -f1; }
json_field() { plutil -extract "$2" raw -o - "$1" 2>/dev/null || true; }

WORK="$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/wound-notarize.XXXXXX")"
KEYCHAIN=""
OLD_KEYCHAINS=()
cleanup() {
  if [[ -n "$KEYCHAIN" ]]; then
    security list-keychains -d user -s ${OLD_KEYCHAINS[@]+"${OLD_KEYCHAINS[@]}"} 2>/dev/null || true
    security delete-keychain "$KEYCHAIN" 2>/dev/null || true
  fi
  rm -rf "$WORK"
}
trap cleanup EXIT

if [[ "$AUTH" == api-key ]]; then
  printf '%s' "$APPLE_API_KEY_P8" | base64 --decode > "$WORK/AuthKey.p8"
  NOTARY_AUTH=(--key "$WORK/AuthKey.p8" --key-id "$APPLE_API_KEY_ID" --issuer "$APPLE_API_ISSUER_ID")
else
  NOTARY_AUTH=(--apple-id "$APPLE_ID" --team-id "$APPLE_TEAM_ID" --password "$APPLE_APP_SPECIFIC_PASSWORD")
fi

# notarytool errors carry no secrets, but mask any that slip in before showing the tail.
redact() {
  local s="$1" v
  for v in APPLE_DEVELOPER_ID_P12 APPLE_DEVELOPER_ID_P12_PASSWORD APPLE_API_KEY_ID APPLE_API_ISSUER_ID APPLE_API_KEY_P8 \
    APPLE_ID APPLE_APP_SPECIFIC_PASSWORD; do
    [[ -n "${!v:-}" ]] && s="${s//"${!v}"/<redacted>}"
  done
  printf '%s\n' "$s"
}
show_tail() { redact "$(tail -n 20 "$1" 2>/dev/null || true)" >&2; }

submit() {
  VERSION="${VERSION:?VERSION is required}"
  is_version "$VERSION" || { echo "VERSION may hold only letters, digits, and ._-: $VERSION" >&2; exit 1; }
  [[ -d "$APP" ]] || { echo "$APP is missing; run scripts/bundle.sh first" >&2; exit 1; }
  local signed="Wound-$VERSION-macos-universal-signed.zip"

  KEYCHAIN="$WORK/signing.keychain-db"
  local line
  while IFS= read -r line; do
    line="${line#"${line%%[![:space:]]*}"}"; line="${line#\"}"; line="${line%\"}"
    [[ -n "$line" ]] && OLD_KEYCHAINS+=("$line")
  done < <(security list-keychains -d user)

  # 1. Import the certificate into a keychain that lives only for this run; the login keychain is untouched.
  local keychain_password
  keychain_password="$(uuidgen)"
  security create-keychain -p "$keychain_password" "$KEYCHAIN"
  security set-keychain-settings -lut 3600 "$KEYCHAIN"
  security unlock-keychain -p "$keychain_password" "$KEYCHAIN"
  printf '%s' "$APPLE_DEVELOPER_ID_P12" | base64 --decode > "$WORK/developer-id.p12"
  security import "$WORK/developer-id.p12" -k "$KEYCHAIN" -f pkcs12 -P "$APPLE_DEVELOPER_ID_P12_PASSWORD" -T /usr/bin/codesign >/dev/null
  rm -f "$WORK/developer-id.p12"
  security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$keychain_password" "$KEYCHAIN" >/dev/null
  security list-keychains -d user -s "$KEYCHAIN" ${OLD_KEYCHAINS[@]+"${OLD_KEYCHAINS[@]}"}

  # Sign with the SHA-1 of this team's Developer ID Application certificate, so a shared name cannot pick another one.
  local identity
  identity="$(security find-identity -v -p codesigning "$KEYCHAIN" \
    | awk -v team="($APPLE_TEAM_ID)\"" 'index($0, "\"Developer ID Application: ") && index($0, team) { print $2; exit }')"
  [[ -n "$identity" ]] || { echo "The .p12 has no Developer ID Application certificate for this team" >&2; exit 1; }

  # 2. Hardened runtime and a secure timestamp, both required for notarization. The GitHub build is not
  # sandboxed and needs no entitlements or runtime exceptions; the identifier stays com.s3onghyun.wound.
  codesign --force --options runtime --timestamp --keychain "$KEYCHAIN" --sign "$identity" "$APP"
  check_signature

  # 3. The zip that is submitted is the zip that is kept; finish unpacks exactly this file and staples it.
  rm -rf "$NOTARY"
  mkdir -p "$NOTARY"
  ditto -c -k --sequesterRsrc --keepParent "$APP" "$NOTARY/$signed"
  local sha
  sha="$(sha256_of "$NOTARY/$signed")"
  (cd "$NOTARY" && shasum -a 256 "$signed" > "$signed.sha256")

  # Submit without --wait and keep only the id; finish asks for the result later.
  xcrun notarytool submit "$NOTARY/$signed" "${NOTARY_AUTH[@]}" --output-format json \
    > "$WORK/submit.json" 2> "$WORK/submit.err" || true
  local id
  id="$(json_field "$WORK/submit.json" id)"
  if ! is_uuid "$id"; then
    echo "Notarization submit failed: no submission id. End of the notarytool output:" >&2
    show_tail "$WORK/submit.json"
    show_tail "$WORK/submit.err"
    exit 1
  fi

  local commit
  commit="$(git rev-parse HEAD 2>/dev/null || true)"
  [[ "$commit" =~ ^[0-9a-f]{40}$ ]] || commit=""
  # Every value was format-checked above, so none can hold a quote or a backslash.
  printf '{\n  "id": "%s",\n  "version": "%s",\n  "zip": "%s",\n  "sha256": "%s",\n  "commit": "%s",\n  "submitted_at": "%s"\n}\n' \
    "$id" "$VERSION" "$signed" "$sha" "$commit" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$NOTARY/submission.json"
  echo "Notarization submitted: $id"
  echo "Signed archive: $NOTARY/$signed (sha256 $sha)"
}

# The Developer ID signature is valid and belongs to APPLE_TEAM_ID.
check_signature() {
  codesign --verify --deep --strict --verbose=2 "$APP"
  local team
  team="$(codesign -dv "$APP" 2>&1 | sed -n 's/^TeamIdentifier=//p')"
  [[ "$team" == "$APPLE_TEAM_ID" ]] || { echo "The app's TeamIdentifier is not APPLE_TEAM_ID" >&2; exit 1; }
}

finish() {
  local json="$NOTARY/submission.json"
  [[ -f "$json" ]] || { echo "$json is missing; download the submit artifact into $NOTARY" >&2; exit 1; }
  local recorded version signed sha
  recorded="$(json_field "$json" id)"
  version="$(json_field "$json" version)"
  signed="$(json_field "$json" zip)"
  sha="$(json_field "$json" sha256)"
  is_uuid "$recorded" || { echo "submission.json has a malformed id" >&2; exit 1; }
  is_version "$version" || { echo "submission.json has a malformed version" >&2; exit 1; }
  [[ "$signed" == "Wound-$version-macos-universal-signed.zip" ]] || { echo "submission.json names a zip that does not match its version" >&2; exit 1; }
  [[ -f "$NOTARY/$signed" ]] || { echo "$NOTARY/$signed is missing" >&2; exit 1; }
  [[ "$sha" =~ ^[0-9a-f]{64}$ && "$(sha256_of "$NOTARY/$signed")" == "$sha" ]] \
    || { echo "The signed zip does not match submission.json" >&2; exit 1; }
  (cd "$NOTARY" && shasum -a 256 -c "$signed.sha256" >/dev/null) \
    || { echo "The signed zip does not match $signed.sha256" >&2; exit 1; }

  local id="${1:-$recorded}"
  is_uuid "$id" || { echo "The submission id must be a UUID" >&2; exit 1; }
  [[ "$id" == "$recorded" ]] || echo "Using the given submission id $id instead of $recorded from the artifact"
  echo "Checking notarization: submission $id, version $version"

  # Retry a transient status failure up to three times.
  local status="" try
  for try in 1 2 3; do
    if xcrun notarytool info "$id" "${NOTARY_AUTH[@]}" --output-format json > "$WORK/info.json" 2> "$WORK/info.err"; then
      status="$(json_field "$WORK/info.json" status)"
      break
    fi
    echo "notarytool info failed ($try/3) for submission $id" >&2
    ((try < 3)) && sleep "${NOTARY_RETRY_SECONDS:-20}"
  done
  if [[ -z "$status" ]]; then
    show_tail "$WORK/info.err"
    echo "Could not read the notarization status of submission $id; run again later" >&2
    exit 1
  fi
  echo "Notarization status: $status (submission $id)"
  case "$status" in
    Accepted) ;;
    "In Progress")
      echo "Notarization is still in progress for submission $id. Nothing changed; run phase 2 again once Apple finishes" >&2
      exit "$EX_IN_PROGRESS" ;;
    *)
      echo "Notarization $status for submission $id. Notarization log:" >&2
      # Only the validated UUID reaches notarytool log.
      xcrun notarytool log "$id" "${NOTARY_AUTH[@]}" || true
      exit 1 ;;
  esac

  # 4. Staple the ticket to the very app phase 1 signed and submitted, so Gatekeeper passes offline too.
  rm -rf "$APP"
  mkdir -p build
  ditto -x -k "$NOTARY/$signed" build
  [[ -d "$APP" ]] || { echo "The signed zip holds no Wound.app" >&2; exit 1; }
  check_signature
  xcrun stapler staple "$APP"
  xcrun stapler validate "$APP"
  codesign --verify --deep --strict --verbose=2 "$APP"
  spctl --assess --type execute --verbose=2 "$APP" 2>&1 | tee "$WORK/spctl.txt"
  grep -q "source=Notarized Developer ID" "$WORK/spctl.txt" \
    || { echo "Gatekeeper does not see a notarized Developer ID app" >&2; exit 1; }

  # 5. Archive the stapled app under the release name and layout that the Homebrew cask reads.
  local zip="Wound-$version-macos-universal.zip"
  rm -f "dist/$zip" "dist/$zip.sha256"
  ditto -c -k --sequesterRsrc --keepParent "$APP" "dist/$zip"
  (cd dist && shasum -a 256 "$zip" > "$zip.sha256")
  echo "Notarized and stapled: dist/$zip"
}

if [[ "$MODE" == submit ]]; then submit; else finish "${2:-}"; fi
