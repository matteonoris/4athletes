# App Review design correction — 8 November 2026

App: 4Athletes (`6771865051`, `com.thestolenspot.4athletes`), iOS 1.0.4.
Existing submission: `4cf63f5a-744b-4963-97d4-fb7ec2e10ea9`.

**Latest state — 11 November:** review approved and manual release completed at
Matteo's explicit request. Build 40 is READY_FOR_DISTRIBUTION; Italy is AVAILABLE,
free, and the public Italian App Store page is verified. See the
[publication record](../app-store-release-2026-11-11/README.md). The sections below
retain the earlier preparation and review history.

## Resubmitted — 8 November 2026

Matteo explicitly authorized resubmitting 1.0.4 (40) using the existing review
submission and retaining manual release. Fresh read-only checks confirmed build
40 attached to version `98ea4b7a-4640-4378-86cf-f27dacab9be7`, MANUAL release
and zero blocking validation errors with the actual IPA/URL checks.

The existing rejected version item
`NGNmNjNmNWEtNzQ0Yi00OTYzLTk3ZDQtZmI3ZWMyZTEwZWE5fDZ8ODg1OTc4Njk1`
was marked resolved, returning it to READY_FOR_REVIEW. The existing submission
`4cf63f5a-744b-4963-97d4-fb7ec2e10ea9` was then submitted again with
`asc review submissions-submit --confirm`; no new submission was created.

Apple accepted the resubmission at **11:01 Europe/Rome, 8 November 2026**
(`2026-11-08T10:01:29.647Z`). Subsequent API reads confirm submission and
version WAITING_FOR_REVIEW, build `238ec3f4-e875-44b2-8195-6b7fd71a6d3f`
(40) attached, releaseType MANUAL and the same sole version item. The earlier
build-39 rejection remains part of this submission's history. No production
release or separate reviewer reply was sent.

Read-only monitoring:

```powershell
asc --profile 4athletes-matteo --strict-auth --read-only review submissions-get --id 4cf63f5a-744b-4963-97d4-fb7ec2e10ea9 --output table
asc --profile 4athletes-matteo --strict-auth --read-only versions view --version-id 98ea4b7a-4640-4378-86cf-f27dacab9be7 --include-build --output table
```

Approval will still require a separate manual release action. Do not create
a duplicate submission or resubmit again while this review is pending.

## Observed rejection

Apple's message dated 5 November, 16:25, reports Guideline 4 — Design: the
Sign in with Apple button uses logo artwork that did not come from Apple's
design resources. The review device was iPad Air 11-inch (M3), build 39.
Read-only checks on 8 November confirmed REJECTED / UNRESOLVED_ISSUES and
MANUAL release. There is one observed review message; this does not guarantee
that a subsequent review will find no other issues.

## Correction

The former Flutter ElevatedButton with `PhosphorIcons.appleLogo` is replaced by
Apple's native `ASAuthorizationAppleIDButton(type: .continue, style: ...)`.
Apple supplies its artwork, text proportions, localization and VoiceOver label.
The button is 56 points high, fills the login column like the Google button,
and uses Apple's white style on dark backgrounds and black style on light
backgrounds. The native corner-radius property is 16; no custom logo is drawn.
Theme changes recreate the native control with the appropriate Apple style.

Flutter embeds the control through UiKitView. The factory is registered during
`didInitializeImplicitFlutterEngine` for the app's UIScene lifecycle. A per-view
method channel forwards the native press to the existing Apple auth handler;
disposal removes that handler. The provider/session, signup-age and health-consent
logic are unchanged. No new package, data collection or permission is introduced.

References: [Apple's Sign in with Apple guidelines](https://developer.apple.com/design/human-interface-guidelines/sign-in-with-apple),
[ASAuthorizationAppleIDButton](https://developer.apple.com/documentation/authenticationservices/asauthorizationappleidbutton),
[Flutter iOS platform-view registration](https://docs.flutter.dev/platform-integration/ios/platform-views).

## Build preparation

App Store Connect returned next build number 40. Immutable tag
`testflight-v1.0.4+40` points to source `437f5339924f242a7325b65fcee1aed165d26c0f`.
[Workflow 42466961670](https://github.com/matteonoris/4athletes/actions/runs/42466961670)
succeeded, including Swift compilation, Ruby/YAML syntax checks, signed-IPA
permission/entitlement verification, upload, Apple processing and external
TestFlight distribution. Never reuse this release tag.

Local verification: 41 focused button/auth tests passed, followed by all 555
tests in the full Flutter suite. Two additional actual AuthScreen iPad-layout
checks (both themes) passed: the native button is as wide and at least as tall
as Google, and its press enters the existing Apple signup handler. iOS source
permission verification and whitespace checks passed. Dart analysis of all six
changed/new Dart files is clean. Native Swift compilation
and signed-IPA verification run in the existing macOS GitHub Actions lane.

- Apple build: `238ec3f4-e875-44b2-8195-6b7fd71a6d3f`, 1.0.4 (40), VALID,
  APP_STORE_ELIGIBLE, usesNonExemptEncryption=false, not expired.
- TestFlight: IN_BETA_TESTING, explicitly assigned to External Testers.
- Downloaded IPA: 28,665,499 bytes; SHA-256
  `FF97F0772AF63CB6076AB6C3C95A3D08A056800C7635254E9C54E1B933D3D63F`.
- Actual IPA inspection confirms the correct bundle/version, iPhone/iPad family
  [1,2], and executable references to ASAuthorizationAppleIDButton and the new
  native bridge. All 19 privacy manifests are byte-identical to build 39;
  none declares tracking. This is not a full runtime traffic audit.
- Stage dry-run matched the plan. Confirmed staging attached build 40 to the
  existing App Store version `98ea4b7a-4640-4378-86cf-f27dacab9be7` with no
  localization changes. Final API checks show PREPARE_FOR_SUBMISSION and MANUAL.
- Private reviewer notes now reference build 40 and explain the native Apple
  button fix. Every other existing note and contact/demo credential field was
  preserved; sensitive values were compared in memory and not printed.
- Validation with the actual IPA and public URL checks: zero errors, the known
  first-version What's New warning and two informational findings (manual
  release and App Privacy state not verifiable through the public API).

The original submission `4cf63f5a-744b-4963-97d4-fb7ec2e10ea9` remains
UNRESOLVED_ISSUES, preserving the build-39 rejection history. No reviewer reply,
resubmission or production release was sent during this preparation. Do not
create a duplicate submission for retry. Private review contacts/demo
credentials remain outside this report.

Flutter widget tests can verify bridge callbacks, layout sizes and theme
selection, but do not render UIKit artwork. Physical iPhone/iPad verification
was requested on build 40; Matteo replied positively to the requested native
appearance/tap checks. He did not separately identify an iPad test, so no
physical iPad verification is claimed. Earlier full health/Watch/partial-denial
limitations remain outside this focused button fix.
