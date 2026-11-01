# App Store release preparation — 1 November 2026

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
