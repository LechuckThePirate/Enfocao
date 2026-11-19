local _, ns = ...
local L = ns.L

-- Today's plan: what to do in this session, sized to how long the player usually plays (Profile.lua: short, an
-- hour, long). Made once a day (at the daily reset it starts again) for each character, from:
--   * quick chores of the account, with the store: profession cooldowns ready, mail about to run out (5 min each)
--   * the manual goals still to tick (10 min each)
--   * a stretch of the other goals, the closest to done first: as much of each as fits in its share of the time
--     ("Raise Skinning by 15 points", "40% of a level"). A step is done when that stretch is, or the goal is.
-- Goals set later in the day join the plan. With nothing to plan, the best suggestions are offered as ideas.
--   EnfocaoDB.plan[key] = { day =, made =, lastGoal = (the newest goal then), minutes =, announced =, skipped = { [stepId] = true },
--                           steps = { { id =, kind = "goal" | "chore", goal =, from =, amount =, minutes =, text =, done = } } }

local SESSION_MINUTES = { short = 45, hour = 60, long = 120 }
local GOAL_STEPS = { short = 1, hour = 2, long = 3 }
local CHORE_MINUTES, MANUAL_MINUTES, GOAL_MINUTES = 5, 10, 20
local MAIL_SOON = 3 * 86400

local function levelsPerHour(level)
    if level < 10 then return 3 end
    if level < 20 then return 1.5 end
    if level < 30 then return 1 end
    if level < 40 then return 0.7 end
    if level < 50 then return 0.5 end
    return 0.35
end

-- How far a goal can move in some minutes (in its own units, as its `position`), and how that reads.
local STRETCH = {
    level = {
        amount = function(g, minutes)
            local rec = ns.GetChar(g.char) or {}
            local rate = levelsPerHour(rec.level or 1)
            local rested = ns.RestedShare(g.char)
            if rested and rested > 0.3 then rate = rate * 1.5 end
            return rate * minutes / 60
        end,
        text = function(g, amount)
            return L["Towards level %d: %d%% of a level"]:format(g.p.level, math.floor(amount * 100 + 0.5))
        end,
    },
    profession = {
        amount = function(_, minutes) return math.max(5, math.floor(25 * minutes / 60)) end,
        text = function(g, amount) return L["Raise %s by %d points"]:format(g.p.name or "?", math.floor(amount + 0.5)) end,
    },
    reputation = {
        amount = function(_, minutes) return math.max(200, math.floor(1200 * minutes / 60)) end,
        text = function(g, amount) return L["%d reputation with %s"]:format(math.floor(amount + 0.5), g.p.name or "?") end,
    },
    gold = {
        amount = function(g, minutes)
            local rec = ns.GetChar(g.char) or {}
            return math.max(1, math.floor((rec.level or 1) * minutes / 60)) * 10000
        end,
        text = function(_, amount)
            return L["Earn %dg (quests, farming, the auction house)"]:format(math.floor(amount / 10000 + 0.5))
        end,
    },
    items = {
        amount = function(g) return math.max(1, math.ceil((g.p.count or 1) / 4)) end,
        text = function(g, amount) return L["Gather %d more %s"]:format(math.floor(amount + 0.5), ns.ItemName(g.p.item)) end,
    },
    quest = {
        amount = function() return 1 end,
        text = function(g) return L["Work on the quest: %s"]:format(g.p.name or ("#" .. g.p.quest)) end,
    },
}

local function session()
    local profile = ns.Profile()
    return profile and SESSION_MINUTES[profile.session] and profile.session or "hour"
end

-- The day a plan belongs to: the last daily reset (a few seconds of jitter in the game's countdown don't count).
local function today(now)
    return ns.LastReset("daily") or ns.DayKey(now)
end

local function sameDay(a, b)
    if type(a) == "number" and type(b) == "number" then return math.abs(a - b) < 3600 end
    return a == b
