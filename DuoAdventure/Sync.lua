local _, NS = ...
local PREFIX, LIMIT, TTL = "DuoAdventureV2", 200, 120
local db, snapshot, changed, registered
local peers, incoming, requests = {}, {}, {}
local outbox, pumping, sequence, pending, lastRequest = {}, false, 0, nil, -100
local consented, grouped, prompt, checkbox, stamp = false, false, nil, nil, ""
local dirty, scheduled, lastPush, lastSignature, awaiting = false, false, -100, nil, false
local broadcast, checkParty
local function public(v) return not issecretvalue or not issecretvalue(v) end
local function ready()
    return db and db.sync and consented and not InCombatLockdown() and IsInGroup() and not IsInRaid()
        and C_ChatInfo and C_ChatInfo.SendAddonMessage and registered
        and not (C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown())
        and not (C_ChatInfo.AreOutgoingAddonChatMessagesRestricted and C_ChatInfo.AreOutgoingAddonChatMessagesRestricted())
end
local function roster()
    local members = {}
    for i = 1, GetNumSubgroupMembers() do
        local name = NS.FullName("party" .. i)
        if name then members[name:lower()] = name end
    end
    return members
end
local function fingerprint()
    local names = {}; for name in pairs(roster()) do names[#names + 1] = name end
    table.sort(names); return table.concat(names, ";")
end
local function clear()
    peers, incoming, requests, outbox, pending = {}, {}, {}, {}, nil
end
function NS.ScheduleSync(force)
    dirty = true
    if force then lastSignature = nil end
    if scheduled then return end
    scheduled = true
    C_Timer.After(math.max(1, 3 - (GetTime() - lastPush)), function()
        scheduled = false
        if not ready() then return end -- latest public state is rebuilt after restrictions lift
        if #outbox > 0 or GetTime() - lastPush < 3 then return end
        broadcast()
    end)
end
local function sendNext()
    if #outbox == 0 then
        pumping = false
        if dirty then NS.ScheduleSync() end
        return
    end
    if not ready() then outbox = {}; pumping = false; dirty = true; return end
    local packet = table.remove(outbox, 1)
    if packet.roster ~= fingerprint() then outbox = {}; pumping = false; return end
    local result = C_ChatInfo.SendAddonMessage(PREFIX, packet.text, "PARTY")
    if Enum and Enum.SendAddonMessageResult and result ~= Enum.SendAddonMessageResult.Success then
        NS.Print("A progress report was rejected/throttled by the client. Try Request progress later.")
        outbox = {}; pumping = false; return
    end
    C_Timer.After(.25, sendNext) -- one paced outbox for broadcasts and request replies
end
local function queue(messages)
    if not ready() or #outbox + #messages > 256 then return false end
    local stamp = fingerprint()
    for _, text in ipairs(messages) do
        if #text > 240 then return false end
        outbox[#outbox + 1] = {text = text, roster = stamp}
    end
    if not pumping then pumping = true; sendNext() end
    return true
end
function NS.PeerQuest(name, id)
    local peer = peers[name:lower()]
    if not peer or GetTime() - peer.time > TTL then return nil end
    return peer.quests[id], math.floor(GetTime() - peer.time)
end
function NS.SyncStatus()
    local label = "Progress sharing (DuoAdventure addon reports, not WoW Party Sync): "
    if not db.sync or not consented then return label .. "OFF / awaiting this party's consent (use Progress sharing on/off)." end
    local count = 0; for _, peer in pairs(peers) do if GetTime() - peer.time <= TTL then count = count + 1 end end
    return label .. "ON | fresh party reports: " .. count .. " | quest changes + 30s refresh; combat/chat restrictions defer updates."
end
function NS.SetSync(enabled)
    if InCombatLockdown() then NS.Print("Change progress sharing consent outside combat."); return end
    db.sync = not not enabled; consented = not not enabled; awaiting = false; clear(); lastSignature = nil
    if prompt then prompt:Hide() end
    NS.Print(enabled and "Progress sharing enabled for this party, including joining members: quest IDs/completion/objective counts update on quest changes and every 30 seconds outside restrictions. Private notes stay local. These are DuoAdventure reports, not WoW Party Sync."
        or "Progress sharing disabled; transient party reports cleared. WoW Party Sync, if any, is unchanged.")
    if enabled then NS.ScheduleSync(true) end
    changed()
end
function NS.RequestSync()
    if not ready() then NS.Print("Requesting progress needs progress sharing on, an ordinary party, supported addon messaging and no combat/chat restrictions. Both players must turn it on."); return end
    if GetTime() - lastRequest < 10 then NS.Print("Wait 10 seconds between progress requests."); return end
    sequence = sequence + 1
    local guid = UnitGUID("player")
    if not public(guid) or not guid then return end
    local nonce = guid:match("(%w+)$") .. "." .. GetServerTime() .. "." .. sequence
    pending = {nonce = nonce, time = GetTime()}; incoming = {}; peers = {}; lastRequest = GetTime()
    if queue({"Q|" .. nonce}) then NS.Print("Requested opted-in party progress reports. No reply can mean disabled addon, restrictions, offline peer or packet loss.") end
    changed()
end
local function packets(nonce, rows)
    local count = math.min(#rows, LIMIT)
    local messages = {"B|" .. nonce .. "|" .. count}
    local chunk = {}
    for i = 1, count do
        local row = rows[i]
        local record = row.id .. ":" .. (row.complete and "1" or "0") .. ":" .. row.done .. ":" .. row.total .. ":" .. (row.progress or "")
        if #chunk > 0 and (#chunk == 8 or #("R|" .. nonce .. "|" .. table.concat(chunk, ",") .. "," .. record) > 240) then
            messages[#messages + 1] = "R|" .. nonce .. "|" .. table.concat(chunk, ","); chunk = {}
        end
        chunk[#chunk + 1] = record
    end
    if #chunk > 0 then messages[#messages + 1] = "R|" .. nonce .. "|" .. table.concat(chunk, ",") end
    messages[#messages + 1] = "E|" .. nonce
    return messages
end
local function reply(nonce) queue(packets(nonce, snapshot())) end
broadcast = function()
    local rows = snapshot()
    -- Canonical quest-ID ordering avoids broadcasts caused only by native header order changes.
    table.sort(rows, function(a,b) return a.id < b.id end)
    local signature = table.concat(packets("signature", rows), "\n")
    dirty = false
    if signature == lastSignature then return end
    sequence = sequence + 1
    local nonce = "A" .. GetServerTime() .. "." .. sequence
    if queue(packets(nonce, rows)) then lastSignature = signature; lastPush = GetTime() else dirty = true end
end
function NS.ReceiveSync(prefix, message, channel, sender)
    if not ready() or not public(prefix) or not public(message) or not public(channel) or not public(sender) then return end
    if prefix ~= PREFIX or channel ~= "PARTY" or type(message) ~= "string" or #message > 240 or type(sender) ~= "string" then return end
    local canonical = roster()[sender:lower()]
    if not canonical then return end -- sender must currently belong to this party; no whisper/guild/raid intake
    local kind, nonce, body = message:match("^([QBRE])|([%w%.]+)|?(.*)$")
    if not kind or #nonce > 64 then return end
    local key = canonical:lower()
    if kind == "Q" then
        if body ~= "" or (requests[key] and GetTime() - requests[key] < 10) then return end
        requests[key] = GetTime(); reply(nonce); return
    end
    local pushed = nonce:sub(1,1) == "A"
    if not pushed and (not pending or nonce ~= pending.nonce or GetTime() - pending.time > 90) then return end
    if kind == "B" then
        local count = tonumber(body)
        if not body:match("^%d+$") or count > LIMIT then return end
        if incoming[key] and (incoming[key].nonce == nonce or GetTime() - incoming[key].started < 3) then return end
        if pushed and peers[key] and GetTime() - peers[key].time < 3 then return end
        incoming[key] = {quests = {}, expected = count, count = 0, nonce = nonce, started = GetTime()}
    elseif kind == "R" then
        local state = incoming[key]
        if not state or state.nonce ~= nonce or body == "" then return end
        local records = 0
        for record in body:gmatch("[^,]+") do
            records = records + 1
            local id, complete, done, total, progress = record:match("^(%d+):([01]):(%d+):(%d+):([%d%./;]*)$")
            id, done, total = tonumber(id), tonumber(done), tonumber(total)
            if records > 8 or not id or id < 1 or id > 10000000 or total > 64 or done > total or state.quests[id] or state.count >= state.expected then incoming[key] = nil; return end
            local objectives = 0
            for fulfilled, required in progress:gmatch("([%d%.]+)/([%d%.]+);") do
                objectives = objectives + 1
                local f, r = tonumber(fulfilled), tonumber(required)
                if objectives > 6 or not f or not r or f < 0 or r < 0 or f > 1000000 or r > 1000000 then incoming[key] = nil; return end
            end
            local consumed = progress:gsub("[%d%.]+/[%d%.]+;", "")
            if consumed ~= "" then incoming[key] = nil; return end
            state.quests[id] = {complete = complete == "1", done = done, total = total, progress = progress}; state.count = state.count + 1
        end
    elseif kind == "E" then
        local state = incoming[key]
        if not state or state.nonce ~= nonce then return end
        if body ~= "" or state.count ~= state.expected then incoming[key] = nil; return end
        state.time = GetTime(); peers[key] = state; incoming[key] = nil; changed()
    end
end
function NS.InitSync(settings, readSnapshot, onChange)
    db, snapshot, changed = settings, readSnapshot, onChange
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix and C_ChatInfo.IsAddonMessagePrefixRegistered then
        C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
        registered = C_ChatInfo.IsAddonMessagePrefixRegistered(PREFIX)
    end
    prompt = NS.Panel("DuoAdventure - share quest progress", 540, 320)
    prompt:SetScript("OnHide", function() if not InCombatLockdown() then awaiting = false end end)
    checkbox = CreateFrame("CheckButton", nil, prompt, "UICheckButtonTemplate")
    checkbox:SetSize(26, 26); checkbox:SetPoint("TOPLEFT", 16, -40)
    local label = prompt:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("TOPLEFT", 48, -46); label:SetText("Share quest progress automatically with this party")
    NS.Button(prompt, "Apply toggle", 16, -75, 130, function() NS.SetSync(checkbox:GetChecked()) end)
    NS.Button(prompt, "Keep off", 160, -75, 100, function() NS.SetSync(false) end)
    local function promptText()
        local notice = NS.NativeNotice and NS.NativeNotice() or ""
        return "Opt in for this party, including members who join later. Sends quest IDs, completion and objective counts on changes and every 30s. Private notes stay local. Combat/chat restrictions defer updates. Close without applying to leave sharing off."
            .. "\n\nThese are DuoAdventure addon reports. They are not WoW Party Sync: this never starts, joins, answers or stops Party Sync and cannot put quests on hold."
            .. (notice ~= "" and ("\n\n" .. notice) or "")
    end
    prompt:Text(promptText())
    checkParty = function()
        if InCombatLockdown() then return end
        local inParty = IsInGroup() and not IsInRaid()
        local current = inParty and fingerprint() or ""
        if not inParty then
            if grouped then clear() end
            grouped, consented, stamp, awaiting = false, false, "", false; prompt:Hide(); return
        end
        if not grouped then
            clear(); consented = false; awaiting = true; checkbox:SetChecked(db.sync)
        elseif current ~= stamp then clear(); lastSignature = nil end
        if awaiting then prompt:Text(promptText()); prompt:Show() end
        local rosterChanged = current ~= stamp
        grouped, stamp = true, current
        if consented and rosterChanged then NS.ScheduleSync(true) end
    end
    local events = CreateFrame("Frame")
    for _, event in ipairs({"CHAT_MSG_ADDON", "GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "PLAYER_LEAVING_WORLD", "QUEST_LOG_UPDATE", "QUEST_ACCEPTED", "QUEST_REMOVED", "QUEST_TURNED_IN", "QUEST_WATCH_UPDATE", "QUEST_LOG_CRITERIA_UPDATE", "QUEST_DATA_LOAD_RESULT"}) do events:RegisterEvent(event) end
    events:SetScript("OnEvent", function(_, event, ...)
        if event == "CHAT_MSG_ADDON" then NS.ReceiveSync(...)
        elseif event == "PLAYER_LEAVING_WORLD" then clear(); grouped = false; consented = false
        elseif event == "PLAYER_REGEN_DISABLED" then clear(); dirty = true; prompt:Hide()
        elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_REGEN_ENABLED" then
            checkParty(); if consented and event ~= "GROUP_ROSTER_UPDATE" then NS.ScheduleSync(true) end
        else NS.ScheduleSync() end
    end)
    C_Timer.After(1, checkParty)
    if C_Timer.NewTicker then C_Timer.NewTicker(30, function()
        checkParty()
        if consented then NS.ScheduleSync(true) end
    end) end
end
