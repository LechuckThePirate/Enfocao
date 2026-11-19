local _, ns = ...
local L = ns.L

-- Preferences (/enfocao prefs, the button on the main window, the minimap menu): the "Today" window, what happens
-- when a goal is reached, the window's size and picture, the minimap button. All of them for the whole account.
local WIDTH, HEIGHT = 440, 470
local prefs
local controls = {}

local function makeSlider(parent, y, min, max, step, getValue, setValue, labelFor)
    local label = ns.UI_Text(parent, "GameFontHighlight", "")
    label:SetPoint("TOPLEFT", 24, y)
    local slider = CreateFrame("Slider", nil, parent)
    slider:SetOrientation("HORIZONTAL")
    slider:SetSize(WIDTH - 70, 16)
    slider:SetPoint("TOPLEFT", 28, y - 20)
    slider:SetMinMaxValues(min, max)
    slider:SetValueStep(step)
    if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
    local bar = slider:CreateTexture(nil, "BACKGROUND")
    bar:SetPoint("LEFT")
    bar:SetPoint("RIGHT")
    bar:SetHeight(4)
    bar:SetColorTexture(1, 1, 1, 0.25)
    slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    local thumb = slider:GetThumbTexture()
    if thumb then thumb:SetSize(20, 20) end
    local refreshing = false
    slider:SetScript("OnValueChanged", function(_, value)
        value = tonumber(("%.2f"):format(math.floor(value / step + 0.5) * step))
        label:SetText(labelFor(value))
        if not refreshing then setValue(value) end
    end)
    function slider.Refresh()
        refreshing = true
        local value = getValue()
        slider:SetValue(value)
        label:SetText(labelFor(value))
        refreshing = false
    end
    controls[#controls + 1] = slider
    return slider
end

local function check(parent, y, text, key, onChange)
    local c = ns.UI_Check(parent, text, function() return ns.settings[key] end, function(v)
        ns.settings[key] = v
        if onChange then onChange(v) end
    end, WIDTH - 70)
    c:SetPoint("TOPLEFT", 20, y)
    controls[#controls + 1] = c
    return c
end

local function header(parent, y, text)
    local h = ns.UI_Text(parent, "GameFontNormal", text)
    h:SetPoint("TOPLEFT", 16, y)
    h:SetTextColor(ns.ACCENT[1], ns.ACCENT[2], ns.ACCENT[3])
end

local function create()
    prefs = CreateFrame("Frame", "EnfocaoPrefsFrame", UIParent, "BackdropTemplate")
    prefs:SetSize(WIDTH, HEIGHT)
    prefs:SetPoint("CENTER")
    prefs:SetFrameStrata("DIALOG")
    prefs:SetToplevel(true)
    prefs:SetClampedToScreen(true)
    ns.UI_Backdrop(prefs, 0.98)
    prefs:SetMovable(true)
    prefs:EnableMouse(true)
    prefs:RegisterForDrag("LeftButton")
    prefs:SetScript("OnDragStart", prefs.StartMoving)
    prefs:SetScript("OnDragStop", prefs.StopMovingOrSizing)
    tinsert(UISpecialFrames, "EnfocaoPrefsFrame")
    local close = CreateFrame("Button", nil, prefs, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)
    local title = ns.UI_Text(prefs, "GameFontNormalLarge", L["Enfocao!! preferences"])
    title:SetPoint("TOPLEFT", 16, -14)

    local y = -44
    header(prefs, y, L["The \"Today\" window"])
    y = y - 20
    check(prefs, y, L["Show the playing character's goals on screen"], "hud", function() ns.Hud_Refresh() end)
    y = y - 24
    check(prefs, y, L["Lock its position"], "hudLocked")
    y = y - 28
    makeSlider(prefs, y, 1, 10, 1, function() return ns.settings.hudMax end, function(v)
        ns.settings.hudMax = v
        ns.Hud_Refresh()
    end, function(v) return L["Goals it lists: %d"]:format(v) end)

    y = y - 54
    header(prefs, y, L["When a goal is reached"])
    y = y - 20
    check(prefs, y, L["Play a sound"], "sound")
    y = y - 24
    check(prefs, y, L["Show a message in the middle of the screen"], "centerMessage")

    y = y - 34
    header(prefs, y, L["Other"])
    y = y - 20
    check(prefs, y, L["No chat message at startup"], "quiet")
    y = y - 24
    local minimap = ns.UI_Check(prefs, L["Minimap button"], ns.Minimap_IsShown, function(v) ns.Minimap_SetShown(v) end, WIDTH - 70)
    minimap:SetPoint("TOPLEFT", 20, y)
    controls[#controls + 1] = minimap
    y = y - 30
    makeSlider(prefs, y, 0.6, 1.4, 0.05, function() return ns.settings.scale or 1 end, function(v)
        ns.settings.scale = v
        ns.UI_ApplyScale()
    end, function(v) return L["Window size: %d%%"]:format(v * 100) end)
    y = y - 46
    makeSlider(prefs, y, 0, 0.6, 0.02, function() return ns.settings.artAlpha or 0.22 end, function(v)
        ns.settings.artAlpha = v
        ns.UI_ApplyScale()
    end, function(v) return L["Background picture: %d%%"]:format(v * 100) end)

    local reset = ns.UI_Button(prefs, L["Reset preferences"], 160, function()
        ns.ResetSettings()
        ns.Prefs_Refresh()
    end)
    reset:SetPoint("BOTTOMLEFT", 16, 14)
    local about = ns.UI_Button(prefs, L["About"], 100, function() ns.About_Show() end)
    about:SetPoint("BOTTOMRIGHT", -16, 14)
    prefs:Hide()
end

function ns.Prefs_Refresh()
    if not (prefs and prefs:IsShown()) then return end
    for _, c in ipairs(controls) do c.Refresh() end
end

function ns.Prefs_Toggle()
    if not prefs then create() end
    if prefs:IsShown() then prefs:Hide() return end
    prefs:Show()
    prefs:Raise()
    ns.Prefs_Refresh()
end

function ns.Prefs_Frame() return prefs end
