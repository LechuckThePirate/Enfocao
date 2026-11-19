local _, ns = ...
local L = ns.L

-- Two views of the character the window shows: its active goals (with their progress; click a manual one to tick
-- it, right-click any for its menu) and the ones achieved (with when, and how long they took).

local ACTIVE_COLUMNS = {
    { title = L["Goal"], width = 330 },
    { title = L["Progress"], width = 260, descFirst = true },
    { title = L["Set"] },
}
local DONE_COLUMNS = {
    { title = L["Goal"], width = 330 },
    { title = L["Achieved"], width = 200, descFirst = true },
    { title = L["It took"] },
}

local function goalMenu(goal, anchor)
    local options = {}
    if goal.type == "manual" then
        options[#options + 1] = { name = goal.done and L["Untick"] or L["Tick as done"], run = function() ns.Goals_Tick(goal.id) end }
    end
    if goal.done then
        options[#options + 1] = { name = L["Back to the active goals"], run = function() ns.Goals_Reopen(goal.id) end }
    end
    options[#options + 1] = { name = L["Remove this goal"], color = { 1, 0.4, 0.4 }, run = function() ns.Goals_Remove(goal.id) end }
    ns.PopupMenu(anchor, options, function(opt)
        opt.run()
        ns.UI_Refresh(true)
    end, 200, "right")
end

local function activeRow(goal)
    local progress = ns.Goals_Progress(goal)
    local color = progress.known and { 1, 1, 1 } or { 0.55, 0.55, 0.55 }
    return {
        cells = {
            { text = ns.Goals_Title(goal), icon = ns.Goals_Icon(goal), color = { 1, 0.9, 0.6 } },
            { text = progress.status, color = color, bar = progress.fraction, barColor = ns.ACCENT },
            { text = ns.FormatAgo(goal.created), color = { 0.7, 0.7, 0.7 } },
        },
        sort = { ns.Goals_Title(goal), progress.fraction, goal.created },
        onClick = function(_, button, frame)
            if button == "RightButton" then return goalMenu(goal, frame) end
            if goal.type == "manual" then
                ns.Goals_Tick(goal.id)
                ns.UI_Refresh(true)
            end
        end,
        tooltip = function()
            local lines = { ns.Goals_Title(goal), { progress.status, 1, 1, 1 } }
            if not progress.known then
                lines[#lines + 1] = { L["Unknown until this character logs in (with BakalaoStudios DataStore)."], 0.7, 0.7, 0.7 }
            end
            if goal.type == "manual" then lines[#lines + 1] = { L["Click: tick it. Right-click: menu."], 0.6, 0.6, 0.6 }
            else lines[#lines + 1] = { L["Right-click: menu."], 0.6, 0.6, 0.6 } end
            return lines
        end,
    }
end

local function doneRow(goal)
    local took = (goal.doneAt and goal.created) and ns.FormatDuration(goal.doneAt - goal.created) or "-"
    return {
        cells = {
            { text = ns.Goals_Title(goal), icon = ns.Goals_Icon(goal), color = { 0.6, 1, 0.6 } },
            { text = goal.doneAt and date("%d/%m/%Y %H:%M", goal.doneAt) or "-", color = { 0.85, 0.85, 0.85 } },
            { text = took, color = { 0.7, 0.7, 0.7 } },
        },
        sort = { ns.Goals_Title(goal), goal.doneAt or 0, (goal.doneAt or 0) - (goal.created or 0) },
        onClick = function(_, button, frame) if button == "RightButton" then goalMenu(goal, frame) end end,
    }
end

ns.UI_RegisterView({
    key = "goals",
    emblem = "goals",
    order = 10,
    title = L["Goals"],
    text = L["What this character is going for, and how far it is. They update by themselves."],
    build = function(content)
        content.add = ns.UI_Button(content, L["+ New goal"], 140, function() ns.NewGoal_Show() end)
        content.add:SetPoint("TOPLEFT", 0, -2)
        content.count = ns.UI_Text(content, "GameFontHighlight", "")
        content.count:SetPoint("LEFT", content.add, "RIGHT", 12, 0)
        content.table = ns.UI_Table(content, ACTIVE_COLUMNS)
        content.table:SetPoint("TOPLEFT", 0, -32)
        content.table:SetPoint("BOTTOMRIGHT")
    end,
    refresh = function(content)
        local goals = ns.Goals_For(ns.ViewKey(), false)
        local rows = {}
        for _, g in ipairs(goals) do rows[#rows + 1] = activeRow(g) end
        content.table:SetRows(rows)
        content.table:SetEmptyText(L["No goals yet. Set one with \"+ New goal\": a level, a profession, a reputation, gold, items..."])
        content.count:SetText(#goals == 1 and L["1 active goal"] or L["%d active goals"]:format(#goals))
    end,
})

ns.UI_RegisterView({
    key = "achieved",
    emblem = "achieved",
    order = 30,
    title = L["Achieved"],
    text = L["Every goal reached, and how long it took."],
    build = function(content)
        content.table = ns.UI_Table(content, DONE_COLUMNS)
        content.table:SetPoint("TOPLEFT")
        content.table:SetPoint("BOTTOMRIGHT")
        content.table.sortCol, content.table.sortDesc = 2, true
    end,
    refresh = function(content)
        local rows = {}
        for _, g in ipairs(ns.Goals_For(ns.ViewKey(), true)) do rows[#rows + 1] = doneRow(g) end
        content.table:SetRows(rows)
        content.table:SetEmptyText(L["Nothing achieved yet: it'll come."])
    end,
})
