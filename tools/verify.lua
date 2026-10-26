-- Lua 5.1 syntax and focused mocked behavior checks. These do NOT prove WoW compatibility.
local names = {"DuoBags", "DuoUI", "DuoSupport", "DuoSocial", "DuoAdventure"}
local function runtimeFiles(name)
    local files = {}
    for line in io.lines(name .. "/" .. name .. ".toc") do
        if line:match("%.lua$") then files[#files + 1] = name .. "/" .. line end
    end
    return files
end
for _, name in ipairs(names) do
    for _, file in ipairs(runtimeFiles(name)) do assert(loadfile(file)) end
end
assert(loadfile("DuoBags/Rules.lua"))
local NS = {}
assert(loadfile("DuoBags/Rules.lua"))("DuoBags", NS)
local item = {id = 1, cached = true, quality = 0, price = 1}
local db = {keep = {}, partner = {}}
local legacy = NS.MigrateBagRules({version = 1, keep = {[9] = true}, legacyTags = {[7] = true}})
assert(legacy.version == 2 and legacy.keep[9] and legacy.partner[7] and legacy.legacyTags[7])
assert(NS.SaleEligible(item, db))
for _, key in ipairs({"locked", "quest", "hasLoot", "noValue", "equippable"}) do
    item[key] = true; assert(not NS.SaleEligible(item, db), key); item[key] = nil
end
item.cached = false; assert(not NS.SaleEligible(item, db)); item.cached = true
item.quality = 1; assert(not NS.SaleEligible(item, db)); item.quality = 0
item.price = 0; assert(not NS.SaleEligible(item, db)); item.price = 1
db.keep[1] = true; assert(not NS.SaleEligible(item, db)); db.keep[1] = nil
db.partner[1] = true; assert(not NS.SaleEligible(item, db)); db.partner[1] = nil
assert(NS.Matches("Herb [keep]", "KEEP")); assert(NS.Matches("100%", "%"))
assert(not NS.Matches("Herb", "ore")); assert(NS.Matches("Herb", ""))
function CopyTable(t) local r = {}; for k,v in pairs(t) do r[k] = type(v) == "table" and CopyTable(v) or v end; return r end
assert(loadfile("DuoBags/Common.lua"))("DuoBags", NS)
local saved = {version = 1, keep = {[7] = true}, extra = "preserve"}
NS.Defaults(saved, {version = 1, keep = {}, partner = {}})
assert(saved.keep[7] and saved.extra == "preserve" and saved.partner)
local a, b = {}, {}; NS.Defaults(a, {notes = {a = 1}}); NS.Defaults(b, {notes = {a = 1}})
a.notes.a = 2; assert(b.notes.a == 1)
assert(loadfile("DuoSupport/Classes.lua"))("DuoSupport", NS)
local migrated = NS.PrepareSupportDB({version = 1, partner = "Keep-Realm", priorities = {havoc = "custom priority"}, agreement = {havoc = "custom agreement"}, bindings = {[1] = "K"}})
assert(migrated.version == 2 and migrated.classPlans.EVOKER.priorities.havoc == "custom priority")
assert(migrated.classPlans.EVOKER.agreement.havoc == "custom agreement" and migrated.bindings[1] == "K" and migrated.partner == "Keep-Realm")
assert(migrated.classPlans.DEMONHUNTER.priorities.havoc ~= "custom priority")
local starter = NS.KnownEntries("EVOKER", function(id) return id == 361469 end)
assert(#starter == 1 and starter[1].id == 361469, "level-10 learned-only list")
local dh = NS.KnownEntries("DEMONHUNTER", function(id) return id == 183752 or id == 198589 end)
assert(#dh == 2 and dh[1].id == 198589 and dh[2].id == 183752)
assert(#NS.KnownEntries("WARRIOR", function() return true end) == 0)
assert(loadfile("DuoAdventure/Planner.lua"))("DuoAdventure", NS)
local log = {
    {id = 1, index = 1, zone = "B", complete = false, distance = 10},
    {id = 2, index = 2, zone = "A", complete = true},
    {id = 3, index = 3, zone = "A", complete = false, distance = 4},
    {id = 4, index = 4, zone = "A", complete = false, distance = 1},
}
local ordered = NS.OrderQuests(log, "speed", {[1] = 1}, "A")
assert(ordered[1].id == 1 and ordered[2].id == 2 and ordered[3].id == 4 and ordered[4].id == 3)
assert(NS.OrderQuests(log, "adventure", {}, "A")[1].id == 1 and log[1].id == 1)

-- Small frame model catches initialization, missing methods, event dispatch and combat deferral.
local combat, group = false, 1
local now, sends = 100, {}
function GetTime() return now end
function GetServerTime() return 10000 end
local playerClass, playerLevel = "EVOKER", 10
function UnitClass() return playerClass == "EVOKER" and "Evoker" or "Demon Hunter", playerClass end
function UnitLevel() return playerLevel end
function GetZoneText() return "Starter zone" end
local allFrames, timers = {}, {}
local methods = {}
function methods:SetScript(k, fn) self.scripts[k] = fn end
function methods:RegisterEvent(k) self.events[k] = true end
function methods:SetText(v) self.text = v; if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self) end end
function methods:GetText() return self.text or "" end
function methods:SetChecked(value) self.checked = value end
function methods:GetChecked() return self.checked end
function methods:GetStringHeight() return 100 end
function methods:GetHeight() return 1000 end
function methods:GetCenter() return 0, 0 end
function methods:GetScale() return 1 end
function methods:GetParent() return self.parent end
function methods:Show() self.visible = true; if self.scripts.OnShow then self.scripts.OnShow(self) end end
function methods:Hide() self.visible = false end
function methods:IsShown() return self.visible end
function methods:SetShown(v) if v then self:Show() else self:Hide() end end
function methods:SetAttribute(k,v) assert(not combat, "protected attribute in combat"); self.attributes[k] = v end
function methods:SetMinMaxValues(a,b) self.minimum = a; self.maximum = b end
function methods:SetValue(v) self.value = v end
local function noop() end
for _, method in ipairs({"SetSize", "SetPoint", "SetFrameStrata", "SetBackdrop", "SetBackdropColor", "SetBackdropBorderColor", "SetClampedToScreen", "SetMovable", "EnableMouse", "RegisterForDrag", "StartMoving", "StopMovingOrSizing", "SetWidth", "SetHeight", "SetScrollChild", "SetJustifyH", "SetJustifyV", "SetAllPoints", "SetAutoFocus", "ClearFocus", "ClearAllPoints", "SetScale", "SetFont", "SetStatusBarTexture", "SetStatusBarColor", "SetColorTexture", "RegisterForClicks"}) do methods[method] = noop end
function CreateFrame(kind, name, parent)
    local f = setmetatable({parent = parent, scripts = {}, events = {}, attributes = {}, visible = true, name = name}, {__index = methods})
    allFrames[#allFrames + 1] = f; return f
end
function methods:CreateFontString() return CreateFrame("FontString", nil, self) end
function methods:CreateTexture() return CreateFrame("Texture", nil, self) end
UIParent = CreateFrame("Frame"); STANDARD_TEXT_FONT = "font"
function InCombatLockdown() return combat end
function GetNormalizedRealmName() return "Realm" end
function IsInRaid() return false end
function IsInGroup() return group > 0 end
function GetNumSubgroupMembers() return group end
function UnitFullName(unit) if unit == "party1" or unit == "target" then return "Companion", "Realm" end; return "Player", "Realm" end
function UnitName(unit) return UnitFullName(unit) end
function UnitIsPlayer() return true end
function UnitInParty() return true end
function UnitIsUnit(a,b) return a == b end
function UnitIsGroupLeader() return false end
function UnitIsGroupAssistant() return false end
function UnitIsConnected() return true end
function UnitGroupRolesAssigned() return "DAMAGER" end
function UnitGUID() return "Player-1" end
local opaque = setmetatable({}, {__tostring = function() error("secret formatted") end, __lt = function() error("secret compared") end})
function UnitHealth() return opaque end
function UnitHealthMax() return opaque end
function IsModifiedClick() return false end
function IsInGuild() return false end
local cvar, sales, invitations = false, 0, 0
C_Timer = {After = function(_, fn) timers[#timers + 1] = fn end}
local function flush() local q = timers; timers = {}; for _,fn in ipairs(q) do fn() end end
C_CVar = {GetCVarBool = function() return cvar end, SetCVar = function(_, v) cvar = v == "1" end}
C_Item = {GetItemInfo = function() return "Grey item", "item:1", 0, 1, 1, "Junk", "Junk", 1, "", 1, 10 end, IsEquippableItem = function() return false end}
C_Container = {
    GetContainerNumSlots = function(b) return b == 0 and 1 or 0 end,
    GetContainerNumFreeSlots = function() return 0 end,
    GetContainerItemInfo = function() return {itemID = 1, hyperlink = "item:1", stackCount = 1} end,
    GetContainerItemQuestInfo = function() return {isQuestItem = false} end,
    UseContainerItem = function() sales = sales + 1 end,
}
local learned = {[361469] = true, [351338] = true}
C_SpellBook = {IsSpellKnown = function(id) return not not learned[id] end}
C_Spell = {GetSpellInfo = function(id) return {name = "Spell " .. id} end}
C_PartyInfo = {CanInvite = function() return true end, InviteUnit = function() invitations = invitations + 1 end}
C_ChatInfo = {
    RegisterAddonMessagePrefix = function() return 0 end,
    IsAddonMessagePrefixRegistered = function() return true end,
    InChatMessagingLockdown = function() return false end,
    AreOutgoingAddonChatMessagesRestricted = function() return false end,
    SendAddonMessage = function(prefix, payload, channel) sends[#sends + 1] = {prefix, payload, channel}; return 0 end,
}
C_QuestLog = {
    GetNumQuestLogEntries = function() return 3, 2 end,
    GetInfo = function(i)
        if i == 1 then return {isHeader = true, title = "Starter zone"} end
        return {questID = i, title = "Starter quest " .. i, isStory = i == 2}
    end,
    IsComplete = function(id) return id == 3 end,
    GetDistanceSqToQuest = function(id) return id * 10, true end,
    GetQuestObjectives = function() return {{text = "Read and explore", finished = false}} end,
    IsUnitOnQuest = function(_,id) return id == 2 end,
    IsPushableQuest = function() return true end,
}
MerchantFrame = CreateFrame("Frame"); MerchantFrame.selectedTab = 1
SlashCmdList = {}
local function event(name, ...)
    local frames = {}; for i,f in ipairs(allFrames) do frames[i] = f end
    for _, f in ipairs(frames) do if f.events[name] and f.scripts.OnEvent then f.scripts.OnEvent(f, name, ...) end end
    flush()
end
for _, name in ipairs(names) do
    local namespace = {}
    for _, file in ipairs(runtimeFiles(name)) do assert(loadfile(file))(name, namespace) end
    if name == "DuoAdventure" then NS.adventure = namespace end
    event("ADDON_LOADED", name)
end
event("PLAYER_LOGIN")
local actionButtons = {}
for _,f in ipairs(allFrames) do if type(f.name) == "string" and f.name:match("^DuoSupportAction") then actionButtons[#actionButtons + 1] = f end end
assert(#actionButtons == 6)
assert(actionButtons[1].attributes.type == nil, "grouped friendly action without partner must be disabled")
SlashCmdList.DUOBAGS("auto on"); assert(cvar)
SlashCmdList.DUOBAGS("preview")
local sell
for _,f in ipairs(allFrames) do if f.text == "Sell ONE" then sell = f end end
assert(sell); sell.scripts.OnClick(); assert(sales == 1)
sell.scripts.OnClick(); assert(sales == 1, "preview must be single use")
SlashCmdList.DUOBAGS("preview"); SlashCmdList.DUOBAGS("keep 1"); sell.scripts.OnClick(); assert(sales == 1)
SlashCmdList.DUOBAGS("keep 1"); SlashCmdList.DUOBAGS("preview"); event("BAG_UPDATE_DELAYED"); sell.scripts.OnClick(); assert(sales == 1)
SlashCmdList.DUOUI("partner Companion-Realm")
SlashCmdList.DUOSUPPORT("partner Companion-Realm")
SlashCmdList.DUOSUPPORT("setup")
assert(actionButtons[1].attributes.unit == "Companion-Realm" and actionButtons[1].attributes.spell == 361469)
assert(actionButtons[2].attributes.unit == "target" and actionButtons[2].attributes.spell == 351338)
SlashCmdList.DUOSOCIAL("")
SlashCmdList.DUOSOCIAL("note Companion-Realm private")
assert(DuoSocialDB.notes["Companion-Realm"] == "private")
SlashCmdList.DUOADVENTURE("")
SlashCmdList.DUOADVENTURE("mode speed"); assert(DuoAdventureDB.mode == "speed")
SlashCmdList.DUOADVENTURE("pin 2 1"); assert(DuoAdventureDB.pins[2] == 1)
SlashCmdList.DUOADVENTURE("focus 2"); SlashCmdList.DUOADVENTURE("social")
assert(DuoSocialDB.activity:find("Starter quest 2", 1, true))
assert(#sends == 0, "sync must default off and never send on startup")
SlashCmdList.DUOADVENTURE("sync on"); SlashCmdList.DUOADVENTURE("sync")
assert(#sends == 1 and sends[1][3] == "PARTY")
local nonce = sends[1][2]:match("^Q|(.+)$"); assert(nonce)
local adventure = NS.adventure
adventure.ReceiveSync("DuoAdventureV2", "B|" .. nonce .. "|1", "PARTY", "Stranger-Realm")
assert(not adventure.PeerQuest("Stranger-Realm", 2))
adventure.ReceiveSync("DuoAdventureV2", "B|" .. nonce .. "|1", "WHISPER", "Companion-Realm")
adventure.ReceiveSync("DuoAdventureV2", "R|" .. nonce .. "|3:0:0:1:", "PARTY", "Companion-Realm")
adventure.ReceiveSync("DuoAdventureV2", "E|" .. nonce, "PARTY", "Companion-Realm")
assert(not adventure.PeerQuest("Companion-Realm", 2), "wrong-channel begin must not assemble")
adventure.ReceiveSync("DuoAdventureV2", "B|" .. nonce .. "|1", "PARTY", "Companion-Realm")
adventure.ReceiveSync("DuoAdventureV2", "R|" .. nonce .. "|3:0:0:1:", "PARTY", "Companion-Realm")
adventure.ReceiveSync("DuoAdventureV2", "E|" .. nonce, "PARTY", "Companion-Realm")
assert(adventure.PeerQuest("Companion-Realm", 3).total == 1)
flush()
local catchup = false
for _, frame in ipairs(allFrames) do if type(frame.text) == "string" and frame.text:find("Catch-up suggestion:", 1, true) then catchup = true end end
assert(catchup, "peer incomplete snapshot should inform before-turn-in catch-up advice")
now = now + 121; assert(not adventure.PeerQuest("Companion-Realm", 3), "stale peer data must expire")
adventure.ReceiveSync("DuoAdventureV2", "Q|peer.1", "PARTY", "Companion-Realm")
for i = 1, 10 do flush() end
assert(#sends >= 4, "opted-in party requests should receive a snapshot")
for _, packet in ipairs(sends) do assert(#packet[2] <= 240 and packet[3] == "PARTY" and not packet[2]:find("private",1,true)) end
local before = #sends
adventure.ReceiveSync("DuoAdventureV2", "Q|peer.2", "PARTY", "Companion-Realm"); flush()
assert(#sends == before, "peer requests must be rate-limited")
SlashCmdList.DUOADVENTURE("sync off")
adventure.ReceiveSync("DuoAdventureV2", "Q|peer.3", "PARTY", "Companion-Realm"); flush()
assert(#sends == before, "disabled peers must not respond")
local activity = DuoSocialDB.activity
SlashCmdList.DUOADVENTURE("focus 3"); event("QUEST_LOG_UPDATE"); assert(DuoSocialDB.activity == activity, "social plan must not be copied automatically")
SlashCmdList.DUOSOCIAL("partner Different-Realm"); SlashCmdList.DUOSOCIAL("invite"); assert(invitations == 1)
combat = true; event("PLAYER_REGEN_DISABLED")
SlashCmdList.DUOADVENTURE("mode adventure"); assert(DuoAdventureDB.mode == "speed")
SlashCmdList.DUOUI("scale 1.2"); SlashCmdList.DUOSUPPORT("spec vengeance")
event("GROUP_ROSTER_UPDATE"); event("UNIT_HEALTH", "player")
SlashCmdList.DUOSOCIAL("invite"); assert(invitations == 1)
combat = false; event("PLAYER_REGEN_ENABLED")
assert(DuoUIDB.profiles.duo.scale == 1.2 and DuoSupportDB.spec == "vengeance")
group = 0; event("GROUP_ROSTER_UPDATE")
assert(actionButtons[1].attributes.unit == "player", "starter solo heal must work without partner")
playerClass = "DEMONHUNTER"; playerLevel = 8; learned = {[195072] = true}
event("PLAYER_SPECIALIZATION_CHANGED")
assert(actionButtons[1].attributes.spell == 195072 and actionButtons[1].attributes.unit == "player", "no minimum level gate on starting DH")
playerLevel = 70; learned = {[198589] = true, [183752] = true}
event("PLAYER_SPECIALIZATION_CHANGED"); event("PLAYER_LEVEL_UP")
assert(actionButtons[1].attributes.spell == 198589 and actionButtons[1].attributes.unit == "player")
assert(actionButtons[2].attributes.spell == 183752 and actionButtons[2].attributes.unit == "target")
assert(not actionButtons[3].visible, "unlearned DH abilities must be absent")
local socialAPI = DuoSocialAPI; DuoSocialAPI = nil; SlashCmdList.DUOADVENTURE("social"); DuoSocialAPI = socialAPI
event("GET_ITEM_INFO_RECEIVED"); event("GUILD_ROSTER_UPDATE")
-- Isolated addon environments: fresh DB, fresh slash registry, no other suite API.
for _, name in ipairs(names) do
    local environment = setmetatable({SlashCmdList = {}, DuoSocialAPI = false}, {__index = _G})
    environment[name .. "DB"] = false
    local namespace = {}; local first = #allFrames + 1
    for _, file in ipairs(runtimeFiles(name)) do
        local chunk = assert(loadfile(file)); setfenv(chunk, environment); chunk(name, namespace)
    end
    local listener = allFrames[first]
    assert(listener.events.ADDON_LOADED, name)
    listener.scripts.OnEvent(listener, "ADDON_LOADED", name)
    if listener.events.PLAYER_LOGIN then listener.scripts.OnEvent(listener, "PLAYER_LOGIN") end
    assert(type(rawget(environment, name .. "DB")) == "table", name)
    local command = environment.SlashCmdList[name:upper()]; assert(command, name)
    command(name == "DuoSupport" and "setup" or "")
end
dofile("tools/verify-sync.lua")
dofile("tools/verify-native.lua")
print("PASS: Lua 5.1 syntax; sale guards/filtering; migrations; five-addon combined/isolated startup; single-use sale consent; combat deferral; opaque health; starting-level solo Evoker/DH controls; quest ordering; local Social integration; opt-in party protocol validation/rate/expiry/privacy; native Party Sync untouched.")
