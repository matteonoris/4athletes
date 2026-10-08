# Android release checklist

## Health Connect privacy entry point — 5 October 2026

Both Health Connect privacy entry points now target the dedicated native
`HealthPermissionsRationaleActivity`, rather than `MainActivity`:

- Android 13 and lower: `androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE`.
- Android 14+: the existing `ViewPermissionUsageActivity` alias handles
  `android.intent.action.VIEW_PERMISSION_USAGE` with category
  `android.intent.category.HEALTH_PERMISSIONS`, retaining the required
  `android.permission.START_VIEW_PERMISSION_USAGE` protection.

The activity displays exactly `https://matteonoris.github.io/4athletes/privacy/`,
matching Flutter's legal link and the URL to enter in Play Console. It does not
start Flutter, require login, or request/import health data. Incoming intent data
cannot substitute another page. JavaScript, file access, content access and
mixed HTTP content are disabled. Other HTTPS/mail links open externally.
Load failures offer retry and opening the canonical notice in the browser;
closing the activity returns to its caller. Native controls and the existing
public page support light/dark mode. Internet access is explicitly declared.

Source version for this correction is `1.0.3+31`; the signed `+30` artifact below
predates the privacy correction. All other release gates still apply.

### Latest signed artifact and verification — 6 October 2026

- Release APK and AAB builds succeeded. The current AAB was built on
  5 October 2026 at 21:19 Europe/Rome: `1.0.3+31`, 70,187,608 bytes,
  at `build/app/outputs/bundle/release/app-release.aab`.
- Merged release manifest confirms version code 31, target API 36 and the
  dedicated activity/alias. The bundle contains the native privacy layout.
- APK/AAB upload certificates match the existing private upload key:
  `D6:07:52:38:86:6C:88:0E:33:EE:71:F9:DC:76:1A:54:69:33:35:3D:8D:2B:4E:CF:EB:FA:05:B3:14:79:12:0B`.
- AAB SHA-256:
  `0B06E9221D8831371F346E369404656EA088127B2442DA416ADD3D6BC3D7D00C`.
  `jarsigner -verify` returned `jar verified`, exit 0, with the same
  self-signed/chain/timestamp/POSIX/JarInputStream warnings documented below.
  This does not establish successful Play validation.
- On the Pixel_8 Android 14/API 34 emulator, the legacy rationale action
  resolved to the dedicated activity and displayed the public notice without
  login. This tests the legacy route on API 34, not an Android 13 device.
- The actual Health Connect app's **Read privacy policy** link launched
  `ViewPermissionUsageActivity` and displayed the same notice. **Chiudi**
  returned to Health Connect. A direct shell launch of the protected alias
  was denied, as expected; its system-only permission was retained.
- With Wi-Fi/mobile data disabled before the first load, the error/retry/browser
  controls appeared. After reconnecting, **Riprova** loaded the real notice.
  Light/dark native controls and the public page were visually verified:
  [light](images/health-connect-privacy-light.png),
  [dark](images/health-connect-privacy-dark.png).
- The emulator's existing debug-signed app was retained. A temporary copy of
  the compiled release APK was signed with the standard local debug key and
  installed with `-r`, preserving app data. This test copy is outside the repo;
  the APK/AAB under `build/app/outputs` remain release-signed.
- A heart-rate OS permission inadvertently toggled during emulator navigation
  was revoked and verified `granted=false`; the privacy activity never calls
  a health reader. Original light mode and enabled Wi-Fi/mobile data were restored.
  Initial cold-boot Settings/System UI ANR dialogs were dismissed before the
  successful checks; physical-device performance remains unverified.

No Play upload was performed. Final signed Play-installed/physical-device
testing, including Android 13, remains part of the release checklist.

