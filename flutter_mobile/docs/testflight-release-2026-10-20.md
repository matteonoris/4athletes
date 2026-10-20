# TestFlight release — 20 October 2026

## Release scope

Apple version `1.0.4 (37)` publishes the current mobile updates after the
[iOS permission audit](ios-permissions-audit.md). It removes microphone,
menstrual-flow and unused heartbeat-series access, preserves the actively used
Apple SDNN recovery input, and registers the native workout channel through
the current UIScene/Flutter engine lifecycle.

The release also includes the existing email/password login, remote-response
guards after logout/deletion, daily/outside-workout steps and the agreed
movement contribution to strain, health-score notification navigation and
account-deletion wording updates. Source/release notes are bilingual. No
unrelated store screenshots, web prototype, Android native changes, credentials
or backend operations are included in this release action.

`NSHealthUpdateUsageDescription` is retained as authorization compatibility
metadata with explicit read-only wording; no HealthKit write type is requested.
The signed IPA is checked before upload for its usage keys, signed HealthKit
and Sign in with Apple entitlements, absence of persistent background modes and
exact release version/build.

## Local validation

- The complete Flutter suite passed: 522 tests, including light/dark UI,
  consent/revocation, login, deletion, daily steps, scoring and workout flows.
- After removing the final legacy RR path, 58 focused tests passed across the
  native read guards, AppState health jobs/loading, daily metric normalization,
  sleep synchronization, daily steps and recovery calculations.
- The complete suite was then repeated on the final tagged source: all 522
  tests passed again in 3 minutes 59 seconds.
- Static analysis of all 26 changed/new Dart source and test files reported
  no issues. The source permission/entitlement verifier and diff whitespace
  checks also passed. The remote build result is recorded below when complete.

No physical iPhone/Apple Watch validation is claimed. Remaining device checks
include partial/denied HealthKit access, real source-value comparisons and
optional device-specific records. This release does not modify App Store
privacy declarations or submit an App Store production review.

## Publication status

Published tag: `testflight-v1.0.4+37`, immutable release commit
`58fae10c9f988387281a91cc45843b7f23e9fec8`.
[GitHub Actions run 39466615149](https://github.com/matteonoris/4athletes/actions/runs/39466615149)
was still `in_progress` at 19:52 Europe/Rome on 20 October 2026, in the combined
build/upload step, with no failed step reported. The initial release app build
succeeded at 19:36:52; the latest available detailed log reaches archive Swift
compilation. The signed IPA verifier, Apple upload/processing and external
distribution have **not yet been confirmed**. GitHub publication is complete;
TestFlight availability must not be claimed until that run succeeds and its
processing/distribution output is checked. Do not reuse the published tag if a
retry is needed: fix the failure and use the next build number.

The current signed Android artifact remains `1.0.4+36` with its existing
documented hash; this iOS release does not rebuild or upload an Android bundle.
