# Age rating answers

App Store Connect → Apps → Wound → **App Information** → Age Rating → Edit.
Item names from <https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions> (read 2026-11-18).
The exact answer choices are only shown inside App Store Connect (unverified here); for every item below pick the lowest choice (None / No).

| Section | Item | Answer |
|---|---|---|
| In-App Controls | Parental Controls | No |
| | Age Assurance | No |
| Capabilities | Unrestricted Web Access | No (the privacy link opens the user's own browser; there is no in-app web view) |
| | User-Generated Content | No |
| | Social Media | No |
| | Messaging and Chat | No |
| | Advertising | No |
| Mature Themes | Profanity or Crude Humor | None |
| | Horror/Fear Themes | None |
| | Alcohol, Tobacco, or Drug Use or References | None |
| Medical or Wellness | Medical or Treatment Information | None |
| | Health or Wellness Topics | No |
| Sexuality or Nudity | Mature or Suggestive Themes | None |
| | Sexual Content or Nudity | None |
| | Graphic Sexual Content and Nudity | None |
| Violence | Cartoon or Fantasy Violence | None |
| | Realistic Violence | None |
| | Prolonged Graphic or Sadistic Realistic Violence | None |
| | Guns or Other Weapons | None |
| Chance-Based Activities | Gambling | No |
| | Simulated Gambling | None |
| | Contests | None |
| | Loot Boxes | No |

Expected result: **4+**.

## Category and Korea

- Primary category **Lifestyle** (`public.app-category.lifestyle` in Info.plist), secondary **Utilities**.
- Not Games or Entertainment: on the Korean storefront those categories also show a GRAC (게임물관리위원회) rating, which a watch does not need.
