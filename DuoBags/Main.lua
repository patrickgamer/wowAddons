local addon, NS = ...
local db, panel, search, status, preview
local loot = {}
local mode = "inventory"
local function itemAt(bag, slot)
    local info = C_Container.GetContainerItemInfo(bag, slot)
    if not info then return nil end
    local name, _, quality, _, _, class, subclass, _, _, _, price = C_Item.GetItemInfo(info.itemID)
    local quest = C_Container.GetContainerItemQuestInfo(bag, slot)
    return {id = info.itemID, link = info.hyperlink, name = name, quality = quality,
        price = price or 0, cached = name ~= nil, count = info.stackCount, locked = info.isLocked,
        noValue = info.hasNoValue, hasLoot = info.hasLoot, equippable = C_Item.IsEquippableItem(info.itemID),
        quest = not quest or quest.isQuestItem or quest.questID ~= nil,
        category = class and (class .. "/" .. (subclass or "")) or "Loading", bag = bag, slot = slot}
end
local function inventory()
    local items, free, total, reagentFree = {}, 0, 0, 0
    for bag = 0, (NUM_TOTAL_EQUIPPED_BAG_SLOTS or 5) do
        local slots = C_Container.GetContainerNumSlots(bag)
        local available = C_Container.GetContainerNumFreeSlots(bag) or 0
        total = total + slots; free = free + available
        if bag == 5 then reagentFree = available end
        for slot = 1, slots do
            local item = itemAt(bag, slot)
            if item then items[#items + 1] = item end
        end
    end
    return items, free, total, reagentFree
end
local function autoStatus()
    local enabled = C_CVar.GetCVarBool("autoLootDefault")
    local held = IsModifiedClick("AUTOLOOTTOGGLE")
    local scope = "shared native setting"
    if C_CVar.GetCVarInfo then
        local _, _, account, character = C_CVar.GetCVarInfo("autoLootDefault")
        scope = account and "server account" or (character and "server character" or "local client/shared")
    end
    return "Auto-loot default: " .. (enabled and "ON" or "OFF") .. "; effective now: " .. ((enabled ~= held) and "ON" or "OFF") .. "; scope: " .. scope
end
local function refresh()
    if not db or not panel:IsShown() then return end
    local items, free, total, reagent = inventory()
    status:SetText(free .. "/" .. total .. " free (reagent: " .. reagent .. ") | " .. autoStatus())
    local lines = {}
    if mode == "loot" then
        lines[#lines + 1] = "Loot received since login/reload (items only):"
        for id, count in pairs(loot) do
            local name, link = C_Item.GetItemInfo(id)
            lines[#lines + 1] = (link or name or ("Item " .. id)) .. " x" .. count
        end
    else
        if mode == "sale" then lines[#lines + 1] = "Preview: grey items only. Click Sell ONE to sell the first listed stack.\nKeep and Companion tags always exclude items. Re-preview after inventory changes."
        else lines[#lines + 1] = "Search names, category, ID, keep or Companion.\n/duobags keep ID | /duobags partner ID (toggle item-type protection)" end
        for _, item in ipairs(items) do
            local tags = (db.keep[item.id] and " [keep]" or "") .. (db.partner[item.id] and " [for Companion: note only]" or "")
            local text = (item.name or ("Loading " .. item.id)) .. " " .. item.category .. tags .. " " .. item.id
            if (mode ~= "sale" or NS.SaleEligible(item, db)) and NS.Matches(text, search:GetText()) then
                lines[#lines + 1] = string.format("%d:%d  %s x%d | %s | ID %d%s", item.bag, item.slot, item.link or item.name or "Loading", item.count, item.category, item.id, tags)
            end
        end
    end
    panel:Text(table.concat(lines, "\n\n"))
end
local function makePreview()
    if InCombatLockdown() then NS.Print("Preview outside combat."); return end
    preview = nil
    if not MerchantFrame or not MerchantFrame:IsShown() then NS.Print("Open a vendor first."); return end
    search:SetText("")
    local items = inventory()
    preview = {}
    for _, item in ipairs(items) do if NS.SaleEligible(item, db) then preview[#preview + 1] = item end end
    mode = "sale"; panel:Show(); refresh()
    NS.Print(#preview .. " candidate stacks. Sell ONE requires another click; inventory changes invalidate this preview.")
end
local function sellOne()
    if InCombatLockdown() or not MerchantFrame or not MerchantFrame:IsShown() or MerchantFrame.selectedTab ~= 1 then NS.Print("Use the vendor Buy tab outside combat."); return end
    if (SpellIsTargeting and SpellIsTargeting()) or (CursorHasItem and CursorHasItem()) then NS.Print("Clear your cursor/spell targeting before selling."); return end
    if mode ~= "sale" or not panel:IsShown() or not preview or not preview[1] then NS.Print("Create a fresh sale preview first."); return end
    local old = preview[1]
    local now = itemAt(old.bag, old.slot)
    preview = nil -- never reuse a consent snapshot, even if the operation fails
    if not NS.SaleEligible(now, db) or now.id ~= old.id or now.link ~= old.link or now.count ~= old.count then NS.Print("Item changed; preview again."); return end
    C_Container.UseContainerItem(old.bag, old.slot)
end
local function command(message)
    local cmd, rest = NS.Words(message)
    if cmd == "keep" or cmd == "partner" then
        local id = tonumber(rest:match("item:(%d+)") or rest)
        if not id or id < 1 or id % 1 ~= 0 then NS.Print("Supply an item ID or item link."); return end
        db[cmd][id] = not db[cmd][id] or nil; preview = nil; refresh()
    elseif cmd == "auto" then
        if rest ~= "on" and rest ~= "off" then NS.Print(autoStatus() .. ". /duobags auto on|off changes Blizzard's shared native setting; modifier reverses it."); return end
        C_CVar.SetCVar("autoLootDefault", rest == "on" and "1" or "0"); refresh()
        NS.Print("Native auto-loot changed explicitly. This is Blizzard's shared setting, not a DuoBags-only preference; may affect other characters. Modifier behavior is unchanged.")
    elseif cmd == "preview" then makePreview()
    elseif cmd == "loot" then mode = "loot"; NS.Toggle(panel); refresh()
    elseif cmd == "clearloot" then loot = {}; refresh()
    elseif cmd == "" then mode = "inventory"; NS.Toggle(panel); refresh()
    else NS.Print("/duobags | keep ID | partner ID | auto on/off | preview | loot | clearloot") end
end
local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        if ... ~= addon then return end
        DuoBagsDB = NS.MigrateBagRules(NS.Defaults(DuoBagsDB or {}, {version = 1, keep = {}, partner = {}})); db = DuoBagsDB
        panel = NS.Panel("DuoBags - inventory and supplies", 780, 510)
        search = CreateFrame("EditBox", nil, panel, "InputBoxTemplate"); search:SetSize(240, 22); search:SetPoint("TOPLEFT", 18, -42); search:SetAutoFocus(false)
        search:SetScript("OnTextChanged", function() preview = nil; refresh() end); search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        NS.Button(panel, "Loot", 275, -40, 80, function() mode = "loot"; refresh() end)
        NS.Button(panel, "Inventory", 360, -40, 85, function() mode = "inventory"; refresh() end)
        NS.Button(panel, "Preview", 450, -40, 85, makePreview)
        NS.Button(panel, "Sell ONE", 540, -40, 90, sellOne)
        NS.Button(panel, "Auto-loot toggle", 635, -40, 130, function() command("auto " .. (C_CVar.GetCVarBool("autoLootDefault") and "off" or "on")) end)
        status = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); status:SetPoint("TOPLEFT", 14, -78)
        status:SetWidth(750); status:SetJustifyH("LEFT")
        local badge = CreateFrame("Button", nil, UIParent); badge:SetSize(225, 24); badge:SetPoint("BOTTOMLEFT", 12, 125)
        local label = badge:CreateFontString(nil, "OVERLAY", "GameFontNormal"); label:SetAllPoints()
        badge:SetScript("OnClick", function() command("") end)
        panel:SetScript("OnShow", refresh)
        NS.Badge = function()
            local free, total = 0, 0
            for bag = 0, (NUM_TOTAL_EQUIPPED_BAG_SLOTS or 5) do
                free = free + (C_Container.GetContainerNumFreeSlots(bag) or 0)
                total = total + C_Container.GetContainerNumSlots(bag)
            end
            label:SetText("DuoBags " .. free .. "/" .. total .. " free")
        end
        for _, e in ipairs({"PLAYER_LOGIN", "BAG_UPDATE_DELAYED", "GET_ITEM_INFO_RECEIVED", "CHAT_MSG_LOOT", "MERCHANT_CLOSED", "CVAR_UPDATE", "MODIFIER_STATE_CHANGED"}) do events:RegisterEvent(e) end
        SLASH_DUOBAGS1 = "/duobags"; SlashCmdList.DUOBAGS = command
    elseif event == "CHAT_MSG_LOOT" then
        local message, _, _, _, _, _, _, _, _, _, _, guid = ...
        if issecretvalue and (issecretvalue(message) or issecretvalue(guid)) then return end
        if guid == UnitGUID("player") then
            local id = tonumber(message:match("item:(%d+)"))
            if id then loot[id] = (loot[id] or 0) + (tonumber(message:match("[xX](%d+)")) or 1) end
        end
        NS.Debounce(refresh)
    else
        if event == "BAG_UPDATE_DELAYED" or event == "MERCHANT_CLOSED" then preview = nil end
        NS.Debounce(function() refresh(); NS.Badge() end)
    end
end)
