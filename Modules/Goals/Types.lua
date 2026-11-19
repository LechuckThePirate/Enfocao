local _, ns = ...
local L = ns.L

-- The kinds of goal. Each one knows:
--   name, icon                 for lists and the "new goal" form
--   title(goal)                what the goal says ("Fishing to 225")
--   position(goal, key)        where the character is now, as a number on the way to the target (nil when unknown:
--                              a character the store doesn't know); the progress bar goes from where it was when
--                              the goal was set (goal.p.start) to target(goal)
--   target(goal)               the number to reach
--   status(goal, key)          a short text of where it stands ("150 / 225")
--   valid(p, key)              whether the parameters make a goal (the form's check)
-- A goal: { id, char = key, type, p = { ... }, created, done, doneAt }  (manual ones: p.text, p.reset, ticked by hand)

-- Reputation: one scale for every standing (the thresholds of Classic), so a goal like "Exalted with Argent Dawn" is
-- a distance in points from wherever the character is.
local STANDING_BASE = { -42000, -6000, -3000, 0, 3000, 9000, 21000, 42000 }
local function repPosition(r)
    if not r or not r.standing then return nil end
    return (STANDING_BASE[r.standing] or 0) + (r.cur or 0)
end

local function professionOf(key, p)
    local rec = ns.GetChar(key)
    for _, prof in ipairs(rec and rec.professions or {}) do
        if (p.skillLine and prof.skillLine == p.skillLine) or prof.name == p.name then return prof end
    end
    return nil
end

local function gold(copper) return math.floor((copper or 0) / 10000) end

ns.GOAL_TYPES = {
    level = {
        order = 1, name = L["Reach a level"], icon = "Interface\\Icons\\Spell_Holy_InnerFire",
        title = function(g) return L["Level %d"]:format(g.p.level) end,
        position = function(_, key)
            local rec = ns.GetChar(key)
            if not rec or not rec.level then return nil end
            local share = (rec.xp and rec.xpMax and rec.xpMax > 0) and rec.xp / rec.xpMax or 0
            return rec.level + share
        end,
        target = function(g) return g.p.level end,
        status = function(_, key)
            local rec = ns.GetChar(key)
            if not rec or not rec.level then return "?" end
            local pct = (rec.xp and rec.xpMax and rec.xpMax > 0) and math.floor(rec.xp / rec.xpMax * 100) or 0
            return L["level %d (%d%%)"]:format(rec.level, pct)
        end,
        valid = function(p, key)
            local rec = ns.GetChar(key)
            return type(p.level) == "number" and p.level > (rec and rec.level or 0) and p.level <= 60
        end,
    },
    profession = {
        order = 2, name = L["Raise a profession"], icon = "Interface\\Icons\\Trade_BlackSmithing",
        title = function(g) return L["%s to %d"]:format(g.p.name or "?", g.p.rank) end,
        position = function(g, key)
            local prof = professionOf(key, g.p)
            return prof and prof.rank or nil
        end,
        target = function(g) return g.p.rank end,
        status = function(g, key)
            local prof = professionOf(key, g.p)
            return prof and ("%d / %d"):format(prof.rank or 0, g.p.rank) or L["not learned"]
        end,
        valid = function(p) return type(p.rank) == "number" and p.rank > 0 and p.rank <= 300 and p.name ~= nil end,
    },
    reputation = {
        order = 3, name = L["Reputation with a faction"], icon = "Interface\\Icons\\INV_Misc_Ribbon_01",
        title = function(g) return L["%s with %s"]:format(ns.StandingName(g.p.standing), g.p.name or "?") end,
        position = function(g, key) return repPosition(ns.Reputation(key, g.p.faction)) end,
        target = function(g) return STANDING_BASE[g.p.standing] or 0 end,
        status = function(g, key)
            local r = ns.Reputation(key, g.p.faction)
            if not r then return "?" end
            return ("%s %d / %d"):format(ns.StandingName(r.standing), r.cur or 0, r.max or 0)
        end,
        valid = function(p) return type(p.faction) == "number" and type(p.standing) == "number" and p.standing >= 2 and p.standing <= 8 end,
    },
    gold = {
        order = 4, name = L["Save gold"], icon = "Interface\\Icons\\INV_Misc_Coin_02",
        title = function(g)
            return (g.p.account and L["%dg on the whole account"] or L["Save %dg"]):format(gold(g.p.amount))
        end,
        position = function(g, key)
            if g.p.account then return ns.AccountGold() end
            local rec = ns.GetChar(key)
            return rec and rec.money or nil
        end,
        target = function(g) return g.p.amount end,
        status = function(g, key)
            local have = g.p.account and ns.AccountGold() or (ns.GetChar(key) or {}).money
            return ("%dg / %dg"):format(gold(have), gold(g.p.amount))
        end,
        valid = function(p) return type(p.amount) == "number" and p.amount > 0 end,
    },
    items = {
        order = 5, name = L["Gather items"], icon = "Interface\\Icons\\INV_Misc_Bag_10",
        title = function(g) return L["%d x %s"]:format(g.p.count, ns.ItemName(g.p.item)) end,
        position = function(g, key) return ns.ItemCount(key, g.p.item, g.p.account) end,
        target = function(g) return g.p.count end,
        status = function(g, key) return ("%d / %d"):format(ns.ItemCount(key, g.p.item, g.p.account), g.p.count) end,
        valid = function(p) return type(p.item) == "number" and type(p.count) == "number" and p.count > 0 end,
        iconOf = function(g) return ns.ItemIcon(g.p.item) end,
    },
    quest = {
        order = 6, name = L["Complete a quest"], icon = "Interface\\Icons\\INV_Misc_Note_01",
        title = function(g) return L["Quest: %s"]:format(g.p.name or ("#" .. g.p.quest)) end,
        position = function(g, key)
            local done = ns.QuestDone(key, g.p.quest)
            if done == nil then return nil end
            return done and 1 or 0
        end,
        target = function() return 1 end,
        status = function(g, key)
            local done = ns.QuestDone(key, g.p.quest)
            if done == nil then return "?" end
            return done and L["completed"] or L["not yet"]
        end,
        valid = function(p) return type(p.quest) == "number" and p.quest > 0 end,
    },
    manual = {
        order = 7, name = L["Something else (I tick it)"], icon = "Interface\\Icons\\INV_Misc_Note_06",
        title = function(g) return g.p.text or "?" end,
        position = function(g) return g.p.ticked and 1 or 0 end,
        target = function() return 1 end,
        status = function(g)
            local again = g.p.reset == "daily" and L["every day"] or (g.p.reset == "weekly" and L["every week"]) or nil
            return (g.p.ticked and L["done"] or L["to do"]) .. (again and (" · " .. again) or "")
        end,
        valid = function(p) return type(p.text) == "string" and p.text:gsub("%s", "") ~= "" end,
        manual = true,
    },
}

-- The kinds in their order, for the form: { { key =, def = } }.
function ns.GoalTypes()
    local list = {}
    for key, def in pairs(ns.GOAL_TYPES) do list[#list + 1] = { key = key, def = def } end
    table.sort(list, function(a, b) return a.def.order < b.def.order end)
    return list
end

ns.STANDING_BASE = STANDING_BASE
