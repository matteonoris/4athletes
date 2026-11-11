# App Store manual release — 11 November 2026

Matteo explicitly authorized releasing **4Athletes 1.0.4 (40)**, keeping the app
free and available only in Italy. No pricing or territory mutation was needed.

Before release, API checks confirmed:

- Version `98ea4b7a-4640-4378-86cf-f27dacab9be7`, iOS 1.0.4, build
  `238ec3f4-e875-44b2-8195-6b7fd71a6d3f` (40), PENDING_DEVELOPER_RELEASE,
  releaseType MANUAL.
- Italy price: EUR 0.0, isFree=true; base territory ITA.
- All 175 territory records were read with complete pagination: exactly one
  enabled territory, ITA. availableInNewTerritories=false.
- Existing review submission `4cf63f5a-744b-4963-97d4-fb7ec2e10ea9` was COMPLETE
  and its version item APPROVED, as verified in the preceding status check.

The authorized action completed successfully:

```powershell
asc --profile 4athletes-matteo --strict-auth versions release --version-id 98ea4b7a-4640-4378-86cf-f27dacab9be7 --confirm --output json
```

The CLI returned releaseRequestId `98ea4b7a-4640-4378-86cf-f27dacab9be7`.
Subsequent API checks confirmed **READY_FOR_DISTRIBUTION**, the same build 40,
and price EUR 0.0. Italy initially reported PROCESSING_TO_AVAILABLE, then
**AVAILABLE**. Exactly one territory remains enabled; automatic availability
in new territories remains disabled. No new review submission was created.

Public verification on 11 November (final check at approximately 09:26
Europe/Rome): the [Italian App Store page](https://apps.apple.com/it/app/id6771865051)
returned HTTP 200, title “App 4Athletes - App Store”, and its public
SoftwareApplication structured data identifies 4Athletes with an EUR 0 offer.
The public lookup endpoint initially returned zero results during propagation;
the direct public page and the country availability were subsequently verified.
Search indexing across every client was not separately tested.

App: `6771865051`, bundle `com.thestolenspot.4athletes`. Released source remains
immutable tag `testflight-v1.0.4+40`, commit
`437f5339924f242a7325b65fcee1aed165d26c0f`, workflow `42466961670`.
See the [build and review evidence](../app-store-review-2026-11-08/README.md).

Read-only follow-up:

```powershell
asc --profile 4athletes-matteo --strict-auth --read-only versions view --version-id 98ea4b7a-4640-4378-86cf-f27dacab9be7 --include-build --output table
asc --profile 4athletes-matteo --strict-auth --read-only pricing current --app 6771865051 --territory ITA --output table
asc --profile 4athletes-matteo --strict-auth --read-only pricing availability territory-availabilities --availability 6771865051 --paginate --output json
```

Do not repeat the release request or change pricing/availability automatically.
Private keys, App Review credentials and signing resources were not changed.