Reference: [Health Connect privacy activity](https://developer.android.com/health-and-fitness/health-connect/get-started#show-your-apps-privacy-policy-dialog).

## Current security status — 5 October 2026

The previous anonymous-access/RLS blocker was repaired through Supabase MCP.
All public tables now have RLS and anonymous personal-table grants are zero.
Protected memberships, manager approval, last-manager safeguards, athlete-only
calendar patches, numeric leaderboard totals, recipient-only notifications and
private avatar storage are applied. See `backend-security-plan.md` and the
rolled-back synthetic verification in `supabase/tests/security_authorization.sql`.
The declaration of minimum age 14 is also enforced on profile writes by the server.

The three approved empty test teams were deleted; all 29 profiles were retained.
All five Zanetti Goggi Giovani Senior coaches and Battista Tomasoni in Team Batti
are managers. Current invitation codes were rotated; retrieve and share the new
codes from the manager's app. Existing users need the updated client for team
management and athlete calendar access; no iOS release was triggered.

58 distinct focused Flutter tests passed across the manager/pending/read-only
flows, existing ski/report calculations and health consent behavior. Targeted
static analysis had no errors or warnings; style INFO diagnostics remain.
Database tests additionally passed authorization, private Storage, old-token
revocation, minimum age, sports summaries and historical own-session checks,
with no test accounts/records left behind.

The security rollout used `1.0.3+30`; its artifact/signature snapshot is retained
below. Use the newer `+31` artifact in the privacy update above for the current
test rollout. The October 4 `+29` artifact predates the security upgrade.

### Verified artifact — 5 October 2026, 19:56 Europe/Rome

- `build/app/outputs/bundle/release/app-release.aab`: `1.0.3+30`, 70,184,604 bytes.
- Release build succeeded; merged manifest confirms package
  `com.matteonoris.app4athletes`, version code 30 and target API 36.
- Upload certificate SHA-256 matches the configured private upload key:
  `D6:07:52:38:86:6C:88:0E:33:EE:71:F9:DC:76:1A:54:69:33:35:3D:8D:2B:4E:CF:EB:FA:05:B3:14:79:12:0B`.
- Bundle file SHA-256:
  `484BF6FA59691A64608F0BB0D42E9CE0121D5E94BA6489C97FC7FB5603B29EC7`.
- `jarsigner -verify` returned `jar verified` and exit 0. It also reports the
  existing self-signed/untrusted-chain, no-timestamp and manifest-ordering
  JarInputStream warnings, plus unprotected POSIX/symlink attributes. This is
  certificate/signature verification, not successful Play bundle validation.
- No Play upload or iOS tag was performed. Physical-device tests and the
  remaining checklist gates below still apply.

Still pending: administrator MFA verification, leaked-password protection
availability/activation, audited account/health-data deletion, remaining lawful
health-processing requirements, real-device validation (including Health Connect
privacy), Play declarations/assets, closed testing and production-access approval.
Zero advisor ERROR findings do not establish Play approval or full legal compliance.

The remaining Supabase WARN concerns
[leaked-password protection](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection).
The membership/audit/attempt tables intentionally deny direct client access;
their three no-policy INFO findings are explained in `backend-security-plan.md`.

The Android app ID is `com.matteonoris.app4athletes`. Build from
`flutter_mobile` with `flutter build appbundle --release`. Upload the resulting
`build/app/outputs/bundle/release/app-release.aab` to Google Play Console only
after checking its signing certificate.

## Release signing

The release build requires `flutter_mobile/android/key.properties` and a
separate upload keystore. Both are ignored by Git. Use the upload key already
registered in Play Console for an existing app; a new upload key can be chosen
when enrolling a new app in Play App Signing. Back up the key and passwords.

```properties
storeFile=C:/path/to/upload-keystore.jks
storePassword=...
keyAlias=upload
keyPassword=...
```

`storeFile` can be an absolute path or a path relative to `flutter_mobile/android`.
The build fails if these settings or the keystore are missing. Never upload an
AAB signed with the Android debug certificate. Confirm the AAB's certificate
with `keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab`
and compare it with the upload certificate shown in Play Console.

Before building, ensure the ignored `.env` in `flutter_mobile` has working
`SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `GOOGLE_WEB_CLIENT_ID`. Register the
Google Play app-signing certificate's SHA fingerprints for Android Google
Sign-In; register the upload certificate too if testing a locally installed
release build.
Increase `versionCode` in `pubspec.yaml` for each Play update.

Run Flutter tests and the release build sequentially. Both regenerate Android
plugin-registration files; running tests during a build can insert the
development-only integration-test plugin into the release registrant and fail
Java compilation. After the tests, use the regular release build command above
to regenerate the production registrant before compiling.

## Play Console and public content

- Complete developer identity and package registration in Play Console.
- Publish and verify `https://matteonoris.github.io/4athletes/privacy/`, linked
  from the app and entered in Play Console.
- Enter `https://matteonoris.github.io/4athletes/delete-account/` in Play
  Console. The app links to this email-based request path. Establish an audited
  process to verify requests and remove the auth user, associated app rows and
  avatar, subject to any legitimate retention requirement.
- Before allowing under-14 athletes, add and verify a parental authorization
  flow. Document explicit consent for health-data processing separately from
  operating-system permissions. Do not analyze or export individual health
  records for the thesis without the separate notice, lawful basis, and any
  required ethics or platform approvals.
- Complete Data safety, Health apps and individual Health Connect permission
  declarations. The Android app requests exercise, sleep and vital-sign data.
  Complete the foreground-service declaration for `dataSync`.
- Complete app access with working reviewer credentials, content rating,
  target audience, store description, screenshots, icon, feature graphic,
  support contact and privacy URL. Verify descriptions against Android features.
- If the Play developer account is a personal account created after
  13 November 2023, complete the required closed test before applying for
  production access: at least 12 testers opted in continuously for 14 days.
- Test sign-up, Google sign-in, account deletion, Health Connect consent,
  notifications, camera/gallery import and core athlete/coach flows on real
  Android devices before production. Check the release in Play Console's
  pre-launch report and app bundle explorer.

Official references: [target API level](https://support.google.com/googleplay/android-developer/answer/11926878),
[app account deletion](https://support.google.com/googleplay/android-developer/answer/13327111),
[Health apps declaration](https://support.google.com/googleplay/android-developer/answer/14738291),
[foreground services](https://support.google.com/googleplay/android-developer/answer/13392821),
[new personal account testing](https://support.google.com/googleplay/android-developer/answer/14151465).

## Release readiness review — 30 September 2026

This is the original review snapshot. The 4 October implementation update
below supersedes its missing upload-key and missing client age-check findings.

The owner confirmed a verified personal Play Console account created the
previous week. 4athletes has not yet been created in Play Console and no Android
package has been uploaded. A closed test with at least 12 testers opted in for
14 consecutive days is required before applying for production access. The
minimum test duration does not include Google's production-access or app review.

### Confirmed locally

- App ID: `com.matteonoris.app4athletes`; current version: `1.0.3+29`.
- Flutter 3.41.8 supplies compile and target API 36; the installed Android
  toolchain and licences are available. This matches the current new-app
  submission requirement. Minimum supported Android API is 26; Health Connect
  availability must still be checked separately on each device.
- Both public privacy/deletion URLs returned HTTP 200. Links exist before
  sign-in and in the profile. The deletion link initiates an email request.
- Required local backend/auth configuration values are present and not obvious
  placeholders; this does not verify backend authorization or release sign-in.
- All 406 automated Flutter tests passed. Full static analysis reported no
  errors, 53 informational findings and one unused-import warning in the
  standalone `scratch.dart` file; its warning caused a nonzero analysis exit.
  These checks do not replace validation of a signed Play-installed app.
- The source manifest no longer requests broad image/storage access or the
  unused menstruation/cadence/elevation health permissions. Verify the final
  merged release manifest after rebuilding.
- The existing AAB dated 24 September is signed by `CN=Android Debug` and predates
  the privacy links and permission changes. Do not upload it. Its ten arm64/x86_64
  libraries have ELF LOAD alignment of at least 16 KB; final-package alignment,
  RELRO, and runtime compatibility still require verification on the new build.

### Work still required

| Requirement | Current finding | Completion condition |
| --- | --- | --- |
| Upload signing | `android/key.properties` is absent; a fresh release build fails with the expected signing-configuration error. | Configure a private upload keystore, back it up, build a new AAB, and verify its certificate. |
| Google sign-in in a Play build | Not verified with the Play app-signing certificate. | Register the Android package and Play certificate SHA fingerprints in the Google authentication configuration, then test a Play-installed build. |
| Health data disclosure and consent | The onboarding lists some data types but omits sleep from the item list and does not fully describe cloud storage/coach access. `markHealthAccessEnabled` stores a local access preference rather than a documented explicit-consent record. Other health-permission entry points also exist. | Provide a complete disclosure before collection, record applicable explicit consent, support withdrawal, and cover every permission/sync entry point. |
| Health Connect privacy entry point | Both privacy actions target `MainActivity`, which does not handle those actions by displaying the privacy notice. | Make the Health Connect privacy link display the same notice used in Play Console, on Android 13 and Android 14+. |
| Athletes under 14 | No verifiable guardian authorization flow or age restriction exists in signup. | Prepare guardian authorization and the applicable Families/SDK safeguards, or enforce a truthful minimum-age restriction for the initial release. |
| Account/data deletion | Web/email request path exists; backend deletion and retention have not been audited. | Verify identity, delete associated auth/database/storage data, define retained-data and backup handling, confirm completion, and test the process. |
| Backend data isolation | Athlete/coach access is described by the owner but live authorization rules have not been checked in this review. No project Supabase MCP tools were available. | Use the project Supabase MCP to check policies and storage permissions and verify athletes/coaches cannot access unrelated records. |
| Play Console content | App is not created. | Complete Data safety, Health apps, requested Health Connect permissions, foreground-service declaration, target audience, IARC rating, ads declaration and reviewer access. Provide a demonstration video for the foreground service and verify its declared type/use case matches the implementation. |
| Store listing | No Android listing has been prepared/verified. Existing iOS copy mentions Apple Health. | Supply Android-specific text, support contact, 512×512 store icon, 1024×500 feature graphic and at least two phone screenshots. Add the required non-medical-device disclaimer and healthcare-professional guidance for the health features. |
| Final device validation | No device is currently connected; no final signed Play-installed build exists. | Test registration, both roles, Health Connect grant/denial/revocation, foreground sync, notifications, imports, privacy/deletion links and account deletion on a real Android device; inspect Play pre-launch results and 16 KB compatibility. |

The thesis is a separate intended use. It is not authorized by publishing the
service privacy notice or granting operating-system permissions. Keep research
analysis/exports out of this release until the required notice, lawful basis,
participant/guardian consent, safeguards and applicable independent approval
are established.

Pending owner information: the final tester count/enrollment; and access to Play Console/project Supabase
MCP for the remaining external checks. Do not ask the owner to send passwords
in chat.

### Owner decisions — 4 October 2026

- The first Android release will be for users aged 14 and older. Under-14
  support and its parental authorization flow are deferred. The client signup
  restriction and public privacy update are now implemented; keep Play Console
  audience declarations consistent before release. See the implementation
  status below for the scope of this check.
- The owner expects to have the required testers available. Confirm at least
  12 actual participants and their continuous 14-day closed-test enrollment.
- An upload keystore is a file created locally, usually with a `.jks` or
  `.keystore` extension. `android/key.properties` references its chosen location;
  there is no universal release-key location. Android's automatically created
  `.android/debug.keystore` is for development only. Since no 4athletes Android
  package has yet been uploaded, a new private upload key can be created if none
  exists. Follow the [Flutter signing guide](https://docs.flutter.dev/deployment/android#sign-the-app)
  and keep the key and passwords backed up privately.

### Implementation update — 4 October 2026

- Signup requires a valid declared date of birth and at least 14 completed
  years before Google or Apple sign-in. It rechecks the date at the personal
  details step and before saving the profile, including the skip-photo path.
  There is no fallback birth date. Ten focused tests passed for invalid dates,
  the birthday boundary, leap years, both providers, and both light/dark themes.
  Static analysis of the changed signup source and tests found no issues.
- This is a client signup restriction. Server-side enforcement, existing
  accounts, restored sessions, and verification of declared ages have not been
  audited. It does not establish parental authorization or health-data consent.
- The public privacy notice was updated on `gh-pages` in commit `90bfcd1` and
  verified online with HTTP 200. It excludes under-14 users from the first
  Android release, including those with parental permission, and describes the
  declared birth-date check. Its update date is 4 October 2026.
- A new RSA 3072 upload key was generated with alias `upload` and 10,000-day
  validity. Keystore: `C:\Users\matte\AndroidKeys\4athletes\4athletes-upload.jks`.
  Its random password and recovery configuration are in `signing-private.json`
  in the same private directory. The directory and ignored Android
  `key.properties` restrict access to the current Windows user and SYSTEM.
  Never print, commit or publish the private credentials. A secure off-device
  backup of this directory still needs to be made by the owner.
- The public upload certificate is `upload-certificate.pem` in that directory.
  SHA-256: `D6:07:52:38:86:6C:88:0E:33:EE:71:F9:DC:76:1A:54:69:33:35:3D:8D:2B:4E:CF:EB:FA:05:B3:14:79:12:0B`.
  The ignored `flutter_mobile/android/key.properties` is configured for this
  key. This supersedes the missing-key finding in the September review.
- A fresh `flutter build appbundle --release` succeeded. The new
  `build/app/outputs/bundle/release/app-release.aab` is version `1.0.3+29`,
  70,106,710 bytes (about 66.9 MB), built on 4 October 2026. Its certificate
  SHA-256 matches the upload certificate above; it is not debug-signed.
  The refreshed merged release manifest targets API 36, labels the app
  `4athletes`, and contains none of the removed broad photo/storage or unused
  menstruation/cadence/elevation health permissions. This supersedes the old
  September AAB finding. It has not been uploaded to Play or validated on a
  real device; the remaining September checklist items still apply.
  `jarsigner -verify` returned exit 0 and `jar verified`. It also reported
  self-signed/no-timestamp certificate warnings and a JarInputStream warning
  about manifest ordering; Play's bundle validation is still pending.

Additional official references checked for this review:
[16 KB support](https://developer.android.com/guide/practices/page-sizes),
[Health Connect privacy activity](https://developer.android.com/health-and-fitness/health-connect/get-started),
[Health Content and Services](https://support.google.com/googleplay/android-developer/answer/16679511),
[Families policy](https://support.google.com/googleplay/android-developer/answer/9893335),
[store assets](https://support.google.com/googleplay/android-developer/answer/9866151).

### Health consent and verified backend audit — 4 October 2026

- Supabase MCP is connected to the app's actual project
  `hqzushizdfxrnktoqbtr` (4Athletes), in `eu-north-1`.
- The service health-import consent flow is implemented on signup, restored
  login and OAuth replacement routes. Acceptance/refusal/revocation are stored
  in an append-only per-account protected table, with server time and notice
  version. Profile controls include revocation/reactivation and a separate
  health-data deletion email request. The latter still requires an audited
  backend deletion procedure. See `health-data-consent.md`.
- 52 focused Flutter tests passed, including the consent gate in both themes,
  failed saves, account changes, offline revocation, pending-read cancellation,
  signed-out/declined import prevention and the existing minimum-age checks.
  Static analysis of 16 changed source/test files found no issues.
- The public privacy notice is updated in `gh-pages` commit `66db671`.
- **Critical release blocker confirmed:** eight public tables have disabled RLS
  and allow anonymous SELECT/INSERT: profiles, teams, training sessions, body
  metrics, PRs, jumps, calendar events and notifications. UI filtering does not
  provide server authorization. The protected consent register does not repair
  this. Design and verify athlete/coach/team policies and protected membership
  changes before release. Storage authorization is still unaudited.
  [Supabase finding and remediation](https://supabase.com/docs/guides/database/database-linter?lint=0013_rls_disabled_in_public).
- This supersedes the earlier statements that MCP was unavailable and service
  health consent was unimplemented. It does not close the remaining Health
  Connect privacy-action, deletion, historical/manual health-data basis,
  existing-account age, real-device, Play Console and closed-test gates.
- A fresh release build completed after the consent integration and tests:
  `build/app/outputs/bundle/release/app-release.aab`, `1.0.3+29`, 70,173,282 bytes,
  4 October 2026 at 20:47 local time. Its SHA-256 signing certificate matches
  the private upload key documented above. Signature verification returned
  `jar verified` and exit 0, with the previously documented self-signed,
  no-timestamp and JarInputStream manifest-order warnings. Play bundle
  validation and real-device testing remain pending; do not upload as a
  releasable build until the critical backend access issue is corrected.
