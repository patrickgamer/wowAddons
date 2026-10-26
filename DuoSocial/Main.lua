local addon, NS = ...
local db, panel, search
local showOffline = false
local checks = {roles = false, activity = false, preparation = false}
local function safeAction(callback)
    if InCombatLockdown() then NS.Print("Use group actions outside combat."); return end
    callback()
end
local function invite()
    safeAction(function()
        if db.partner == "" then NS.Print("Set /duosocial partner Name-Realm first."); return end
        if NS.FindPartner(db.partner) then NS.Print("Partner is already in your group."); return end
        if not C_PartyInfo or not C_PartyInfo.InviteUnit or (IsInGroup() and (not C_PartyInfo.CanInvite or not C_PartyInfo.CanInvite())) then NS.Print("Invitation is unavailable or you lack permission."); return end
        C_PartyInfo.InviteUnit(db.partner) -- preserves Blizzard confirmation flow
    end)
end
local function ready()
    safeAction(function()
        if not IsInGroup() or not (UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")) then NS.Print("Ready check requires a group and leader/assistant permission."); return end
        if DoReadyCheck then DoReadyCheck() else NS.Print("Ready checks are unavailable.") end
    end)
end
local function refresh()
    if not db or not panel:IsShown() then return end
    if InCombatLockdown() then panel:Text("Roster paused during combat. Reopens with current data afterward.\nUse Blizzard's native group frames in combat."); return end
    local query = search:GetText()
    local lines = {"Partner: " .. (db.partner ~= "" and db.partner or "not configured") .. (NS.FindPartner(db.partner) and " (in group)" or " (not matched)"),
        "Manual session checklist: " .. (checks.roles and "[x]" or "[ ]") .. " roles  " .. (checks.activity and "[x]" or "[ ]") .. " activity  " .. (checks.preparation and "[x]" or "[ ]") .. " preparation",
        "Activity: " .. db.activity, "PARTY / RAID"}
    local function append(name, details)
        if not name then return end
        local text = (db.favourites[name] and "* " or "") .. name .. " | " .. details .. (db.notes[name] and ("\n  Private note: " .. db.notes[name]) or "")
        if query == "" or text:lower():find(query:lower(), 1, true) then lines[#lines + 1] = text end
    end
    local units = {}
    if IsInRaid() then for i = 1, GetNumGroupMembers() do units[#units + 1] = "raid" .. i end
    else units[1] = "player"; for i = 1, GetNumSubgroupMembers() do units[#units + 1] = "party" .. i end end
    for _, unit in ipairs(units) do
        append(NS.FullName(unit), (UnitGroupRolesAssigned(unit) or "NONE") .. (UnitIsGroupLeader(unit) and " | Leader" or "") .. (UnitIsGroupAssistant(unit) and " | Assistant" or "") .. (UnitIsConnected(unit) and " | Online" or " | Offline"))
    end
    lines[#lines + 1] = "\nGUILD " .. (showOffline and "(including offline)" or "(online only)")
    if not IsInGuild() then lines[#lines + 1] = "No guild. Party and private favourites still work."
    else
        local count = GetNumGuildMembers()
        if count == 0 then lines[#lines + 1] = "Roster not received yet; click Refresh." end
        for i = 1, count do
            local name, rank, _, level, class, zone, _, _, online = GetGuildRosterInfo(i)
            if name and (online or showOffline) then
                if not name:find("-", 1, true) then name = name .. "-" .. GetNormalizedRealmName() end
                append(name, (online and "Online" or "Offline") .. " | " .. (rank or "?") .. " | " .. (class or "?") .. " " .. (level or "?") .. " | " .. (zone or "?"))
            end
        end
    end
    lines[#lines + 1] = "\nPRIVATE FAVOURITES (presence not inferred)"
    local favs = {}; for name in pairs(db.favourites) do favs[#favs + 1] = name end; table.sort(favs)
    for _, name in ipairs(favs) do append(name, "Favourite") end
    lines[#lines + 1] = "\n/duosocial favourite Name-Realm\n/duosocial note Name-Realm private text\n/duosocial unnote Name-Realm\n/duosocial check roles|activity|preparation\nNo notes are sent to chat or written to the guild."
    panel:Text(table.concat(lines, "\n\n"))
end
local function requestRoster()
    if not InCombatLockdown() and IsInGuild() and C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster() end
    refresh()
end
local function command(message)
    local cmd, rest = NS.Words(message)
    if cmd == "" then NS.Toggle(panel); requestRoster(); return
    elseif cmd == "partner" then db.partner = rest
    elseif cmd == "select" then
        if InCombatLockdown() then NS.Print("Select a partner outside combat."); return end
        if not UnitIsPlayer("target") or not UnitInParty("target") or UnitIsUnit("target", "player") then NS.Print("Target your party partner first."); return end
        db.partner = NS.FullName("target")
    elseif cmd == "invite" then invite(); return
    elseif cmd == "ready" then ready(); return
    elseif cmd == "favourite" then
        if not rest:match("^%S+%-%S+$") then NS.Print("Use the full Name-Realm shown in the roster."); return end
        db.favourites[rest] = not db.favourites[rest] or nil
    elseif cmd == "note" then
        local name, text = rest:match("^(%S+)%s+(.+)$")
        if not name or not name:find("-", 1, true) then NS.Print("/duosocial note Name-Realm private text"); return end
        db.notes[name] = text
    elseif cmd == "unnote" then db.notes[rest] = nil
    elseif cmd == "offline" then showOffline = not showOffline
    elseif cmd == "activity" then db.activity = rest
    elseif cmd == "check" and checks[rest] ~= nil then checks[rest] = not checks[rest]
    else NS.Print("/duosocial | partner Name-Realm | select | invite | ready | favourite Name-Realm | note Name-Realm text | unnote Name-Realm | offline | activity text | check roles/activity/preparation"); return end
    refresh()
end
local events = CreateFrame("Frame"); events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" then
        if name ~= addon then return end
        DuoSocialDB = NS.Defaults(DuoSocialDB or {}, {version = 1, partner = "", favourites = {}, notes = {}, activity = "Agree an activity together."}); db = DuoSocialDB
        panel = NS.Panel("DuoSocial - party, guild and private notes", 700, 540)
        search = CreateFrame("EditBox", nil, panel, "InputBoxTemplate"); search:SetSize(235, 22); search:SetPoint("TOPLEFT", 18, -42); search:SetAutoFocus(false)
        search:SetScript("OnTextChanged", refresh); search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        NS.Button(panel, "Invite partner", 270, -40, 130, invite)
        NS.Button(panel, "Ready check", 405, -40, 120, ready)
        NS.Button(panel, "Refresh", 530, -40, 110, requestRoster)
        NS.Button(panel, "Roles", 15, -72, 90, function() checks.roles = not checks.roles; refresh() end)
        NS.Button(panel, "Activity", 110, -72, 90, function() checks.activity = not checks.activity; refresh() end)
        NS.Button(panel, "Preparation", 205, -72, 110, function() checks.preparation = not checks.preparation; refresh() end)
        NS.Button(panel, "Offline toggle", 320, -72, 130, function() showOffline = not showOffline; refresh() end)
        for _, e in ipairs({"GROUP_ROSTER_UPDATE", "GUILD_ROSTER_UPDATE", "PLAYER_GUILD_UPDATE", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "PARTY_LEADER_CHANGED", "PLAYER_ROLES_ASSIGNED"}) do events:RegisterEvent(e) end
        SLASH_DUOSOCIAL1 = "/duosocial"; SlashCmdList.DUOSOCIAL = command
        -- Optional local-only integration. Callers must expose this through a deliberate user action.
        DuoSocialAPI = {version = 1, SetActivity = function(text)
            if InCombatLockdown() or type(text) ~= "string" then return false end
            db.activity = text; refresh(); return true
        end}
    else NS.Debounce(refresh) end
end)
