local _, ns = ...
local L = ns.L

-- Suggested goals: small advisors look at what is known of a character and propose goals, each with why and a score
-- (how much it brings and how close it is: 0-100). The player accepts one (it becomes a goal), leaves it for later
-- (it comes back in a few days) or dismisses it (it never comes back). Nothing already set as a goal is suggested.
--   advisor(key, rec) -> { { id =, goal = { type =, p = }, why =, score = } }
-- `id` names the suggestion for "later" / "dismiss" ("level:40", "prof:Fishing:225"...), so a new target is a new one.

local MAX_LEVEL = 60
local SNOOZE = 3 * 86400

-- Levels worth aiming at, and what each brings.
local MILESTONES = {
    { level = 10, why = "talents, and your class's quests" },
    { level = 20, why = "new spells and the dungeons of the middle levels" },
    { level = 30, why = "more talents, and five levels from thinking of your mount" },
    { level = 40, why = "your mount, and better armor for many classes" },
    { level = 50, why = "the dungeons of Blackrock and the last zones" },
    { level = 60, why = "the top level: raids, attunements and the end game" },
}

-- Profession ranks: the cap of each, the next one and the level its trainer asks for.
local NEXT_RANK = {
    [75] = { name = "Journeyman", level = 10, cap = 150 },
    [150] = { name = "Expert", level = 20, cap = 225 },
    [225] = { name = "Artisan", level = 35, cap = 300 },
}

-- Attunements and keys worth starting once the level allows (quest per faction where they differ).
ns.ATTUNEMENT_GOALS = {
    { id = "brd", name = "Shadowforge Key (Blackrock Depths)", level = 48, quest = { Alliance = 3802, Horde = 3802 } },
    { id = "mc", name = "Molten Core attunement", level = 55, quest = { Alliance = 7848, Horde = 7848 } },
    { id = "scholo", name = "Skeleton Key (Scholomance)", level = 55, quest = { Alliance = 5505, Horde = 5511 } },
    { id = "ony", name = "Onyxia's Lair attunement", level = 55, quest = { Alliance = 6502, Horde = 6602 } },
    { id = "ubrs", name = "Seal of Ascension (Upper Blackrock Spire)", level = 57, quest = { Alliance = 4743, Horde = 4743 } },
    { id = "bwl", name = "Blackwing Lair attunement", level = 58, quest = { Alliance = 7761, Horde = 7761 } },
}

local SLOT_NAMES = {
    [1] = "head", [3] = "shoulders", [5] = "chest", [6] = "waist", [7] = "legs", [8] = "feet", [9] = "wrists",
    [10] = "hands", [15] = "back", [16] = "main hand weapon",
}

ns.MILESTONES, ns.NEXT_RANK, ns.SLOT_NAMES = MILESTONES, NEXT_RANK, SLOT_NAMES -- (for the translations test)

local function round5(n) return math.floor(n / 5 + 0.5) * 5 end

local advisors = {}

