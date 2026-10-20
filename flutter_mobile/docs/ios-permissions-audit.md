# iOS permission usage audit — 20 October 2026

## Scope and result

Prepared for Apple version `1.0.4 (37)`. The audit follows every app-declared
permission, HealthKit authorization type and native reader through its consumer.
It covers the installed `health` 13.3.2 and image-picker implementations as well
as Flutter, Swift, Info.plist, entitlements and the CocoaPods permission flags.
This is source review and automated verification; actual iPhone/Apple Watch
sample comparison and permission refusal/partial-grant checks remain pending.
No individual health records were read or exported during this audit.

Unused microphone access is removed from Info.plist and the permission-handler
build flags. Unused menstrual-flow authorization is removed from the iOS health
request. Height was already removed from both platform request lists; manual
height entry and existing charts remain available. The plugin-only `SPEED` enum
is removed from the iOS request list because it is Android-only; iOS running
speed has its own native HealthKit reader and authorization.

The legacy heartbeat-series permission and its RR reader/import job are also
removed. That path only calculated and persisted a separate RMSSD baseline;
no screen or wellness score consumed its output. The active Apple HRV feature
continues to read SDNN for its chart and personal recovery baseline. The
historical server table/data is not altered by this client release.

The native HealthKit channel was registered from the launch-time `window`, which
can be nil with the current UIScene lifecycle. It now registers through
`didInitializeImplicitFlutterEngine`, like the other existing native channels.
This makes the workout reader reachable in the current lifecycle.
Actual device behavior still requires verification.

## App permissions and capabilities

| Declaration / request | Implemented use |
| --- | --- |
| Camera: `NSCameraUsageDescription`, `PERMISSION_CAMERA` | Signup/profile photo capture and workout-sheet photo import, through `ImagePicker.pickImage`. Workout documents are recognized locally by `WorkoutDocumentReader`. No video or microphone capture feature exists. |
| Photos: `NSPhotoLibraryUsageDescription`, `PERMISSION_PHOTOS` | Signup/profile image selection (`Permission.photos` and `ImagePicker`); the picker also supports image workout-sheet import. Profile pickers use the plugin's default full-metadata path, which uses Photos authorization; workout documents explicitly disable full metadata. |
| HealthKit: entitlement and `NSHealthShareUsageDescription` | Read-only import of the categories listed below. The description now names the app's actual training, movement, sleep and recovery uses. |
| `NSHealthUpdateUsageDescription` | Compatibility description for HealthKit authorization, retained with explicit wording that the app does not write health data. This key is not a grant or request for write access. All Dart requests explicitly use `HealthDataAccess.READ`; the Swift request uses `toShare: nil`. The pinned plugin sends an empty write set for READ. |
| Local notifications: alerts, sounds and badges | `TrainingReminderNotificationService.requestPermission`, requested from onboarding/profile; training and measurement reminders and completed health-score notifications. Initialization does not prompt. No remote-push entitlement is declared. |
| Sign in with Apple entitlement | `AppState.signInWithApple` uses the identity token for login and the authorized email/name for first-time profile registration. These identity scopes are separate from HealthKit access. |
| Temporary execution after backgrounding | `beginBackgroundTask` lets an already-started score refresh finish within the time iOS allows. No persistent background mode or HealthKit background-delivery entitlement is declared. |

There are no app-declared microphone, location, motion/fitness, tracking,
contacts, calendar, Bluetooth or photo-library-write usage keys. Choosing
workout places on a map does not use device location; selecting a PDF uses the
system document picker. App calendar features do not access the iOS calendar.

## HealthKit read categories and consumers

The 16 remaining HealthKit categories below have product consumers. Six plugin
sleep enums map to the same HealthKit sleep-analysis category. The
remaining types below each have a query and a consumer; availability and a user's
granular permissions determine which data is returned.

| HealthKit category | Reader and consumer |
| --- | --- |
| Workouts | Native `fetchNormalizedWorkouts` and Dart `WORKOUT` fallback; training history/details, dates, activity type and training-strain inputs. |
| Heart rate | Native workout-window samples and Dart `HEART_RATE`; average/maximum HR, zone durations, activity charts and cardiovascular load. |
| Step count | `DailyStepsService` platform aggregates and native/Dart workout samples; daily/outside-workout steps, capped movement contribution to strain and running cadence. iOS empty/zero aggregates remain unavailable rather than evidence of zero activity. |
| Active energy burned | Native workout totals, native `activeEnergyBurned` fallback and Dart `ACTIVE_ENERGY_BURNED` fallback; session kcal in workout details. No daily energy dashboard is claimed. |
| Walking/running distance | Sport-specific native/Dart samples; running/hiking session distance, pace and speed. |
| Cycling distance | Sport-specific native/Dart samples; cycling session distance and derived speed. |
| Swimming distance | Sport-specific native/Dart samples; swimming session distance. |
| Running speed (iOS 16+) | Native `runningSpeed` query and authorization; workout average running speed, including missing-distance cases. |
| Flights climbed | Native and Dart workout-window reads; explicitly estimated session elevation shown in activity details, not a GPS route or measured altitude. |
| Sleep analysis | `HealthSyncService` queries in-bed/asleep/awake/core/deep/REM streams; sleep/stage history, naps, Sleep Score, sleep need/debt and recovery inputs. Missing stages are not invented. |
| Resting heart rate | `syncDailyHealthMetrics` / `RESTING_HEART_RATE`; `resting_hr` logs, charts and personal-baseline recovery input. |
| HRV SDNN | Daily `HEART_RATE_VARIABILITY_SDNN`; `hrv_sdnn` logs/charts and Apple-specific recovery baseline. It is kept distinct from RMSSD. |
| Body mass | Daily `WEIGHT`, normalized to kg; weight history/chart and latest profile weight. |
| Oxygen saturation | Daily `BLOOD_OXYGEN`, converted from the Apple fraction to percentage points; `spo2` history/chart and recovery input. |
| Respiratory rate | Daily `RESPIRATORY_RATE`; `resp` history/chart and recovery input in breaths/minute. |
| Sleeping wrist temperature (supported OS/device) | Daily `SLEEP_WRIST_TEMPERATURE`; absolute Celsius `wrist_temp_c`, assigned to wake date, shown in Health and used with the compatible personal baseline. Not Android's skin-temperature deviation. |

All reads retain the existing account/consent/revocation guards and late-result
discarding. HealthKit intentionally does not reveal whether a read permission
was refused: authorization completion and empty reads must not be described as
proof that every category was granted. Optional streams and personal history
remain necessary for the corresponding indicators.

## Release verification

`tool/verify_ios_permissions.py --source` checks source usage keys and
entitlements. The TestFlight lane runs the same verifier against the actual
signed IPA, checking its binary Info.plist, executable's signed HealthKit/Apple
sign-in entitlements and exact version/build before uploading to Apple. This
artifact check does not itself prove HealthKit runtime access.

Test results, immutable release commit/tag and GitHub Actions/Apple processing
status are recorded in `testflight-release-2026-10-20.md`.

## Primary references

- [Apple: HealthKit authorization and usage descriptions](https://developer.apple.com/documentation/healthkit/hkhealthstore/requestauthorization(toshare:read:)) — Apple warns that the usage keys must be set for authorization.
- [Apple: health update usage description](https://developer.apple.com/documentation/bundleresources/information-property-list/nshealthupdateusagedescription) — describes writing, not a permission granted merely by including the key.
- [Flutter: UIScene migration and channel registration](https://docs.flutter.dev/release/breaking-changes/uiscenedelegate) — application channels belong in implicit-engine initialization.
