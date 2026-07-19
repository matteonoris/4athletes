# AGENTS.md

## Project Memory

- For backend work involving Supabase, use the project's Supabase MCP server instead of guessing schema, data, or project state.
- iOS TestFlight releases are triggered from GitHub Actions by pushing a tag like `testflight-v1.2.3+45`; see `flutter_mobile/docs/ai-release-runbook.md` before releasing.
- Do not assume direct ownership of the Apple Developer account. The release pipeline relies on the existing GitHub secrets and signing setup.
- For mobile app testing, a Pixel 8 Android emulator is available as the `Pixel_8` AVD. Launch it with `flutter emulators --launch Pixel_8`, then run the app from `flutter_mobile` with `flutter run -d emulator-5554`.
- If the Pixel 8 emulator appears as `offline`, use the SDK adb/emulator binaries under `C:\Users\matte\AppData\Local\Android\Sdk`. A cold boot with `emulator.exe -avd Pixel_8 -no-snapshot-load` fixed this previously.
- For onboarding review on the emulator only, run from `flutter_mobile` with `flutter run -d emulator-5554 --dart-define=ONBOARDING_PREVIEW=true`. Optional: add `--dart-define=ONBOARDING_PREVIEW_STEP=4` to start from a specific signup step. Do not pass these flags when testing real login/data on a physical Pixel 8.
- The `web_prototype` onboarding is a local UI review surface mirroring the Flutter mobile signup flow. Keep it disconnected from Supabase/GitHub and use it to preview UI changes before applying them to iOS/Android.
- When changing Flutter UI, verify and preserve behavior in both dark mode and light mode. Avoid hardcoded dark-only colors such as white text on theme cards unless the background is guaranteed to stay dark.
- Alpine skiing is a core ski-club workflow. Athlete-created sessions must keep the dedicated completed-session form (no team selection or athlete invitations) with title/date/times/location, up to two specialties, snow/weather/quality, free-skiing laps, multiple tracks, training/addestramento, chrono and personal data. Persist the modular per-specialty payload used by the athlete Home and coach reports, and preserve monthly club/athlete pass counts for every specialty (SL, GS, SG, DH and SX).
