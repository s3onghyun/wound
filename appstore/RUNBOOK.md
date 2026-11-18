# Mac App Store submission runbook

How Wound goes from this repository to "Waiting for Review" without Xcode: SwiftPM + Command Line Tools build, `codesign`, `productbuild`, and an upload through the App Store Connect API.
The GitHub release (`scripts/bundle.sh`, `.github/workflows/release.yml`) is untouched by this path.

Apple pages were read on 2026-11-17/18. Anything marked **(unverified)** is an interpretation or something Apple's pages do not state outright.

## Owner actions (need the owner's Apple account)

| # | Action | Where | Who |
|---|---|---|---|
| 1 | Confirm the support and privacy pages are live (GitHub Pages from `main` → `/docs`) | <https://s3onghyun.github.io/wound/>, <https://s3onghyun.github.io/wound/privacy.html> | firstmate enables Pages; owner checks |
| 2 | Sign the latest Apple Developer Program License Agreement | App Store Connect → Business → Agreements | Account Holder |
| 3 | Declare **non-trader** status for the EU Digital Services Act ([steps](#4-eu-digital-services-act-non-trader-declaration)) | App Store Connect → Business → Agreements → Compliance | Account Holder or Admin |
| 4 | Register the explicit App ID `com.s3onghyun.wound` ([steps](#1-app-id)) | developer.apple.com → Certificates, Identifiers & Profiles | Account Holder or Admin |
| 5 | Create a CSR on this Mac, then the **Apple Distribution** and **Mac Installer Distribution** certificates, and install both ([steps](#2-certificates)) | Keychain Access + Certificates, Identifiers & Profiles | Account Holder or Admin |
| 5a | Create the **Mac App Store Connect** provisioning profile ([steps](#2a-provisioning-profile)) and keep it outside the repository | Certificates, Identifiers & Profiles → Profiles | Account Holder or Admin |
| 6 | Create the macOS app record ([fields](#3-app-store-connect-app-record)) | App Store Connect → Apps → + → New App | Account Holder, Admin or App Manager |
| 7 | Enter metadata, App Privacy, age rating, price (Free), availability ([sources](#5-metadata)) | App Store Connect → the app | Account Holder, Admin or App Manager |
| 8 | Build, sign and package (commands in [§6](#6-build-sign-package)); a crewmate can run them once the certificates are in the keychain | this Mac | owner's keychain |
| 9 | Upload the `.pkg` with `scripts/upload-mas.py` ([§7](#7-upload)) | this Mac | App Store Connect API key (no Apple ID sign-in) |
| 10 | Pick the build, add screenshots, **Add for Review → Submit** ([§8](#8-submit)) | App Store Connect → the app → macOS App 0.x | owner |

Every signed build embeds a provisioning profile. App Review alone would not need one (Wound uses no entitlement besides App Sandbox, TN3125), but without it App Store Connect warns ITMS-90889 and the build cannot go to TestFlight.
That is what happened to the first upload (0.1.2 build 1, 2026-11-18): accepted with the single warning ITMS-90889 "Cannot be used with TestFlight because the bundle at “Wound.app” is missing a provisioning profile". From build 2 on, `scripts/bundle-mas.sh` refuses to sign without a profile.

## 1. App ID

Certificates, Identifiers & Profiles → Identifiers → **+** → **App IDs** → type **App** → Continue.

- Platform: **macOS**
- Description: `Wound`
- Bundle ID: **Explicit**, `com.s3onghyun.wound` (the id the GitHub build has always used; keeping it means one id for both channels)
- Capabilities: none. App Sandbox is not a portal capability; it comes from the entitlements file.

## 2. Certificates

Distribution certificates belong to the team, one of each type per team, and "Only the Account Holder or Admin role can create distribution certificates" (<https://developer.apple.com/help/account/reference/certificate-types>).

1. **CSR from this Mac's keychain.** Keychain Access → menu Keychain Access → Certificate Assistant → **Request a Certificate From a Certificate Authority…** → User Email Address: the Apple ID email, Common Name: your name, CA Email: empty, **Saved to disk** → Continue. The private key stays in the login keychain of this Mac.
2. Certificates → **+** → **Apple Distribution** ("Distribute your … macOS … app … or submit it to App Store Connect") → upload the CSR → Download → double-click the `.cer` to install it.
   Its keychain name is `Apple Distribution: <Name> (<TEAMID>)`.
   (The older **Mac App Distribution** type, keychain name `3rd Party Mac Developer Application: <Name> (<TEAMID>)`, also works for signing the app. Create one or the other, not both.)
3. Certificates → **+** → **Mac Installer Distribution** ("Sign and submit a Mac Installer Package, containing your signed app, to the Mac App Store") → same CSR → Download → install.
   Its keychain name is `3rd Party Mac Developer Installer: <Name> (<TEAMID>)`.
4. Check: `security find-identity -v -p codesigning` lists the Apple Distribution identity; `security find-identity -v` also lists the installer identity.

Not needed for the App Store: Developer ID certificates (those are for notarized direct downloads, a separate decision).

## 2a. Provisioning profile

Profiles → **+** → Distribution → **Mac App Store Connect** → App ID `com.s3onghyun.wound` → the **Apple Distribution** certificate of §2 → name `Wound Mac App Store` → Generate → Download.
Created 2026-11-18, expires 2027-11-18; regenerate it before then, and whenever the Apple Distribution certificate is replaced (the profile names the certificate).

Keep the `.provisionprofile` outside the repository (on this Mac: `~/.local/share/apple-mas/Wound_Mac_App_Store.provisionprofile`, mode 600) and pass its path as `MAS_PROVISIONING_PROFILE`.
`scripts/check-mas-profile.sh <profile> <bundle id> <identity>`, which `bundle-mas.sh` runs before building, fails unless it is a macOS distribution profile (no `ProvisionedDevices`, no `ProvisionsAllDevices`, no `get-task-allow`), not expired, for App ID `<TEAMID>.com.s3onghyun.wound`, and lists the certificate of `MAS_SIGN_IDENTITY` (compared by SHA-1 with `security find-identity`).

## 3. App Store Connect app record

Apps → **+** → **New App** (<https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app>). The Account Holder must have signed the latest agreement first.

| Field | Value |
|---|---|
| Platforms | **macOS** only |
| Name | `Wound: Mechanical Watch` (2-30 characters; a name can be used by one app per localization, so plain `Wound` may already be taken — if this one is too, try `Wound – Watch You Wind`) |
| Primary Language | **English (U.S.)** |
| Bundle ID | `com.s3onghyun.wound` (appears after step 1) |
| SKU | `wound-macos` (any unique string; never shown to customers) |
| User Access | **Full Access** |

After creation, App Information:

| Field | Value |
|---|---|
| Subtitle, localizations | from `metadata/en-US` and `metadata/ko` (add **Korean** under the language menu) |
| Category | Primary **Lifestyle**, secondary **Utilities** (`metadata/primary_category.txt`, `secondary_category.txt`; see `age-rating.md` for why not Entertainment) |
| Content Rights | Does not contain, show or access third-party content |
| Age Rating | `age-rating.md` → 4+ |
| Copyright (version page) | `2026 <your legal name>` |
| Pricing and Availability | Price **Free** (USD 0); all countries or regions, including the EU (allowed for non-traders) |
| App Privacy | `app-privacy.md` → Data Not Collected |

## 4. EU Digital Services Act non-trader declaration

Owner decision: declare **not a trader**. This is the owner's own legal determination; Apple says it "can't determine whether you're a trader."
Source: <https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements> (read 2026-11-18). Role: Account Holder or Admin.

1. App Store Connect → **Business** (top of the page).
2. **Agreements** tab → scroll to the **Compliance** section.
3. Next to **Digital Services Act**, click **Complete Compliance Requirements**.
4. Select **This is not a trader account.** (No contact details are asked for or published.)
5. Click **Done**.

Effect, per the same page: "consumers in the EU will be informed that consumer rights stemming from applicable consumer protection laws won't apply to contracts between you and them."
The declaration is required even without EU distribution; if it is still missing, App Store Connect asks for it at the next new-app submission.
To change it later for this app only: Apps → Wound → General → App Compliance → Digital Services Act → Edit.

## 5. Metadata

Everything to paste is in `appstore/metadata/`, one file per App Store Connect field (the fastlane `deliver` layout, so the folder also works with that tool if it is ever used):

| File | Field | Limit (checked by `swift test`) |
|---|---|---|
| `<locale>/name.txt` | Name | 30 characters |
| `<locale>/subtitle.txt` | Subtitle | 30 characters |
| `<locale>/promotional_text.txt` | Promotional Text | 170 characters |
| `<locale>/description.txt` | Description | 4000 characters |
| `<locale>/keywords.txt` | Keywords | 100 bytes, comma separated |
| `<locale>/support_url.txt` | Support URL | must reach real contact (GitHub issues) |
| `<locale>/privacy_url.txt` | Privacy Policy URL | required for macOS |
| `review_information/notes.txt` | App Review Information → Notes | 4000 bytes |

Locales: `en-US` = English (U.S.), `ko` = Korean.
Review contact (name, phone, email) is entered by the owner and is not stored here. Sign-in required: **No**.

Screenshots: `appstore/screenshots/en-US/*.png` and `appstore/screenshots/ko/*.png`, 2880×1800, PNG, no alpha (accepted 16:10 sizes: 1280×800, 1440×900, 2560×1600, 2880×1800; 1-10 per locale).
Upload them in file order: 1 running dial, 2 Explain (going train, bridges lifted), 3 caseback rotor, 4 unwound.
Each is a Retina capture of the MAS build's own window (the sandboxed app, launched with `-AppleLanguages '(en)'` or `'(ko)'`) on a plain dark backdrop with a caption; nothing in the window is retouched.
The icon comes from the build (`Contents/Resources/Wound.icns`, 16-1024 px, made by `scripts/make-icon.sh`); there is no separate upload for macOS.

## 6. Build, sign, package

On this Mac, from the repository root, after the certificates are installed.
Version: `CFBundleShortVersionString` comes from `VERSION` and must equal the version created in App Store Connect.
Build: `MAS_BUILD` is the integer `CFBundleVersion`; start at 1 and raise it for every upload (App Store Connect rejects a build number it has already seen for that version).

```sh
# Command Line Tools 27.2 cannot build the package with its default build system; use the 26.5 SDK
# and the native build system (drop both once a fixed CLT or Xcode is installed).
export SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk
export SWIFT_BUILD_FLAGS="--build-system native"

swift test -Xswiftc -F/Library/Developer/CommandLineTools/Library/Developer/Frameworks \
  -Xlinker -F/Library/Developer/CommandLineTools/Library/Developer/Frameworks \
  -Xlinker -rpath -Xlinker /Library/Developer/CommandLineTools/Library/Developer/Frameworks $SWIFT_BUILD_FLAGS

MAS_BUILD=2 \
MAS_SIGN_IDENTITY="Apple Distribution: <Name> (<TEAMID>)" \
MAS_INSTALLER_IDENTITY="3rd Party Mac Developer Installer: <Name> (<TEAMID>)" \
MAS_PROVISIONING_PROFILE=~/.local/share/apple-mas/Wound_Mac_App_Store.provisionprofile \
MAS_KEYCHAIN=~/Library/Keychains/mas-build.keychain-db \
  scripts/bundle-mas.sh
# -> build/mas/Wound.app and build/mas/Wound-<version>-2.pkg
```

What `scripts/bundle-mas.sh` does, so it can be done by hand if needed:

0. With a signing identity: requires `MAS_PROVISIONING_PROFILE` and runs `scripts/check-mas-profile.sh` on it (§2a), which also yields the team id.
1. `swift build -c release --triple {arm64,x86_64}-apple-macosx14.0 -Xswiftc -DMAS` into `.build/mas-*`, then `lipo -create` a universal binary.
   `-D MAS` compiles out `--self-test`, `--render-demo`, `--render-explain` and `--render-icon` (guideline 2.5.19); the script fails if any of those strings is still in the binary.
2. Assembles `Wound.app`: binary, `Wound_Wound.bundle` (sounds), `en.lproj`/`ko.lproj`, `Wound.icns`, `PrivacyInfo.xcprivacy`.
3. Writes Info.plist with `LSApplicationCategoryType` = `public.app-category.lifestyle`, integer `CFBundleVersion`, `CFBundleIconFile`, `ITSAppUsesNonExemptEncryption` = false (answers the export-compliance question), `CFBundleLocalizations` en/ko, `LSUIElement`, and the `DTSDK*`/`DTPlatform*` keys of the SDK used.
4. `xattr -cr Wound.app` (uploads must carry no `com.apple.quarantine`; <https://developer.apple.com/news/upcoming-requirements/>).
5. With a signing identity: copies the profile to `Wound.app/Contents/embedded.provisionprofile`, and signs with `Resources/MAS/Wound.entitlements` (App Sandbox) plus `com.apple.application-identifier` = `<TEAMID>.com.s3onghyun.wound` and `com.apple.developer.team-identifier` = `<TEAMID>`, the two entitlements the profile grants (written to `build/mas/Wound.entitlements`).
   An ad hoc build gets App Sandbox only, because an unprovisioned app carrying those restricted entitlements would not launch.
6. `codesign --force --options runtime --entitlements build/mas/Wound.entitlements --sign "$MAS_SIGN_IDENTITY" Wound.app`, `codesign --verify --strict --deep`, then reads the signed entitlements back and fails unless App Sandbox, the App ID and the team are there and the embedded profile is the checked one.
7. `productbuild --sign "$MAS_INSTALLER_IDENTITY" --component Wound.app /Applications Wound-<version>-<build>.pkg` and `pkgutil --check-signature`.

Checks before uploading:

```sh
codesign -d --entitlements - build/mas/Wound.app       # app-sandbox, application-identifier, team-identifier
ls build/mas/Wound.app/Contents/embedded.provisionprofile
codesign -dvv build/mas/Wound.app 2>&1 | grep Authority # Apple Distribution: …
pkgutil --check-signature build/mas/Wound-*.pkg         # 3rd Party Mac Developer Installer: …
plutil -p build/mas/Wound.app/Contents/Info.plist
```

Do not test-install the `.pkg` on this Mac with `installer`: it targets `/Applications/Wound.app`, where the GitHub build is installed.

## 7. Upload

`xcrun altool` needs Xcode, which this Mac does not have, and the Transporter app needs an Apple ID sign-in.
Neither is needed: `scripts/upload-mas.py` uploads through the public App Store Connect API (`POST /v1/buildUploads`, `POST /v1/buildUploadFiles`, the presigned `PUT`, then `PATCH … uploaded: true`) with an API key, and a key with the **Developer** role is enough.

```sh
# Key: ~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8 (mode 600); ids are overridable, see the script header.
scripts/upload-mas.py build/mas/Wound-<version>-<build>.pkg
```

It reads the version and build number from the package, uploads it, and polls until Apple's upload validation finishes (about a minute), printing every ITMS error and warning; exit 0 means state `COMPLETE`.
The build then shows up under the app's builds, usually already `VALID`; `GET /v1/builds?filter[app]=<app id>` shows `processingState`.
A rejected upload prints its ITMS errors, the state is `FAILED` and the exit status is 1.

The build's `CFBundleShortVersionString` must match the App Store version being submitted; this app's macOS version record was created as `1.0`, so rename it to the `VERSION` value (or build with `VERSION=1.0`) before choosing the build in §8.

Results of the first upload (0.1.2 build 1, 2026-11-18), for the risks a build made without Xcode carries:

- No `DTXcode`/`DTXcodeBuild` keys: accepted, no ITMS-90534.
- `Contents/Resources/Wound_Wound.bundle` without its own Info.plist: accepted.
- Only warning: ITMS-90889 (no provisioning profile, so no TestFlight); fixed from build 2 by embedding the profile (§2a).

## 8. Submit

App Store Connect → Apps → Wound → the macOS version (same number as `VERSION`):

1. Screenshots: drag the English set into English (U.S.) and the Korean set into Korean.
2. Paste promotional text, description, keywords, support URL from `metadata/`.
3. Build → **+** → choose the processed build. Export compliance is pre-answered by `ITSAppUsesNonExemptEncryption` = false.
4. App Review Information: contact details; Notes from `metadata/review_information/notes.txt`; sign-in not required.
5. Version Release: manual or automatic, owner's choice.
6. **Add for Review** → **Submit to App Review**. Status becomes "Waiting for Review".

## 9. TestFlight (optional)

TestFlight for macOS needs a provisioning profile even without restricted entitlements (TN3125). Signed builds embed the §2a profile, so a processed build can be added to TestFlight without another step here.

## 10. Local sandbox rehearsal (no account needed)

```sh
WOUND_BUNDLE_IDENTIFIER=com.s3onghyun.wound.mastest MAS_BUILD=1 scripts/bundle-mas.sh   # ad-hoc signed
open -n build/mas/Wound.app --args -AppleLanguages '(ko)'                               # or '(en)'
log show --last 10m --predicate 'sender == "Sandbox" AND eventMessage CONTAINS "Wound"'  # expect nothing
```

A test bundle id keeps the rehearsal's sandbox container (`~/Library/Containers/com.s3onghyun.wound.mastest`) and settings apart from the installed Wound.
