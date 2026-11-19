local ADDON, ns = ...
local L = ns.L

-- Minimap button (as in the sibling addons): left-click opens or closes the window, right-click a menu, drag moves
-- it around the minimap. The tooltip lists the playing character's goals.
local ICON = "Interface\\AddOns\\" .. ADDON .. "\\Icons\\Enfocao.png"
local button

local function settingsTable()
    if not ns.settings.minimap then ns.settings.minimap = { angle = 235, hide = false } end
    return ns.settings.minimap
end

local function updatePosition()
    local angle = math.rad(settingsTable().angle)
    local radius = Minimap:GetWidth() / 2 + 5
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function onDragUpdate()
    local mx, my = Minimap:GetCenter()
    local scale = Minimap:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    settingsTable().angle = math.deg((math.atan2 or math.atan)(cy / scale - my, cx / scale - mx))
    updatePosition()
end

function ns.Minimap_MenuOptions()
    local options = {}
    for _, view in ipairs(ns.UI_Views()) do
        options[#options + 1] = { name = view.title, run = function() ns.UI_Show(view.key) end }
    end
    options[#options + 1] = { name = L["+ New goal"], color = { 1, 0.82, 0 }, run = function() ns.NewGoal_Show() end }
    options[#options + 1] = { name = ns.settings.hud and L["Hide the \"Today\" window"] or L["Show the \"Today\" window"],
        color = { 0.85, 0.31, 0.69 }, run = function() ns.Hud_SetShown(not ns.settings.hud) end }
    options[#options + 1] = { name = L["Preferences"], color = { 0.85, 0.31, 0.69 }, run = function() ns.Prefs_Toggle() end }
    options[#options + 1] = { name = L["About Enfocao!!"], color = { 0.85, 0.31, 0.69 }, run = function() ns.About_Show() end }
    options[#options + 1] = { name = L["Hide the minimap button"], color = { 0.7, 0.7, 0.7 }, run = function() ns.Minimap_Toggle() end }
    return options
end

-- The tooltip's summary: the playing character's active goals, the closest to done first.
function ns.Minimap_TooltipLines()
    local goals = ns.Goals_For(ns.MyKey(), false)
    if #goals == 0 then return { { L["No goals yet."], 0.7, 0.7, 0.7 } } end
    local list = {}
    for _, g in ipairs(goals) do list[#list + 1] = { goal = g, progress = ns.Goals_Progress(g) } end
    table.sort(list, function(a, b) return a.progress.fraction > b.progress.fraction end)
    local lines = {}
    for i, e in ipairs(list) do
        if i > 5 then break end
        lines[#lines + 1] = { ("%s  |cffd94fb0%d%%|r"):format(ns.Goals_Title(e.goal), math.floor(e.progress.fraction * 100)), 1, 1, 1 }
    end
    return lines
end

local function create()
    button = CreateFrame("Button", "EnfocaoMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:SetHighlightTexture(136477) -- Interface\Minimap\UI-Minimap-ZoomButton-Highlight

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetSize(20, 20)
    background:SetPoint("TOPLEFT", 6, -5)
    background:SetTexture(136467) -- Interface\Minimap\UI-Minimap-Background

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(21, 21)
    icon:SetPoint("TOPLEFT", 5, -4)
    icon:SetTexture(ICON)

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(50, 50)
    border:SetPoint("TOPLEFT")
    border:SetTexture(136430) -- Interface\Minimap\MiniMap-TrackingBorder

    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetScript("OnClick", function(self, mouse)
        GameTooltip_Hide()
        if mouse == "RightButton" then
            ns.PopupMenu(self, ns.Minimap_MenuOptions(), function(opt) opt.run() end, 200, "right")
        else
            ns.UI_Toggle()
        end
    end)
    button:SetScript("OnDragStart", function(self)
        self:LockHighlight()
        self:SetScript("OnUpdate", onDragUpdate)
    end)
    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        self:UnlockHighlight()
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Enfocao!!")
        for _, line in ipairs(ns.Minimap_TooltipLines()) do GameTooltip:AddLine(line[1], line[2], line[3], line[4]) end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L["Left-click: open the window"], 0.7, 0.7, 0.7)
        GameTooltip:AddLine(L["Right-click: menu"], 0.7, 0.7, 0.7)
        GameTooltip:AddLine(L["Drag: move"], 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)
end

function ns.Minimap_Init()
    if not Minimap then return end
    if not button then create() end
    updatePosition()
    button:SetShown(not settingsTable().hide)
end

function ns.Minimap_SetShown(show)
    settingsTable().hide = not show
    if button then button:SetShown(show) end
end

function ns.Minimap_IsShown()
    return not settingsTable().hide
end

function ns.Minimap_Toggle()
    ns.Minimap_SetShown(not ns.Minimap_IsShown())
    ns.Print(ns.Minimap_IsShown() and L["Minimap button shown."] or L["Minimap button hidden. Show it again with /enfocao minimap."])
    ns.Prefs_Refresh()
end

function ns.Minimap_Button() return button end
