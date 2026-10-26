local addon, NS = ...
local db, panel, search, nativeSeen
local nativeTriggers = {PLAYER_ENTERING_WORLD = true, GROUP_ROSTER_UPDATE = true}
local function accessible(value) return not issecretvalue or not issecretvalue(value) end
local function quests()
    local rows = {}
    if not C_QuestLog or not C_QuestLog.GetInfo or not C_QuestLog.GetNumQuestLogEntries then return rows end
    local zone = "Other quests"
    for index = 1, C_QuestLog.GetNumQuestLogEntries() do
        local info = C_QuestLog.GetInfo(index)
        if info and accessible(info) and (not canaccesstable or canaccesstable(info)) then
            if info.isHeader then zone = info.title or "Other quests"
            elseif info.questID and info.questID > 0 and not info.isHidden then
                local distance
                if C_QuestLog.GetDistanceSqToQuest then
                    local d, continent = C_QuestLog.GetDistanceSqToQuest(info.questID)
                    if accessible(d) and accessible(continent) and continent and type(d) == "number" then distance = d end
                end
                local completed = C_QuestLog.IsComplete and C_QuestLog.IsComplete(info.questID)
                if accessible(completed) then
                    rows[#rows + 1] = {id = info.questID, title = info.title or "Loading quest", index = index,
                        zone = zone, complete = not not completed, distance = distance, story = info.isStory or info.campaignID ~= nil}
                end
            end
        end
    end
    return rows
end
local function findQuest(id)
    for _, quest in ipairs(quests()) do if quest.id == id then return quest end end
