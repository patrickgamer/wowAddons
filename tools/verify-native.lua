-- Intent (captain, WOWA-18): "basically we need to ensure that we don't trigger the default/standard
-- hold functionality either directly or indirectly." Two full DuoAdventure clients (DuoSocial on one)
-- drive every addon entry point with WoW's native Party Sync first OFF, then already ACTIVE before any
-- addon action. Native session commands and confirmation answers are tripwires. This models addon code
-- paths only; it is not WoW's transport, Party Sync engine, quest holds or protected execution.
local clock, tasks = 0, {}
local function after(delay, fn) tasks[#tasks + 1] = {at = clock + delay, fn = fn} end
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
local touched = {}
local function tripwire(label) return function() touched[#touched + 1] = label; error("addon touched native " .. label, 2) end end
local function forbidden(label)
    return setmetatable({}, {__index = function(_, key) touched[#touched + 1] = label; error("addon touched " .. label .. "." .. tostring(key), 2) end})
end
local QuestSessionCommand = {None = 0, Start = 1, Stop = 2, SessionActiveNoCommand = 3}
local function session(active)
    local s = {exists = active, joined = active, pending = false, command = QuestSessionCommand.None}
    s.api = {Exists = function() return s.exists end, HasJoined = function() return s.joined end,
        HasPendingCommand = function() return s.pending end, GetPendingCommand = function() return s.command end,
        RequestSessionStart = tripwire("RequestSessionStart"), RequestSessionStop = tripwire("RequestSessionStop"),
        SendSessionBeginResponse = tripwire("SendSessionBeginResponse"), SetQuestIsSuperTracked = tripwire("SetQuestIsSuperTracked")}
    return s
end
local base = {string = string, table = table, math = math, type = type, pairs = pairs, ipairs = ipairs, tostring = tostring,
    tonumber = tonumber, select = select, next = next, error = error, assert = assert, setmetatable = setmetatable, unpack = unpack}
local function copy(t) local r = {}; for k, v in pairs(t) do r[k] = type(v) == "table" and copy(v) or v end; return r end
local clients = {}
-- Quest log rows follow C_QuestLog.GetInfo/GetQuestObjectives field names for the target build.
local function client(short, companion, s, saved, withSocial)
    local c = {short = short, full = short .. "-Realm", grouped = false, combat = false, frames = {}, panels = {}, prints = {},
        invites = 0, readyChecks = 0, opened = {}, logToggles = 0, saved = saved or {}, quests = {}, partyQuests = {}}
    local methods = {}
    function methods:SetScript(k, fn) self.scripts[k] = fn end
    function methods:RegisterEvent(k) self.events[k] = true end
    function methods:SetText(v) self.text = v; if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self) end end
    function methods:GetText() return self.text or "" end
    function methods:SetChecked(v) self.checked = v end
    function methods:GetChecked() return self.checked end
    function methods:Show() self.visible = true end
    function methods:Hide() self.visible = false; if self.scripts.OnHide then self.scripts.OnHide(self) end end
    function methods:IsShown() return self.visible end
    function methods:SetShown(v) if v then self:Show() else self:Hide() end end
    function methods:GetStringHeight() return 100 end
    function methods:GetHeight() return 1000 end
    function methods:CreateFontString() return methods.new("FontString", self) end
    for _, m in ipairs({"SetSize", "SetPoint", "SetFrameStrata", "SetBackdrop", "SetBackdropColor", "SetBackdropBorderColor", "SetClampedToScreen", "SetMovable", "EnableMouse", "RegisterForDrag", "StartMoving", "StopMovingOrSizing", "SetWidth", "SetHeight", "SetScrollChild", "SetJustifyH", "SetJustifyV", "SetAutoFocus", "ClearFocus"}) do methods[m] = function() end end
    function methods.new(kind, parent)
        local f = setmetatable({kind = kind, parent = parent, scripts = {}, events = {}, visible = true}, {__index = methods})
        c.frames[#c.frames + 1] = f; return f
    end
    local function unitName(unit)
        if unit == "player" then return short, "Realm" end
        if unit == "party1" and c.grouped then return companion, "Realm" end
    end
    local env = setmetatable({
        CreateFrame = function(kind, _, parent) return methods.new(kind, parent) end,
        UIParent = methods.new("Frame"), print = function(text) c.prints[#c.prints + 1] = text end, CopyTable = copy,
        InCombatLockdown = function() return c.combat end, IsInGroup = function() return c.grouped end, IsInRaid = function() return false end,
        GetNumSubgroupMembers = function() return c.grouped and 1 or 0 end, GetNumGroupMembers = function() return c.grouped and 2 or 0 end,
        UnitFullName = unitName, UnitName = unitName, GetNormalizedRealmName = function() return "Realm" end,
        UnitGUID = function() return "Player-1-" .. short end, UnitIsConnected = function() return true end,
        UnitIsGroupLeader = function(unit) return unit == "player" and withSocial end, UnitIsGroupAssistant = function() return false end,
        UnitGroupRolesAssigned = function() return "DAMAGER" end, IsInGuild = function() return false end, GetZoneText = function() return "Starter Isle" end,
        GetTime = function() return clock end, GetServerTime = function() return 50000 + math.floor(clock) end,
        C_Timer = {After = after, NewTicker = function(interval, fn) local tick; tick = function() fn(); after(interval, tick) end; after(interval, tick) end},
        C_EventUtils = {IsEventValid = function() return true end},
        Enum = {SendAddonMessageResult = {Success = 0}, QuestSessionCommand = QuestSessionCommand},
        C_QuestSession = s.api, QuestSessionManager = forbidden("QuestSessionManager"), StaticPopupDialogs = forbidden("StaticPopupDialogs"),
        StaticPopup_Show = tripwire("StaticPopup_Show"), StaticPopup_ShowCustomGenericConfirmation = tripwire("StaticPopup confirmation"),
        AcceptGroup = tripwire("AcceptGroup"), ConfirmBNRequestInviteFriend = tripwire("ConfirmBNRequestInviteFriend"),
        C_PartyInfo = {CanInvite = function() return true end, InviteUnit = function() c.invites = c.invites + 1 end,
            ConfirmInviteUnit = tripwire("ConfirmInviteUnit"), ConfirmRequestInviteFromUnit = tripwire("ConfirmRequestInviteFromUnit"),
            ConfirmInviteTravelPass = tripwire("ConfirmInviteTravelPass"), ConfirmLeaveParty = tripwire("ConfirmLeaveParty"),
            ConfirmConvertToRaid = tripwire("ConfirmConvertToRaid"), ConfirmReadyCheck = tripwire("ConfirmReadyCheck")},
        DoReadyCheck = function() c.readyChecks = c.readyChecks + 1 end,
        QuestMapFrame_OpenToQuestDetails = function(id) c.opened[#c.opened + 1] = id end,
        ToggleQuestLog = function() c.logToggles = c.logToggles + 1 end,
        C_ChatInfo = {RegisterAddonMessagePrefix = function() end, IsAddonMessagePrefixRegistered = function() return true end,
            InChatMessagingLockdown = function() return false end, AreOutgoingAddonChatMessagesRestricted = function() return false end,
            SendAddonMessage = function(prefix, text, channel)
                assert(c.grouped and not c.combat and channel == "PARTY")
                for _, other in ipairs(clients) do if other ~= c and other.grouped then other:event("CHAT_MSG_ADDON", prefix, text, channel, c.full) end end
                return 0
            end},
        C_QuestLog = {
            GetNumQuestLogEntries = function() return #c.quests + 1 end,
            GetInfo = function(i)
                if i == 1 then return {isHeader = true, title = "Starter Isle", questLogIndex = 1} end
                local q = c.quests[i - 1]; return q and {questID = q.id, title = q.title, questLogIndex = i, isHeader = false, isHidden = false}
            end,
            IsComplete = function() return false end,
            GetQuestObjectives = function(id) for _, q in ipairs(c.quests) do if q.id == id then return q.objectives end end end,
            IsUnitOnQuest = function(unit, id) return unit == "party1" and c.partyQuests[id] == true end,
            IsPushableQuest = function(id) for _, q in ipairs(c.quests) do if q.id == id then return q.shareable end end end,
        },
        SlashCmdList = {},
    }, {__index = base})
    c.env = env
    function c:event(name, ...)
        local frames = {}; for i, f in ipairs(self.frames) do frames[i] = f end
        for _, f in ipairs(frames) do if f.events[name] and f.scripts.OnEvent then f.scripts.OnEvent(f, name, ...) end end
    end
    function c:click(label)
        for _, f in ipairs(self.frames) do if f.kind == "Button" and f.text == label then f.scripts.OnClick(f); return end end
        error("no button " .. label)
    end
    function c:slash(addon, text) self.env.SlashCmdList[addon](text) end
    function c:printed(fragment) local n = 0; for _, p in ipairs(self.prints) do if p:find(fragment, 1, true) then n = n + 1 end end; return n end
    function c:load()
        local list = withSocial and {"DuoSocial", "DuoAdventure"} or {"DuoAdventure"}
        for _, addon in ipairs(list) do
            env[addon .. "DB"] = self.saved[addon]
            local ns = {}
            for line in io.lines(addon .. "/" .. addon .. ".toc") do
                if line:match("%.lua$") then
                    local chunk = assert(loadfile(addon .. "/" .. line)); setfenv(chunk, env); chunk(addon, ns)
                    if line == "Common.lua" then
                        local panel = ns.Panel
                        ns.Panel = function(title, ...) local f = panel(title, ...); self.panels[title] = f; return f end
                    end
                end
            end
            if addon == "DuoAdventure" then self.ns = ns end
            self:event("ADDON_LOADED", addon)
            self.saved[addon] = env[addon .. "DB"]
        end
        self:event("PLAYER_LOGIN"); self:event("PLAYER_ENTERING_WORLD")
    end
    function c:panelText(prefix) for title, f in pairs(self.panels) do if title:find(prefix, 1, true) then return f.body.text or "", f end end end
    clients[#clients + 1] = c
    return c
end
local function both(list, name, ...) for _, c in ipairs(list) do c:event(name, ...) end end
local CALLBACKS = {"INVITE_TO_PARTY_CONFIRMATION", "GROUP_INVITE_CONFIRMATION", "PARTY_INVITE_REQUEST", "READY_CHECK",
    "LEAVE_PARTY_CONFIRMATION", "CONVERT_TO_RAID_CONFIRMATION", "REQUEST_INVITE_CONFIRMATION", "BNET_REQUEST_INVITE_CONFIRMATION",
    "INVITE_TRAVEL_PASS_CONFIRMATION", "QUEST_SESSION_MEMBER_CONFIRM", "QUEST_SESSION_NOTIFICATION", "QUEST_SESSION_CREATED",
    "QUEST_SESSION_JOINED", "QUEST_SESSION_ENABLED_STATE_CHANGED"}

local function scenario(active)
    clock, tasks, clients, touched = 0, {}, {}, {}
    local s = session(active)
    local a = client("Player", "Companion", s, nil, true)
    local b = client("Companion", "Player", s, nil, false)
    a.quests = {{id = 80001, title = "Shared hunt", shareable = true, objectives = {{text = "Wolves slain: 3/10", numFulfilled = 3, numRequired = 10, finished = false}}},
        {id = 80002, title = "Personal errand", shareable = false, objectives = {{text = "Letter delivered: 0/1", numFulfilled = 0, numRequired = 1, finished = false}}}}
    b.quests = {{id = 80001, title = "Shared hunt", shareable = true, objectives = {{text = "Wolves slain: 5/10", numFulfilled = 5, numRequired = 10, finished = false}}}}
    a.partyQuests, b.partyQuests = {[80001] = true}, {[80001] = true, [80002] = true}
    a:load(); b:load(); advance(2)
    local notice = active and 1 or 0
    a:slash("DUOADVENTURE", "native")
    assert(a.prints[#a.prints]:find(active and "ACTIVE for you" or "not active, as reported by WoW", 1, true), "native status must reflect WoW's report")
    -- Party join: the addon prompt is explicitly not Party Sync and repeats the native warning when WoW reports a session.
    a.grouped, b.grouped = true, true; both(clients, "GROUP_ROSTER_UPDATE"); advance(2)
    local promptText, prompt = a:panelText("share quest progress")
    assert(prompt.visible and promptText:find("not WoW Party Sync", 1, true), "join prompt must separate addon sharing from Party Sync")
    assert((promptText:find("ACTIVE for you", 1, true) ~= nil) == active, "join prompt shows the native notice only when WoW reports it")
    -- Consent, legacy and new commands, both buttons, reports both ways including the unshareable quest.
    b:click("Keep off")
    for _, f in ipairs(a.frames) do if f.kind == "CheckButton" then f:SetChecked(true) end end
    a:click("Apply toggle"); b:slash("DUOADVENTURE", "sync on"); advance(5)
    assert(a.ns.PeerQuest("Companion-Realm", 80001).progress == "5.00/10.00;", "shared progress must still arrive")
    assert(b.ns.PeerQuest("Player-Realm", 80002), "an unshareable quest the companion lacks must still be reported")
    a.quests[1].objectives[1].numFulfilled = 4; a:event("QUEST_WATCH_UPDATE"); advance(5)
    assert(b.ns.PeerQuest("Player-Realm", 80001).progress == "4.00/10.00;", "event updates must still broadcast")
    a:click("Request progress"); advance(11); a:slash("DUOADVENTURE", "share"); advance(11); a:slash("DUOADVENTURE", "sync"); advance(5)
    b:click("Progress sharing on/off"); assert(not b.saved.DuoAdventure.sync); b:slash("DUOADVENTURE", "share on"); advance(5)
    assert(a.ns.PeerQuest("Companion-Realm", 80001), "re-enabled sharing must exchange again")
    -- Native quest navigation and DuoSocial actions happen only on explicit commands.
    a:slash("DUOADVENTURE", "open 80002"); a:click("Native quest log"); a:slash("DUOADVENTURE", "focus 80002"); a:click("Social plan")
    assert(a.opened[1] == 80002 and a.logToggles == 1 and a.saved.DuoSocial.activity:find("Personal errand", 1, true))
    a:slash("DUOSOCIAL", "partner Friend-Realm"); a:slash("DUOSOCIAL", "invite"); a:slash("DUOSOCIAL", "ready")
    -- Another member proposes a native start (or stop): every callback reaches registered addon frames
    -- while WoW reports the request, and none is answered. The request then lapses on WoW's side.
    s.pending, s.command = true, active and QuestSessionCommand.Stop or QuestSessionCommand.Start
    for _, name in ipairs(CALLBACKS) do both(clients, name, "Friend-Realm", false) end
    advance(2)
    a:slash("DUOADVENTURE", "native")
    assert(a.prints[#a.prints]:find(active and "stop request is pending" or "start request is pending", 1, true), "pending request is shown, not answered")
    s.pending, s.command = false, QuestSessionCommand.None
    -- Combat deferral, roster change with renewed consent, reload and the 30-second refresh.
    a.combat = true; a:event("PLAYER_REGEN_DISABLED"); a.quests[2].objectives[1].numFulfilled = 1; a:event("QUEST_WATCH_UPDATE"); advance(5)
    a.combat = false; a:event("PLAYER_REGEN_ENABLED"); advance(5)
    assert(b.ns.PeerQuest("Player-Realm", 80002).progress == "1.00/1.00;", "combat-deferred progress must recover")
    a.grouped, b.grouped = false, false; both(clients, "GROUP_ROSTER_UPDATE"); advance(2)
    a.grouped, b.grouped = true, true; both(clients, "GROUP_ROSTER_UPDATE"); advance(2)
    a:click("Apply toggle"); b:click("Apply toggle"); advance(5)
    a.grouped = false; for i, c in ipairs(clients) do if c == a then table.remove(clients, i) end end
    local reloaded = client("Player", "Companion", s, a.saved, true)
    reloaded.quests, reloaded.partyQuests, reloaded.grouped = a.quests, a.partyQuests, true
    reloaded.quests[3] = {id = 80003, title = "Second errand", shareable = false, objectives = {{text = "Crates found: 0/4", numFulfilled = 0, numRequired = 4, finished = false}}}
    reloaded:load(); advance(2); reloaded:click("Apply toggle"); advance(35)
    assert(b.ns.PeerQuest("Player-Realm", 80003), "reloaded client must report after renewed consent")
    -- Nothing touched the native session: OFF stays OFF, a pre-existing session is neither stopped nor re-answered.
    assert(#touched == 0, "native session or confirmation touched: " .. table.concat(touched, ","))
    assert(s.exists == active and s.joined == active, "native Party Sync state must be unchanged by addon actions")
    assert(a.invites == 1 and a.readyChecks == 1 and b.invites == 0, "invites/ready checks only from explicit commands")
    for _, c in ipairs({a, b, reloaded}) do assert(c:printed("ACTIVE for you") == notice + (c == a and notice or 0), c.full .. " notice count") end
    assert(a:printed("request is pending") == 1, "pending request appears only in the explicit status read")
    -- The planner keeps the unshareable quest and shows the two kinds of state on separate lines.
    reloaded:slash("DUOADVENTURE", ""); local text = reloaded:panelText("choose your questing pace")
    assert(text:find("Progress sharing (DuoAdventure addon reports, not WoW Party Sync): ON", 1, true), "addon sharing line")
    assert(text:find(active and "WoW Party Sync (native, read-only): ACTIVE for you" or "WoW Party Sync (native, read-only): not active", 1, true), "native line")
    assert(text:find("Personal errand", 1, true) and text:find("Native sharing is unavailable", 1, true), "unshareable quest stays planned")
    return s, reloaded, b
end

scenario(true)
local s, a, b = scenario(false)
-- Someone else starts Party Sync outside the addon: one notice, no addon response; ending it is WoW's job.
s.exists, s.joined = true, true; a:event("QUEST_SESSION_JOINED"); b:event("QUEST_SESSION_JOINED"); a:event("GROUP_ROSTER_UPDATE"); advance(2)
assert(a:printed("ACTIVE for you") == 1 and b:printed("ACTIVE for you") == 1, "independent native start gets one notice")
assert(a:panelText("choose your questing pace"):find("read-only): ACTIVE for you", 1, true), "open planner shows the native session")
s.exists, s.joined = false, false; a:event("QUEST_SESSION_LEFT"); advance(2)
assert(a:panelText("choose your questing pace"):find("read-only): not active", 1, true), "planner follows WoW ending the session")
assert(#touched == 0, "native session touched after independent start")

-- Status reading never infers inactive from missing, inaccessible or partial data.
local function status(api, secret)
    local ns, env = {}, setmetatable({C_QuestSession = api, Enum = {QuestSessionCommand = QuestSessionCommand},
        issecretvalue = secret and function(v) return v == secret end}, {__index = base})
    local chunk = assert(loadfile("DuoAdventure/Native.lua")); setfenv(chunk, env); chunk("DuoAdventure", ns)
    return ns.NativePartySync(), ns.NativeStatus()
end
local SECRET = {}
local function api(exists, joined, pending, command)
    return {Exists = exists ~= "missing" and function() return exists end or nil, HasJoined = function() return joined end,
        HasPendingCommand = pending ~= "missing" and function() return pending end or nil, GetPendingCommand = function() return command end}
end
local cases = {
    {nil, nil, "unknown"}, {api(false, false, "missing"), nil, "unknown"}, {api("missing", false, false), nil, "unknown"},
    {api(SECRET, false, false), SECRET, "unknown"}, {api(nil, nil, false), nil, "unknown"}, {api(false, false, false), nil, "inactive"},
    {api(true, false, false), nil, "exists"}, {api(true, true, false), nil, "active"},
    {api(false, false, true, QuestSessionCommand.Start), nil, "pending-start"}, {api(true, true, true, QuestSessionCommand.Stop), nil, "pending-stop"},
    {api(false, false, true, SECRET), SECRET, "pending"},
}
for i, case in ipairs(cases) do
    local state, text = status(case[1], case[2])
    assert(state == case[3], "native status case " .. i .. ": " .. state)
    assert((text:find("not active", 1, true) ~= nil) == (state == "inactive"), "only an explicit WoW report reads as not active")
end
print("PASS: native Party Sync untouched (off vs pre-existing active, consent, refresh, reports, navigation, invitations, callbacks, combat, roster, reload); separate status/notice; unknown never shown as inactive.")
