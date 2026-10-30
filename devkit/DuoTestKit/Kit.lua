-- Developer-only, read-only recorder. It never casts, targets, invites, sends messages, answers dialogs
-- or touches WoW's native Party Sync (C_QuestSession is only read). It stores no character, realm,
-- guild or message text: only counts, booleans, versions and the step names the tester types.
local _, NS = ...
local CANARY = "DTK-CANARY-PRIVATE-NOTE" -- type this as a private DuoSocial note; it must never cross the wire
local WATCHED_PREFIX = "DuoAdventureV2"
local db
local counters = {packetsReceived = 0, packetsSent = 0, canaryLeaks = 0, secretPackets = 0}
local blocked = {}
local current

local function printf(text) print("|cff66ccffDuoTestKit|r " .. text) end

-- Returns true, false or "unknown"; secret, missing or non-boolean answers are never read as false.
local function readBoolean(fn)
    if type(fn) ~= "function" then return "unknown" end
    local value = fn()
    if issecretvalue and issecretvalue(value) then return "unknown" end
    if type(value) ~= "boolean" then return "unknown" end
    return value
end

function NS.PartySyncState()
    local api = type(C_QuestSession) == "table" and C_QuestSession or nil
    if not api then return {exists = "unknown", joined = "unknown"} end
    return {exists = readBoolean(api.Exists), joined = readBoolean(api.HasJoined)}
end

local function groupKind()
    if IsInRaid() then return "raid" end
    if IsInGroup() then return "party" end
    return "solo"
end

local function copy(source)
    local result = {}
    for key, value in pairs(source) do result[key] = value end
    return result
end

function NS.Snapshot()
    return {time = GetServerTime(), partySync = NS.PartySyncState(), group = groupKind(),
        combat = InCombatLockdown() and true or false, counters = copy(counters)}
end

local function recordAddons()
    local list = {}
    for index = 1, C_AddOns.GetNumAddOns() do
        local name = C_AddOns.GetAddOnInfo(index)
        if name and name:find("^Duo") then
            list[#list + 1] = {name = name, loaded = C_AddOns.IsAddOnLoaded(name) and true or false,
                version = C_AddOns.GetAddOnMetadata(name, "Version") or "?"}
        end
    end
    return list
end

local function startRun()
    local version, build, _, interface = GetBuildInfo()
    db.run = {version = version, build = build, interface = interface, addons = recordAddons(), steps = {},
        started = GetServerTime()}
end

-- ADDON_ACTION_BLOCKED / FORBIDDEN: which addon tried which protected function while locked down.
function NS.OnBlocked(kind, addon, func)
    local key = kind .. ":" .. tostring(addon) .. ":" .. tostring(func)
    blocked[key] = (blocked[key] or 0) + 1
    if db and db.run then db.run.blocked = copy(blocked) end
end

function NS.OnAddonMessage(prefix, text)
    if prefix ~= WATCHED_PREFIX then return end
    counters.packetsReceived = counters.packetsReceived + 1
    if issecretvalue and issecretvalue(text) then
        counters.secretPackets = counters.secretPackets + 1
        return
    end
    if type(text) == "string" and text:find(CANARY, 1, true) then counters.canaryLeaks = counters.canaryLeaks + 1 end
end

function NS.OnAddonMessageSent(prefix)
    if prefix == WATCHED_PREFIX then counters.packetsSent = counters.packetsSent + 1 end
end

-- begin <id> [sync]: "sync" says the tester will start or stop Party Sync during this step.
function NS.Begin(id, flag)
    if not id or id == "" then return printf("usage: /dtk begin <step-id> [sync]") end
    current = {id = id, captainSync = flag == "sync", before = NS.Snapshot()}
    printf("step " .. id .. " started" .. (current.captainSync and " (Party Sync change expected)" or ""))
end

function NS.End(result)
    if not current then return printf("no step is open") end
    if result ~= "pass" and result ~= "fail" and result ~= "skip" then return printf("usage: /dtk end pass|fail|skip") end
    current.after, current.result = NS.Snapshot(), result
    table.insert(db.run.steps, current)
    printf("step " .. current.id .. " recorded: " .. result)
    current = nil
end

function NS.Status()
    local s = NS.Snapshot()
    printf(("Party Sync exists=%s joined=%s | %s | packets in=%d out=%d canary=%d secret=%d | steps=%d"):format(
        tostring(s.partySync.exists), tostring(s.partySync.joined), s.group, counters.packetsReceived,
        counters.packetsSent, counters.canaryLeaks, counters.secretPackets, db.run and #db.run.steps or 0))
end

function NS.Command(input)
    local word, a, b = (input or ""):match("^%s*(%S*)%s*(%S*)%s*(%S*)")
    word = word:lower()
    if word == "begin" then NS.Begin(a, b)
    elseif word == "end" then NS.End(a)
    elseif word == "status" or word == "" then NS.Status()
    elseif word == "shot" then
        if type(Screenshot) == "function" then Screenshot() else printf("Screenshot is unavailable; use the system screenshot key") end
    elseif word == "reset" then
        DuoTestKitDB = {}; db = DuoTestKitDB; db.schema = 1; counters.packetsReceived, counters.packetsSent = 0, 0
        counters.canaryLeaks, counters.secretPackets = 0, 0; blocked, current = {}, nil; startRun(); printf("recording reset")
    else printf("/dtk begin <id> [sync] | end pass|fail|skip | status | shot | reset") end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("CHAT_MSG_ADDON")
frame:RegisterEvent("ADDON_ACTION_BLOCKED")
frame:RegisterEvent("ADDON_ACTION_FORBIDDEN")
frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        if ... ~= "DuoTestKit" then return end
        DuoTestKitDB = DuoTestKitDB or {}
        db = DuoTestKitDB
        db.schema = db.schema or 1
    elseif event == "PLAYER_LOGIN" then
        startRun()
        hooksecurefunc(C_ChatInfo, "SendAddonMessage", NS.OnAddonMessageSent)
        printf("recording; /dtk begin <id> to start a step")
    elseif event == "CHAT_MSG_ADDON" then NS.OnAddonMessage(...)
    elseif event == "ADDON_ACTION_BLOCKED" then NS.OnBlocked("blocked", ...)
    else NS.OnBlocked("forbidden", ...) end
end)
SLASH_DUOTESTKIT1 = "/dtk"
SlashCmdList.DUOTESTKIT = NS.Command