end

local function position(g)
    local def = ns.GOAL_TYPES[g.type]
    return def and def.position(g, g.char) or nil
end

-- A stretch of a goal: from where it is now, as far as fits in `minutes` (never past the target).
local function goalStep(g, minutes)
    local def = ns.GOAL_TYPES[g.type]
    if def.manual then
        return { id = "g:" .. g.id, kind = "goal", goal = g.id, minutes = MANUAL_MINUTES }
    end
    local stretch, pos = STRETCH[g.type], position(g)
    if not stretch or pos == nil then return nil end
    local left = def.target(g) - pos
    if left <= 0 then return nil end
    return { id = "g:" .. g.id, kind = "goal", goal = g.id, from = pos, amount = math.min(left, stretch.amount(g, minutes)),
        minutes = minutes }
end

-- The account's chores (the playing character's plan only, with the store).
local function chores(key, now)
    local store = ns.Store()
    if not store or not ns.IsMe(key) then return {} end
    local list = {}
    for _, c in ipairs(store.Cooldowns(nil, true) or {}) do
        if #list < 3 and store.CooldownReady(c.cd, now) then
            list[#list + 1] = { id = "cd:" .. c.key .. ":" .. tostring(c.id), kind = "chore", minutes = CHORE_MINUTES,
                text = L["%s: %s is ready"]:format(c.rec.name or c.key, c.cd.name or "?"), icon = c.cd.icon }
        end
    end
    for _, c in ipairs(ns.Characters()) do
        local left = store.MailExpiresIn(c.rec, now)
        if left and left < MAIL_SOON then
            list[#list + 1] = { id = "mail:" .. c.key, kind = "chore", minutes = CHORE_MINUTES,
                text = L["%s: mail runs out in %s"]:format(c.rec.name or c.key, ns.FormatDuration(math.max(0, left))),
                icon = "Interface\\Icons\\INV_Letter_15" }
        end
    end
    return list
end

