local addon, NS = ...
local db, panel, buttons = nil, nil, {}
local pending = false
local page, classToken = 1, nil
local function classPlan() return db.classPlans[classToken] end
local checks = {roles = false, supplies = false, bindings = false}
local function known(id)
    if C_SpellBook and C_SpellBook.IsSpellKnown then return C_SpellBook.IsSpellKnown(id) end
    return IsPlayerSpell and IsPlayerSpell(id) or false
end
local function update()
    if not db then return end
    if InCombatLockdown() then pending = true; return end
    pending = false
    local className, class = UnitClass("player"); classToken = class
    local module = NS.Classes[class]
    local partner = NS.FindPartner(db.partner)
    local full = partner and NS.FullName(partner)
    local solo = not IsInGroup()
    local plan = classPlan()
    local specName = "not selected/unlocked"
    local specIndex = GetSpecialization and GetSpecialization()
    if specIndex and GetSpecializationInfo then local _, name = GetSpecializationInfo(specIndex); specName = name or specName end
    local lines = {"Detected: " .. (className or "Unknown class") .. " | level " .. UnitLevel("player") .. " | " .. specName .. " | " .. (solo and "SOLO" or "GROUP"),
        "Partner: " .. (db.partner ~= "" and db.partner or "not configured") .. (full and " (matched)" or " (not matched)"),
        "Manual Havoc/Vengeance planning profile: " .. db.spec .. "\nPreparation priority: " .. (plan and plan.priorities[db.spec] or "Class module not installed; native controls remain available."),
        "Draft/static interrupt agreement: " .. (plan and plan.agreement[db.spec] or "Agree manually."),
        module and module.guide or "This class has no reference module yet. No unlearned abilities are offered.",
        "REFERENCE ONLY - choose your own actions. Native action bars show cooldowns; native party frames show health.\nKnown abilities and your binding notes:"}
    local actions = {}
    local entries = NS.KnownEntries(class, known)
    if #entries == 0 then lines[#lines + 1] = "No reference abilities learned yet. Continue your starting quests and revisit after learning spells; there is no level or end-game gate." end
    for _, entry in ipairs(entries) do
            local info = C_Spell.GetSpellInfo(entry.id)
            if info then
                lines[#lines + 1] = entry.category .. ": " .. info.name .. " [" .. entry.id .. "] - " .. (db.bindings[entry.id] or "set /duosupport bind ID your-key")
                if entry.action then actions[#actions + 1] = {entry = entry, name = info.name} end
            end
    end
    local pages = math.max(1, math.ceil(#actions / 6)); page = math.min(page, pages)
    lines[#lines + 1] = "Manual action page " .. page .. "/" .. pages .. " (Next actions or /duosupport page N, outside combat). Target buttons use YOUR selected target; they never choose an enemy."
    for i, b in ipairs(buttons) do
        local action = actions[(page - 1) * 6 + i]
        if action then
            local entry = action.entry
            local unit, label
            if entry.action == "self" then unit, label = "player", "self"
            elseif entry.action == "target" then unit, label = "target", "your target"
            elseif solo then unit, label = "player", "self (solo)"
            else unit, label = full, full and "partner" or "partner not matched" end
            b:SetText(action.name .. " -> " .. label)
            b:SetAttribute("type", unit and "spell" or nil); b:SetAttribute("spell", entry.id)
            b:SetAttribute("unit", unit); b:SetAttribute("checkselfcast", false); b:SetAttribute("checkfocuscast", false)
            b:Show()
        else b:SetAttribute("type", nil); b:Hide() end
    end
    lines[#lines + 1] = "\nSession checklist (manual; /duosupport check roles|supplies|bindings):"
    for _, key in ipairs({"roles", "supplies", "bindings"}) do lines[#lines + 1] = (checks[key] and "[x] " or "[ ] ") .. key end
    lines[#lines + 1] = "\nSETUP FROM YOUR FIRST PLAYABLE LEVEL\n1. Solo: no partner setup required. Learned self-survival and utility controls appear immediately, including before specialisation unlock. There is no minimum-level gate.\n2. Duo: set partner Name-Realm or target the party member and use select. Friendly spells use that identity; missing grouped partners disable those buttons.\n3. Read each button's recipient. Click once to request one action. Page/configure outside combat; keep the panel open if using it in combat.\n4. Set binding reference notes and use native Keybindings for actual bindings. Evokers can alternatively assign learned friendly spells in native Click Casting on Blizzard frames. Demon Hunters have personal sustain/utility, not Evoker-style off-healing.\n5. Keep native health/resource/cooldown displays visible. No combat analysis or automatic spell/target choice."
    panel:Text(table.concat(lines, "\n\n"))
end
local function command(message)
    local cmd, rest = NS.Words(message)
    if cmd == "" then NS.Toggle(panel); update(); return
    elseif cmd == "partner" then db.partner = rest
    elseif cmd == "select" then
        if InCombatLockdown() then NS.Print("Select a partner outside combat."); return end
        if not UnitIsPlayer("target") or not UnitInParty("target") or UnitIsUnit("target", "player") then NS.Print("Target your party partner first."); return end
        db.partner = NS.FullName("target")
    elseif cmd == "spec" and (rest == "havoc" or rest == "vengeance") then db.spec = rest
    elseif cmd == "agreement" and classPlan() then classPlan().agreement[db.spec] = rest
    elseif cmd == "priority" and classPlan() then classPlan().priorities[db.spec] = rest
    elseif cmd == "page" then
        local n = tonumber(rest); if not n or n < 1 or n % 1 ~= 0 then NS.Print("Use page 1, 2, ..."); return end
        page = n
    elseif cmd == "bind" then
        local id, note = rest:match("^(%d+)%s+(.+)$"); id = tonumber(id)
        if not id or not known(id) then NS.Print("Use a learned spell ID and a binding note."); return end
        db.bindings[id] = note
    elseif cmd == "check" and checks[rest] ~= nil then checks[rest] = not checks[rest]
    elseif cmd == "setup" then if not InCombatLockdown() then panel:Show() end
    else NS.Print("/duosupport | setup | partner Name-Realm | select | spec havoc/vengeance | page N | bind ID note | agreement text | priority text | check roles/supplies/bindings"); return end
    update(); if pending then NS.Print("Saved; secure buttons and reference will refresh after combat.") end
end
local events = CreateFrame("Frame"); events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" then
        if name ~= addon then return end
        DuoSupportDB = NS.PrepareSupportDB(DuoSupportDB); db = DuoSupportDB
        panel = NS.Panel("DuoSupport - deliberate actions", 730, 740)
        -- Keep protected buttons outside the scrolling region. All mutations are out of combat.
        panel:SetHeight(math.min(740, UIParent:GetHeight() - 40))
        NS.Button(panel, "Setup / refresh", 15, -40, 140, update)
        NS.Button(panel, "Roles checked", 165, -40, 140, function() checks.roles = not checks.roles; update() end)
        NS.Button(panel, "Next actions", 315, -40, 140, function()
            if InCombatLockdown() then NS.Print("Change action pages outside combat."); return end
            local actions = 0; for _, entry in ipairs(NS.KnownEntries(classToken, known)) do if entry.action then actions = actions + 1 end end
            page = page % math.max(1, math.ceil(actions / 6)) + 1; update()
        end)
        local footer = CreateFrame("Frame", nil, panel); footer:SetSize(690, 90); footer:SetPoint("BOTTOMLEFT", 15, 14)
        for i = 1, 6 do
            local b = CreateFrame("Button", addon .. "Action" .. i, footer, "SecureActionButtonTemplate,UIPanelButtonTemplate")
            b:SetSize(222, 26); b:SetPoint("TOPLEFT", ((i - 1) % 3) * 228, -math.floor((i - 1) / 3) * 29)
            b:RegisterForClicks("AnyUp", "AnyDown"); b:Hide(); buttons[i] = b
        end
        -- Six user-selected-page actions, independent of class or available end-game spells.
        local scroll = panel.body:GetParent():GetParent(); scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -32, 115)
        for _, e in ipairs({"PLAYER_LOGIN", "PLAYER_LEVEL_UP", "SPELLS_CHANGED", "PLAYER_SPECIALIZATION_CHANGED", "GROUP_ROSTER_UPDATE", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED"}) do events:RegisterEvent(e) end
        SLASH_DUOSUPPORT1 = "/duosupport"; SlashCmdList.DUOSUPPORT = command
        update()
    elseif event == "PLAYER_REGEN_DISABLED" then panel:StopMovingOrSizing()
    else update() end
end)
