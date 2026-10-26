# DuoSocial 0.1.0

A compact local party/guild companion for regular play with Companion. Private notes and favourites are stored locally in this addon's SavedVariables. Nothing automatically invites, sends messages or changes guild notes.

Optional **DuoAdventure** integration: its Social plan button or `/duoadventure social` explicitly copies your selected quest/mode into this addon's local activity text. It does not publish a plan, inspect anyone else's addon data or share private notes. `DuoSocialAPI.version = 1` exposes `SetActivity(text)` for this local out-of-combat action. Disabling either addon leaves the other usable.

## Implemented, commands and everyday use

- `/duosocial` opens/closes the panel outside combat. Search roster names, roles, ranks, zones, favourites and your private notes with the search field. The roster includes player/party or raid, available assigned roles, leader/assistant and online status. `NONE` means no assigned role; it does not identify a specialisation.
- Guild members are online-only by default. **Offline toggle** or `/duosocial offline` includes cached offline members. **Refresh** requests the asynchronous native guild roster. Solo/no-guild and not-yet-loaded data show explanatory text. Guild rank is shown; rank names do not imply group leader/assistant permissions.
- `/duosocial partner Name-Realm` configures Companion's actual character, or target Companion in your party and run `/duosocial select`. Empty `partner` clears it. Use exact full names from the roster, including realm; ambiguous short names are not resolved.
- **Invite partner** or `/duosocial invite` attempts an invitation only after your explicit action, outside combat and with native permission checks. Blizzard handles full groups, offline/invalid targets, cross-faction/instance restrictions and confirmations. Existing matched partners are not invited again. No automatic retry or confirmation bypass.
- **Ready check** or `/duosocial ready` is available outside combat to a group leader/assistant. Solo/non-permitted attempts explain the restriction locally. Group-management scope is invitation and ready check; use native group UI for promotion, removal and other management.
- `/duosocial favourite Name-Realm` toggles a local favourite. Favourites are listed even if absent from cached rosters, with **no implied presence or online status**. Matching is exact and case-sensitive for stored notes/favourites; use the displayed spelling.
- `/duosocial note Name-Realm your private text` stores a private note. `/duosocial unnote Name-Realm` removes it. These are unrelated to native public/officer guild notes; neither is changed. Favourites and note search are local only.
- `/duosocial activity Your agreed activity` stores the plan. **Roles**, **Activity**, **Preparation** or `/duosocial check roles|activity|preparation` toggle manual session checkmarks. Activity text persists; checkmarks reset on reload/login. They do not inspect gear or readiness automatically.

Roster presentation pauses in combat and refreshes afterward; use Blizzard group frames in combat. Refreshes are event-driven and debounced. No repeated polling, automatic invites, chat sends or guild-note setters. Cached rosters can be incomplete/throttled; native actions may fail for reasons only WoW knows. All notes are account-wide within this WoW account/installation and should be treated as private local data when backing up/sharing WTF.

## Installation on Windows and macOS

Keep `DuoSocial/DuoSocial.toc`, `Common.lua` and `Main.lua` together directly under the repository. Windows: the existing `<RETAIL_ADDONS_PATH>` junction to `<REPOSITORY_PATH>` exposes it automatically. macOS: follow the [whole-folder symlink instructions](../README.md#installation-and-first-use) using actual local repository and Retail paths. Do not link WTF. Restart WoW to discover the folder, enable DuoSocial, then `/reload` for edits. Other suite addons are optional.

## SavedVariables and reset

`DuoSocialDB` stores schema-1 partner identity, favourites, private notes and activity in normal account-wide `WTF/Account/<account>/SavedVariables/DuoSocial.lua`. Missing defaults merge non-destructively. Session checkmarks, search and offline-view toggle are memory-only. Exit WoW, back up and remove only `DuoSocial.lua` and `.lua.bak` from SavedVariables for a complete reset. This deletes the local private notes/favourites, so preserve a separate WTF backup. No notes belong in Git.

## Compatibility and actual verification

Target: Retail Midnight 12.1.5.70575 / interface 120105, based on the installed client's build metadata and patch marker. Confirm the runtime value via `/dump select(4, GetBuildInfo())`. Matching-build invitation/guild roster APIs reviewed; see [API notes](../docs/API-NOTES.md). Lua 5.1 syntax and mocked startup, solo/no-guild, private-note storage, explicit invite and combat refusal passed. **In-game Windows/macOS, real asynchronous guild/offline data, real permissions, invitations and ready checks remain untested.** A mock is not proof of client API compatibility.

## Manual checks in WoW (outstanding)

1. Load only DuoSocial with fresh settings while solo/no guild. Open/search/refresh without errors. Configure full partner identity and a favourite who is absent/offline; no presence should be inferred.
2. In a guild, Refresh and wait for data. Check online/offline views, incomplete/throttled data and search by name/rank/private note. Add/remove notes/favourites and `/reload`; stored text persists, checkmarks reset. Confirm no public/officer notes change and no messages are sent.
3. In party/raid, verify roles, leader/assistant and connection state; test group roster changes and partner not occupying party1. Test explicit invitation when permitted, already grouped, offline, full group and native confirmation cases. Nothing should happen without your click/command.
4. Test Ready check as leader, assistant, ordinary member and solo. Observe native context restrictions. Enter combat with panel open; roster pauses, actions refuse, and data refreshes after combat.
5. Repeat with the complete suite and on macOS, including UI scale, reload/login, no-guild/offline and missing permissions. Record actual results/builds in [verification](../docs/VERIFICATION.md).

## Future ideas (not implemented)

Clickable member selection for notes/favourites, richer local scheduling and optional user-triggered access to more native group tools. Automatic messages/invitations and guild-note editing are outside this version.
