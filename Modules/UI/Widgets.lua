local _, ns = ...

-- The pieces the windows are made of: buttons, checkboxes, text, a dropdown menu of our own (it doesn't depend
-- on Blizzard's menus, which change between client versions) and a scrolling, sortable table.

local BACKDROP = { bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 }
ns.ACCENT = { 0.85, 0.31, 0.69 } -- Enfocao's magenta

function ns.UI_Backdrop(frame, alpha, border)
    frame:SetBackdrop(BACKDROP)
    frame:SetBackdropColor(0.04, 0.05, 0.07, alpha or 0.96)
    local b = border or { 0.45, 0.2, 0.4, 1 }
    frame:SetBackdropBorderColor(b[1], b[2], b[3], b[4] or 1)
end

function ns.UI_Text(parent, font, text, width, justify)
    local fs = parent:CreateFontString(nil, "ARTWORK", font or "GameFontHighlight")
    if width then fs:SetWidth(width) end
    fs:SetJustifyH(justify or "LEFT")
    if text then fs:SetText(text) end
    return fs
end

function ns.UI_Button(parent, text, width, onClick, height)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width or 100, height or 22)
    b:SetText(text)
    b:SetScript("OnClick", onClick)
    return b
end

function ns.UI_Check(parent, text, getValue, setValue, width)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetSize(24, 24)
    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("LEFT", check, "RIGHT", 2, 0)
    label:SetJustifyH("LEFT")
    if width then label:SetWidth(width) end
    label:SetText(text)
    check.label = label
    check:SetScript("OnClick", function(self) setValue(self:GetChecked() and true or false) end)
    function check.Refresh() check:SetChecked(getValue() and true or false) end
    return check
end

function ns.UI_EditBox(parent, width, onEnter)
    local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    box:SetSize(width or 160, 20)
    box:SetAutoFocus(false)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEnterPressed", function(self)
        if onEnter then onEnter(self:GetText(), self) end
        self:ClearFocus()
    end)
    return box
end

-- A button that opens a menu of options under it and shows the picked one: { { name =, value = } }.
function ns.UI_Dropdown(parent, width, getOptions, getValue, setValue)
    local b = ns.UI_Button(parent, "", width or 150, nil)
    local function label()
        local value = getValue()
        for _, opt in ipairs(getOptions()) do
            if opt.value == value then return opt.name end
        end
        return "-"
    end
    function b.Refresh() b:SetText(label() .. " |cff999999v|r") end
    b:SetScript("OnClick", function(self)
        ns.PopupMenu(self, getOptions(), function(opt)
            setValue(opt.value)
            self.Refresh()
        end, math.max(width or 150, 160))
    end)
    b.Refresh()
    return b
end

---------------------------------------------------------------------------------------------------
-- Popup menu: options { { name =, color = {r,g,b}, disabled = } }. Clicking the same control again closes it;
-- picking an option closes it and calls onPick(option, index). Opens under the control, or to its right with
-- side = "right".
---------------------------------------------------------------------------------------------------
local ROW_H, PER_COL = 18, 20
local popup

