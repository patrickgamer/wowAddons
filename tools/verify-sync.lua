-- Deterministic two-client protocol model; not a substitute for WoW's native message transport.
local clock, tasks, peers, wire = 100, {}, {}, {}
local function after(delay, callback) tasks[#tasks + 1] = {at = clock + delay, fn = callback} end
local function advance(seconds)
    local stop = clock + seconds
    while true do
        local first
        for i, task in ipairs(tasks) do if task.at <= stop and (not first or task.at < tasks[first].at) then first = i end end
        if not first then break end
        local task = table.remove(tasks, first); clock = task.at; task.fn()
    end
    clock = stop
end
local function client(name, companion)
    local c = {name = name, companion = companion, grouped = false, combat = false, locked = false, rows = {}, buttons = {}, frames = {}, db = {sync = false}}
    local ns = {Print = function() end, FullName = function() return c.companion end}
    local function frame()
        local f = {scripts = {}, events = {}, visible = false}
        function f:SetScript(k,fn) self.scripts[k] = fn end
        function f:RegisterEvent(k) self.events[k] = true end
        function f:Show() self.visible = true end
        function f:Hide() self.visible = false; if self.scripts.OnHide then self.scripts.OnHide() end end
        function f:SetChecked(v) self.checked = v end
        function f:GetChecked() return self.checked end
        function f:SetSize() end; function f:SetPoint() end; function f:SetText() end; function f:Text() end
        function f:CreateFontString() return frame() end
        c.frames[#c.frames + 1] = f; return f
    end
    ns.Panel = function() c.prompt = frame(); return c.prompt end
    ns.Button = function(_, text, _, _, _, fn) c.buttons[text] = fn end
    local env = setmetatable({
        CreateFrame = function(kind)
            local f = frame(); if kind == "CheckButton" then c.checkbox = f end; return f
        end,
        InCombatLockdown = function() return c.combat end,
        IsInGroup = function() return c.grouped end, IsInRaid = function() return false end,
        GetNumSubgroupMembers = function() return c.grouped and 1 or 0 end,
        GetTime = function() return clock end, GetServerTime = function() return math.floor(clock) end,
        UnitGUID = function() return name end,
        C_Timer = {After = after, NewTicker = function(interval, fn)
            local tick; tick = function() fn(); after(interval, tick) end; after(interval, tick)
        end},
        Enum = {SendAddonMessageResult = {Success = 0}},
        C_ChatInfo = {
            RegisterAddonMessagePrefix = function() end, IsAddonMessagePrefixRegistered = function() return true end,
            InChatMessagingLockdown = function() return c.locked end,
            AreOutgoingAddonChatMessagesRestricted = function() return false end,
            SendAddonMessage = function(prefix, message, channel)
                assert(not c.combat and not c.locked and c.grouped)
                wire[#wire + 1] = {sender = name, text = message, channel = channel}
                for _, peer in ipairs(peers) do if peer ~= c then peer.ns.ReceiveSync(prefix, message, channel, name) end end
                return 0
            end,
        },
    }, {__index = _G})
    local chunk = assert(loadfile("DuoAdventure/Sync.lua")); setfenv(chunk, env); chunk("DuoAdventure", ns)
    ns.InitSync(c.db, function() return CopyTable(c.rows) end, function() c.updates = (c.updates or 0) + 1 end)
    function c:event(event)
        for _, f in ipairs(self.frames) do if f.events[event] then f.scripts.OnEvent(f, event) end end
    end
    c.ns = ns; peers[#peers + 1] = c; return c
end
local a, b = client("Alice-Realm", "Bob-Realm"), client("Bob-Realm", "Alice-Realm")
a.rows = {{id = 10, complete = false, done = 0, total = 1, progress = "1.00/10.00;"}}
b.rows = {{id = 10, complete = false, done = 0, total = 1, progress = "2.00/10.00;"}}
advance(1); assert(#wire == 0 and not a.prompt.visible)
a.grouped, b.grouped = true, true; a:event("GROUP_ROSTER_UPDATE"); b:event("GROUP_ROSTER_UPDATE")
assert(a.prompt.visible and b.prompt.visible and #wire == 0, "join must prompt without publishing")
-- The actual join toggle applies consent; declining does not publish.
b.buttons["Keep off"](); assert(not b.db.sync and #wire == 0)
a.checkbox:SetChecked(true); a.buttons["Apply toggle"](); b.ns.SetSync(true); advance(4)
assert(a.ns.PeerQuest("Bob-Realm", 10).progress == "2.00/10.00;")
assert(b.ns.PeerQuest("Alice-Realm", 10).progress == "1.00/10.00;")
local before = #wire
a.rows[1].progress = "3.00/10.00;"; a:event("QUEST_WATCH_UPDATE")
a.rows[1].progress = "4.00/10.00;"; a:event("QUEST_LOG_UPDATE"); advance(4)
assert(b.ns.PeerQuest("Alice-Realm", 10).progress == "4.00/10.00;", "incremental kill progress must broadcast before objective completion")
assert(#wire == before + 3, "burst should coalesce into one snapshot")
before = #wire; a:event("QUEST_LOG_UPDATE"); advance(4); assert(#wire == before, "unchanged log must not spam")
a.rows[2] = {id = 11, complete = false, done = 0, total = 0}; a:event("QUEST_ACCEPTED"); advance(4)
assert(b.ns.PeerQuest("Alice-Realm", 11))
a.rows[1].complete = true; a.rows[1].done = 1; a:event("QUEST_WATCH_UPDATE"); advance(4)
assert(b.ns.PeerQuest("Alice-Realm", 10).complete)
table.remove(a.rows, 1); a:event("QUEST_TURNED_IN"); advance(4); assert(not b.ns.PeerQuest("Alice-Realm", 10))
a.combat = true; a:event("PLAYER_REGEN_DISABLED"); before = #wire
a.rows[1].progress = "3.00/8.00;"; a:event("QUEST_WATCH_UPDATE"); advance(4); assert(#wire == before)
a.combat = false; a:event("PLAYER_REGEN_ENABLED"); advance(4)
assert(b.ns.PeerQuest("Alice-Realm", 11).progress == "3.00/8.00;")
a.locked = true; a.rows[1].progress = "4.00/8.00;"; a:event("QUEST_LOG_UPDATE"); advance(4)
a.locked = false; advance(35)
assert(b.ns.PeerQuest("Alice-Realm", 11).progress == "4.00/8.00;", "periodic refresh must recover from chat restrictions")
local _, age = b.ns.PeerQuest("Alice-Realm", 11); assert(age < 35, "periodic refresh must keep idle peers fresh")
a.ns.SetSync(false); before = #wire; a:event("QUEST_LOG_UPDATE"); advance(4)
for i = before + 1, #wire do assert(wire[i].sender ~= a.name) end
a.grouped = false; a:event("GROUP_ROSTER_UPDATE"); assert(not a.ns.PeerQuest("Bob-Realm",10))
a.db.sync = true; a.grouped = true; a:event("GROUP_ROSTER_UPDATE"); advance(4)
assert(a.prompt.visible and a.ns.SyncStatus():find("awaiting",1,true), "new party requires consent even with saved toggle on")
for _, packet in ipairs(wire) do assert(packet.channel == "PARTY" and #packet.text <= 240 and not packet.text:find("private",1,true)) end
print("PASS: two-peer automatic quest sync; join consent; incremental counts; debounce; accept/complete/turn-in; periodic refresh; restriction recovery; opt-out/rejoin/privacy.")
