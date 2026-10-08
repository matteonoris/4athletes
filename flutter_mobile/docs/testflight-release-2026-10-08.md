# TestFlight release — 8 October 2026

Version: **1.0.3 (33)**. Tag: `testflight-v1.0.3+33`.
Release commit: `64e2c9de934c8211ee4f50213bfa29e86d630d24`.
[GitHub Actions run](https://github.com/matteonoris/4athletes/actions/runs/37777710857).
The initial build 32 run was cancelled before upload to include deletion of
temporary app media copies. Its tag was preserved; build 33 uses a new tag.

## Included changes

- Protected team RPC clients compatible with the deployed authorization rules,
  manager approval and membership controls, restricted coach health edits,
  private avatar URLs, and updated attendance and team reports.
- Health-data consent and revocation, minimum signup age, Apple Health access
  guidance, and account deletion with persistent status reconciliation and
  removal of app-scoped temporary media copies.
- On-device exercise import from photos/PDFs with review and catalog matching,
  workout location suggestions and maps, athlete reports and activity details.
- Current mobile source and supporting backend migration/function/test files;
  local `web_prototype` changes are excluded from the release commit.

## Verification before tagging

- Full Flutter test suite: **464 passed**.
- Final account-deletion tests: **9 passed**, including light/dark themes,
  confirmation, verified completion, receipt recovery, recent-login rejection
  and temporary media cleanup while preserving original files.
- Final regression check for account state, consent and signup: **23 passed**.
- `flutter analyze lib test integration_test --no-fatal-infos`: exit 0,
  no errors or warnings; 55 informational style diagnostics.
- Final changed-file analysis after cache cleanup: exit 0, no errors or warnings;
  one informational unnecessary-import diagnostic in a test.
- Workflow YAML parsed locally. Fastfile/Ruby YAML syntax checks run in CI because
  no local Ruby executable is configured on this Windows host.
- Staged diff whitespace checks passed; scanned release sources contained no
  detected private keys, privileged tokens or literal credentials.
- Supabase MCP verified deployed protected team/deletion RPCs, zero public
  tables without RLS, zero anonymous personal-table grants and private avatars.
  Security advisors reported zero ERROR findings. The pre-existing disabled
  [leaked-password protection warning](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection)
  remains separate administration work.
- Source build number 31 and latest successful tracked TestFlight build 29 were
  checked before build 32. After cancelling that run, the final release uses
  build 33. Existing tags were preserved.

## Distribution status

GitHub `main` and the new tag were pushed. The workflow completed successfully
on 8 October at **14:45:04 Europe/Rome**. Fastlane's recorded results confirm:

- Apple finished processing **1.0.3 (33)** at **14:43:53**.
- Distribution to external testers succeeded at **14:43:57**, using the existing
  `External Testers` group and configured tester notification option.
- The signed IPA artifact was saved by GitHub Actions and signing cleanup passed.

Existing GitHub signing/API secrets were used. No direct Apple account ownership
or separate local App Store Connect CLI access was assumed. Processing and
distribution were verified through the authenticated workflow's Fastlane logs.
This release does not establish physical-device acceptance testing.

The release tag freezes the commit above. Subsequent edits from the ongoing
Android/account-deletion chat are not included in this uploaded iOS build.
