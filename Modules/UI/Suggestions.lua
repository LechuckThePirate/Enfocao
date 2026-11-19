local _, ns = ...
local L = ns.L

-- The Suggestions view: what Enfocao would advise the character the window shows, best first, each with why and
-- three buttons (accept: it becomes a goal; later: it comes back in a few days; dismiss: never again). On top, the
-- player's style (the "Your style" form, Profile.lua), which weighs them; it opens by itself the first time.
local ROW_H, GAP = 66, 6

local function makeRow(content, i)
    local row = CreateFrame("Frame", nil, content.list, "BackdropTemplate")
    row:SetHeight(ROW_H)
    row:SetPoint("TOPLEFT", 0, -(i - 1) * (ROW_H + GAP))
    row:SetPoint("RIGHT", 0, 0)
    row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    row:SetBackdropColor(0.08, 0.05, 0.08, 0.8)
    row:SetBackdropBorderColor(ns.ACCENT[1], ns.ACCENT[2], ns.ACCENT[3], 0.35)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(40, 40)
    row.icon:SetPoint("LEFT", 10, 0)
    row.title = ns.UI_Text(row, "GameFontNormal", "")
    row.title:SetPoint("TOPLEFT", 60, -10)
    row.why = ns.UI_Text(row, "GameFontHighlightSmall", "", 470)
    row.why:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -4)
    row.why:SetTextColor(0.85, 0.8, 0.85)
    row.score = row:CreateTexture(nil, "ARTWORK")
    row.score:SetPoint("BOTTOMLEFT", 60, 6)
    row.score:SetHeight(3)
    row.accept = ns.UI_Button(row, L["Accept"], 80, nil, 22)
    row.accept:SetPoint("TOPRIGHT", -10, -10)
    row.later = ns.UI_Button(row, L["Later"], 80, nil, 22)
    row.later:SetPoint("TOPRIGHT", row.accept, "BOTTOMRIGHT", 0, -4)
    row.dismiss = CreateFrame("Button", nil, row, "UIPanelCloseButton")
    row.dismiss:SetSize(22, 22)
    row.dismiss:SetPoint("RIGHT", row.accept, "LEFT", -6, 0)
    row.dismiss:SetScript("OnEnter", function(self) ns.UI_ShowTooltip(self, { L["Dismiss: don't suggest it again"] }) end)
    row.dismiss:SetScript("OnLeave", GameTooltip_Hide)
    return row
end

local function draw(content)
    local key = ns.ViewKey()
    local list = ns.Advice_For(key)
    content.suggestions = list
    local height = content.list:GetHeight() or 400
    local fits = math.max(1, math.floor((height + GAP) / (ROW_H + GAP)))
    content.offset = math.max(0, math.min(content.offset or 0, #list - fits))
    for i = 1, fits do
        local s = list[content.offset + i]
        local row = content.rows[i] or makeRow(content, i)
        content.rows[i] = row
        if s then
            local goal = { type = s.goal.type, p = s.goal.p }
            row.icon:SetTexture(ns.Goals_Icon(goal))
            local title = ns.Goals_Title(goal)
            if s.key and s.key ~= key then title = title .. " (" .. ns.ColorName(ns.GetChar(s.key)) .. ")" end
            row.title:SetText(title)
            row.why:SetText(s.why)
            row.score:SetWidth(math.max(4, 4 * s.score))
            row.score:SetColorTexture(ns.ACCENT[1], ns.ACCENT[2], ns.ACCENT[3], 0.7)
            row.accept:SetScript("OnClick", function()
                local made = ns.Advice_Accept(key, s)
                if made then ns.Print(L["New goal: %s"]:format("|cffffd100" .. ns.Goals_Title(made) .. "|r")) end
                ns.UI_Refresh(true)
            end)
            row.later:SetScript("OnClick", function()
                ns.Advice_Later(key, s.id)
                ns.UI_Refresh(true)
            end)
            row.dismiss:SetScript("OnClick", function()
                ns.Advice_Dismiss(key, s.id)
                ns.UI_Refresh(true)
            end)
            row:Show()
        else
            row:Hide()
        end
    end
    for i = fits + 1, #content.rows do content.rows[i]:Hide() end
    content.empty:SetShown(#list == 0)
    local more = #list - content.offset - fits
    content.more:SetText(more > 0 and L["Scroll for %d more"]:format(more) or "")
end

ns.UI_RegisterView({
    key = "suggestions",
    emblem = "suggestions",
    order = 20,
    title = L["Suggestions"],
    text = L["What I'd advise you to spend your time on, from what I know of this character and your style."],
    build = function(content)
        content.style = ns.UI_Text(content, "GameFontHighlight", "")
        content.style:SetPoint("TOPLEFT", 4, -6)
        content.styleButton = ns.UI_Button(content, L["Your style"], 110, function() ns.Profile_Show() end)
        content.styleButton:SetPoint("TOPRIGHT", 0, -2)
        content.list = CreateFrame("Frame", nil, content)
        content.list:SetPoint("TOPLEFT", 0, -32)
        content.list:SetPoint("BOTTOMRIGHT", 0, 16)
        content.list:EnableMouseWheel(true)
        content.list:SetScript("OnMouseWheel", function(_, delta)
            content.offset = math.max(0, (content.offset or 0) - delta)
            draw(content)
        end)
        content.rows = {}
        content.empty = ns.UI_Text(content.list, "GameFontDisable", L["Nothing to suggest right now: you're on track."], 500)
        content.empty:SetPoint("TOPLEFT", 4, -10)
        content.more = ns.UI_Text(content, "GameFontDisableSmall", "")
        content.more:SetPoint("BOTTOMRIGHT", 0, 0)
    end,
    refresh = function(content)
        local profile = ns.Profile()
        local styleName = L["not set yet"]
        for _, s in ipairs(ns.PROFILE_STYLES) do
            if profile and profile.style == s.key then styleName = L[s.name] end
        end
        content.style:SetText(L["Your style: %s"]:format("|cffd94fb0" .. styleName .. "|r"))
        draw(content)
        -- the first time: ask the player's style
        if not ns.Profile_IsSet() and not content.askedStyle then
            content.askedStyle = true
            ns.Profile_Show()
        end
    end,
})
