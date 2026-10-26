local addon, NS = ...
function NS.Print(message) print("|cff70d9cf" .. addon .. ":|r " .. message) end
function NS.Words(message)
    local command, rest = message:match("^(%S*)%s*(.-)%s*$")
    return command:lower(), rest
end
function NS.Defaults(db, defaults)
    for k, v in pairs(defaults) do
        if db[k] == nil then db[k] = type(v) == "table" and CopyTable(v) or v
        elseif type(v) == "table" and type(db[k]) == "table" then NS.Defaults(db[k], v) end
    end
    return db
end
function NS.FullName(unit)
    local name, realm = UnitFullName(unit)
    if not name then return nil end
    return name .. "-" .. ((realm and realm ~= "") and realm or GetNormalizedRealmName())
end
function NS.FindPartner(name)
    if not name or name == "" then return nil end
    local match
    local units = {}
    if IsInRaid() then for i = 1, GetNumGroupMembers() do units[#units + 1] = "raid" .. i end
    else for i = 1, GetNumSubgroupMembers() do units[#units + 1] = "party" .. i end end
    for _, unit in ipairs(units) do
        local full = NS.FullName(unit)
        if full and (full:lower() == name:lower() or (not name:find("-", 1, true) and UnitName(unit):lower() == name:lower())) then
            if match then return nil end -- ambiguous short name; require Name-Realm
            match = unit
        end
    end
    return match
end
function NS.Button(parent, text, x, y, width, callback)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width or 120, 24); b:SetPoint("TOPLEFT", x, y); b:SetText(text)
    b:SetScript("OnClick", callback)
    return b
end
function NS.Panel(title, width, height)
    local f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    f:SetSize(width, height); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG")
    f:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1})
    f:SetBackdropColor(.035, .05, .065, .96); f:SetBackdropBorderColor(.2, .65, .6)
    f:SetClampedToScreen(true); f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) if not InCombatLockdown() then self:StartMoving() end end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    local heading = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    heading:SetPoint("TOPLEFT", 14, -12); heading:SetText(title)
    NS.Button(f, "X", width - 40, -6, 30, function() if InCombatLockdown() then NS.Print("Close after combat.") else f:Hide() end end)
    local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 14, -105); scroll:SetPoint("BOTTOMRIGHT", -32, 14)
    local child = CreateFrame("Frame", nil, scroll); child:SetSize(width - 52, 1); scroll:SetScrollChild(child)
    local body = child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    body:SetPoint("TOPLEFT"); body:SetWidth(width - 56); body:SetJustifyH("LEFT"); body:SetJustifyV("TOP")
    function f:Text(text) body:SetText(text); child:SetHeight(math.max(1, body:GetStringHeight() + 12)) end
    f.body = body
    f:Hide()
    return f
end
function NS.Toggle(panel)
    if InCombatLockdown() then NS.Print("Open or close this panel outside combat."); return end
    panel:SetShown(not panel:IsShown())
end
function NS.Debounce(callback)
    if NS.pending then return end
    NS.pending = true
    C_Timer.After(.2, function() NS.pending = nil; callback() end)
end
