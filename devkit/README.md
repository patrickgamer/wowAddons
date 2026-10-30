# Developer-only test kit

Not an addon of the suite and not part of any runtime load list. `devkit/` is not scanned by WoW, so it stays inactive until you copy or link `devkit/DuoTestKit` into the client's AddOns folder.

## DuoTestKit

A read-only recorder for the guided run sheets in `docs/run-sheets/`. It never casts, targets, invites, sends messages, answers dialogs or starts, joins, answers or stops WoW's native Party Sync (`tools/check-repository.py` enforces this). It stores no character, realm, guild or message text.

Records in `DuoTestKitDB` (SavedVariables, in WoW's normal WTF folder):

- client version, build and interface number; each `Duo*` addon's loaded state and `Version`;
- before and after each step: Party Sync `Exists`/`HasJoined` (read-only; secret, missing or non-boolean answers are `unknown`, never "off"), group kind, combat lockdown, counters;
- counters for `DuoAdventureV2` packets received and sent (counts only), packets whose text was secret, and `canaryLeaks` for the private-note canary `DTK-CANARY-PRIVATE-NOTE` (type it into a DuoSocial private note; it must never reach the wire);
- `ADDON_ACTION_BLOCKED` / `ADDON_ACTION_FORBIDDEN` counts by addon and function name.

Commands: `/dtk begin <id> [sync]` (add `sync` only when you will start or stop Party Sync yourself during that step), `/dtk end pass|fail|skip`, `/dtk status`, `/dtk shot` (calls `Screenshot()` if the client lets addons; otherwise use the system key), `/dtk reset`. Step ids are short labels such as `quest-share`; do not type names.

Install (Windows or macOS): copy or link `devkit/DuoTestKit` as `Interface/AddOns/DuoTestKit` in the Retail folder. Disable it again for normal play. Reset: `/dtk reset`, or delete `DuoTestKit.lua` from the WTF SavedVariables folder.

## Reading a recording

After logout: `lua5.1 tools/kit-report.lua <path to DuoTestKit.lua> [second recording]`. It prints versions and steps and fails (exit 1) on a Party Sync change outside a `sync`-flagged step, a canary in a packet, stored name-like text or a failed step. With two recordings (kit only, then all five addons, same journey) it also fails when the Party Sync after-states differ. Keep recordings and the WTF path out of the repository.

## Development tools

All development-only, none required to play: Lua 5.1, `luacheck` (`.luacheckrc`), `lua-language-server`, and:

- `python3 tools/check-api.py --api-dir <Blizzard_APIDocumentationGenerated>` checks `C_` namespace functions, `Enum` fields, `RegisterEvent` names and global calls against Blizzard's published UI source (<https://github.com/Gethe/wow-ui-source>, match the client build, 12.1.5.70575 at time of writing).
- `python3 tools/check-types.py --wow-api <Annotations folder of Ketho/vscode-wow-api>` runs the language server with community WoW definitions. It is noisy (nil-check warnings) and the definitions may trail the build.
- `lua5.1 tools/verify-kit.lua` is the kit's mocked model test.
