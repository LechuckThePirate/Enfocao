local _, ns = ...
local L = ns.L

-- Templates: a handful of goals that go together ("Ready for Molten Core": level 60, the attunement, the Hydraxian
-- Waterlords), set in one go. Only what the character doesn't have yet, and doesn't go for already, is set; each goal
-- remembers its template (goal.group) and the Goals view says it.
--   { id, name, text, icon, minLevel, maxLevel, goals = function(key, rec) -> { { type =, p = } } }

local function factionName(id, english)
    local f = ns.FactionByID and ns.FactionByID(id)
    return (f and f.name) or L[english]
end

local function round5(n) return math.floor(n / 5 + 0.5) * 5 end

local function attunement(id, rec)
    for _, a in ipairs(ns.ATTUNEMENT_GOALS) do
        if a.id == id then
            local quest = a.quest[rec.faction or "Alliance"] or a.quest.Alliance
            return { type = "quest", p = { quest = quest, name = L[a.name] } }
        end
    end
    return nil
end

ns.GOAL_TEMPLATES = {
    {
        id = "ride", name = "Ready to ride", minLevel = 20, maxLevel = 39, icon = "Interface\\Icons\\Ability_Mount_RidingHorse",
        text = "Level 40, and the gold for the mount and its training.",
        goals = function() return { { type = "level", p = { level = 40 } }, { type = "gold", p = { amount = 100 * 10000 } } } end,
    },
    {
        id = "crafts", name = "Professions up to date", minLevel = 10, icon = "Interface\\Icons\\Trade_BlackSmithing",
        text = "Your professions and First Aid as high as your level allows.",
        goals = function(_, rec)
            local list = {}
            local expected = math.min(300, round5((rec.level or 1) * 5))
            for _, p in ipairs(rec.professions or {}) do
                if (p.primary or p.slot == 6) and (p.rank or 0) < expected then
                    list[#list + 1] = { type = "profession",
                        p = { name = p.name, skillLine = p.skillLine, icon = p.icon, rank = expected } }
                end
            end
            return list
        end,
    },
    {
        id = "pvp", name = "Battleground veteran", minLevel = 10, icon = "Interface\\Icons\\INV_BannerPVP_02",
        text = "Honored with the battlegrounds your level opens.",
        goals = function(_, rec)
            local list = {}
            local side = rec.faction == "Horde" and "Horde" or "Alliance"
            for _, bg in ipairs(ns.BATTLEGROUNDS) do
                if (rec.level or 1) >= bg.level then
                    list[#list + 1] = { type = "reputation", p = { faction = bg.faction[side],
                        name = factionName(bg.faction[side], bg.factionName[side]), standing = 6 } }
                end
            end
            return list
        end,
    },
    {
        id = "epic", name = "Epic mount", minLevel = 45, icon = "Interface\\Icons\\Ability_Mount_JungleTiger",
        text = "Level 60, and about 1000 gold for the mount and its training.",
        goals = function() return { { type = "level", p = { level = 60 } }, { type = "gold", p = { amount = 1000 * 10000 } } } end,
    },
    {
        id = "mc", name = "Ready for Molten Core", minLevel = 55, icon = "Interface\\Icons\\Spell_Fire_Incinerate",
        text = "Level 60, the attunement, and Honored with the Hydraxian Waterlords to douse the runes.",
        goals = function(_, rec)
            return { { type = "level", p = { level = 60 } }, attunement("mc", rec),
                { type = "reputation", p = { faction = 749, name = factionName(749, "Hydraxian Waterlords"), standing = 6 } } }
        end,
    },
    {
        id = "ony", name = "Ready for Onyxia", minLevel = 55, icon = "Interface\\Icons\\INV_Misc_Head_Dragon_01",
        text = "Level 60 and the attunement to her lair.",
        goals = function(_, rec) return { { type = "level", p = { level = 60 } }, attunement("ony", rec) } end,
    },
    {
        id = "bwl", name = "Ready for Blackwing Lair", minLevel = 57, icon = "Interface\\Icons\\INV_Misc_Head_Dragon_Black",
        text = "Level 60, the Seal of Ascension and the attunement to the lair.",
        goals = function(_, rec)
            return { { type = "level", p = { level = 60 } }, attunement("ubrs", rec), attunement("bwl", rec) }
        end,
    },
}

function ns.Template_Get(id)
    for _, t in ipairs(ns.GOAL_TEMPLATES) do
        if t.id == id then return t end
    end
    return nil
end

-- The goals a template would set for a character: the valid ones it doesn't go for already (nor has done: a quest
-- completed, a level reached).
function ns.Template_Goals(key, template)
    local rec = ns.GetChar(key)
    if not rec then return {} end
    local taken = {}
    for _, g in ipairs(ns.Goals_For(key, false)) do taken[ns.Goals_Signature(g)] = true end
    local list = {}
    local ok, goals = pcall(template.goals, key, rec)
    for _, g in ipairs(ok and goals or {}) do
        local def = ns.GOAL_TYPES[g.type]
        if def and not taken[ns.Goals_Signature(g)] and def.valid(g.p, key) then
            local probe = { type = g.type, p = g.p, char = key }
            local pos = def.position(probe, key)
            if pos == nil or pos < def.target(probe) then list[#list + 1] = g end
        end
    end
    return list
end

-- The templates that fit a character's level and would set something: { { template =, goals = } }.
function ns.Templates_For(key)
    local rec = ns.GetChar(key)
    if not rec then return {} end
    local level = rec.level or 1
    local list = {}
    for _, t in ipairs(ns.GOAL_TEMPLATES) do
        if level >= (t.minLevel or 1) and level <= (t.maxLevel or 60) then
            local goals = ns.Template_Goals(key, t)
            if #goals > 0 then list[#list + 1] = { template = t, goals = goals } end
        end
    end
    return list
end

-- Sets a template's goals; returns how many.
function ns.Template_Apply(key, template)
    local n = 0
    for _, g in ipairs(ns.Template_Goals(key, template)) do
        if ns.Goals_Add(key, g.type, ns.Copy(g.p), template.id) then n = n + 1 end
    end
    return n
end
