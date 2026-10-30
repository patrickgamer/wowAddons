# Run sheet 1: single client, all five addons

Setup: DuoTestKit and the five addons enabled; fresh test character (Evoker or Demon Hunter); no personal characters. Type `/dtk status` first and note the build.

| Step id | Do | Expect | Record |
|---|---|---|---|
| `build` | `/dtk begin build`, read the line printed at login, `/dtk end pass` | Interface 120105, five `Duo*` addons loaded | `/dtk end fail` if any is missing |
| `lua-errors` | Play 5 minutes with Lua errors shown (`/console scriptErrors 1`) | No errors from any Duo addon | fail on any error |
| `spells` | Open DuoSupport; compare listed spells to the spellbook | Only known spells; no level gate | pass/fail |
| `bags` | Open DuoBags with a full bag and an uncached item | Preview only; keep-listed items protected; nothing sold without a click | pass/fail |
| `ui-combat` | Enter and leave combat with DuoUI visible | Bars update; no taint message; no `blocked:` entries from Duo addons | `/dtk end` then read report |
| `social-solo` | DuoSocial with no guild or group | Clear empty states | pass/fail |
| `canary` | Add a private note containing `DTK-CANARY-PRIVATE-NOTE` | Stays local | checked in sheet 2 |

Afterwards: log out, then `lua5.1 tools/kit-report.lua <DuoTestKit.lua>`. Windows and macOS runs are separate recordings; label each by OS only.
