# App Privacy answers

App Store Connect → Apps → Wound → **App Privacy**.
Source: <https://developer.apple.com/app-store/app-privacy-details/> (read 2026-11-17).

| Question | Answer |
|---|---|
| Privacy Policy URL | `https://s3onghyun.github.io/wound/privacy.html` |
| User Privacy Choices URL | leave empty (optional; there is nothing to opt out of) |
| Do you or your third-party partners collect data from this app? | **No, we do not collect data from this app** |

Choosing "No" ends the questionnaire; the product page then shows **Data Not Collected**.

## Why "No" is accurate

- Wound has no network code, no SDKs, no analytics, no crash reporter, no account.
  The App Store build is sandboxed with only `com.apple.security.app-sandbox`, so it cannot open a network connection even by accident (no `com.apple.security.network.client`).
- Settings, the reserve and the shown time are stored in `UserDefaults` inside the app's container and never leave the Mac.
  Apple's definition: data is "collected" when it is transmitted off the device. Nothing is.
- Automatic winding reads only the seconds since the last input event (`CGEventSource.secondsSinceLastEventType`) and mouse-move/scroll events, in memory, to wind the drawn rotor. It is not stored or sent.

## Privacy manifest

The App Store build carries `Contents/Resources/PrivacyInfo.xcprivacy` (source: `Resources/MAS/PrivacyInfo.xcprivacy`):

- `NSPrivacyTracking` = false, no tracking domains.
- `NSPrivacyCollectedDataTypes` = empty.
- `NSPrivacyAccessedAPITypes`: `NSPrivacyAccessedAPICategoryUserDefaults` with reason `CA92.1` (read and write data only accessible to the app itself).

The code uses no other required-reason API (file timestamps, system boot time, disk space, active keyboards).
`swift test` (`privacyManifestListsEveryRequiredReasonAPI`) fails if one of them appears in `Sources/`, so the manifest cannot silently fall behind.