function ns.PopupMenu(anchor, options, onPick, width, side)
    if not popup then
        popup = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        ns.UI_Backdrop(popup, 0.98, { 0.85, 0.31, 0.69, 1 })
        popup:SetFrameStrata("FULLSCREEN_DIALOG")
        popup:SetClampedToScreen(true)
        popup:EnableMouse(true)
        popup.buttons = {}
        popup:SetScript("OnUpdate", function(self)
            if not IsMouseButtonDown then return end
            if (IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton")) and not self:IsMouseOver()
                and not (self.anchor and self.anchor:IsMouseOver()) then
                self:Hide()
            end
        end)
        popup:Hide()
    end
    if popup:IsShown() and popup.anchor == anchor then popup:Hide() return end
    popup.anchor = anchor
    if not anchor.menuHooked then
        anchor.menuHooked = true
        anchor:HookScript("OnHide", function(self) if popup and popup.anchor == self then popup:Hide() end end)
    end
    local colW = width or 200
    local cols = math.max(1, math.ceil(#options / PER_COL))
    for i, opt in ipairs(options) do
        local b = popup.buttons[i]
        if not b then
            b = CreateFrame("Button", nil, popup)
            b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            b.text:SetPoint("LEFT", 4, 0)
            b.text:SetPoint("RIGHT", -4, 0)
            b.text:SetJustifyH("LEFT")
            b.text:SetWordWrap(false)
            b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
            popup.buttons[i] = b
        end
        b:SetSize(colW - 8, ROW_H)
        b.text:SetText(opt.name)
        local c = opt.color or { 1, 1, 1 }
        b.text:SetTextColor(c[1], c[2], c[3])
        b:SetEnabled(not opt.disabled)
        b:SetScript("OnClick", function()
            popup:Hide()
            onPick(opt, i)
        end)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", 4 + math.floor((i - 1) / PER_COL) * colW, -4 - ((i - 1) % PER_COL) * ROW_H)
        b:Show()
    end
    for i = #options + 1, #popup.buttons do popup.buttons[i]:Hide() end
    popup:SetSize(cols * colW, 8 + math.max(1, math.min(#options, PER_COL)) * ROW_H)
    popup:ClearAllPoints()
    if side == "right" then
        popup:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 2, 0)
    else
        popup:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
    end
    popup:Show()
end

function ns.PopupMenu_Hide()
    if popup then popup:Hide() end
end

---------------------------------------------------------------------------------------------------
-- Table: a header of columns (click to sort, again to reverse) and rows that scroll with the mouse wheel.
--   columns = { { title =, width =, align = "LEFT" | "CENTER" | "RIGHT" } }  (the last one takes what is left)
--   rows    = { { cells = { { text =, color = {r,g,b}, icon =, bar = 0..1, barColor = {r,g,b} } },
--                 sort = { value per column }, onClick = function(row, mouseButton, frame),
--                 tooltip = function(row, cellIndex) -> lines { text or { text, r, g, b } } } }
-- Rows without a sort value of the sorted column go last.
---------------------------------------------------------------------------------------------------
local TABLE_ROW_H = 20

local function showTooltip(owner, lines)
    if not lines or #lines == 0 then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    for i, line in ipairs(lines) do
        if type(line) == "table" then
            if line.right then
                GameTooltip:AddDoubleLine(line[1], line.right, line[2] or 1, line[3] or 1, line[4] or 1, 1, 1, 1)
            else
                GameTooltip:AddLine(line[1], line[2] or 1, line[3] or 1, line[4] or 1, true)
            end
        elseif i == 1 then
            GameTooltip:SetText(line)
        else
            GameTooltip:AddLine(line, 1, 1, 1, true)
        end
    end
    GameTooltip:Show()
end
ns.UI_ShowTooltip = showTooltip

function ns.UI_Table(parent, columns, height)
    local t = CreateFrame("Frame", nil, parent)
    t.columns, t.rows, t.offset, t.sortCol, t.sortDesc = columns, {}, 0, nil, false
    t.rowFrames = {}
    t:SetHeight(height or 300)
    t:EnableMouseWheel(true)

    local header = CreateFrame("Frame", nil, t)
    header:SetPoint("TOPLEFT")
    header:SetPoint("TOPRIGHT")
    header:SetHeight(20)
    local headerBg = header:CreateTexture(nil, "BACKGROUND")
    headerBg:SetAllPoints()
    headerBg:SetColorTexture(0.22, 0.06, 0.18, 0.85)
    local headerLine = header:CreateTexture(nil, "BORDER")
    headerLine:SetPoint("BOTTOMLEFT")
    headerLine:SetPoint("BOTTOMRIGHT")
    headerLine:SetHeight(1)
    headerLine:SetColorTexture(0.85, 0.7, 0.35, 0.7)
    t.header = header
    t.headerButtons = {}

    local scroll = CreateFrame("Slider", nil, t)
    scroll:SetOrientation("VERTICAL")
    scroll:SetPoint("TOPRIGHT", 0, -22)
    scroll:SetPoint("BOTTOMRIGHT", 0, 0)
    scroll:SetWidth(10)
    local track = scroll:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints()
    track:SetColorTexture(1, 1, 1, 0.06)
    scroll:SetThumbTexture("Interface\\Buttons\\WHITE8x8")
    local thumb = scroll:GetThumbTexture()
    if thumb then
        thumb:SetSize(10, 30)
        thumb:SetVertexColor(0.85, 0.31, 0.69, 0.6)
    end
    scroll:SetMinMaxValues(0, 0)
    scroll:SetValueStep(1)
    scroll:SetScript("OnValueChanged", function(_, value)
        local v = math.floor(value + 0.5)
        if v ~= t.offset then
            t.offset = v
            t:Draw()
        end
    end)
    t.scroll = scroll

    t:SetScript("OnMouseWheel", function(_, delta)
        local _, max = scroll:GetMinMaxValues()
        local v = math.max(0, math.min(max or 0, t.offset - delta * 3))
        scroll:SetValue(v)
        if v ~= t.offset then
            t.offset = v
            t:Draw()
        end
    end)

    function t:Visible()
        return math.max(1, math.floor(((self:GetHeight() or 300) - 22) / TABLE_ROW_H))
    end

    -- column x positions from the widths; the last column takes what's left
    function t:Layout()
        local total = (self:GetWidth() or 600) - 14
        local x = 0
        self.colX, self.colW = {}, {}
        for i, col in ipairs(self.columns) do
            local w = col.width or 80
            if i == #self.columns then w = math.max(40, total - x) end
            self.colX[i], self.colW[i] = x, w
            x = x + w
        end
        for i, col in ipairs(self.columns) do
            local b = self.headerButtons[i]
            if not b then
                b = CreateFrame("Button", nil, header)
                b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                b.text:SetPoint("LEFT", 4, 0)
                b.text:SetPoint("RIGHT", -4, 0)
                b.text:SetWordWrap(false)
                b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
                b:SetScript("OnClick", function()
                    if self.sortCol == i then self.sortDesc = not self.sortDesc
                    else self.sortCol, self.sortDesc = i, self.columns[i].descFirst and true or false end
                    if self.onSort then self.onSort(self.sortCol, self.sortDesc) end
                    self:Sort()
                    self:Draw()
                end)
                b:SetScript("OnEnter", function(btn) local c = self.columns[i]; if c and c.tip then showTooltip(btn, { c.title, c.tip }) end end)
                b:SetScript("OnLeave", GameTooltip_Hide)
                self.headerButtons[i] = b
            end
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", self.colX[i], 0)
            b:SetSize(self.colW[i], 20)
            b.text:SetJustifyH(col.align or "LEFT")
            local arrow = ""
            if self.sortCol == i then arrow = self.sortDesc and " v" or " ^" end
            b.text:SetText((col.title or "") .. arrow)
            b:Show()
        end
        for i = #self.columns + 1, #self.headerButtons do self.headerButtons[i]:Hide() end
    end

    function t:SetColumns(cols)
        self.columns = cols
        if self.sortCol and self.sortCol > #cols then self.sortCol = nil end
        for _, f in ipairs(self.rowFrames) do f.built = 0 end
        self:Layout()
    end

    function t:Sort()
        local col = self.sortCol
        if not col then return end
        local desc = self.sortDesc
        table.sort(self.rows, function(a, b)
            local va, vb = a.sort and a.sort[col], b.sort and b.sort[col]
            if va == nil and vb == nil then return (a.order or 0) < (b.order or 0) end
            if va == nil then return false end
            if vb == nil then return true end
            if type(va) ~= type(vb) then va, vb = tostring(va), tostring(vb) end
            if va == vb then return (a.order or 0) < (b.order or 0) end
            if desc then return va > vb end
            return va < vb
        end)
    end

    function t:SetRows(rows)
        for i, r in ipairs(rows) do r.order = i end
        self.rows = rows
        self:Sort()
        local max = math.max(0, #rows - self:Visible())
        self.scroll:SetMinMaxValues(0, max)
        if self.offset > max then self.offset = max end
        self.scroll:SetValue(self.offset)
        self.scroll:SetShown(max > 0)
        self:Draw()
    end

    local function rowFrame(i)
        local f = t.rowFrames[i]
        if f then return f end
        f = CreateFrame("Button", nil, t)
        f:SetHeight(TABLE_ROW_H)
        f:SetPoint("TOPLEFT", 0, -22 - (i - 1) * TABLE_ROW_H)
        f:SetPoint("RIGHT", -12, 0)
        f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        local zebra = f:CreateTexture(nil, "BACKGROUND")
        zebra:SetAllPoints()
        zebra:SetColorTexture(1, 1, 1, (i % 2 == 0) and 0.045 or 0.01)
        -- a character's row: a bar of its class color on the left and a faint wash of it
        f.classBar = f:CreateTexture(nil, "BORDER")
        f.classBar:SetPoint("TOPLEFT", 0, -1)
        f.classBar:SetPoint("BOTTOMLEFT", 0, 1)
        f.classBar:SetWidth(3)
        f.classWash = f:CreateTexture(nil, "BACKGROUND", nil, 1)
        f.classWash:SetPoint("TOPLEFT")
        f.classWash:SetPoint("BOTTOMLEFT")
        f.classWash:SetWidth(180)
        local hl = f:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(0.85, 0.31, 0.69, 0.14)
        f.cells = {}
        f.built = 0
        f:SetScript("OnClick", function(self, button)
            if self.row and self.row.onClick then self.row.onClick(self.row, button, self) end
        end)
        f:SetScript("OnEnter", function(self)
            if not (self.row and self.row.tooltip) then return end
            local x = GetCursorPosition() / (self:GetEffectiveScale() or 1) - (self:GetLeft() or 0)
            local cell = 1
            for c = 1, #t.columns do
                if t.colX[c] and x >= t.colX[c] then cell = c end
            end
            showTooltip(self, self.row.tooltip(self.row, cell))
        end)
        f:SetScript("OnLeave", GameTooltip_Hide)
        t.rowFrames[i] = f
        return f
    end

    local function cell(f, c)
        local cl = f.cells[c]
        if not cl then
            cl = {}
            cl.bar = f:CreateTexture(nil, "BORDER")
            cl.bar:SetColorTexture(1, 1, 1, 1)
            cl.icon = f:CreateTexture(nil, "ARTWORK")
            cl.icon:SetSize(TABLE_ROW_H - 2, TABLE_ROW_H - 2)
            cl.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            cl.text:SetWordWrap(false)
            f.cells[c] = cl
        end
        return cl
    end

    function t:Draw()
        if not self.colX then self:Layout() end
        local visible = self:Visible()
        for i = 1, visible do
            local f = rowFrame(i)
            local row = self.rows[self.offset + i]
            f.row = row
            local class = row and row.cells[1] and row.cells[1].class
            if class then
                local r, g, b = ns.ClassColor(class)
                f.classBar:SetColorTexture(r, g, b, 0.95)
                f.classWash:SetColorTexture(r, g, b, 0.07)
            end
            f.classBar:SetShown(class ~= nil)
            f.classWash:SetShown(class ~= nil)
            if row then
                for c = 1, #self.columns do
                    local data = row.cells[c] or {}
                    local cl = cell(f, c)
                    local x, w = self.colX[c], self.colW[c]
                    local textLeft = x + 4
                    if data.icon then
                        cl.icon:ClearAllPoints()
                        cl.icon:SetPoint("LEFT", x + 2, 0)
                        cl.icon:SetTexture(data.icon)
                        cl.icon:Show()
                        textLeft = x + TABLE_ROW_H + 2
                    else
                        cl.icon:Hide()
                    end
                    cl.text:ClearAllPoints()
                    cl.text:SetPoint("LEFT", textLeft, 0)
                    cl.text:SetWidth(math.max(10, w - (textLeft - x) - 4))
                    cl.text:SetJustifyH(self.columns[c].align or "LEFT")
                    cl.text:SetText(data.text or "")
                    local color = data.color or { 1, 1, 1 }
                    cl.text:SetTextColor(color[1], color[2], color[3])
                    if data.bar then
                        local bc = data.barColor or ns.ACCENT
                        cl.bar:ClearAllPoints()
                        cl.bar:SetPoint("LEFT", x + 2, 0)
                        cl.bar:SetSize(math.max(1, (w - 6) * math.max(0, math.min(1, data.bar))), TABLE_ROW_H - 4)
                        cl.bar:SetVertexColor(bc[1], bc[2], bc[3], 0.45)
                        cl.bar:Show()
                    else
                        cl.bar:Hide()
                    end
                    cl.text:Show()
                end
                for c = #self.columns + 1, #f.cells do
                    f.cells[c].text:Hide()
                    f.cells[c].icon:Hide()
                    f.cells[c].bar:Hide()
                end
                f:Show()
            else
                f:Hide()
            end
        end
        for i = visible + 1, #self.rowFrames do self.rowFrames[i]:Hide() end
        if self.empty then self.empty:SetShown(#self.rows == 0) end
    end

    -- a line shown while there are no rows
    function t:SetEmptyText(text)
        if not self.empty then
            self.empty = self:CreateFontString(nil, "OVERLAY", "GameFontDisable")
            self.empty:SetPoint("TOP", 0, -50)
            self.empty:SetWidth(500)
        end
        self.empty:SetText(text)
    end

    t:SetScript("OnSizeChanged", function(self)
        self:Layout()
        self:SetRows(self.rows)
    end)
    return t
end

-- The cell of a character's name: class colored, with a star for the playing one.
function ns.UI_NameCell(c)
    local r, g, b = ns.ClassColor(c.rec.class)
    local text = c.rec.name or c.key
    if ns.IsMe(c.key) then text = text .. " |cffd94fb0*|r" end
    return { text = text, color = { r, g, b }, class = c.rec.class }
end
