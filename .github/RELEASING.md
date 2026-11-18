# Releasing Wound

`.github/workflows/release.yml` builds the GitHub release in two phases.
Apple usually notarizes in minutes, but a new developer account can wait hours.
Waiting inside one job would rebuild, re-sign, and resubmit on every retry, so a late `Accepted` would have no app left to staple.
Instead phase 1 keeps the submitted app, and phase 2 staples that same app and publishes it once Apple has finished.

| Phase | When | What it does | Publishes |
|---|---|---|---|
| 1 (submit) | push a `vX.Y.Z` tag | movement checks -> universal app (`scripts/bundle.sh`) -> Developer ID signature with the hardened runtime -> notarization submit without waiting -> keeps the signed zip, its `.sha256`, and `submission.json` (the submission id) as the artifact `wound-signed-X.Y.Z` for 90 days | nothing |
| 2 (publish) | manual run with `-f run_id=<phase-1 run id>` after Apple accepts | downloads that artifact, checks its sha256 -> `notarytool info` -> staples the same app -> `stapler validate` and `spctl` -> `Wound-X.Y.Z-macos-universal.zip` and `.sha256` -> GitHub Release | the Release |

While Apple still reports `In Progress`, phase 2 changes nothing and fails; run the same command again later, within the artifact's 90 days.
The Release is titled `Wound vX.Y.Z`, its notes are `.github/release-header.md` followed by the version's `CHANGELOG.md` section, and it carries the zip, its `.sha256`, the demo videos, and the Explain screenshots.

Without the signing secret (`APPLE_DEVELOPER_ID_P12`) phase 1 **fails**; Wound is never released ad-hoc signed again. A missing companion secret fails it too.

The Mac App Store build (`scripts/bundle-mas.sh`, `appstore/RUNBOOK.md`) is separate and untouched by this workflow.

## Release steps

1. Move the `CHANGELOG.md` entries under `## X.Y.Z (date)` and set `VERSION` to `X.Y.Z` in a pull request, then merge it.
2. Tag the merge commit and push only the tag:

   ```sh
   R=s3onghyun/wound
   git tag -a vX.Y.Z -m "Wound vX.Y.Z" <merge commit> && git push origin vX.Y.Z
   ```

3. Find the phase-1 run. Its summary shows the submission id and the exact phase-2 command; the log has `Notarization submitted: <id>`.

   ```sh
   gh run list -R "$R" -w release.yml -L 5
   ```

4. Once Apple has accepted (see "Check a submission from a Mac" below), run phase 2 from the default branch:

   ```sh
   gh workflow run release.yml -R "$R" --ref main -f run_id=<phase-1 run id>
   ```

5. After the Release is up, bump the Homebrew cask in `s3onghyun/homebrew-tap`; it reads the Release's `.sha256`.

| Phase 2 result | Meaning | Next |
|---|---|---|
| success, summary `Published vX.Y.Z` | the Release exists | bump the cask |
| failure, `Notarization still in progress` | Apple is still working; nothing changed | run the same command later, or re-run that phase-2 run |
| failure, `Notarization Invalid` with the notarization log | Apple rejected the app | fix the log's `issues` and release a new patch version from phase 1 |
| failure, `The signed zip does not match submission.json` | the artifact is not what phase 1 left | do not publish; find out why, then redo phase 1 (below) |
| failure, `Tag vX.Y.Z is at …, but phase 1 built …` | the tag moved after phase 1 | move the tag back, or redo phase 1 for it |
| failure, `needs exactly one wound-signed-* artifact` | wrong run id, phase 1 failed, or 90 days passed | check the run id, or redo phase 1 |
| failure, `release … already exists` | already published | nothing |

`-f submission_id=<id>` makes phase 2 check another submission than the one in the artifact.
Stapling finds the ticket by the app's code hash, not the submission id, so this only works when the same app was accepted under that other submission; otherwise `stapler` or `spctl` fails and nothing is published.

### Redo phase 1 for an existing tag

Re-running a tag-push run replays the workflow as it was in that tag.
To rebuild an existing tag with the current workflow, run it from the default branch with `tag`: the source comes from the tag, and the notarization script from the workflow's commit.

```sh
gh workflow run release.yml -R "$R" --ref main -f tag=vX.Y.Z
```

It behaves like a tag push (90-day artifact, nothing published) and submits a fresh signature, so run phase 2 with this run's id.

## Dry run

