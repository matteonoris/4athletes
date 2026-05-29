# AI Release Runbook

Use this document when a user asks an AI agent to release the iOS app to
TestFlight.

## Goal

Create a GitHub tag that triggers the `TestFlight` workflow and uploads a signed
iOS build to App Store Connect/TestFlight.

The Flutter app lives in `flutter_mobile`. The GitHub Actions workflow lives at
the repository root in `.github/workflows/testflight.yml`.

## Preconditions

- Work from the repository root, not from `flutter_mobile`.
- Do not overwrite unrelated local changes. If unrelated files are modified,
  leave them out of release commits.
- GitHub Actions secrets must already exist:
  `ASC_KEY_ID`, `ASC_ISSUER_ID`, `APPSTORE_CONNECT_API_KEY_BASE64`,
  `APPLE_CERTIFICATE_P12_BASE64`, `APPLE_CERTIFICATE_PASSWORD`,
  `APPLE_PROVISIONING_PROFILE_BASE64`, `APPLE_PROVISIONING_PROFILE_NAME`,
  `SUPABASE_URL`, `SUPABASE_ANON_KEY`.
- The TestFlight group `External Testers` must exist in App Store Connect.
- The public TestFlight link, if needed, is managed in App Store Connect.

## Release Steps

1. Read the current version:

```sh
cd flutter_mobile
rg '^version:' pubspec.yaml
```

2. Choose the marketing version and next build number.

Use App Store Connect when available:

```sh
asc builds next-build-number \
  --app com.thestolenspot.4athletes \
  --version 1.0.3 \
  --platform IOS
```

The tag format is:

```text
testflight-v<marketing-version>+<build-number>
```

Example:

```text
testflight-v1.0.3+5
```

3. Update release notes before tagging:

```text
flutter_mobile/ios/fastlane/metadata/en-US/release_notes.txt
flutter_mobile/ios/fastlane/metadata/it/release_notes.txt
```

The Fastlane guardrail checks that `en-US/release_notes.txt` changed since the
last non-TestFlight release tag, such as `v1.0.2+3`.

4. Validate locally:

```sh
ruby -c flutter_mobile/ios/fastlane/Fastfile
ruby -e 'require "yaml"; YAML.load_file(".github/workflows/testflight.yml"); puts "workflow yaml ok"'
git diff --check
```

5. Commit and push only release-related files:

```sh
git status --short
git add .github/workflows/testflight.yml \
  flutter_mobile/README.md \
  flutter_mobile/docs/testflight-github-actions.md \
  flutter_mobile/docs/ai-release-runbook.md \
  flutter_mobile/ios/fastlane/Fastfile \
  flutter_mobile/ios/fastlane/metadata/en-US/release_notes.txt \
  flutter_mobile/ios/fastlane/metadata/it/release_notes.txt
git commit -m "ci: prepare TestFlight release"
git push origin main
```

If there are no code or release-note changes to commit, do not create an empty
commit just for the tag.

6. Create and push the tag:

```sh
git tag testflight-v1.0.3+5
git push origin testflight-v1.0.3+5
```

Never reuse an already-pushed TestFlight tag. If a run fails before upload, fix
the issue and use the next build number.

7. Monitor the workflow:

```sh
gh run list --workflow TestFlight --limit 5
gh run watch <run-id> --exit-status
```

8. Verify App Store Connect after success:

```sh
asc builds info \
  --app com.thestolenspot.4athletes \
  --latest \
  --version 1.0.3 \
  --platform IOS
```

Expected result: the uploaded build appears with processing state `VALID`.

## Known Good Baseline

The pipeline was validated with:

- Tag: `testflight-v1.0.3+4`
- GitHub Actions run: `26626804559`
- Result: success
- App Store Connect build: `1.0.3 (4)`, processing state `VALID`

The workflow currently uses:

- `runs-on: macos-26`
- Flutter `3.41.7`
- Ruby `3.3`
- Fastlane lane `ios ci_beta`

## Failure Notes

- If `ruby/setup-ruby` cannot infer Ruby, keep `ruby-version: "3.3"` in the
  workflow.
- If `device_info_plus` fails on `isiOSAppOnVision`, keep the workflow on
  `macos-26`.
- If release notes fail freshness checks on retry tags, make sure the guardrail
  excludes `testflight-*` tags.
- If signing fails, check that the GitHub secrets match the provisioning profile
  named by `APPLE_PROVISIONING_PROFILE_NAME`.
