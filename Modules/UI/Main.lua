local ADDON, ns = ...
local L = ns.L

-- The main window (/enfocao, the minimap button): the views (goals, achieved...) reached from the bar at the bottom,
-- each with its illustrated header, and on top the character whose goals are shown (only the playing one without
-- BakalaoStudios DataStore). Each view registers itself with
--   ns.UI_RegisterView({ key =, title =, text =, build = function(content), refresh = function(content) })
-- build runs the first time the view is shown; refresh every time the window refreshes while it is shown.
local WIDTH, HEIGHT = 900, 600
local ICON = "Interface\\AddOns\\" .. ADDON .. "\\Icons\\Enfocao.png"
local MEDIA = "Interface\\AddOns\\" .. ADDON .. "\\Media\\"
local views, navButtons = {}, {}
local frame, current, ticker

-- Views are listed by their `order` (then as registered).
function ns.UI_RegisterView(view)
    views[#views + 1] = view
    view.seq = #views
    table.sort(views, function(a, b)
        if (a.order or 50) ~= (b.order or 50) then return (a.order or 50) < (b.order or 50) end
        return a.seq < b.seq
    end)
end

function ns.UI_Views() return views end

-- A view's picture (generated art, images/art/emblems.ps1) in one of its sizes: "Emblem" (128, headers), "Icon" (64,
-- the bar of views) or "Back" (512 with a soft fade, the window's background). Until a view has its own picture,
-- the addon's icon stands in ("main").
function ns.UI_Emblem(viewKey, kind)
    local view
    for _, v in ipairs(views) do if v.key == viewKey then view = v end end
    return MEDIA .. (kind or "Emblem") .. "_" .. (view and view.emblem or "main") .. ".png"
end

local function savePosition()
    local point, _, relPoint, x, y = frame:GetPoint(1)
    ns.settings.windowPos = { point, relPoint, x, y }
end

-- The illustrated header of a view (banner, emblem, title, a line about it); `content` is the space under it.
local function makeViewFrames(view)
    local container = CreateFrame("Frame", nil, frame.body)
    container:SetAllPoints()
    local header = CreateFrame("Frame", nil, container)
    header:SetPoint("TOPLEFT")
    header:SetPoint("TOPRIGHT")
    header:SetHeight(64)
    local banner = header:CreateTexture(nil, "BACKGROUND")
    banner:SetAllPoints()
    banner:SetTexture(MEDIA .. "Banner.png")
    local emblem = header:CreateTexture(nil, "ARTWORK")
    emblem:SetSize(54, 54)
    emblem:SetPoint("LEFT", 8, 0)
    emblem:SetTexture(ns.UI_Emblem(view.key))
    local title = ns.UI_Text(header, "GameFontNormalHuge", view.title)
    title:SetPoint("TOPLEFT", emblem, "TOPRIGHT", 12, -6)
    title:SetTextColor(1, 0.86, 0.45)
    local text = ns.UI_Text(header, "GameFontHighlight", view.text or "", 640)
    text:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    text:SetTextColor(0.9, 0.75, 0.85)
    local content = CreateFrame("Frame", nil, container)
    content:SetPoint("TOPLEFT", 0, -72)
    content:SetPoint("BOTTOMRIGHT")
    return container, content
end

local function selectView(key)
    for i, view in ipairs(views) do
        local selected = view.key == key
        if selected then current = view end
        if view.container then view.container:SetShown(selected) end
        local b = navButtons[i]
        if b then
            if selected then
                b.bg:SetColorTexture(ns.ACCENT[1], ns.ACCENT[2], ns.ACCENT[3], 0.28)
                b.glow:Show()
                b.text:SetTextColor(1, 0.9, 0.55)
                b.icon:SetAlpha(1)
            else
                b.bg:SetColorTexture(0, 0, 0, 0.35)
                b.glow:Hide()
                b.text:SetTextColor(0.8, 0.75, 0.8)
                b.icon:SetAlpha(0.75)
            end
        end
    end
    ns.settings.lastView = key
    frame.art:SetTexture(ns.UI_Emblem(key, "Back"))
    if current and not current.content then
        current.container, current.content = makeViewFrames(current)
        current.build(current.content)
    end
    if current then
        current.container:Show()
        current.refresh(current.content)
    end
end

-- The characters to pick from: the playing one, and the others the store knows.
local function charOptions()
    local list = {}
    for _, c in ipairs(ns.Characters()) do
        local r, g, b = ns.ClassColor(c.rec.class)
        list[#list + 1] = { name = (c.rec.name or c.key) .. (ns.IsMe(c.key) and " *" or ""), value = c.key, color = { r, g, b } }
    end
    return list
end

local function create()
    frame = CreateFrame("Frame", "EnfocaoFrame", UIParent, "BackdropTemplate")
    frame:SetSize(WIDTH, HEIGHT)
    local pos = ns.settings.windowPos
    if pos then frame:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4]) else frame:SetPoint("CENTER") end
    frame:SetScale(ns.settings.scale or 1)
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    ns.UI_Backdrop(frame, 0.97)
    local background = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    background:SetPoint("TOPLEFT", 1, -1)
    background:SetPoint("BOTTOMRIGHT", -1, 1)
    background:SetTexture(MEDIA .. "Window.png")
    -- the open view's picture, large and faint behind everything
    frame.art = frame:CreateTexture(nil, "BACKGROUND", nil, 2)
    frame.art:SetSize(520, 520)
    frame.art:SetAlpha(ns.settings.artAlpha or 0.22)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        savePosition()
    end)
    tinsert(UISpecialFrames, "EnfocaoFrame")

    -- the addon's icon, large and sticking out of the top left corner, as in Alterao!! and Embolsao!!
    local portrait = CreateFrame("Frame", nil, frame)
    portrait:SetSize(68, 68)
    portrait:SetPoint("TOPLEFT", -12, 14)
    portrait:SetFrameLevel(frame:GetFrameLevel() + 10)
    local shadow = portrait:CreateTexture(nil, "BACKGROUND")
    shadow:SetSize(74, 74)
    shadow:SetPoint("CENTER", 2, -3)
    shadow:SetTexture(ICON)
    shadow:SetVertexColor(0, 0, 0, 0.75)
    local icon = portrait:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture(ICON)
    local title = ns.UI_Text(frame, "GameFontNormalLarge", "Enfocao!!")
    title:SetPoint("TOPLEFT", 64, -14)
    title:SetTextColor(ns.ACCENT[1], ns.ACCENT[2], ns.ACCENT[3])
    frame.subtitle = ns.UI_Text(frame, "GameFontDisableSmall", "")
    frame.subtitle:SetPoint("LEFT", title, "RIGHT", 10, -1)

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)
    local prefs = ns.UI_Button(frame, L["Preferences"], 100, function() ns.Prefs_Toggle() end)
    prefs:SetPoint("TOPRIGHT", -36, -10)

    -- whose goals: only shown when the store knows other characters
    frame.who = ns.UI_Dropdown(frame, 170, charOptions, function() return ns.ViewKey() end, function(key)
        ns.SetViewKey(key)
        ns.UI_Refresh(true)
    end)
    frame.who:SetPoint("RIGHT", prefs, "LEFT", -8, 0)

    -- the bar of views, at the bottom
    local bar = CreateFrame("Frame", nil, frame)
    bar:SetPoint("BOTTOMLEFT", 10, 8)
    bar:SetPoint("BOTTOMRIGHT", -10, 8)
    bar:SetHeight(26)
    local line = bar:CreateTexture(nil, "BACKGROUND")
    line:SetPoint("TOPLEFT", 0, 4)
    line:SetPoint("TOPRIGHT", 0, 4)
    line:SetHeight(1)
    line:SetColorTexture(ns.ACCENT[1], ns.ACCENT[2], ns.ACCENT[3], 0.4)
    local x = 0
    for i, view in ipairs(views) do
        local b = CreateFrame("Button", nil, bar)
        b:SetHeight(26)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetSize(20, 20)
        b.icon:SetPoint("LEFT", 6, 0)
        b.icon:SetTexture(ns.UI_Emblem(view.key, "Icon"))
        b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        b.text:SetPoint("LEFT", b.icon, "RIGHT", 5, 0)
        b.text:SetText(view.title)
        local w = math.max(64, (b.text:GetStringWidth() or 60) + 40)
        b:SetWidth(w)
        b:SetPoint("LEFT", x, 0)
        b.bg = b:CreateTexture(nil, "BACKGROUND")
        b.bg:SetAllPoints()
        b.glow = b:CreateTexture(nil, "BORDER")
        b.glow:SetPoint("BOTTOMLEFT", 2, 0)
        b.glow:SetPoint("BOTTOMRIGHT", -2, 0)
        b.glow:SetHeight(2)
        b.glow:SetColorTexture(1, 0.82, 0.35, 0.9)
        b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        b:SetScript("OnClick", function() selectView(view.key) end)
        navButtons[i] = b
        x = x + w + 4
    end

    local body = CreateFrame("Frame", nil, frame)
    body:SetPoint("TOPLEFT", 12, -56)
    body:SetPoint("BOTTOMRIGHT", -12, 42)
    frame.body = body
    frame.art:SetPoint("CENTER", body, "CENTER", 0, 0)

    frame:SetScript("OnShow", function()
        if not ticker and C_Timer.NewTicker then
            ticker = C_Timer.NewTicker(30, function() ns.UI_Refresh(true) end)
        end
    end)
    frame:SetScript("OnHide", function()
        if ticker then ticker:Cancel() ticker = nil end
        ns.PopupMenu_Hide()
    end)
    frame:Hide()
