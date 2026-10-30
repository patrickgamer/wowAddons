# Run sheet 2: two clients, sharing and Party Sync

Setup: two clients (one per Mac), the invitee on the free account (it can join but not create parties). Both enable the kit. Only the person playing starts or stops Party Sync, and only in steps flagged `sync`. No addon does this.

| Step id | Do | Expect |
|---|---|---|
| `invite` | Leader invites the other character by hand; both `/dtk begin invite` and `/dtk end pass` | Group forms; DuoAdventure shows the join prompt |
| `consent` | Accept progress sharing on both | Counters in `/dtk status` rise on both; Party Sync unchanged |
| `share` | Accept a quest on one client; `/dtk begin share` ... `end` | The other client's DuoAdventure lists it as planned; packets in/out both rise |
| `canary` | Private DuoSocial note `DTK-CANARY-PRIVATE-NOTE` on one client | `canaryLeaks` stays 0 on both |
| `native-start` | `/dtk begin native-start sync`; the leader starts Party Sync using Blizzard's own UI; `/dtk end pass` | Addon shows the native-active notice once; held quests listed separately from addon progress |
| `native-stop` | `/dtk begin native-stop sync`; stop it by hand | Notice clears; addon did not answer any prompt |
| `leave` | Leave the group | Sharing stops; renewed consent needed on rejoin |

Party Sync A/B: do the whole journey once with only DuoTestKit enabled (save that recording), then again with all five addons. Compare: `lua5.1 tools/kit-report.lua <kit-only.lua> <all-five.lua>`. It must report no Party Sync difference, and the held quests you read off Blizzard's own quest log must match by hand. If Party Sync will not start for the free or low-level character, record the step as `skip` and say why; that is a finding, not a pass.
