local _, NS = ...
-- Extend this registry for future classes. All availability comes from the live spellbook;
-- never hard-code an end-game level requirement or infer availability from cooldowns.
-- action = self, partner (self while solo), target (the user's current target), or nil (reference only).
NS.Classes = {
    EVOKER = {
        label = "Evoker", guide = "Start with your learned self-heal, movement and defensive controls. Add dispel/interrupt bindings as the spellbook unlocks them. In a duo, agree when off-healing is useful before pulling.",
        spells = {
            {id = 361469, category = "Heal", action = "partner"}, -- Living Flame
            {id = 363916, category = "Defensive", action = "self"}, -- Obsidian Scales
            {id = 358267, category = "Movement", action = "self"}, -- Hover
            {id = 351338, category = "Interrupt", action = "target"}, -- Quell
            {id = 365585, category = "Dispel", action = "partner"}, -- Expunge
            {id = 355913, category = "Heal", action = "partner"}, -- Emerald Blossom
            {id = 374251, category = "Dispel", action = "partner"}, -- Cauterizing Flame
            {id = 374348, category = "Defensive", action = "self"}, -- Renewing Blaze
            {id = 370665, category = "Movement", action = "partner"}, -- Rescue (native further input)
            {id = 360823, category = "Dispel", action = "partner"}, -- Naturalize
            {id = 370960, category = "Defensive", action = "self"}, -- Emerald Communion
        },
        priorities = {havoc = "Agree your own survival and emergency off-healing responsibilities.", vengeance = "Agree pulls and tank recovery before spending time off-healing."},
    },
    DEMONHUNTER = {
        label = "Demon Hunter", guide = "Bind your learned survival and movement abilities from the start. Self-healing is personal sustain, not friendly off-healing. Use native resource/cooldown displays. Agree pulls and interrupt order with your companion.",
        spells = {
            {id = 198589, category = "Defensive", action = "self"}, -- Blur
            {id = 203720, category = "Defensive", action = "self"}, -- Demon Spikes
            {id = 195072, category = "Movement", action = "self"}, -- Fel Rush
            {id = 183752, category = "Interrupt", action = "target"}, -- Disrupt
            {id = 278326, category = "Enemy dispel", action = "target"}, -- Consume Magic
            {id = 228477, category = "Self-sustain (hostile target)", action = "target"}, -- Soul Cleave
            {id = 196718, category = "Group defensive", action = "self"}, -- Darkness
            {id = 196555, category = "Defensive", action = "self"}, -- Netherwalk
            {id = 204021, category = "Defensive (hostile target)", action = "target"}, -- Fiery Brand
            {id = 198793, category = "Movement", action = "self"}, -- Vengeful Retreat
            {id = 187827, category = "Defensive", action = "self"}, -- Vengeance Metamorphosis
            {id = 191427, category = "Defensive / native ground targeting"}, -- Havoc Metamorphosis
            {id = 189110, category = "Movement / native ground targeting"}, -- Infernal Strike
            {id = 212084, category = "Self-sustain / native channel control"}, -- Fel Devastation
            {id = 263648, category = "Defensive", action = "self"}, -- Soul Barrier, only if known
        },
        priorities = {havoc = "Plan personal survival, mobility and group utility; do not assume a companion is healing you.", vengeance = "Plan pulls, mitigation bindings and personal sustain; agree recovery pauses with your companion."},
    },
}
function NS.KnownEntries(class, known)
    local entries = {}
    local module = NS.Classes[class]
    if module then for _, entry in ipairs(module.spells) do if known(entry.id) then entries[#entries + 1] = entry end end end
    return entries
end
function NS.PrepareSupportDB(saved)
    local db = NS.Defaults(saved or {}, {version = 2, partner = "", spec = "havoc", bindings = {}, classPlans = {}})
    -- Preserve the first release's Evoker text and all legacy fields during migration.
    if db.version == 1 and not db.classPlans.EVOKER then
        db.classPlans.EVOKER = {priorities = CopyTable(db.priorities or {}), agreement = CopyTable(db.agreement or {})}
    end
    for class, module in pairs(NS.Classes) do
        db.classPlans[class] = NS.Defaults(db.classPlans[class] or {}, {
            priorities = module.priorities,
            agreement = {havoc = "DRAFT: agree first interrupt and backup before pulling.", vengeance = "DRAFT: agree pulls, first interrupt and backup before pulling."},
        })
    end
    if db.version < 2 then db.version = 2 end
    return db
end