A manual run without inputs does phase 1 only, names the build after the branch (for example `Wound-fm-wound-012-release-macos-universal-signed.zip`), and keeps the artifact for 7 days.

```sh
gh workflow run release.yml -R s3onghyun/wound --ref <branch>
```

Check the log for `Notarization credentials: api-key` and `Notarization submitted: <id>`.
After Apple accepts, run phase 2 on the same branch with that run's id; the summary of phase 1 prints the command.
It staples and verifies but publishes nothing, and keeps the stapled zip as the artifact `wound-dry-run` for 7 days.
Download it, unzip it, and run `spctl -a -vv -t exec Wound.app` and `xcrun stapler validate Wound.app` on a Mac, then delete the test copy.

## What `scripts/notarize-app.sh` does

`submit` (phase 1, needs every signing secret):

1. Creates a keychain for this run only and imports the `.p12`; the runner's login keychain is untouched, and the keychain is deleted at the end.
2. Signs `build/Wound.app` with this team's "Developer ID Application" certificate: `codesign --force --options runtime --timestamp`.
   The identifier stays `com.s3onghyun.wound`.
   The GitHub build is not sandboxed and needs no entitlements or hardened-runtime exceptions: sounds play through `NSSound` from `Contents/Resources/Wound_Wound.bundle`, the global monitor watches only mouse movement and scrolling, and keyboard activity is read as idle time from `CGEventSource`.
3. Zips the signed app as `dist/notary/Wound-X.Y.Z-macos-universal-signed.zip` with a `.sha256` and submits that zip with `xcrun notarytool submit`, without `--wait`.
4. Writes the submission id, version, zip name, zip sha256, built commit, and submission time to `dist/notary/submission.json` and prints `Notarization submitted: <id>`.

`finish [<submission id>]` (phase 2, gets no `.p12`, only the team ID and the notarization credentials):

1. Checks the zip in `dist/notary/` against the sha256 in `submission.json` and its `.sha256`.
2. Runs `xcrun notarytool info <id>`, retrying transient failures three times. `In Progress` exits 75; `Invalid` prints `notarytool log` and exits 1.
3. On `Accepted`, unzips it to `build/Wound.app`, checks the signing team, then runs `xcrun stapler staple`, `stapler validate`, `codesign --verify --deep --strict`, and `spctl --assess`, which must report `source=Notarized Developer ID`.
4. Zips the stapled app as `dist/Wound-X.Y.Z-macos-universal.zip` with its `.sha256`, the same name and layout as before.

Secrets reach only the steps that need them, as environment variables, and are never printed.
The `.p12` reaches phase 1's signing step only; `contents: write` belongs only to the final publish job, which has no Apple secrets.
The release workflow never runs on pull requests.

`scripts/release-artifacts.sh` still makes an ad-hoc-signed, unnotarized archive for local testing; the workflow no longer uses it.

## Secrets

Settings -> Secrets and variables -> Actions -> Repository secrets. Only the names are written down here.

| Name | Required | Contents |
|---|---|---|
| `APPLE_DEVELOPER_ID_P12` | yes | base64 of the exported Developer ID Application certificate and private key (`.p12`) |
| `APPLE_DEVELOPER_ID_P12_PASSWORD` | yes | the `.p12` export password |
| `APPLE_TEAM_ID` | yes | the team ID (10 uppercase letters and digits) |
| `APPLE_API_KEY_ID` | notarization, option A | App Store Connect API key ID |
| `APPLE_API_ISSUER_ID` | notarization, option A | that key's issuer ID |
| `APPLE_API_KEY_P8` | notarization, option A | base64 of `AuthKey_<key id>.p8` |
| `APPLE_ID` | notarization, option B | Apple account email |
| `APPLE_APP_SPECIFIC_PASSWORD` | notarization, option B | that account's app-specific password |

Set option A or option B; any option A value selects option A. Wound uses option A.

## Check a submission from a Mac

The phase-1 summary and log carry the submission id. With the API key kept outside the repository:

```sh
xcrun notarytool info <id> --key ~/keys/AuthKey_XXXXXXXXXX.p8 --key-id <key id> --issuer <issuer id>
xcrun notarytool log  <id> --key ~/keys/AuthKey_XXXXXXXXXX.p8 --key-id <key id> --issuer <issuer id>
```

When it reports `Accepted`, run phase 2. Checking every few hours is enough.
An `Invalid` result's `issues` explain the rejection, most often a signature, hardened-runtime, or timestamp problem.
Fix it and tag a new patch version; never move a published tag.
