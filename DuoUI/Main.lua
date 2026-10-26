local addon, NS = ...
local db, frame, cards = nil, nil, {}
local dirty = false
local defaults = {version = 1, partner = "", font = 16, face = "standard", profiles = {
    solo = {scale = 1, x = -260, y = -120}, duo = {scale = 1, x = -260, y = -120}}}
local function profile() return IsInGroup() and "duo" or "solo" end
local function health(card)
    -- Opaque values go directly to native presentation. Never inspect or format them.
    card.bar:SetMinMaxValues(0, UnitHealthMax(card.unit))
    card.bar:SetValue(UnitHealth(card.unit))
end
local function layout()
    if not db then return end
    if InCombatLockdown() then dirty = true; return end
    dirty = false
    local p = db.profiles[profile()]
    frame:ClearAllPoints(); frame:SetPoint("CENTER", UIParent, "CENTER", p.x, p.y); frame:SetScale(p.scale)
    local partner = NS.FindPartner(db.partner)
    local className = UnitClass("player")
    local units = {"player"}
    if partner then units[#units + 1] = partner end
    for i, card in ipairs(cards) do
        card.unit = units[i]
        card:SetShown(card.unit ~= nil)
        if card.unit then
            card.name:SetFont(db.face == "readable" and "Fonts\\ARIALN.TTF" or STANDARD_TEXT_FONT, db.font, "OUTLINE")
            card.name:SetText((i == 2 and "Partner: " or "") .. (UnitName(card.unit) or "Unknown"))
            health(card)
        end
    end
    frame.hint:SetText((className or "Player") .. " | " .. profile() .. " | " .. (partner and "partner matched" or "configure partner for duo"))
end
local function command(message)
    local cmd, rest = NS.Words(message)
    if cmd == "partner" then db.partner = rest
    elseif cmd == "select" then
        if InCombatLockdown() then NS.Print("Select a partner outside combat."); return end
        if not UnitIsPlayer("target") or not UnitInParty("target") or UnitIsUnit("target", "player") then NS.Print("Target your party partner first."); return end
        db.partner = NS.FullName("target")
    elseif cmd == "scale" then
        local n = tonumber(rest); if not n or n < .6 or n > 2 then NS.Print("Scale must be 0.6 to 2."); return end
        db.profiles[profile()].scale = n
    elseif cmd == "font" then
        local n = tonumber(rest); if not n or n < 10 or n > 28 then NS.Print("Font size must be 10 to 28."); return end
        db.font = n
    elseif cmd == "face" then
        if rest ~= "standard" and rest ~= "readable" then NS.Print("/duoui face standard|readable"); return end
        db.face = rest
    elseif cmd == "position" then
        local x, y = rest:match("^(%-?%d+)%s+(%-?%d+)$")
        if not x or math.abs(tonumber(x)) > 2000 or math.abs(tonumber(y)) > 2000 then NS.Print("/duoui position X Y (center offsets, -2000 to 2000)"); return end
        db.profiles[profile()].x = tonumber(x); db.profiles[profile()].y = tonumber(y)
    elseif cmd == "reset" then db.profiles = CopyTable(defaults.profiles); db.font = 16; db.face = "standard"
    else NS.Print("/duoui partner Name-Realm | select (targeted party member) | scale 0.6-2 | font 10-28 | face standard/readable | position X Y | reset. Drag outside combat. Use Blizzard Edit Mode for native frames."); return end
    layout()
    if dirty then NS.Print("Layout saved; will apply after combat and recheck the roster.") end
end
local events = CreateFrame("Frame"); events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(_, event, unit)
    if event == "ADDON_LOADED" then
        if unit ~= addon then return end
        DuoUIDB = NS.Defaults(DuoUIDB or {}, defaults); db = DuoUIDB
        frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate"); frame:SetSize(235, 125)
        frame:SetMovable(true); frame:SetClampedToScreen(true); frame:EnableMouse(true); frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", function(self) if not InCombatLockdown() then self:StartMoving() end end)
        frame:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
            if InCombatLockdown() then return end
            local x, y = self:GetCenter(); local ux, uy = UIParent:GetCenter()
            local p = db.profiles[profile()]; p.x = x * self:GetScale() - ux; p.y = y * self:GetScale() - uy
            layout()
        end)
        frame.hint = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); frame.hint:SetPoint("TOPLEFT"); frame.hint:SetWidth(235)
        for i = 1, 2 do
            local card = CreateFrame("Frame", nil, frame); card:SetSize(230, 43); card:SetPoint("TOPLEFT", 0, -18 - (i - 1) * 49)
            local bar = CreateFrame("StatusBar", nil, card); bar:SetAllPoints(); bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
            bar:SetStatusBarColor(i == 1 and .15 or .35, .5, .45)
            local bg = bar:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(.04, .04, .05, .8)
            card.name = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); card.name:SetPoint("CENTER")
            card.bar = bar; cards[i] = card
        end
        for _, e in ipairs({"PLAYER_LOGIN", "GROUP_ROSTER_UPDATE", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_NAME_UPDATE"}) do events:RegisterEvent(e) end
        SLASH_DUOUI1 = "/duoui"; SlashCmdList.DUOUI = command
        layout()
    elseif event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
        for _, card in ipairs(cards) do if card.unit == unit then health(card) end end
    elseif event == "GROUP_ROSTER_UPDATE" and InCombatLockdown() then
        -- Do not display the next occupant of a changed party slot under an old name.
        cards[2].unit = nil; cards[2].bar:SetMinMaxValues(0, 1); cards[2].bar:SetValue(0)
        cards[2].name:SetText("Roster changed: refresh after combat")
        dirty = true
    elseif event == "PLAYER_REGEN_DISABLED" then frame:StopMovingOrSizing()
    else layout() end
end)
