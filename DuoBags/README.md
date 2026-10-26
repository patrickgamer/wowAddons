# DuoBags 0.1.0

A lightweight inventory and supplies companion for a returning Retail Midnight player. It leaves Blizzard bags, loot and confirmation windows intact.

## Implemented and everyday usage

- Click the free-space badge above the bottom-left UI or type `/duobags` to open/close the inventory panel. Search by name, localized item class/subclass, item ID, `keep` or `Companion`. Entries show bag/slot, item link, quantity and ID. Free space includes the reagent bag, whose free slots are also shown separately; reagent slots cannot hold arbitrary items.
- `/duobags keep 12345` toggles a persistent item-ID keep rule. Item links can be supplied instead of IDs. The rule protects every carried variant/stack of that ID from this addon's selling.
- `/duobags partner 12345` toggles a persistent **personal note only**, also protected from selling. It says nothing about binding, eligibility, trade timers or tradeability. Inspect native item information before any manual trade.
- The Loot button shows your item receipts since login/reload. `/duobags loot` selects that view and toggles the panel; `/duobags clearloot` clears only the session log. Receipts use accessible self-GUID `CHAT_MSG_LOOT` messages and the installed enUS `xN` quantity suffix. Missing GUID/restricted chat/localized count formats can omit or undercount receipts. Money, currencies, bank transfers and a complete accounting ledger are outside this version.
- At a vendor's Buy tab, click **Preview** or `/duobags preview`. **Sell ONE** then sells the first listed eligible stack, once, following a fresh identity/quantity/protection check. Every subsequent stack needs a new preview and click. Inventory changes, keep/tag edits and search edits invalidate the preview. Other views cannot be used to sell from an old preview. Nothing is sold on opening a vendor.
- Sale candidates must be cached, unlocked, non-equippable grey items with vendor value, without a quest marker/quest ID, embedded loot, keep rule or Companion tag. Unknown quest/cache data is excluded. All equippable items are excluded to preserve gear/appearance choices. The preview is deliberately conservative; use native bags to sell other items manually. Other addons/native junk-sale controls are outside these protections.

## Native auto-loot

The panel displays the native default, effective value with the currently held `AUTOLOOTTOGGLE` modifier, and CVar storage scope. **Auto-loot toggle**, `/duobags auto on` and `/duobags auto off` explicitly change Blizzard's `autoLootDefault`. `/duobags auto` reports status without changing it. No native setting changes on installation/login.

This is Blizzard's setting, not an addon-specific per-character override: server-account scope affects the account; local/shared scope can affect other characters using that client installation; server-character scope is identified if returned by the client. Treat it as shared unless the displayed scope says character. The addon does not restore an old setting on disable/reset. Normal modifier inversion is preserved because Blizzard performs the actual looting. Modifier bindings can be changed in native Keybindings.

Auto-loot only collects eligible items after **you open loot**. No movement, targeting, corpse interaction, loot-slot automation, confirmation acceptance or restriction/ownership bypass is implemented. Full bags and restricted/confirmation loot remain Blizzard's responsibility.

## Installation on Windows and macOS

Keep `DuoBags/DuoBags.toc`, `Common.lua`, `Rules.lua` and `Main.lua` directly inside the DuoBags folder. Windows: the inspected `<RETAIL_ADDONS_PATH>` junction already targets `<REPOSITORY_PATH>`; no copy or new junction is needed. macOS: use the [root whole-folder symlink instructions](../README.md#installation-and-first-use) with the actual local repository and Retail installation. Do not symlink WTF. Restart WoW to discover new addon folders, enable DuoBags, then use `/reload` for later code edits. It works independently of the other three addons.

## SavedVariables and reset

`DuoBagsDB` is account-wide in the normal `WTF/Account/<account>/SavedVariables/DuoBags.lua`. Schema 2 uses generic partner tags and imports boolean item-protection entries from legacy tag tables without discarding existing SavedVariables fields. Session loot is memory-only. To reset, exit WoW, back up and remove only `DuoBags.lua` and its `.lua.bak` from SavedVariables, then restart. This removes keep/partner rules; it does **not** reset native auto-loot. Back up WTF separately from Git.

## Compatibility and actual verification

Target: Retail Midnight 12.1.5.70575 / interface 120105. The installed client's build metadata and patch marker were inspected; definitive `/dump select(4, GetBuildInfo())` confirmation is still needed. Blizzard UI/API source for the matching build reviewed; see [API notes](../docs/API-NOTES.md). Lua 5.1 syntax and mocked startup, sale guards, filtering, settings merge, consent invalidation and explicit auto-loot setting changes passed. Structural/case/line-ending checks are recorded in [verification](../docs/VERIFICATION.md). **No in-game or macOS tests have been performed.** Vendor hardware-action acceptance and actual loot receipts are unverified.

## Manual checks in WoW (outstanding)

1. Enable only DuoBags with fresh settings. Open full/empty bags, search an item/class/ID and verify separate reagent capacity. Confirm native bags still behave normally.
2. Add keep and Companion tags, `/reload`, confirm persistence and ID-wide protection. Remove each with the same command. Try uncached items and confirm they populate after item data arrives.
3. Open a vendor with ordinary grey junk, grey gear, a quest item and protected tags. Confirm only eligible junk appears. Preview with an active search; search should clear. Sell ONE, check inventory/money and buyback, then confirm a second click without preview does nothing. Move an item or edit search/rules after preview and confirm no sale occurs. Test missing vendor, Buyback tab and combat.
4. Check native auto-loot before toggling. Turn on/off explicitly, hold the configured modifier and compare effective display with actual opened-loot behavior. Test on another character to establish native storage scope. Restore your preferred setting explicitly.
5. Loot a single item/stack, someone else's loot, money and confirmation loot. Compare the session summary; confirm no confirmation is accepted for you. Test full bags and ownership restrictions.
6. Repeat alone and with the suite on Windows and macOS, including `/reload`, logout/login, native UI coexistence and adjusted UI scale. Record actual results/builds.

## Future ideas (not implemented)

Clickable item rules, configurable supply lists, richer localized receipt parsing and per-character rule overlays. No automatic selling or automatic tradeability assumptions are planned.
