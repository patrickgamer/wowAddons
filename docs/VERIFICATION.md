# Progress and verification

As of 25 October 2026. This is an initial source implementation, not an in-game-certified release.

## Delivery checklist

- [x] Inspect original checkout/instructions and live AddOns installation; original root README retained and expanded.
- [x] Confirm existing whole-folder junction, preserve it and the existing AddOns backup folder; no unrelated addon changes.
- [x] Inspect the installed Retail client: its executable and build metadata report 12.1.5.70575; its patch marker reports 120105.
- [x] Add user-supplied root AGENTS.md, root documentation and Git hygiene.
- [x] Implement DuoBags first, including explicit native auto-loot configuration and protected-item sale preview.
- [x] Implement DuoUI, with compact passive health presentation and separate solo/duo layout settings.
- [x] Implement DuoSupport, with known-spell reference, secure manual controls and configurable static DH profiles.
- [x] Implement DuoSocial, with private local notes, rosters and explicit group actions.
- [x] Extend DuoSupport with automatic class detection, Evoker/Demon Hunter modules, no minimum-level gate, solo self controls, class plans and non-destructive migration.
- [x] Make DuoUI's class-neutral player/partner support explicit for both starting classes.
- [x] Add DuoAdventure immersion/speed planning, native share/catch-up advice and optional local DuoSocial integration.
- [x] Add explicitly opted-in, on-demand direct party-addon quest snapshots with bounds, pacing, membership validation, expiry and combat/group cancellation.
- [x] Upgrade DuoAdventure to V2: join-prompt checkbox/session consent, automatic event-debounced incremental objective counts, 30-second refresh and restriction recovery.
- [x] Separate DuoAdventure progress sharing from WoW Party Sync (0.3.0): renamed controls and status, a read-only native status line, a native-active notice, and static plus modelled guards against any addon-started, answered or stopped Party Sync.
- [x] Per-addon installation, settings/reset, commands, limitations, manual tests and future ideas documented.
- [x] Review target-build Blizzard source/generated documentation and record design limits.
- [x] Lua 5.1 syntax and focused mocked behavior checks pass using an already installed Lua 5.1 library; no dependencies installed.
- [x] Structural TOC/case/UTF-8/LF checks and focused mocked independent startup pass for all five addons.
- [ ] Confirm `select(4, GetBuildInfo())` is 120105 in the running client.
- [ ] Run each README's Windows in-game checks, individually and together.
- [ ] Run restricted dungeon/raid/PvP combat, secure-action, recipient/roster, key-down/up and taint checks.
- [ ] Run macOS structural/runtime/appearance/modifier checks.
- [ ] Validate actual first-playable-level spell availability on freshly created Evoker and Demon Hunter characters (mocked levels are not unlock evidence).
- [ ] Validate native quest share/catch-up advice and real two-client party snapshot communication, packet restrictions and privacy boundaries.
- [ ] Run DuoAdventure's observation-only Party Sync checks 8–11 (loaded version, native off, already active, unknown) in the running client.

## Actual automated checks

`tools/verify.lua`: runtime files parse with Lua 5.1; sale eligibility/filtering, defaults and schema migration are checked. The mocked frame/API model loads all five addons together and in isolated environments, dispatches login/roster/combat events and tests native-setting writes, one-use sale consent, inventory invalidation, private notes, explicit invitations and deferred secure attributes. Opaque health objects pass directly to bar stubs. Evoker and Demon Hunter injected starting-level spell sets test the absence of level gates, class filtering and explicit self/partner/selected-target recipients. Quest sorting and optional local Social integration are checked. Protocol tests cover opt-in, current-party/wrong-channel filtering, complete packet assembly, rate limiting, expiry and notes exclusion. These mocks are not WoW's protected execution, actual spell unlocks or proof of two-client interoperability.

`tools/check-repository.py`: checks five matching direct-child folders/TOCs, exact reference case, SavedVariables declarations, interface metadata, independent Common.lua copies, UTF-8/LF and runtime path/action scans. Addon messaging is permitted only in DuoAdventure's scoped PARTY protocol; ordinary chat, direct casting/targeting and loot-slot automation calls are rejected. `git diff --check` checks tracked changes; the structural helper also checks new files.