end
local function snapshot()
    local rows = quests()
    for _, row in ipairs(rows) do
        row.done, row.total = 0, 0
        local progress = {}
        local objectives = C_QuestLog.GetQuestObjectives and C_QuestLog.GetQuestObjectives(row.id)
        if objectives and accessible(objectives) and (not canaccesstable or canaccesstable(objectives)) then
            for _, objective in ipairs(objectives) do
                if accessible(objective.finished) and row.total < 64 then
                    row.total = row.total + 1; if objective.finished then row.done = row.done + 1 end
                    local fulfilled, required = objective.numFulfilled, objective.numRequired
                    if #progress < 6 and accessible(fulfilled) and accessible(required) and type(fulfilled) == "number" and type(required) == "number"
                        and fulfilled >= 0 and required >= 0 and fulfilled <= 1000000 and required <= 1000000 then
                        progress[#progress + 1] = string.format("%.2f/%.2f;", fulfilled, required)
                    end
                end
            end
        end
        row.progress = table.concat(progress)
    end
    return rows
end
local function sharedWith(id, complete)
    if IsInRaid() then return "Quest overlap: use native party/quest tools in raids." end
    if not IsInGroup() then return "Solo" end
    if not C_QuestLog.IsUnitOnQuest then return "Party quest overlap unavailable" end
    local members, missing, unknown = {}, {}, {}
    local reports, catchingUp, waiting = {}, {}, {}
    for i = 1, GetNumSubgroupMembers() do
        local unit = "party" .. i
        local name = NS.FullName(unit) or unit
        local report, age = NS.PeerQuest(name, id)
        if report then
            reports[#reports + 1] = name .. ": " .. (report.complete and "ready to turn in" or "not complete") .. (report.total > 0 and ("; objectives " .. report.done .. "/" .. report.total) or "; objective data unavailable") .. ((report.progress and report.progress ~= "") and ("; progress " .. report.progress) or "") .. " (received " .. age .. "s ago)"
            if complete and not report.complete then catchingUp[#catchingUp + 1] = name end
            if not complete and report.complete then waiting[#waiting + 1] = name end
        end
        if UnitIsConnected(unit) then
            local onQuest = C_QuestLog.IsUnitOnQuest(unit, id)
            if not accessible(onQuest) then unknown[#unknown + 1] = name
            elseif onQuest then members[#members + 1] = name
            else missing[#missing + 1] = name end
        else unknown[#unknown + 1] = name end
    end
    local text = #members > 0 and ("Also on quest: " .. table.concat(members, ", ")) or "No confirmed party overlap"
    if #reports > 0 then text = text .. "\nAddon-reported progress: " .. table.concat(reports, "; ") end
    if #catchingUp > 0 then text = text .. "\nCatch-up suggestion: " .. table.concat(catchingUp, ", ") .. " reported incomplete objectives. Confirm the snapshot is current and help finish together before your turn-in if you want to stay in step." end
    if #waiting > 0 then text = text .. "\nCatch-up suggestion: " .. table.concat(waiting, ", ") .. " reported ready; agree whether they will wait while you finish your objectives." end
    if #unknown > 0 then text = text .. "\nUnknown/offline: " .. table.concat(unknown, ", ") end
    if #missing > 0 then
        local pushable = C_QuestLog.IsPushableQuest and C_QuestLog.IsPushableQuest(id)
        local advice
        if not accessible(pushable) or pushable == nil then advice = "Check the native Share button for availability."
        elseif pushable then advice = "Native sharing is available: open quest details, choose Share if your party member still needs this quest, and wait for acceptance."
        else advice = "Native sharing is unavailable: if needed, catch up via the quest giver or prerequisite chain shown in native quest tools." end
        text = text .. "\nNot reported on this quest: " .. table.concat(missing, ", ") .. ". They may already have finished or be ineligible. Ask/check together. " .. advice
        if complete then text = text .. "\nBEFORE YOUR TURN-IN: confirm whether they need the quest or objective catch-up; do not assume sharing gives objective credit." end
    elseif complete and #members > 0 then
        text = text .. "\nBEFORE YOUR TURN-IN: confirm the party's objectives are finished; same quest ID does not prove equal progress."
    end
    return text
end
local function refresh()
    if not db or not panel:IsShown() then return end
    if InCombatLockdown() then panel:Text("Quest planning pauses during combat; native quest UI remains available."); return end
    local rows = NS.OrderQuests(quests(), db.mode, db.pins, GetZoneText() or "")
    local lines = {"Mode: " .. (db.mode == "adventure" and "ADVENTURE / IMMERSION" or "GRINDING / SPEED LEVELLING"),
        NS.SyncStatus(),
        NS.NativeStatus(),
        db.mode == "adventure" and "Native log order, full objective text and story/campaign labels. Read narrative in the native quest window. No dialogue skipping or auto-accept/turn-in."
        or "Planning order: your ranked pins, completed quests, current-zone header, zone grouping, then available objective distance within a zone. This heuristic is not an optimal route or XP/hour recommendation.",
        "Focus: " .. (db.focus and (tostring(db.focus) .. " (your manual choice)") or "none; use /duoadventure focus ID"),
        "Search title, zone or ID. /duoadventure pin ID [rank] | note ID text | open ID | focus ID\nSocial plan copies the focus/mode into your LOCAL DuoSocial activity only."}
    local query = search:GetText():lower()
    local shown = 0
    for _, quest in ipairs(rows) do
        local haystack = (quest.title .. " " .. quest.zone .. " " .. quest.id):lower()
        if query == "" or haystack:find(query, 1, true) then
            shown = shown + 1
            local prefix = (db.pins[quest.id] and ("[pin " .. db.pins[quest.id] .. "] ") or "") .. (quest.complete and "[ready to turn in] " or "")
            lines[#lines + 1] = prefix .. quest.title .. " | " .. quest.zone .. " | ID " .. quest.id .. (quest.story and " | Story/campaign" or "")
            lines[#lines + 1] = sharedWith(quest.id, quest.complete)
            if db.mode == "adventure" and C_QuestLog.GetQuestObjectives then
                local objectives = C_QuestLog.GetQuestObjectives(quest.id)
                if objectives and accessible(objectives) and (not canaccesstable or canaccesstable(objectives)) then
                    for _, objective in ipairs(objectives) do
                        if accessible(objective.text) and accessible(objective.finished) then
                            lines[#lines + 1] = (objective.finished and "  [x] " or "  [ ] ") .. (objective.text or "Objective data pending")
                        end
                    end
                else lines[#lines + 1] = "Objective data pending; use native quest log." end
            end
            if db.notes[quest.id] then lines[#lines + 1] = "Private note: " .. db.notes[quest.id] end
        end
    end
    if shown == 0 then lines[#lines + 1] = "No matching exposed quest-log entries. Accept quests, clear search or expand collapsed headers in the native log; this is not a database of undiscovered quests." end
    lines[#lines + 1] = "\nParty overlap confirms only the same quest ID, not matching phases, eligibility, objective completion or shareability. Native quest sharing and dialogue remain manual. Progress sharing exchanges addon reports only; it is not WoW Party Sync and cannot start, stop, hold or release quests."
    panel:Text(table.concat(lines, "\n\n"))
end
local function socialPlan()
    if InCombatLockdown() then NS.Print("Set the session plan outside combat."); return end
    if not DuoSocialAPI or DuoSocialAPI.version ~= 1 then NS.Print("Enable DuoSocial to copy a local session plan; quest planning works independently."); return end
    local quest = db.focus and findQuest(db.focus)
    if db.focus and not quest then NS.Print("Focused quest is no longer in the exposed log; choose a current quest first."); return end
    if DuoSocialAPI.SetActivity("Questing: " .. db.mode .. (quest and (" | " .. quest.title .. " [" .. quest.id .. "] | Check sharing/catch-up before turn-in.") or " | agree a quest together")) then
        NS.Print("Copied to your local DuoSocial activity. Nothing was sent to another player.")
    end
end
-- Announce a native session once when WoW starts reporting it; DuoAdventure only reads this state.
local function watchNative()
    local state = NS.NativePartySync()
    if state == "unknown" or state:sub(1, 7) == "pending" then return end -- a lapsed vote is not a new session
    if state == "active" and nativeSeen ~= "active" then NS.Print(NS.NativeStatus(state)) end
    nativeSeen = state
end
local function command(message)
    local cmd, rest = NS.Words(message)
    if cmd == "" then NS.Toggle(panel); refresh(); return end
    if cmd == "native" then NS.Print(NS.NativeStatus()); return end
    if InCombatLockdown() then NS.Print("Configure quests outside combat."); return end
    if cmd == "mode" and (rest == "adventure" or rest == "immersion" or rest == "speed" or rest == "grinding") then
        db.mode = (rest == "speed" or rest == "grinding") and "speed" or "adventure"
    elseif cmd == "share" or cmd == "sync" then -- "sync" stays as the original progress-sharing command
        if rest == "on" then NS.SetSync(true) elseif rest == "off" then NS.SetSync(false) else NS.RequestSync() end
        return
    elseif cmd == "social" then socialPlan(); return
    elseif cmd == "unfocus" then db.focus = nil
    elseif cmd == "pin" or cmd == "note" or cmd == "unnote" or cmd == "focus" or cmd == "open" then
        local raw, text = rest:match("^(%d+)%s*(.*)$"); local id = tonumber(raw)
        if not id then NS.Print("Supply a numeric quest ID from the panel."); return end
        if cmd == "unnote" then db.notes[id] = nil
        elseif cmd == "pin" and db.pins[id] and text == "" then db.pins[id] = nil
        else
            if not findQuest(id) then NS.Print("That quest is not in the currently exposed quest log."); return end
            if cmd == "pin" then
                local rank = text ~= "" and tonumber(text) or 1
                if not rank or rank < 1 or rank > 999 or rank % 1 ~= 0 then NS.Print("Pin rank must be 1-999 (lower first)."); return end
                db.pins[id] = rank
            elseif cmd == "note" then db.notes[id] = text ~= "" and text or nil
            elseif cmd == "focus" then db.focus = id
            elseif cmd == "open" then
                if QuestMapFrame_OpenToQuestDetails then QuestMapFrame_OpenToQuestDetails(id)
                else NS.Print("Open the native quest log and select ID " .. id .. "; quest detail navigation is unavailable.") end
            end
        end
    else NS.Print("/duoadventure | mode adventure/speed | share on/off (progress sharing opt-in; sync on/off also works) | share (request progress; sync also works) | native (WoW Party Sync status, read-only) | pin ID [rank] | note ID text | unnote ID | focus ID | unfocus | open ID | social"); return end
    refresh()
end
local events = CreateFrame("Frame"); events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" then
        if name ~= addon then return end
        DuoAdventureDB = NS.Defaults(DuoAdventureDB or {}, {version = 1, mode = "adventure", pins = {}, notes = {}, sync = false}); db = DuoAdventureDB
        panel = NS.Panel("DuoAdventure - choose your questing pace", 740, 590)
        panel:SetHeight(math.min(590, UIParent:GetHeight() - 40))
        search = CreateFrame("EditBox", nil, panel, "InputBoxTemplate"); search:SetSize(230, 22); search:SetPoint("TOPLEFT", 18, -42); search:SetAutoFocus(false)
        search:SetScript("OnTextChanged", refresh); search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        NS.Button(panel, "Adventure", 270, -40, 110, function() command("mode adventure") end)
        NS.Button(panel, "Speed", 385, -40, 90, function() command("mode speed") end)
        NS.Button(panel, "Social plan", 480, -40, 110, socialPlan)
        NS.Button(panel, "Refresh", 595, -40, 100, refresh)
        NS.Button(panel, "Native quest log", 15, -72, 150, function()
            if InCombatLockdown() then NS.Print("Open the quest log outside combat.")
            elseif ToggleQuestLog then ToggleQuestLog() else NS.Print("Use your native Quest Log keybinding.") end
        end)
        NS.Button(panel, "Progress sharing on/off", 180, -72, 180, function() command("share " .. (db.sync and "off" or "on")) end)
        NS.Button(panel, "Request progress", 370, -72, 140, NS.RequestSync)
        NS.InitSync(db, snapshot, function() NS.Debounce(refresh) end)
        for _, e in ipairs({"QUEST_LOG_UPDATE", "QUEST_DATA_LOAD_RESULT", "GROUP_ROSTER_UPDATE", "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "PLAYER_ENTERING_WORLD"}) do events:RegisterEvent(e) end
        for _, e in ipairs(NS.NativeEvents) do
            nativeTriggers[e] = true
            if not C_EventUtils or not C_EventUtils.IsEventValid or C_EventUtils.IsEventValid(e) then events:RegisterEvent(e) end
        end
        SLASH_DUOADVENTURE1 = "/duoadventure"; SlashCmdList.DUOADVENTURE = command
    else
        if nativeTriggers[event] then watchNative() end
        NS.Debounce(refresh)
    end
end)