-- 1. The next milestone level.
advisors[#advisors + 1] = function(_, rec)
    local level = rec.level or 1
    if level >= MAX_LEVEL then return {} end
    for _, m in ipairs(MILESTONES) do
        if m.level > level then
            local left = m.level - level
            return { {
                id = "level:" .. m.level, goal = { type = "level", p = { level = m.level } }, tags = { leveling = true },
                why = L["Level %d brings %s. You are %d levels away."]:format(m.level, L[m.why], left),
                score = math.max(40, 85 - left * 6),
            } }
        end
    end
    return {}
end

-- 2. Rested experience piled up: a good time to level.
advisors[#advisors + 1] = function(key, rec)
    local share = ns.RestedShare(key)
    local level = rec.level or 1
    if not share or share < 0.75 or level >= MAX_LEVEL then return {} end
    return { {
        id = "rested:" .. (level + 1), goal = { type = "level", p = { level = level + 1 } }, tags = { leveling = true },
        why = L["You have %d%% of a level in rested experience: every kill is worth double. A good time to level."]:format(
            math.floor(share * 100)),
        score = 70 + math.floor(math.min(share, 1.5) * 15),
    } }
end

-- 3. The mount at 40: the gold for it.
advisors[#advisors + 1] = function(_, rec)
    local level, money = rec.level or 1, rec.money
    local need = 100 * 10000
    if level < 30 or level >= 40 or not money or money >= need then return {} end
    return { {
        id = "mount", goal = { type = "gold", p = { amount = need } }, tags = { gold = true, leveling = true },
        why = L["At level 40 you can ride: the mount and the riding skill cost about 100 gold. You have %d."]:format(math.floor(money / 10000)),
        score = 55 + (level - 30) * 3,
    } }
end

-- 4. Professions behind the level, or at the top of their rank.
advisors[#advisors + 1] = function(_, rec)
    local list = {}
    local level = rec.level or 1
    for _, p in ipairs(rec.professions or {}) do
        local rank, max = p.rank or 0, p.max or 0
        if p.primary or p.slot == 6 then -- primary professions and First Aid
            local nextRank = NEXT_RANK[max]
            if rank >= max and nextRank and level >= nextRank.level then
                list[#list + 1] = {
                    id = ("prof:%s:%d"):format(p.name, nextRank.cap), tags = { professions = true },
                    goal = { type = "profession", p = { name = p.name, skillLine = p.skillLine, icon = p.icon, rank = nextRank.cap } },
                    why = L["Your %s is at the top of its rank (%d/%d): learn %s from your trainer and take it to %d."]:format(
                        p.name, rank, max, L[nextRank.name], nextRank.cap),
                    score = 75,
                }
            else
                local expected = math.min(max, 300, round5(level * 5))
                if rank + 30 <= expected then
                    list[#list + 1] = {
                        id = ("prof:%s:%d"):format(p.name, expected), tags = { professions = true },
                        goal = { type = "profession", p = { name = p.name, skillLine = p.skillLine, icon = p.icon, rank = expected } },
                        why = L["Your %s is at %d: at your level it could be at %d."]:format(p.name, rank, expected),
                        score = math.min(80, 45 + math.floor((expected - rank) / 5)),
                    }
                end
            end
        end
    end
    return list
end

-- 5. First Aid: cheap, and it saves lives.
advisors[#advisors + 1] = function(_, rec)
    local level = rec.level or 1
    if level < 5 then return {} end
    for _, p in ipairs(rec.professions or {}) do
        if p.slot == 6 then return {} end -- known: the professions advisor follows it
    end
    if rec.professions == nil then return {} end
    return { {
        id = "firstaid", goal = { type = "manual", p = { text = L["Learn First Aid"] } }, tags = { professions = true },
        why = L["First Aid costs almost nothing and heals you between fights: every class wants it."],
        score = 50,
    } }
end

-- 6. Reputations about to go up.
advisors[#advisors + 1] = function(key)
    local list = {}
    for _, f in ipairs(ns.Factions(key)) do
        local r = ns.Reputation(key, f.id)
        if r and r.standing and r.standing >= 4 and r.standing <= 7 and (r.max or 0) > 0 then
            local share = (r.cur or 0) / r.max
            if share >= 0.6 then
                list[#list + 1] = {
                    id = ("rep:%d:%d"):format(f.id, r.standing + 1), tags = { reputation = true },
                    goal = { type = "reputation", p = { faction = f.id, name = f.name, standing = r.standing + 1 } },
                    why = L["You are %d%% of the way to %s with %s."]:format(math.floor(share * 100), ns.StandingName(r.standing + 1), f.name),
                    score = 40 + math.floor(share * 40),
                }
            end
        end
    end
    return list
end

-- 7. Attunements and keys the level allows.
advisors[#advisors + 1] = function(key, rec)
    local list = {}
    local level, faction = rec.level or 1, rec.faction or "Alliance"
    for _, a in ipairs(ns.ATTUNEMENT_GOALS) do
        local quest = a.quest[faction] or a.quest.Alliance
        if level >= a.level and ns.QuestDone(key, quest) == false then
            list[#list + 1] = {
                id = "att:" .. a.id, goal = { type = "quest", p = { quest = quest, name = L[a.name] } }, tags = { raids = true, dungeons = true },
                why = L["At level %d you can start it: one step closer to the end game."]:format(a.level),
                score = 55 + math.min(15, level - a.level),
            }
        end
    end
    return list
end

-- 8. A piece of gear far below the rest.
advisors[#advisors + 1] = function(key)
    local gear = ns.Gear(key)
    if not gear then return {} end
    local levels, sum, n = {}, 0, 0
    for slot in pairs(SLOT_NAMES) do
        local level = ns.ItemLevel(gear[slot])
        if level then
            levels[slot] = level
            sum, n = sum + level, n + 1
        end
    end
    if n < 4 then return {} end
    local average = sum / n
    if average < 15 then return {} end
    local list = {}
    for slot, name in pairs(SLOT_NAMES) do
        local level = levels[slot]
        if level and level < average * 0.65 then
            list[#list + 1] = {
                id = ("gear:%d"):format(slot), goal = { type = "manual", p = { text = L["Better %s"]:format(L[name]) } }, tags = { gear = true },
                why = L["Your %s is item level %d; the rest of your gear is around %d."]:format(L[name], level, math.floor(average)),
                score = 35 + math.floor((average - level) / average * 30),
            }
        end
    end
    return list
end

---------------------------------------------------------------------------------------------------
-- Suggestions, minus what is set already, dismissed or left for later
---------------------------------------------------------------------------------------------------
local function adviceState(key)
    ns.db.advice = ns.db.advice or {}
    local state = ns.db.advice[key]
    if not state then
        state = { dismissed = {}, later = {} }
        ns.db.advice[key] = state
    end
    return state
end

-- What would make a suggestion the same as a goal already set.
local function signature(goal)
    local p = goal.p
    if goal.type == "level" then return "level" end
    if goal.type == "profession" then return "profession:" .. tostring(p.name) end
    if goal.type == "reputation" then return "reputation:" .. tostring(p.faction) end
    if goal.type == "gold" then return "gold" end
    if goal.type == "quest" then return "quest:" .. tostring(p.quest) end
    if goal.type == "items" then return "items:" .. tostring(p.item) end
    return "manual:" .. tostring(p.text)
end

-- The suggestions for a character, best first: { { id, goal, why, score } }.
function ns.Advice_For(key, now)
    now = now or ns.Now()
    local rec = ns.GetChar(key)
    if not rec then return {} end
    local state = adviceState(key)
    local taken = {}
    for _, g in ipairs(ns.Goals_For(key, false)) do taken[signature(g)] = true end
    local candidates = {}
    for _, advisor in ipairs(advisors) do
        local ok, found = pcall(advisor, key, rec)
        for _, s in ipairs(ok and found or {}) do
            if not taken[signature(s.goal)] and not state.dismissed[s.id] and (state.later[s.id] or 0) <= now then
                -- the player's style and likes weigh it (Profile.lua)
                s.score = math.min(100, math.floor(s.score * ns.Profile_Weight(s.tags) + 0.5))
                candidates[#candidates + 1] = s
            end
        end
    end
    table.sort(candidates, function(a, b) return a.score > b.score end)
    -- one suggestion per kind of goal: the best one (a level goal from the rested experience beats the milestone)
    local list, seen = {}, {}
    for _, s in ipairs(candidates) do
        local sig = signature(s.goal)
        if not seen[sig] and not seen[s.id] then
            seen[sig], seen[s.id] = true, true
            list[#list + 1] = s
        end
    end
    return list
end

-- Accept: the suggestion becomes a goal.
function ns.Advice_Accept(key, suggestion)
    return ns.Goals_Add(key, suggestion.goal.type, ns.Copy(suggestion.goal.p))
end

function ns.Advice_Later(key, id, now)
    adviceState(key).later[id] = (now or ns.Now()) + SNOOZE
end

function ns.Advice_Dismiss(key, id)
    adviceState(key).dismissed[id] = true
end

-- Every dismissed or postponed suggestion of a character comes back.
function ns.Advice_Reset(key)
    if ns.db.advice then ns.db.advice[key] = nil end
end
