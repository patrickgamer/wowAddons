# Run sheet 3: restricted combat

Addon messages are reported blocked during encounters, Mythic+ runs and PvP matches (12.0 notes; unverified here). Open-world success is not enough.

| Step id | Do | Expect |
|---|---|---|
| `open-world-combat` | Fight ordinary mobs in a group with sharing on | No Lua errors; no `blocked:`/`forbidden:` entries from Duo addons; progress catches up after combat |
| `boss-pull` | Pull one dungeon or world boss in the group | Sharing defers; `packetsSent` does not climb during the encounter; DuoUI health bars still draw (opaque values); nothing breaks after the encounter |
| `secret-values` | Watch DuoUI and DuoSupport during the pull | No comparison errors; `secretPackets` noted |
| `after` | Leave combat | Deferred work resumes once; Party Sync state unchanged |

Mythic+ and PvP lockdown are thorough-tier only. Record anything you could not reach as `skip`.
