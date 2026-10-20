# Daily steps and daily strain — 19 October 2026

## Agreed behavior

`wellness-scoring-v2.3.0` adds a separate movement component of one point per
1,000 steps outside workouts, capped at 20. The final score is
`training + (100 - training) * movement / 100`. This preserves the training
score, is monotonic and stays within 0–100. These weights are owner-approved
product calibration, not a clinically validated conversion of steps to strain.

The Health screen displays today's total and non-workout steps, observation
time, and missing/exclusion-unavailable states in both light and dark mode.
An observed Android zero is distinct from missing data. Apple Health does not
reveal read denial, so an empty/zero aggregate is conservatively unavailable.

## Collection and exclusion

- `DailyStepsService` uses the health package's aggregate step-count API. On
  Android this uses Health Connect `StepsRecord.COUNT_TOTAL`; on iOS it uses
  HealthKit cumulative statistics. There is no direct sensor or GPS tracking.
- Retain `READ_STEPS` and iOS's existing step scope. Removed the unrelated
  Android `ACTIVITY_RECOGNITION` declaration and runtime prerequisite.
- Read consent is checked before and after awaits through the existing
  account/revision guard. Permission refusal and failed reads never become 0.
- The full refresh reads the selected date and previous calendar day after
  workout imports, then calculates strain before recovery. Explicit workout
  sync also refreshes today's steps before recalculating strain.
- Midnight boundaries are local calendar dates, including DST. Today stops
  at the query start time. Future dates and dates older than 28 days are not
  queried; no additional historical/background permission is introduced.
- Merge and clip workout intervals, then query their complement. Unknown
  workout times or failed interval reads suppress the movement contribution
  without hiding the total. Do not subtract guessed session step counts.
- Persist an exclusion hash. Changed/added/deleted workout intervals invalidate
  the outside count until the next successful sync, preventing stale double
  counting. The session-only personal baselines remain unchanged.

## Persistence and access

Supabase MCP verified that `body_metric_logs` has owner writes, authorized
coach reads, active-account restrictions and no anonymous grants. Migration
`20261019170653_daily_steps_metadata` adds a constrained JSON object column
`metadata`, default `{}`. Existing clients, policies and deletion remain valid.

The new `daily_steps` health log stores total steps as the numeric value and
outside steps, source, observation time and exclusion hash in metadata. New
rows use deterministic UUIDs per account/date to avoid concurrent-device
duplicates. Metadata changes trigger persistence even when the total is equal.
Save responses cannot repopulate another account after logout/deletion.

The live project has no `daily_strain_scores` table. AppState now stores the
score, version, input components, confidence and warnings together in the
existing `strain_score` body log instead of attempting the absent auxiliary
table. No existing scores or real users were bulk recalculated or queried.
Old snapshots update when that date is refreshed. The algorithm version
invalidates old local score caches.

The existing consent notice and public privacy page already cover steps,
optional health imports, sports analysis and authorized coach access. No
research access or export is introduced by this work.

## Verification

- 66 focused Flutter tests passed: source aggregation, overlap/overnight
  exclusion, unavailable/zero distinction, observation time, failed reads,
  consent revocation and account guards, exclusion invalidation, agreed
  examples, bounds, existing strain behavior, health jobs and deletion races.
- The steps view passed widget checks in both light and dark mode.
- Analysis of 11 affected source/test files reported no issues.
- `supabase/tests/daily_steps_metadata.sql` passed against the actual project
  with synthetic identities and transaction rollback: owner writes/deletion,
  JSON validation, authorized coach read-only access, outsider denial and no
  anonymous metadata grant. No synthetic steps records remain.
- Security advisors: zero ERROR findings and no new findings; the existing
  [leaked-password-protection WARN](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection)
  remains unchanged.
- Source version: `1.0.4+35`. See `android-release.md` for the signed artifact.
  The signed AAB built successfully on 19 October 2026 at 19:21:47 Europe/Rome;
  upload certificate and `jarsigner` exit 0 were verified. Its merged manifest
  retains `READ_STEPS` and contains no `ACTIVITY_RECOGNITION` permission.
  Physical-device aggregate comparison and iOS device validation remain.

## Device acceptance before rollout

Compare steps against Health Connect/Apple Health with phone and wearable
sources enabled. Check a day without workouts, a running day, overlapping and
overnight sessions, permission denial/revocation, interrupted sync, account
changes and newly corrected workout times. Check that today's timestamp is
visible and that no background reads are claimed beyond the existing refresh.

References:
- https://developer.android.com/health-and-fitness/health-connect/aggregate-data
- https://developer.android.com/health-and-fitness/health-connect/features/steps
- https://developer.apple.com/documentation/healthkit/hkstatisticscollectionquery
