# DuoUI 0.1.0

A small passive player/partner health display near the character, for Evoker **and Demon Hunter** from starting-level solo play onward. It automatically labels the player's class and works on other classes too; there is no class, spec or level gate. It complements Blizzard's UI and Edit Mode. Native player, party, raid and action bars remain in control. The other player can install the identical addon and configure you as their partner.

## Implemented, commands and usage

Two readable health bars show the player and the explicitly matched party/raid partner. Bars display health without calculating percentages, thresholds or action advice. They do not target, heal or accept native click-casting. Keep native unit frames visible for interaction, numeric health, connection/range state and other details.

- `/duoui` prints help. `/duoui partner Name-Realm` sets Companion's explicit identity; use the real character name. `/duoui select` selects your current targeted party member. Empty `/duoui partner` clears it. An ambiguous short name does not resolve; full Name-Realm is recommended. There is no `party1` identity assumption.
- Drag the companion display outside combat or use `/duoui position -260 -120` for center-relative offsets.
- `/duoui scale 1.2` accepts 0.6–2; `/duoui font 18` accepts 10–28; `/duoui face standard` or `readable` selects the native standard font or Arial Narrow.
- Solo and grouped (`duo`) profiles store position and scale separately. Join/leave a group outside combat to configure each. A larger party/raid also uses the duo profile and shows only the matched partner. Font settings and partner identity are shared across these profiles.
- `/duoui reset` restores both default layouts and font choices while retaining partner identity.

Configuration requested in combat is saved and applied after combat with a new roster lookup. Layout/identity changes are deferred; if the group roster changes during combat the partner bar is cleared until it can be resolved safely afterward. Health values flow directly into supported native status-bar methods; no restricted value is compared, calculated or serialized. The labels and colors are static and do not imply range, connected status or healing priority.

Use **Esc > Edit Mode** to position/scale Blizzard's own player and party frames, and save your native layouts there. DuoUI neither edits those protected frames nor writes to native Edit Mode profiles. Its own profiles are separate. Disabling DuoUI removes its companion display without requiring native-layout restoration.

## Installation on Windows and macOS

Keep `DuoUI/DuoUI.toc`, `Common.lua` and `Main.lua` together. Windows: the existing whole-AddOns junction from `<RETAIL_ADDONS_PATH>` to `<REPOSITORY_PATH>` exposes this addon directly. macOS: follow the [whole-folder symlink setup](../README.md#installation-and-first-use), substituting actual local repository and Retail paths. Never link WTF. Restart to discover the folder, enable DuoUI and use `/reload` for subsequent changes. No other addon is required.

## SavedVariables and reset

`DuoUIDB` stores account-wide schema-1 partner, fonts and solo/duo layouts in normal `WTF/Account/<account>/SavedVariables/DuoUI.lua`. Missing defaults are merged without overwriting existing layouts. `/duoui reset` restores only this addon's layout/fonts. For a complete reset, exit WoW, back up and remove only `DuoUI.lua` and `.lua.bak` from SavedVariables. Native Edit Mode layouts are separate and untouched. Back up WTF separately from Git.

## Compatibility and actual verification

Target: Retail Midnight 12.1.5.70575 / interface 120105, supported by the installed client's build metadata and patch marker. Confirm the runtime interface using `/dump select(4, GetBuildInfo())`. Matching-build generated status-bar documentation explicitly allows secret inputs to `SetMinMaxValues`/`SetValue`; see [API notes](../docs/API-NOTES.md). Lua 5.1 syntax, mocked startup, opaque-health pass-through, settings merge, roster changes and combat deferral passed. **In-game Windows and macOS testing, appearance, font assets, drag coordinates and restricted-instance secret/taint handling remain unverified.** These bars do not show absorbs, prediction, auras, power or cooldowns.

## Manual checks in WoW (outstanding)

1. Enable only DuoUI with fresh settings on newly created Evoker and Demon Hunter characters at each one's first playable level; verify automatic class label, solo player health changes and untouched native frames, including before specialisation unlock. Configure fonts/scale, drag and use numeric positioning at different resolutions/UI scales. `/reload` and confirm persistence.
2. Join Companion, target Companion and use `select` or configure Name-Realm. Test a different person occupying party1, group reordering, partner leave/rejoin, disconnected partner and no match. Join a larger group to confirm only the configured partner appears.
3. Configure different solo/duo positions/scales and join/leave; verify selection and `/duoui reset` restoration.
4. In restricted instance combat, change scale/position/identity; verify deferral until combat ends and current roster revalidation. Change roster during combat and verify no newly occupying party slot is shown under Companion's old label. Check for Lua/secret/taint errors during health updates and reload outside combat.
5. Repeat on macOS, individually and with the suite. Check native Edit Mode, fonts, clamping and adjusted UI scale; record actual builds/results in [verification](../docs/VERIFICATION.md).

## Future ideas (not implemented)

Native Edit Mode integration only through a supported extension point, more layout presets and optional extra passive native-presentation fields. A full UI replacement is outside the initial scope.
