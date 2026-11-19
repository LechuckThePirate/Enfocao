local ADDON, ns = ...
local L = ns.L

-- The small "Today" window: the playing character's active goals, each with its bar, always at hand. Movable
-- (unless locked), shown or hidden from the preferences, the minimap menu or /enfocao hud. A click on its title opens
-- the main window; right-click for its menu.
local ICON = "Interface\\AddOns\\" .. ADDON .. "\\Icons\\Enfocao.png"
local WIDTH, ROW_H = 230, 30
local hud

local function makeRow(i)
    local row = CreateFrame("Frame", nil, hud)
    row:SetSize(WIDTH - 16, ROW_H)
    row:SetPoint("TOPLEFT", 8, -28 - (i - 1) * ROW_H)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(16, 16)
    row.icon:SetPoint("TOPLEFT", 0, -2)
    row.title = ns.UI_Text(row, "GameFontHighlightSmall", "", WIDTH - 40)
    row.title:SetPoint("TOPLEFT", 20, -3)
    row.title:SetWordWrap(false)
    row.barBg = row:CreateTexture(nil, "BACKGROUND")
    row.barBg:SetPoint("TOPLEFT", 20, -18)
    row.barBg:SetSize(WIDTH - 40, 7)
    row.barBg:SetColorTexture(1, 1, 1, 0.1)
    row.bar = row:CreateTexture(nil, "ARTWORK")
    row.bar:SetPoint("TOPLEFT", row.barBg, "TOPLEFT")
    row.bar:SetHeight(7)
    row.bar:SetColorTexture(ns.ACCENT[1], ns.ACCENT[2], ns.ACCENT[3], 0.9)
    row.status = ns.UI_Text(row, "GameFontDisableSmall", "")
    row.status:SetPoint("RIGHT", row.barBg, "RIGHT", 0, 10)
    row:EnableMouse(true)
    row:SetScript("OnEnter", function(self)
        if self.goal then ns.UI_ShowTooltip(self, { ns.Goals_Title(self.goal), { self.statusText or "", 1, 1, 1 } }) end
    end)
    row:SetScript("OnLeave", GameTooltip_Hide)
    return row
end

local function hudMenu(anchor)
    local options = {
        { name = L["Open Enfocao!!"], run = function() ns.UI_Show() end },
        { name = L["+ New goal"], run = function() ns.NewGoal_Show() end },
        { name = ns.settings.hudLocked and L["Unlock position"] or L["Lock position"],
            run = function() ns.settings.hudLocked = not ns.settings.hudLocked end },
        { name = L["Hide this window"], color = { 0.7, 0.7, 0.7 }, run = function() ns.Hud_SetShown(false) end },
    }
    ns.PopupMenu(anchor, options, function(opt) opt.run() end, 200, "right")
end

local function create()
    hud = CreateFrame("Frame", "EnfocaoHud", UIParent, "BackdropTemplate")
    hud:SetWidth(WIDTH)
    hud:SetFrameStrata("MEDIUM")
    hud:SetClampedToScreen(true)
    ns.UI_Backdrop(hud, 0.75, { ns.ACCENT[1] * 0.6, ns.ACCENT[2] * 0.6, ns.ACCENT[3] * 0.6, 0.9 })
    local pos = ns.settings.hudPos
    if pos then hud:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4]) else hud:SetPoint("RIGHT", UIParent, "RIGHT", -60, 120) end
    hud:SetMovable(true)
    hud:EnableMouse(true)
    hud:RegisterForDrag("LeftButton")
    hud:SetScript("OnDragStart", function(self) if not ns.settings.hudLocked then self:StartMoving() end end)
    hud:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint(1)
        ns.settings.hudPos = { point, relPoint, x, y }
    end)
    hud:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" then hudMenu(self) else ns.UI_Toggle() end
    end)

    local icon = hud:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("TOPLEFT", 6, -4)
    icon:SetTexture(ICON)
    hud.title = ns.UI_Text(hud, "GameFontNormal", L["Today"])
    hud.title:SetPoint("LEFT", icon, "RIGHT", 6, 0)
    hud.title:SetTextColor(ns.ACCENT[1], ns.ACCENT[2], ns.ACCENT[3])
    hud.empty = ns.UI_Text(hud, "GameFontDisableSmall", L["No goals: right-click to set one."], WIDTH - 20)
    hud.empty:SetPoint("TOPLEFT", 10, -30)
    hud.rows = {}
end

function ns.Hud_Refresh()
    if not ns.settings or not ns.settings.hud then
        if hud then hud:Hide() end
        return
    end
    if not hud then create() end
    local goals = ns.Goals_For(ns.MyKey(), false)
    local max = ns.settings.hudMax or 5
    local shown = math.min(#goals, max)
    for i = 1, shown do
        local row = hud.rows[i] or makeRow(i)
        hud.rows[i] = row
        local g = goals[i]
        local progress = ns.Goals_Progress(g)
        row.goal, row.statusText = g, progress.status
        row.icon:SetTexture(ns.Goals_Icon(g))
        row.title:SetText(ns.Goals_Title(g))
        row.status:SetText(("%d%%"):format(math.floor(progress.fraction * 100)))
        row.bar:SetWidth(math.max(1, (WIDTH - 40) * progress.fraction))
        row:Show()
    end
    for i = shown + 1, #hud.rows do hud.rows[i]:Hide() end
    hud.empty:SetShown(#goals == 0)
    local more = #goals - shown
    hud.title:SetText(more > 0 and (L["Today"] .. " |cff999999" .. L["(+%d more)"]:format(more) .. "|r") or L["Today"])
    hud:SetHeight(32 + math.max(1, shown) * ROW_H + (#goals == 0 and 4 or 0))
    hud:Show()
end

function ns.Hud_SetShown(show)
    ns.settings.hud = show and true or false
    ns.Hud_Refresh()
    if ns.Prefs_Refresh then ns.Prefs_Refresh() end
end

function ns.Hud_Frame() return hud end
