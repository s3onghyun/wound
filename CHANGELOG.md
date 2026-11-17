# Changelog

## Unreleased

### Added
- Korean interface, including the Explain tour.
- An app icon, drawn by the watch's own rendering code.
- Settings… and Privacy Policy in the menu bar menu, and a privacy policy link in Settings.
- A Mac App Store build (`scripts/bundle-mas.sh`) with App Sandbox, a privacy manifest, and no command-line modes, plus store material in `appstore/`.

### Fixed
- Show Wound in the menu bar menu reopens the watch window after it has been closed.

### Changed
- Automatic winding no longer installs a global key-press monitor. Keyboard activity still winds the rotor through the time since the last input event, and other apps' keystrokes are never seen.

## 0.1.1 (2026-11-17)

### Fixed
- Turning Sound on no longer crashes the app. The sounds are now found inside `Wound.app/Contents/Resources`, and a missing sound bundle leaves the watch silent instead of stopping it.

## 0.1.0 (2026-11-06)

### Added
- First public release of Wound, a macOS mechanical watch that runs on a 40-hour power reserve.
- An ad-hoc-signed universal app archive for Apple silicon and Intel Macs.
