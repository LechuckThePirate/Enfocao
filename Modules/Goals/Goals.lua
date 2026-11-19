local _, ns = ...
local L = ns.L

-- The goals, saved account-wide in EnfocaoDB.goals (a goal belongs to one character: goal.char). Progress is worked
-- out from what is known of the character (Data/Character.lua) every time it may have changed; a goal reached is
-- marked done (with the date) and announced. Manual goals are ticked by hand, and the repeating ones untick at the
-- daily / weekly reset.

function ns.Goals_All()
    ns.db.goals = ns.db.goals or {}
    return ns.db.goals
end

function ns.Goals_Get(id)
    for _, g in ipairs(ns.Goals_All()) do
        if g.id == id then return g end
    end
    return nil
end

-- A character's goals, active (done = false) or achieved (done = true), oldest first (achieved: newest first).
function ns.Goals_For(key, done)
    local list = {}
    for _, g in ipairs(ns.Goals_All()) do
        if g.char == key and (g.done and true or false) == (done and true or false) then list[#list + 1] = g end
    end
    table.sort(list, function(a, b)
        if done then return (a.doneAt or 0) > (b.doneAt or 0) end
        return (a.created or 0) < (b.created or 0)
    end)
    return list
end

-- A new goal for a character: nil and why when the parameters don't make one.
function ns.Goals_Add(key, typeKey, p)
    local def = ns.GOAL_TYPES[typeKey]
    if not def or not ns.GetChar(key) then return nil, L["Unknown character."] end
    p = p or {}
    if not def.valid(p, key) then return nil, L["Check the values: that goal can't be set."] end
    ns.db.nextGoal = (ns.db.nextGoal or 0) + 1
    local goal = { id = ns.db.nextGoal, char = key, type = typeKey, p = p, created = ns.Now(), done = false }
    -- where the character is now: the bar starts there
    if not def.manual then p.start = def.position(goal, key) end
    if typeKey == "quest" then
        local store = ns.Store()
        if store then store.WatchQuest(p.quest) end -- every character records it from now on
    end
    table.insert(ns.Goals_All(), goal)
    ns.Goals_Check()
    return goal
end

function ns.Goals_Remove(id)
    for i, g in ipairs(ns.Goals_All()) do
        if g.id == id then
            table.remove(ns.Goals_All(), i)
            return true
        end
    end
    return false
end

-- Where a goal stands: { fraction = 0..1, status = text, known = (false: no data about that character), done = }.
function ns.Goals_Progress(goal)
    local def = ns.GOAL_TYPES[goal.type]
    if not def then return { fraction = 0, status = "?", known = false, done = false } end
    local pos = def.position(goal, goal.char)
    local target = def.target(goal)
    if pos == nil then return { fraction = 0, status = def.status(goal, goal.char), known = false, done = false } end
    local start = goal.p.start
    if not start or start >= target then start = math.min(0, target) end
    local fraction = (pos - start) / math.max(1e-9, target - start)
    fraction = math.max(0, math.min(1, fraction))
    return { fraction = fraction, status = def.status(goal, goal.char), known = true, done = pos >= target }
end

function ns.Goals_Title(goal)
    local def = ns.GOAL_TYPES[goal.type]
    return def and def.title(goal) or "?"
end

function ns.Goals_Icon(goal)
    local def = ns.GOAL_TYPES[goal.type]
    if not def then return 134400 end
    if def.iconOf then return def.iconOf(goal) end
    if goal.type == "profession" and goal.p.icon then return goal.p.icon end
    return def.icon
end

-- A goal reached: in the chat, with a sound and (for the playing character) a message in the middle of the screen.
function ns.Goals_Announce(goal)
    local rec = ns.GetChar(goal.char)
    local who = ns.IsMe(goal.char) and "" or (" (" .. ns.ColorName(rec) .. ")")
    ns.Print(L["Goal reached: %s"]:format("|cffffd100" .. ns.Goals_Title(goal) .. "|r") .. who)
    if not ns.IsMe(goal.char) then return end
    if ns.settings.sound and PlaySound then pcall(PlaySound, (SOUNDKIT and SOUNDKIT.UI_QUEST_COMPLETE) or 878) end
    if ns.settings.centerMessage and RaidNotice_AddMessage and RaidWarningFrame then
        pcall(RaidNotice_AddMessage, RaidWarningFrame, L["Goal reached: %s"]:format(ns.Goals_Title(goal)),
            { r = ns.ACCENT[1], g = ns.ACCENT[2], b = ns.ACCENT[3] })
    end
end

-- Repeating manual goals untick at their reset.
local function applyResets(now)
    for _, g in ipairs(ns.Goals_All()) do
        local reset = g.type == "manual" and g.p.reset
        if g.done and reset and reset ~= "none" then
            local last = ns.LastReset(reset)
            if last and (g.doneAt or 0) < last and last <= (now or ns.Now()) then
                g.done, g.doneAt, g.p.ticked = false, nil, false
            end
        end
    end
end

-- Looks at every active goal it can (the playing character's, and the others' with the store): the ones reached are
-- marked done and announced. Returns the goals just reached.
function ns.Goals_Check(now)
    now = now or ns.Now()
    applyResets(now)
    local reached = {}
    for _, g in ipairs(ns.Goals_All()) do
        if not g.done and not (ns.GOAL_TYPES[g.type] or {}).manual then
            local progress = ns.Goals_Progress(g)
            if progress.known and progress.done then
                g.done, g.doneAt = true, now
                reached[#reached + 1] = g
            end
        end
    end
    for _, g in ipairs(reached) do ns.Goals_Announce(g) end
    return reached
end

-- Ticks or unticks a manual goal (a repeating one comes back at its reset).
function ns.Goals_Tick(id)
    local g = ns.Goals_Get(id)
    if not g or g.type ~= "manual" then return end
    g.p.ticked = not g.p.ticked
    g.done = g.p.ticked
    g.doneAt = g.done and ns.Now() or nil
    if g.done then ns.Goals_Announce(g) end
end

-- Puts an achieved goal back among the active ones (it is reached again at once if it still is).
function ns.Goals_Reopen(id)
    local g = ns.Goals_Get(id)
    if not g then return end
    g.done, g.doneAt = false, nil
    if g.type == "manual" then g.p.ticked = false end
end

-- Everything that may move a goal: the store's changes, and the game's events for the playing character (the
-- store may not be installed). A burst of them checks once.
function ns.Goals_Init()
    local function changed() ns.Debounce("goals", 1, function()
        ns.Goals_Check()
        ns.UI_Refresh()
    end) end
    for _, event in ipairs({ "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP", "PLAYER_MONEY", "BAG_UPDATE_DELAYED", "SKILL_LINES_CHANGED",
        "UPDATE_FACTION", "QUEST_TURNED_IN", "CHAT_MSG_SKILL", "BANKFRAME_CLOSED" }) do
        ns.On(event, changed)
    end
    local store = ns.Store()
    if store then store.RegisterCallback(changed) end
end
