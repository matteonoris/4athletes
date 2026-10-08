# Team visibility incident — 8 October 2026

The owner reported that existing users appeared to have lost their real teams
on iPhone/TestFlight and Android after deletion of the example teams.

## Verified database state

Read through the project Supabase MCP (`hqzushizdfxrnktoqbtr`):

- Zanetti Goggi Giovani Senior: 21 active memberships, including 16 athletes
  and five coach managers. All 21 profiles still reference that team.
- Team Batti: one active membership, its coach manager Battista Tomasoni.
- All 29 profiles remain. Seven profiles have no membership; the verified
  bootstrap audit does not assign them to either real team.
- The 22 membership audit records are all `owner_confirmed_bootstrap` from
  5 October. Their membership states match the current registry. No recorded
  leave or removal was found.
- The stored team member counters agree with the registry and profile links.

No membership or personal data was changed during this investigation. Do not
assign unlinked accounts to a real team without evidence of their membership.

## Reproduced cause

The old client at `testflight-v1.0.3+29` loads teams with
`from('teams').select()` (`SELECT *`). Since the security rollout, authenticated
clients have access only to approved team columns. Invitation codes are
available to managers through the validated RPC, rather than direct table
access. The old team query fails with:

```text
42501: permission denied for table teams
```

The old app catches the failure and presents an empty team list. This can look
like loss of membership even when the membership and profile link are intact.
Reinserting the existing memberships would not repair that query.

The working source already uses `TeamAccessService.teams()` / `get_my_teams`
and `TeamAccessService.directory()` / `team_directory`. Remote TestFlight tags
were checked on 8 October: the latest tracked tag is `testflight-v1.0.3+29`,
pointing to `bb6f2f910bc7e5088f23d25cf3acbf90446247ff`, before these client
changes. This is a check of release tags, not live App Store Connect inventory.

## Verification

In a read-only transaction, tested the authenticated database role and account
claim for each of the 29 profiles, then rolled back:

- Each of the 22 existing members receives its correct team from
  `get_my_teams` and its full authorized team directory (21 or one).
- Each of the seven unlinked accounts receives no team and no real-team
  directory.
- All 29 accounts receive zero directory rows for teams they do not belong to.
- Reproduced the legacy `SELECT *` failure for an existing coach manager.

All 29 checks passed. No physical device was connected for Android inspection;
installed build numbers were not verified on the owner's devices.

## Required distribution

Distribute mobile builds containing the protected team client changes to both
platforms, then verify the Teams screen with existing accounts. The signed
Android `1.0.3+31` build documented in `android-release.md` already includes
the protected team client. A new iOS/TestFlight release is still needed.
No release tag, upload, install, or account reinvitation was performed in this
investigation. Preserve current RLS, private avatars, manager-only invitation
codes and the membership registry when resolving client compatibility.
