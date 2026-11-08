# App Review design correction — 8 November 2026

App: 4Athletes (`6771865051`, `com.thestolenspot.4athletes`), iOS 1.0.4.
Existing submission: `4cf63f5a-744b-4963-97d4-fb7ec2e10ea9`.

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

App Store Connect returned next build number 40. Validation results, source tag,
CI run, signed artifact and TestFlight availability will be recorded after
observed completion. Never reuse an uploaded release tag.

Local verification: 41 focused button/auth tests passed, followed by all 555
tests in the full Flutter suite. Two additional actual AuthScreen iPad-layout
checks (both themes) passed: the native button is as wide and at least as tall
as Google, and its press enters the existing Apple signup handler. iOS source
permission verification and whitespace checks passed. Dart analysis of all six
changed/new Dart files is clean. Native Swift compilation
and signed-IPA verification run in the existing macOS GitHub Actions lane.

The existing rejected submission is preserved. No reviewer reply, resubmission
or production release has been sent during preparation. Keep release MANUAL.
Private review contacts/demo credentials remain outside this report.

Flutter widget tests can verify bridge callbacks, layout sizes and theme
selection, but do not render UIKit artwork. Physical iPhone/iPad verification
of the native appearance and press still needs the new TestFlight build.
