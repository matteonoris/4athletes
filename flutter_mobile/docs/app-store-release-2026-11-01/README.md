# App Store release preparation — 1 November 2026

## Returning social login fix — 2 November 2026

Matteo's iPhone test exposed a release blocker in build 38: Google login after
logout incorrectly restarted signup for an existing account. A targeted,
read-only backend diagnostic confirmed an existing profile with eligible saved
age/role but no gender value. No account data was changed; identifying query
inputs and personal profile values are deliberately excluded from this report.

Both Google and Apple classified any profile without normalized gender as new.
Signup now applies to an absent profile or a trigger-created row with no saved
birth date. Existing profiles use the same strict owner/age/role checks as email
login, without requiring optional gender or overwriting saved information.
Logout clears social-signup flags; delayed profile/authentication responses
cannot restore login or retain a local session after logout. Health consent is
still handled by the existing consent gate; this fix does not grant consent.

Focused auth/signup suite: 57 passed, including 22 new real-state social-login
regressions with mocked provider channels and synthetic HTTP data. Coverage
includes logout/login without gender, genuine new/incomplete accounts, invalid
and under-14 profiles, account ownership, delayed responses and both themes.
Full Flutter suite: 550 passed. Dart analysis of the changed source/test found
no issues; iOS source permission verification and git diff --check passed.
Fastfile/workflow/signing are unchanged; CI validates Ruby/YAML as before.
App Store Connect's next-build-number check returned 39. The immutable tag is
`testflight-v1.0.4+39`, source commit `e4bbf17af22633aa561765ef2f9dd659f23aa860`.
[Workflow 41413050161](https://github.com/matteonoris/4athletes/actions/runs/41413050161)
completed successfully. CI logs confirm Ruby/YAML checks, signed-IPA permission
verification, upload and external distribution. Apple build
`5693d92b-4aeb-4c26-a9f2-332d4d27301f` is VALID, APP_STORE_ELIGIBLE,
usesNonExemptEncryption=false and IN_BETA_TESTING, explicitly assigned to
External Testers.

Downloaded IPA: 28,650,116 bytes; SHA-256
`3BC040E0D8B1ADE1C402DBE7B58BD01C72927C8943D0876B4C1206351C843C73`.
Local plist inspection confirms the correct bundle, 1.0.4 (39) and device family
[1,2]. All 19 bundled privacy manifests match build 38 byte-for-byte; none
declares tracking. No new privacy category or permission was introduced.

Stage dry-run matched the plan; confirmed stage attached build 39 with zero
metadata changes. The private reviewer-note header now says 39; every other
note and contact/demo credential field was preserved, verified in memory without
printing sensitive values. Validation with the actual IPA and bounded public
URL checks has zero errors, one existing first-version What's New warning and
two informational findings (manual release and API-unverifiable privacy state).
App Privacy publication remains supported by the earlier authenticated proof;
the API cannot independently attest it. No production review submission was made.

Device feedback during the build: Matteo confirmed manual location entry works.
He initially reported missing Health/activity fields under iOS Settings >
4athletes; after checking Health > profile > Privacy > Apps, he confirmed
4athletes is present with read switches enabled. HealthKit permissions live in
Health; this source does not request the separate Core Motion permission.
This verified the reported OS-switch state, not an actual data import. After
updating to build 39 without uninstalling, Matteo explicitly confirmed both
checks work: logout followed by Google login opens the existing account without
signup, and a recent known Apple Health workout is imported into the app.
No personal health values were requested or recorded. Physical Apple/email
login, granular permission denial and iPad/Watch comparisons are not newly
verified by this report.

## Earlier administrative check — 2 November 2026

Matteo supplied Alberto's messages dated 1 November 18:34/18:38: Free Apps and
Paid Apps agreements active (updated 30 October), DSA trader active with verified
contacts and applied to 4Athletes, Italy-only availability without automatic
territories, medical status No, and Matteo's access restricted to 4Athletes with
App Manager/customer-support capabilities and individual API keys. These
administrative statements are Alberto's confirmation, not an independent
account-wide audit by this agent. No other apps were enumerated to test scope.

Read-only API checks on 2 November confirm build **38** is already attached to
version 1.0.4 and the private reviewer notes already reference build 38 and
manual locations. Athlete credentials and private coach instructions are still
present. Validation: zero blocking errors, one first-version What's New warning.
Production state remains PREPARE_FOR_SUBMISSION / NOT_SUBMITTED, manual release.

Alberto's remarks about a build-37 attachment/notes and unpublished privacy do
not describe the current verified preparation. App Privacy was published on
1 November after Matteo's explicit attestation; saved authenticated UI proof
exists in the original checkout. The Apple browser session expired by the
2 November follow-up, so publication was not newly reverified in that session.

The 17 privacy categories were checked against the release source/IPA. Contacts
describes the stored athlete/coach/team social graph, not device address-book
access. Precise Location remains relevant to historical saved coordinate-bearing
locations retained and re-saved in workout/session payloads and map previews;
manual entry does not read device GPS. Photon search collection is removed from
build 38. Removing these two categories would require a separate functional/data
review, not merely hiding optional OS permissions.

Remaining: Matteo's physical iPhone test result. Physical iPad/Apple Watch checks
remain unverified. No new release, build, workflow, privacy publication or
production submission was performed during this follow-up.

Target: 4Athletes, app 6771865051, com.thestolenspot.4athletes, iOS 1.0.4 (38).
Owner authorized continuing toward App Store publication today, subject to actual
readiness and Apple review. No approval time is promised.

## Isolated source

Based on dc325ae, including only the already reviewed signup-only birth-date
change and removal of Photon/manual workout locations. Unrelated local monthly
report and Android background work are excluded. Historical locations/maps remain
supported. Minimum signup age remains 14 on client/server. No backend migration.

## Validation before tag

- Full Flutter suite: 528 passed on this isolated source.
- Analysis of the five affected Dart source/test files: no issues.
- iOS source permission verification and whitespace checks passed.
- Fastfile/workflow are unchanged from build 37; Ruby/YAML syntax is also checked
  by the existing GitHub Actions before signing/build. No local Ruby available.
- No physical-device validation is claimed; owner testing remains required.

## App Store preparation

- Apple calculated 13+ (12+ on older OS); no override to 16+, per owner request.
  Standard Apple EULA is selected. Signup eligibility remains 14+ and age URL
  points to privacy/#minori. Questionnaire declares age assurance, wellness,
  communication via team calendar/invitations and frequent sports competitions;
  no public UGC distribution/social feed, ads, gambling, medical diagnosis,
  violence or sexual content.
- Owner confirmed rights/licenses; saved USES_THIRD_PARTY_CONTENT.
- Support published at https://matteonoris.github.io/4athletes/support/ and saved
  in Italian version localization. Public privacy updated on gh-pages 0707852.
- Price free, Italy only and manual release remain the intended settings.
- Privacy draft has 17 configured data types. Do not publish based on build 37;
  verify build 38 and provider disclosures before publishing labels/submission.
- Alberto must finish/confirm DSA, agreements and regulated-medical-device status.

Secrets and private App Review notes are deliberately excluded from this report.
CI status, signed artifact verification and any final submission must be recorded
only after observed success. No production submission has occurred at this point.

## Verified build and staging — 1 November 2026

- Workflow 41323538015 completed successfully for commit
  8c1768112fc844a648c45fa8a04b0b1d9bbc8b35, tag testflight-v1.0.4+38.
- CI signed-IPA permission/entitlement/version verifier passed. Apple processing
  finished and external TestFlight distribution succeeded at 16:10 UTC (17:10
  Europe/Rome). Build ID: 290adfca-b78f-4ab9-8c4a-f07f3aeee51f.
- Apple state VALID, APP_STORE_ELIGIBLE, not expired, non-exempt encryption false
  flag (usesNonExemptEncryption=false); External Testers membership explicit,
  external state IN_BETA_TESTING.
- Downloaded IPA: 28,648,337 bytes; SHA-256
  E4D4FB552907CF7E686F3BC6EC00FFFB6673F424811144BA74A31773D47827CD.
  Local plist inspection confirms bundle, 1.0.4 (38), iPhone/iPad family [1,2].
- Only GoogleSignIn's manifest in the IPA declares collected data. Its eight
  declared types/purposes match the prepared labels, linked=true/tracking=false.
  This manifest check is not a full runtime traffic audit of every provider.
- Stage dry-run matched the plan; confirmed stage attached build 38 with zero
  metadata changes. Validate with the actual IPA and URL checks has zero errors,
  one first-version What's New warning and two information-only findings.
- Private App Review notes now reference build 38 and manual locations. Contact,
  demo username/password/required flag and private coach instructions preserved;
  no credentials were printed or saved to these reports.
- Matteo expressly confirmed Apple's accuracy/compliance attestation. App Privacy
  was published through the authenticated UI and the publication confirmation
  was visibly verified. Search History is excluded for the new manual-only flow;
  historical location/map data remain declared as appropriate.
- Standard metadata dry-run is empty. App Store version remains
  PREPARE_FOR_SUBMISSION / NOT_SUBMITTED; release remains MANUAL.
- The tested release commit is now also on remote main. The original local dirty
  checkout was not reset or pulled; unrelated local changes remain untouched.

## Remaining human gates

Matteo has agreed to test on iPhone, but has not yet reported the result.
Physical iPad/Apple Watch testing is not verified. Alberto has not yet confirmed
agreements/DSA or the regulated-medical-device status declaration. The owner was
provided a ready-to-forward message with the exact App Store Connect sections.
Do not claim a production submission or publication before it actually happens.

Additional auth/signup and manual-location widget checks at 1024x1366 in both themes passed in a 19-test batch including existing map regressions. These are Flutter layout tests, not physical iPad verification.

## Medical status resolved

Authenticated App Information UI now explicitly states the app is not considered
a regulated medical device in any country or region. The earlier warning is
absent. This status was observed after the owner's administrator-side actions;
the agent did not change regulatory status or accept agreements. DSA/agreements
remain unverified and the iPhone test result is still pending.
