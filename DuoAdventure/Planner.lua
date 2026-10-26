local _, NS = ...
-- Deterministic log-planning heuristic. It is not a path finder or an XP/hour model.
function NS.OrderQuests(quests, mode, pins, zone)
    local ordered = {}
    for i, quest in ipairs(quests) do ordered[i] = quest end
    if mode == "speed" then
        table.sort(ordered, function(a, b)
            local ap, bp = pins[a.id] or math.huge, pins[b.id] or math.huge
            if ap ~= bp then return ap < bp end
            if a.complete ~= b.complete then return a.complete end
            local az, bz = a.zone == zone, b.zone == zone
            if az ~= bz then return az end
            if a.zone ~= b.zone then return a.zone < b.zone end
            local ad, bd = a.distance or math.huge, b.distance or math.huge
            if ad ~= bd then return ad < bd end
            return a.index < b.index
        end)
    end
    return ordered
end