local function build(key, now)
    local budget = SESSION_MINUTES[session()]
    local plan = { day = today(now), made = now, lastGoal = ns.db.nextGoal or 0, minutes = budget, steps = {}, skipped = {} }
    local used = 0
    for _, s in ipairs(chores(key, now)) do
        plan.steps[#plan.steps + 1] = s
        used = used + s.minutes
    end
    local others = {}
    for _, g in ipairs(ns.Goals_For(key, false)) do
        if ns.GOAL_TYPES[g.type].manual then
            plan.steps[#plan.steps + 1] = goalStep(g)
            used = used + MANUAL_MINUTES
        else
            others[#others + 1] = { goal = g, fraction = ns.Goals_Progress(g).fraction }
        end
    end
    -- the closest to done first: finishing feels good
    table.sort(others, function(a, b) return a.fraction > b.fraction end)
    local left = budget - used
    local count = math.min(#others, GOAL_STEPS[session()], math.max(1, math.floor(left / GOAL_MINUTES)))
    local share = math.max(GOAL_MINUTES, math.floor(math.max(left, GOAL_MINUTES) / math.max(1, count)))
    local taken = 0
    for _, o in ipairs(others) do
        if taken >= count then break end
        local step = goalStep(o.goal, share)
        if step then
            plan.steps[#plan.steps + 1] = step
            taken = taken + 1
        end
    end
    return plan
end

local function savePlan(key, plan)
    ns.db.plan = ns.db.plan or {}
    ns.db.plan[key] = plan
    return plan
end

-- Today's plan of a character (made if there is none for today yet), with the goals set since it was made.
local function current(key, now)
    now = now or ns.Now()
    local plan = ns.db.plan and ns.db.plan[key]
    if not plan or not sameDay(plan.day, today(now)) then plan = savePlan(key, build(key, now)) end
    local inPlan = {}
    for _, s in ipairs(plan.steps) do inPlan[s.id] = true end
    for _, g in ipairs(ns.Goals_For(key, false)) do
        local id = "g:" .. g.id
        if not inPlan[id] and not plan.skipped[id] and g.id > (plan.lastGoal or 0) then
            local step = goalStep(g, GOAL_MINUTES)
            if step then plan.steps[#plan.steps + 1] = step end
        end
    end
    return plan
end

-- Where a step stands: { id, kind, text, icon, minutes, fraction, done, goal (the goal itself) }; nil for a step
-- whose goal was removed.
local function resolve(step)
    if step.kind == "chore" then
        return { id = step.id, kind = "chore", text = step.text, icon = step.icon or "Interface\\Icons\\INV_Misc_PocketWatch_01",
            minutes = step.minutes, fraction = step.done and 1 or 0, done = step.done and true or false }
    end
    local g = ns.Goals_Get(step.goal)
    if not g then return nil end
    local out = { id = step.id, kind = "goal", goal = g, icon = ns.Goals_Icon(g), minutes = step.minutes }
    if ns.GOAL_TYPES[g.type].manual then
        out.text, out.done = ns.Goals_Title(g), g.done and true or false
        out.fraction = out.done and 1 or 0
        return out
    end
    out.text = STRETCH[g.type].text(g, step.amount)
    local pos = position(g)
    if g.done then
        out.fraction, out.done = 1, true
    elseif pos == nil then
        out.fraction, out.done = 0, false
    else
        out.fraction = math.max(0, math.min(1, (pos - step.from) / math.max(1e-9, step.amount)))
        out.done = pos >= step.from + step.amount - 1e-6
    end
    return out
end

-- Today's plan, ready to show: { minutes (the session), used, done (steps done), steps = { resolved }, ideas }.
-- `ideas` are the best suggestions when no goal is in the plan.
function ns.Plan_For(key, now)
    local plan = current(key, now)
    local out = { minutes = plan.minutes, used = 0, done = 0, steps = {}, ideas = {} }
    local anyGoal = false
    for _, step in ipairs(plan.steps) do
        local s = not plan.skipped[step.id] and resolve(step)
        if s then
            out.steps[#out.steps + 1] = s
            out.used = out.used + (s.minutes or 0)
            if s.done then out.done = out.done + 1 end
            if s.kind == "goal" then anyGoal = true end
        end
    end
    if not anyGoal then
        for i, s in ipairs(ns.Advice_For(key, now)) do
            if i > 3 then break end
            out.ideas[#out.ideas + 1] = s
        end
    end
    return out
end

-- A new plan for today, from scratch (what was skipped comes back).
function ns.Plan_New(key, now)
    now = now or ns.Now()
    return savePlan(key, build(key, now))
end

-- Ticks a chore, or the manual goal of a step.
function ns.Plan_Tick(key, id)
    local plan = current(key)
    for _, step in ipairs(plan.steps) do
        if step.id == id then
            if step.kind == "chore" then
                step.done = not step.done
            else
                local g = ns.Goals_Get(step.goal)
                if g and g.type == "manual" then ns.Goals_Tick(g.id) end
            end
        end
    end
    ns.Plan_Check(key)
end

-- Leaves a step out of today's plan.
function ns.Plan_Skip(key, id)
    current(key).skipped[id] = true
end

-- Every step done: said once (the playing character's plan).
function ns.Plan_Check(key)
    key = key or ns.MyKey()
    if not ns.IsMe(key) then return false end
    local plan = current(key)
    local view = ns.Plan_For(key)
    if #view.steps == 0 or view.done < #view.steps or plan.announced then return false end
    plan.announced = true
    ns.Print(L["Today's plan is done. Well played!"])
    if ns.settings.sound and PlaySound then pcall(PlaySound, (SOUNDKIT and SOUNDKIT.UI_QUEST_ROLLING_FORWARD_01) or 878) end
    return true
end

ns.SESSION_MINUTES = SESSION_MINUTES
