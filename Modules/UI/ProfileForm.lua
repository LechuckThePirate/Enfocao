local _, ns = ...
local L = ns.L

-- The "Your style" form: how the player plays (one of three), what they like (any) and how long they usually play
-- (one of three), as buttons that light up. It weighs the suggestions (Advice/Profile.lua).
local WIDTH, HEIGHT = 520, 470
local CHIP_H = 26
local form

-- A button that lights up when picked.
local function chip(parent, text, width)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(width, CHIP_H)
    b:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.text:SetPoint("CENTER")
    b.text:SetText(text)
    function b.SetOn(on)
        b.on = on
        if on then
            b:SetBackdropColor(ns.ACCENT[1], ns.ACCENT[2], ns.ACCENT[3], 0.45)
            b:SetBackdropBorderColor(1, 0.82, 0.35, 1)
            b.text:SetTextColor(1, 1, 1)
        else
            b:SetBackdropColor(0, 0, 0, 0.4)
            b:SetBackdropBorderColor(ns.ACCENT[1], ns.ACCENT[2], ns.ACCENT[3], 0.4)
            b.text:SetTextColor(0.8, 0.75, 0.8)
        end
    end
    b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    b.SetOn(false)
    return b
end

local function section(parent, y, text)
    local t = ns.UI_Text(parent, "GameFontNormal", text)
    t:SetPoint("TOPLEFT", 18, y)
    t:SetTextColor(1, 0.86, 0.45)
    return t
end

-- A row of chips where one is picked.
local function oneOf(parent, y, options, width, perRow)
    local group = { chips = {}, value = nil }
    for i, opt in ipairs(options) do
        local b = chip(parent, L[opt.name], width)
        b:SetPoint("TOPLEFT", 18 + ((i - 1) % perRow) * (width + 6), y - math.floor((i - 1) / perRow) * (CHIP_H + 6))
        b.key = opt.key
        if opt.text then
            b:SetScript("OnEnter", function(self) ns.UI_ShowTooltip(self, { L[opt.name], L[opt.text] }) end)
            b:SetScript("OnLeave", GameTooltip_Hide)
        end
        b:SetScript("OnClick", function() group.Set(opt.key) end)
        group.chips[#group.chips + 1] = b
    end
    function group.Set(value)
        group.value = value
        for _, b in ipairs(group.chips) do b.SetOn(b.key == value) end
    end
    return group
end

local function create()
    form = CreateFrame("Frame", "EnfocaoProfileFrame", UIParent, "BackdropTemplate")
    form:SetSize(WIDTH, HEIGHT)
    form:SetPoint("CENTER")
    form:SetFrameStrata("DIALOG")
    form:SetToplevel(true)
    form:SetClampedToScreen(true)
    ns.UI_Backdrop(form, 0.98, { ns.ACCENT[1], ns.ACCENT[2], ns.ACCENT[3], 1 })
    form:EnableMouse(true)
    form:SetMovable(true)
    form:RegisterForDrag("LeftButton")
    form:SetScript("OnDragStart", form.StartMoving)
    form:SetScript("OnDragStop", form.StopMovingOrSizing)
    tinsert(UISpecialFrames, "EnfocaoProfileFrame")
    local close = CreateFrame("Button", nil, form, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)
    local title = ns.UI_Text(form, "GameFontNormalLarge", L["Your style"])
    title:SetPoint("TOPLEFT", 18, -14)
    local intro = ns.UI_Text(form, "GameFontHighlightSmall",
        L["Tell me how you like to play and I'll tune my suggestions. You can change it whenever you want."], WIDTH - 40)
    intro:SetPoint("TOPLEFT", 18, -38)

    section(form, -72, L["How do you play?"])
    form.style = oneOf(form, -94, ns.PROFILE_STYLES, 154, 3)

    section(form, -136, L["What do you enjoy? (any)"])
    form.likes = {}
    for i, like in ipairs(ns.PROFILE_LIKES) do
        local b = chip(form, L[like.name], 154)
        b:SetPoint("TOPLEFT", 18 + ((i - 1) % 3) * 160, -158 - math.floor((i - 1) / 3) * (CHIP_H + 6))
        b.key = like.key
        b:SetScript("OnClick", function(self) self.SetOn(not self.on) end)
        form.likes[#form.likes + 1] = b
    end

    section(form, -264, L["How long do you usually play?"])
    form.session = oneOf(form, -286, ns.PROFILE_SESSIONS, 154, 3)

    local note = ns.UI_Text(form, "GameFontDisableSmall",
        L["Your time per session will shape the daily plan, coming in a next version."], WIDTH - 40)
    note:SetPoint("TOPLEFT", 18, -322)

    local save = ns.UI_Button(form, L["Save"], 120, function()
        local likes = {}
        for _, b in ipairs(form.likes) do
            if b.on then likes[b.key] = true end
        end
        ns.Profile_Save(form.style.value, likes, form.session.value)
        form:Hide()
        ns.UI_Refresh(true)
    end)
    save:SetPoint("BOTTOMRIGHT", -18, 16)
    local cancel = ns.UI_Button(form, CANCEL or "Cancel", 100, function() form:Hide() end)
    cancel:SetPoint("RIGHT", save, "LEFT", -8, 0)
    form:Hide()
end

function ns.Profile_Show()
    if not form then create() end
    local profile = ns.Profile() or {}
    form.style.Set(profile.style or "balanced")
    form.session.Set(profile.session or "hour")
    for _, b in ipairs(form.likes) do b.SetOn(profile.likes and profile.likes[b.key] or false) end
    form:Show()
    form:Raise()
end

function ns.Profile_Frame() return form end
