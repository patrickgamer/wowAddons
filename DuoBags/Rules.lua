local _, NS = ...
function NS.MigrateBagRules(db)
    db.keep = db.keep or {}; db.partner = db.partner or {}
    if (db.version or 1) < 2 then
        -- Import old item-tag tables without embedding private legacy field names in source.
        -- Preserve unknown fields in local SavedVariables; never discard a user's protection rules.
        for key, tags in pairs(db) do
            if key ~= "keep" and key ~= "partner" and type(tags) == "table" then
                for id, protected in pairs(tags) do
                    if type(id) == "number" and id > 0 and id % 1 == 0 and protected == true then db.partner[id] = true end
                end
            end
        end
        db.version = 2
    end
    return db
end
function NS.SaleEligible(item, db)
    return item and item.cached and item.quality == 0 and item.price > 0
        and not item.locked and not item.quest and not item.hasLoot
        and not item.noValue and not item.equippable and not db.keep[item.id] and not db.partner[item.id]
end
function NS.Matches(text, query)
    return query == "" or text:lower():find(query:lower(), 1, true) ~= nil
end
