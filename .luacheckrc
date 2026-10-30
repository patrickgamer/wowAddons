-- Development only (not loaded by WoW). Undefined-global reads are disabled because WoW's API is checked
-- by tools/check-api.py against Blizzard's own documentation instead.
std = "lua51"
max_line_length = false
codes = true
ignore = { "113", "212/self", "213" }
globals = { "SlashCmdList", "DuoBagsDB", "DuoUIDB", "DuoSupportDB", "DuoSocialDB", "DuoAdventureDB", "DuoTestKitDB",
    "SLASH_DUOBAGS1", "SLASH_DUOUI1", "SLASH_DUOSUPPORT1", "SLASH_DUOSOCIAL1", "SLASH_DUOADVENTURE1", "SLASH_DUOTESTKIT1", "DuoSocialAPI" }
