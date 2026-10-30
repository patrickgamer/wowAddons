-- Intent (WOWA-28 plan): the developer-only recorder must be read-only, store no names, expose
-- Party Sync changes and private-note leaks, and its report reader must catch them. This loads the real
-- Kit.lua against a mocked client and runs the real tools/kit-report.lua on the SavedVariables it writes.
-- It models code paths only; it is not proof the kit works in WoW.
local report = dofile("tools/kit-report.lua")
local touched = {}
local function tripwire(label) return function() touched[#touched + 1] = label; error("kit touched " .. label, 2) end end

local function newClient(opts)
    opts = opts or {}
    local env = {state = {exists = false, joined = false}, scripts = {}, sent = {}, secret = {}, printed = {}}
    local sessionApi = {Exists = function() return env.state.exists end, HasJoined = function() return env.state.joined end}
    if opts.hostileSession then
        for _, f in ipairs({"RequestSessionStart", "RequestSessionStop", "SendSessionBeginResponse", "SetQuestIsSuperTracked"}) do sessionApi[f] = tripwire(f) end
    end
    local clock = 1000
    local G = setmetatable({
        print = function(text) env.printed[#env.printed + 1] = text end,
        GetServerTime = function() clock = clock + 5; return clock end,
        GetBuildInfo = function() return "12.1.5", "70575", "Jan 1 2026", 120105 end,
        IsInRaid = function() return false end, IsInGroup = function() return env.grouped and true or false end,
        InCombatLockdown = function() return env.combat and true or false end,
        issecretvalue = function(v) return env.secret[v] == true end,
        C_QuestSession = sessionApi,
        C_ChatInfo = {SendAddonMessage = function(prefix, text) env.sent[#env.sent + 1] = prefix; return 0 end,
            SendChatMessage = tripwire("SendChatMessage")},
        C_AddOns = {GetNumAddOns = function() return 3 end,
            GetAddOnInfo = function(i) return ({"DuoBags", "Blizzard_Foo", "DuoAdventure"})[i] end,
            IsAddOnLoaded = function(n) return n ~= "Blizzard_Foo" end,
            GetAddOnMetadata = function() return "0.3.0" end},
        hooksecurefunc = function(tbl, name, hook)
            local original = tbl[name]
            tbl[name] = function(...) local r = original(...); hook(...); return r end
        end,
        CreateFrame = function() return {RegisterEvent = function() end, SetScript = function(f, _, fn) env.onEvent = fn end} end,
        SlashCmdList = {}, string = string, table = table, type = type, tostring = tostring, pairs = pairs, ipairs = ipairs,
    }, {__index = function(_, k) if k == "DuoTestKitDB" or k == "Screenshot" or k == "C_QuestSession" then return nil end error("kit read an unmocked global " .. tostring(k), 2) end})
    G._G = G
    env.G = G
    local chunk = assert(loadfile("devkit/DuoTestKit/Kit.lua"))
    setfenv(chunk, G)
    chunk("DuoTestKit", {})
    env.event = function(name, ...) env.onEvent(nil, name, ...) end
    env.slash = function(text) G.SlashCmdList.DUOTESTKIT(text) end
    G.Screenshot = nil
    return env
end

local function serialise(value, indent)
    if type(value) ~= "table" then return type(value) == "string" and string.format("%q", value) or tostring(value) end
    local parts = {}
    for k, v in pairs(value) do parts[#parts + 1] = "[" .. serialise(k) .. "]=" .. serialise(v) end
    return "{" .. table.concat(parts, ",") .. "}"
end
local function save(env, path)
    local f = assert(io.open(path, "w")); f:write("DuoTestKitDB = " .. serialise(env.G.DuoTestKitDB) .. "\n"); f:close()
end

local function boot(opts)
    local env = newClient(opts)
    env.event("ADDON_LOADED", "SomeOtherAddon"); assert(env.G.DuoTestKitDB == nil, "kit initialised for another addon")
    env.event("ADDON_LOADED", "DuoTestKit")
    env.event("PLAYER_LOGIN")
    return env
end

-- 1. A clean journey: Party Sync never changes except in a captain-flagged step; packets are counted by prefix only.
local env = boot({hostileSession = true})
local run = env.G.DuoTestKitDB.run
assert(run.version == "12.1.5" and run.interface == 120105 and #run.addons == 2, "build and Duo addons recorded, Blizzard addons skipped")
env.slash("begin quest-share"); env.grouped = true
env.event("CHAT_MSG_ADDON", "DuoAdventureV2", "payload", "PARTY", "Someone-Realm")
env.event("CHAT_MSG_ADDON", "OtherAddon", "payload", "PARTY", "Someone-Realm")
env.G.C_ChatInfo.SendAddonMessage("DuoAdventureV2", "x", "PARTY")
env.slash("end pass")
env.slash("begin start-sync sync"); env.state.exists, env.state.joined = true, true; env.slash("end pass")
env.event("ADDON_ACTION_BLOCKED", "DuoSupport", "CastSpellByID")
local steps = env.G.DuoTestKitDB.run.steps
assert(#steps == 2 and steps[1].after.counters.packetsReceived == 1 and steps[1].after.counters.packetsSent == 1, "only the watched prefix is counted")
assert(steps[1].after.partySync.exists == false and steps[2].after.partySync.joined == true)
assert(env.G.DuoTestKitDB.run.blocked["blocked:DuoSupport:CastSpellByID"] == 1, "blocked action recorded")
assert(#touched == 0, "kit touched native Party Sync or chat: " .. table.concat(touched, ","))
local dir = os.getenv("TMPDIR") or "/tmp"
local pathA = dir .. "/dtk-verify-a.lua"; save(env, pathA)
local lines, problems = report.analyse(env.G.DuoTestKitDB)
assert(#problems == 0, "clean journey reported problems: " .. table.concat(problems, "; "))

-- 2. Secret or missing answers read as unknown, never as "not active".
env.secret[true] = true
assert(env.G.C_QuestSession.Exists() == true)
env.slash("begin secret"); env.slash("end pass")
local last = env.G.DuoTestKitDB.run.steps[3]
assert(last.before.partySync.exists == "unknown" and last.before.partySync.joined == "unknown", "secret answer must read unknown")
env.G.C_QuestSession = nil
env.slash("begin missing"); env.slash("end pass")
assert(env.G.DuoTestKitDB.run.steps[4].before.partySync.exists == "unknown", "missing API must read unknown")

-- 3. Planted defects the reader must catch.
local function expect(label, mutate, needle)
    local e = boot(); e.slash("begin s"); mutate(e); e.slash("end pass")
    local _, probs = report.analyse(e.G.DuoTestKitDB)
    for _, p in ipairs(probs) do if p:find(needle, 1, true) then return end end
    error("planted defect not caught: " .. label .. " (" .. table.concat(probs, "; ") .. ")")
end
expect("unflagged Party Sync change", function(e) e.state.joined = true end, "Party Sync changed")
expect("private-note canary on the wire", function(e) e.event("CHAT_MSG_ADDON", "DuoAdventureV2", "note DTK-CANARY-PRIVATE-NOTE", "PARTY", "x") end, "canary")
local leak = boot(); leak.G.DuoTestKitDB.run.addons[1].version = "Jane-Doe"
local _, leakProblems = report.analyse(leak.G.DuoTestKitDB)
assert(#leakProblems > 0, "stored name-like text not caught")
local failing = boot(); failing.slash("begin f"); failing.slash("end fail")
local _, failProblems = report.analyse(failing.G.DuoTestKitDB); assert(#failProblems == 1)

-- 4. Kit-only versus all-five comparison catches a differing Party Sync outcome.
local a, b = boot(), boot()
for _, e in ipairs({a, b}) do e.slash("begin x sync") end
a.state.joined = true
a.slash("end pass"); b.slash("end pass")
assert(#report.compare(a.G.DuoTestKitDB, b.G.DuoTestKitDB) == 1, "A/B Party Sync difference not caught")
assert(#report.compare(a.G.DuoTestKitDB, a.G.DuoTestKitDB) == 0)
os.remove(pathA)
print("PASS: kit records build, Duo addon versions, read-only Party Sync, watched-prefix counts and blocked actions; unknown never reads as inactive; no native/chat calls; reader catches unflagged change, canary, stored names, failed steps and A/B differences.")
