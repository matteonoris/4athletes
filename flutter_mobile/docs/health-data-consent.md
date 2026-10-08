# Health-data consent implementation

## Implemented — 4 October 2026

- Explicit consent during signup, before operating-system health permissions,
  and once at first access after this update for existing accounts without a
  recorded choice. Both restored login and replacement routes after OAuth are
  gated. A refused choice is recorded too; normal app use remains available.
- Later imports silently verify the saved server choice. No repeated consent
  screen is shown for each import. System permissions still control individual
  data streams. Unavailable server verification blocks imports, not a previously
  completed choice or historical-data viewing.
- Profile > Gestisci dati salute supports revocation, reactivation and an email
  request to delete health data while keeping the account. The request opens a
  composer; it does not send mail or delete records automatically. OS permissions
  have their own separate entry in Profile.
- Revocation immediately invalidates running import jobs. A per-account local
  stop survives restart if the server cannot be reached. Pending revocation is
  retried at startup, foreground access and when opening health-data settings.
- Each asynchronous device-read scope captures its account and consent revision.
  Subsequent native/plugin queries stop when that scope is invalidated; returned
  data is discarded. Already-issued OS queries or network writes cannot be
  recalled. Consent revocation is separate from deleting historical data.
- Consent concerns the service only. Research/thesis use and the processing basis
  for manually entered or previously collected health data remain separate.

## Verified backend

Project Supabase MCP: `hqzushizdfxrnktoqbtr` (4Athletes), `eu-north-1`.
The region is verified; the owner reports an active processing agreement.

Migration applied through MCP and copied using its actual server migration
version: `supabase/migrations/20261004182156_create_health_consent_events.sql`.

`health_consent_events` contains account ID, granted/declined/revoked decision,
notice version `2026-10-04`, server-generated identity/order and timestamp.
Authenticated users can select their own history and insert their own decisions.
RLS rejects cross-account inserts; anonymous access, history updates/deletes,
and client-supplied timestamps are denied. Account deletion cascades from
`auth.users` to this history; other associated data deletion remains unaudited.

A rolled-back server test using two existing identities verified isolation,
owner insert/revocation, cross-account rejection, immutable history and time,
and anonymous denial. No test decision remains in the database.

## Critical pre-existing release blocker

MCP verified disabled RLS plus anonymous SELECT/INSERT grants on eight tables:
`profiles`, `teams`, `training_sessions`, `body_metric_logs`, `pr_logs`,
`jump_logs`, `calendar_events`, `notifications`. Supabase security advisors
reported the corresponding errors. Public client credentials are not secret;
these grants allow access outside the restrictions in the app UI.

The new consent table is protected independently. It does not repair access
control on existing data. Do not release or claim verified coach/athlete isolation
until appropriate server policies, protected role/team membership, storage
permissions and adversarial access tests are implemented. Do not simply enable
RLS everywhere without mapping the actual coach/team workflows first.

Reference: https://supabase.com/docs/guides/database/database-linter?lint=0013_rls_disabled_in_public

## Verification / publication

52 focused Flutter tests passed, covering persisted choices, save failures,
offline revocation, account changes, late job results, native-read cancellation,
registration age checks, light/dark consent screens and restored access.

Public privacy updated on `gh-pages` in commit `66db671`; it describes the
updated app version and does not authorize research or promise automatic deletion.
The disconnected `web_prototype/?preview=health-consent` remains a simulated
review surface. Real Health Connect/iOS device validation is still required.

See `android-release.md` for the signed bundle status and remaining Play gates.
