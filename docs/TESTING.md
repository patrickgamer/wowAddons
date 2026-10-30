# Testing plan and limits

From the WOWA-28 plan, minimum viable depth: one real client on each of two Macs (a paid account on one, a free account on the other), no Windows yet, no companion, no live automation. This file records the rungs, what is permitted, and the gaps.

## Rungs and status

1. Structure: `tools/check-repository.py` - automated, passing.
2. Models: `tools/verify.lua` (includes sync and native models) and `tools/verify-kit.lua` - automated, passing; they model code paths only.
3. API names against Blizzard's documentation: `tools/check-api.py` - automated against 12.1.5.70575 documentation. It proves names exist, not signatures, secrecy or behaviour. One name is unverified: `GetGuildRosterInfo` (DuoSocial) is in neither the documentation nor Blizzard's UI source; settle it in the guild run.
4. One real client, 5. two real clients, 6. restricted combat: guided run sheets in `docs/run-sheets/`, recorded by DuoTestKit. **Not yet run; no in-game result exists for any addon.**
7. Windows and the next patch (test realm 12.1.7): later.

## What automation is permitted

- Blizzard's published policy (2020-21 forum posts, not re-confirmed this session) prohibits software or hardware that mirrors input to several accounts or automates or streamlines multiboxing. That is a ban on broadcasting and multiboxing aids. It does not by itself rule out every outside tool.
- `AGENTS.md` independently forbids addons automating casting, movement, target selection or rotation, and any addon starting, joining, answering or stopping native Party Sync.
- Not established: a Blizzard statement permitting external scripted input to drive a single client for testing. Without one, this project does not use scripted keyboard or mouse input against the live client. Reading files the client writes (SavedVariables after logout, screenshots a person takes) is ordinary and is what the kit relies on.
- Consequence: real-client proof needs a person at the keyboard on each Mac, following the run sheets. Unattended real-client runs are not promised. Fleet work covers rungs 1-3 and reads the recordings afterwards.

## Accounts

- Free (Starter/trial) accounts can join a party but not create one, per Blizzard support pages and the Warcraft wiki; this is not verified against Midnight. So the free account must always be the invitee and never the leader or the Party Sync starter.
- Free characters are capped at level 20, so some content cannot be reached; whether Party Sync starts for low-level characters, whether `Screenshot()` is callable by addons, and whether a starting character can reach a dungeon boss in the planned sessions are all unverified.
- No account, install or purchase was made while building this; installing WoW and creating the free account are separate steps.

## Gaps this piece leaves

Live results for every addon; restricted combat behaviour; Windows; the 12.1.7 realm; whether Party Sync is available to the account types in use.
