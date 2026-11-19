local _, ns = ...
local L = ns.L

-- The Today view: the plan for this session (Plan/Plan.lua), sized to the player's style. Click a chore or a manual
-- goal to tick it; right-click a step to leave it out of today. With no goal in the plan, the best suggestions show
-- as ideas (click one to set it as a goal).

local COLUMNS = {
    { title = L["Step"], width = 420 },
    { title = L["Progress"], width = 220 },
    { title = L["Time"] },
}

local function stepMenu(key, step, anchor)
    local options = {
        { name = L["Leave it out of today"], run = function() ns.Plan_Skip(key, step.id) end },
    }
    if step.goal then
        options[#options + 1] = { name = L["Open the goals"], run = function() ns.UI_Show("goals") end }
        for _, opt in ipairs(ns.Goals_AddonOptions(step.goal)) do options[#options + 1] = opt end
    end
    ns.PopupMenu(anchor, options, function(opt)
        opt.run()
        ns.UI_Refresh(true)
    end, 200, "right")
end

local function stepRow(key, step)
    local tickable = step.kind == "chore" or (step.goal and step.goal.type == "manual")
    return {
        cells = {
            { text = step.text, icon = step.icon, color = step.done and { 0.6, 1, 0.6 } or { 1, 0.9, 0.6 } },
            { text = step.done and L["done"] or ("%d%%"):format(math.floor(step.fraction * 100)), bar = step.fraction,
                barColor = ns.ACCENT, color = { 1, 1, 1 } },
            { text = L["~%d min"]:format(step.minutes or 0), color = { 0.7, 0.7, 0.7 } },
        },
        onClick = function(_, button, frame)
            if button == "RightButton" then return stepMenu(key, step, frame) end
            if tickable then
                ns.Plan_Tick(key, step.id)
                ns.UI_Refresh(true)
            end
        end,
        tooltip = function()
            local lines = { step.text }
            if step.goal then lines[#lines + 1] = { L["For the goal: %s"]:format(ns.Goals_Title(step.goal)), 1, 1, 1 } end
            lines[#lines + 1] = { tickable and L["Click: tick it. Right-click: menu."] or L["Right-click: menu."], 0.6, 0.6, 0.6 }
            return lines
        end,
    }
end

local function ideaRow(key, s)
    local goal = { type = s.goal.type, p = s.goal.p }
    return {
        cells = {
            { text = L["Idea: %s"]:format(ns.Goals_Title(goal)), icon = ns.Goals_Icon(goal), color = { 0.95, 0.6, 0.85 } },
            { text = "", color = { 1, 1, 1 } },
            { text = "", color = { 0.7, 0.7, 0.7 } },
        },
        onClick = function(_, button)
            if button ~= "LeftButton" then return end
            local made = ns.Advice_Accept(key, s)
            if made then ns.Print(L["New goal: %s"]:format("|cffffd100" .. ns.Goals_Title(made) .. "|r")) end
            ns.UI_Refresh(true)
        end,
        tooltip = function()
            return { ns.Goals_Title(goal), { s.why, 1, 1, 1 }, { L["Click: set it as a goal."], 0.6, 0.6, 0.6 } }
        end,
    }
end

local function sessionName()
    local profile = ns.Profile()
    for _, s in ipairs(ns.PROFILE_SESSIONS) do
        if profile and profile.session == s.key then return L[s.name] end
    end
    return L["About an hour"]
end

ns.UI_RegisterView({
    key = "today",
    emblem = "today",
    order = 5,
    title = L["Today"],
    text = L["Your plan for this session: a bit of each goal, sized to the time you usually play."],
    build = function(content)
        content.summary = ns.UI_Text(content, "GameFontHighlight", "", 560)
        content.summary:SetPoint("TOPLEFT", 4, -6)
        content.style = ns.UI_Button(content, L["Your style"], 110, function() ns.Profile_Show() end)
        content.style:SetPoint("TOPRIGHT", 0, -2)
        content.new = ns.UI_Button(content, L["New plan"], 110, function()
            ns.Plan_New(ns.ViewKey())
            ns.UI_Refresh(true)
        end)
        content.new:SetPoint("RIGHT", content.style, "LEFT", -8, 0)
        content.table = ns.UI_Table(content, COLUMNS)
        content.table:SetPoint("TOPLEFT", 0, -32)
        content.table:SetPoint("BOTTOMRIGHT")
    end,
    refresh = function(content)
        local key = ns.ViewKey()
        local plan = ns.Plan_For(key)
        local rows = {}
        for _, step in ipairs(plan.steps) do rows[#rows + 1] = stepRow(key, step) end
        for _, s in ipairs(plan.ideas) do rows[#rows + 1] = ideaRow(key, s) end
        content.table:SetRows(rows)
        content.table:SetEmptyText(L["Nothing planned: set a goal, or accept a suggestion."])
        content.summary:SetText(L["%s: %d of %d steps done, about %d of %d minutes planned."]:format(
            "|cffd94fb0" .. sessionName() .. "|r", plan.done, #plan.steps, plan.used, plan.minutes))
    end,
})