`tools/verify-native.lua` owns the captain's rule that the addons must not trigger native Party Sync holds directly or indirectly. It loads two full DuoAdventure clients, with DuoSocial on one, and runs consent (Apply toggle, Keep off, `share on`, `sync on`, the on/off button), manual refresh (button, `share`, `sync`), received reports, quest events, `open ID`, the Native quest log button, Social plan, an explicit invite and ready check, and native invitation/confirmation/session callbacks while a start or stop request is pending. It also covers combat deferral, leaving and rejoining with renewed consent, a reload and the 30-second refresh. It does this twice: Party Sync off, then already active before any addon action. Native session commands and confirmation functions are tripwires. Party Sync stays off or stays active, never answered, and the unshareable quest the companion lacks stays planned and reported. Progress and native status appear on separate lines. The active notice is printed once per session start or reload, and a session started outside the addon gets one notice. Eleven status cases show that missing, secret, non-boolean or partial answers read as unknown, never as not active. `check-repository.py` rejects native Party Sync commands, confirmation answers, dialog clicks, QuestSession references outside `DuoAdventure/Native.lua` and invitations outside DuoSocial's explicit invite. It also self-tests its patterns. Seven deliberately planted defects (an auto-answered vote, an auto-confirmed invitation, an invitation from a received report, unknown shown as inactive, dropped unshareable quests, a repeated notice and a missing native line) each failed at least one of these checks before being discarded. These are code-path models, not WoW's Party Sync engine, quest holds or transport.

`tools/verify-sync.lua` adds two communicating protocol instances with a deterministic virtual clock. Checks cover join prompt/checkbox application, no publishing before consent, initial exchange, incremental counts before completion, burst coalescing, unchanged-log suppression, accepted/completed/turned-in quests, idle refresh, combat/chat deferral and recovery, opt-out and renewed consent on rejoin. This tests code state transitions rather than Blizzard's real transport, secret aspects or UI rendering.

Execution uses the bundled Python 3 runtime and an existing 32-bit Lua 5.1 DLL through the supplied PowerShell wrapper. For the 0.3.0 Party Sync change, `python3 tools/check-repository.py`, `lua5.1 tools/verify.lua` (including both models) and `git diff --check` passed in a macOS development environment, using Python 3.9 and a Lua 5.1.5 interpreter built from the official lua.org source outside the repository. That is not in-game macOS testing. These are development checks only and are not runtime requirements. No WoW client interaction, casts, vendor transactions, invitations, native setting changes or macOS runtime checks were performed. The user separately authorized committing and pushing the completed source directly to main.

## Static operating reference checks

`docs/index.html` is a source-verified guide, not additional in-game evidence. Its five addon sections were checked against current manifests, READMEs, command dispatchers, button registrations, sale rules, class modules and sync code. The earlier guide incorrectly described `/duoui` as a panel toggle; the page correctly documents help output and automatically displayed passive bars. It also distinguishes independent addon progress reports from native Party Sync holds and manual quest sharing.

Reference validation: `tidy -errors -quiet docs/index.html`, `python3 tools/check-repository.py` and `git diff --check` passed. A local browser loaded the served page; an isolated Chromium check loaded the HTML directly from disk with networking disabled at 1280, 390 and 320 pixel widths, checked section navigation, matching anchors, no horizontal page/table overflow and no external resource requests. Screenshots were inspected for wide/narrow readability. All ten distinct online source links returned HTTP 200. Modified public files were reviewed for UTF-8/LF, private identities and machine paths; commits use generic contributor metadata.

No addon runtime files changed. The Lua mock suite was not rerun for this documentation-only change because a Lua 5.1 runner was unavailable in the documentation environment. No WoW installation, settings, native Party Sync state or GitHub Pages configuration/deployment changed. All outstanding game checks above remain outstanding.

For the 0.3.0 Party Sync change, the DuoAdventure and sharing sections were rechecked against `DuoAdventure.toc`, `Native.lua`, `Sync.lua`, the `Main.lua` command handler and button registrations. `tidy -errors -quiet docs/index.html` passed. A headless Chromium loaded the page from disk with networking blocked at 1280, 390 and 320 pixel widths, and found no horizontal overflow and no in-page link without a matching anchor. Screenshots of the DuoAdventure and sharing sections were inspected at 1280, 390 and 320 pixels. Online links were not rechecked in that environment. No WoW installation, settings, native Party Sync state or GitHub Pages configuration changed.

## Record future manual results here

For each run record: date, OS, full GetBuildInfo tuple, addons enabled, fresh/existing settings, context (starting character/solo/group/guild/open-world/restricted instance/two-client sync), test steps, result and any Lua/taint errors. Do not paste account identifiers, private notes or WTF data into tracked reports. See all five addon READMEs for detailed outstanding cases.
