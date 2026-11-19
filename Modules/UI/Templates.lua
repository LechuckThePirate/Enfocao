local _, ns = ...
local L = ns.L

-- The Templates view: sets of goals that go together, the ones that fit the character the window shows. Click one
-- to set its goals (only those it doesn't have or go for yet).

local COLUMNS = {
    { title = L["Template"], width = 300 },
    { title = L["What it sets"], width = 380 },
    { title = L["Goals"] },
}

local function row(key, entry)
    local t = entry.template
    local titles = {}
    for _, g in ipairs(entry.goals) do titles[#titles + 1] = ns.Goals_Title({ type = g.type, p = g.p }) end
    return {
        cells = {
            { text = L[t.name], icon = t.icon, color = { 1, 0.9, 0.6 } },
            { text = table.concat(titles, ", "), color = { 0.9, 0.85, 0.9 } },
            { text = tostring(#entry.goals), color = { 0.7, 0.7, 0.7 } },
        },
        onClick = function(_, button)
            if button ~= "LeftButton" then return end
            local n = ns.Template_Apply(key, t)
            ns.Print(L["%s: %d goals set."]:format("|cffffd100" .. L[t.name] .. "|r", n))
            ns.UI_Refresh(true)
        end,
        tooltip = function()
            local lines = { L[t.name], { L[t.text], 1, 1, 1 } }
            for _, title in ipairs(titles) do lines[#lines + 1] = { "- " .. title, 1, 0.9, 0.6 } end
            lines[#lines + 1] = { L["Click: set these goals."], 0.6, 0.6, 0.6 }
            return lines
        end,
    }
end

ns.UI_RegisterView({
    key = "templates",
    emblem = "templates",
    order = 25,
    title = L["Templates"],
    text = L["Goals that go together, set in one go: only what this character still needs."],
    build = function(content)
        content.table = ns.UI_Table(content, COLUMNS)
        content.table:SetPoint("TOPLEFT")
        content.table:SetPoint("BOTTOMRIGHT")
    end,
    refresh = function(content)
        local key = ns.ViewKey()
        local rows = {}
        for _, entry in ipairs(ns.Templates_For(key)) do rows[#rows + 1] = row(key, entry) end
        content.table:SetRows(rows)
        content.table:SetEmptyText(L["No template fits this character right now."])
    end,
})