end

function ns.UI_Frame() return frame end

function ns.UI_IsShown()
    return frame ~= nil and frame:IsShown()
end

function ns.UI_Show(viewKey)
    if not frame then create() end
    frame:Show()
    frame:Raise()
    local key = viewKey or ns.settings.lastView or (views[1] and views[1].key)
    local found = false
    for _, view in ipairs(views) do if view.key == key then found = true end end
    selectView(found and key or views[1].key)
    ns.UI_Refresh(true)
end

function ns.UI_Toggle()
    if frame and frame:IsShown() then frame:Hide() else ns.UI_Show() end
end

function ns.UI_Current() return current end

local queued = false
local function draw()
    queued = false
    if not (frame and frame:IsShown()) then return end
    frame.who.Refresh()
    frame.who:SetShown(#ns.Characters() > 1)
    local rec = ns.GetChar(ns.ViewKey())
    frame.subtitle:SetText(rec and (rec.name or "") or "")
    if current and current.content then current.refresh(current.content) end
end

-- Redraws what is shown (a burst of calls draws once). now = true draws at once.
function ns.UI_Refresh(now)
    if ns.Hud_Refresh then ns.Hud_Refresh() end
    if not (frame and frame:IsShown()) then return end
    if now then
        draw()
    elseif not queued then
        queued = true
        C_Timer.After(0.2, function() ns.SafeCall(draw) end)
    end
end

function ns.UI_ApplyScale()
    if frame then
        frame:SetScale(ns.settings.scale or 1)
        frame.art:SetAlpha(ns.settings.artAlpha or 0.22)
    end
end
