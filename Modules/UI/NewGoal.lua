local _, ns = ...
local L = ns.L

-- The "new goal" form, beside the main window: the character (the one the window shows), the kind of goal and the
-- fields of that kind. Items and quests can be shift-clicked into their box (from the bags, the quest log, a chat
-- link) or typed (an item's id or name, a quest's id).
local WIDTH, HEIGHT = 380, 330
local form

-- An item from what was typed: a link, an id or a name the store or the game's cache knows.
function ns.ParseItem(text)
    text = text and text:gsub("^%s+", ""):gsub("%s+$", "") or ""
    local id = tonumber(text:match("item:(%d+)") or text:match("^(%d+)$"))
    if id then return id end
    if text == "" then return nil end
    local store = ns.Store()
    if store then
        local wanted = text:lower()
        for _, r in ipairs(store.SearchItems(text)) do
            if r.name:lower() == wanted then return r.id end
        end
    end
    return nil
end

function ns.ParseQuest(text)
    text = text or ""
    return tonumber(text:match("quest:(%d+)") or text:match("^%s*(%d+)%s*$"))
end

function ns.QuestTitle(questID)
    if C_QuestLog and C_QuestLog.GetTitleForQuestID then
        local ok, title = pcall(C_QuestLog.GetTitleForQuestID, questID)
        if ok and type(title) == "string" and title ~= "" then return title end
    end
    return nil
end

local function label(parent, text, y)
    local fs = ns.UI_Text(parent, "GameFontNormal", text)
    fs:SetPoint("TOPLEFT", 16, y)
    return fs
end

local function numberBox(parent, y)
    local box = ns.UI_EditBox(parent, 90)
    box:SetNumeric(true)
    box:SetPoint("TOPLEFT", 170, y + 2)
    return box
end

-- The fields each kind shows, and how they make the goal's parameters.
local function rebuild()
    local f = form
    local kind = f.kind
    local key = ns.ViewKey()
    for _, w in ipairs(f.fields) do w:Hide() end
    local function show(...) for _, w in ipairs({ ... }) do w:Show() end end
    f.error:SetText("")
    local hasStore = ns.Store() ~= nil
    if kind == "level" then
        f.numLabel:SetText(L["Level to reach"])
        show(f.numLabel, f.num)
    elseif kind == "profession" then
        f.profLabel:SetText(L["Profession"])
        f.numLabel:SetText(L["Skill to reach"])
        f.prof.Refresh()
        show(f.profLabel, f.prof, f.numLabel, f.num)
    elseif kind == "reputation" then
        f.faction.Refresh()
        f.standing.Refresh()
        show(f.factionLabel, f.faction, f.standingLabel, f.standing)
    elseif kind == "gold" then
        f.numLabel:SetText(L["Gold to have"])
        show(f.numLabel, f.num)
        if hasStore then show(f.account) end
    elseif kind == "items" then
        f.numLabel:SetText(L["How many"])
        show(f.itemLabel, f.item, f.itemName, f.numLabel, f.num)
        if hasStore then show(f.account) end
    elseif kind == "quest" then
        show(f.questLabel, f.quest, f.questName)
    elseif kind == "manual" then
        f.reset.Refresh()
        show(f.textLabel, f.text, f.resetLabel, f.reset)
    end
    local rec = ns.GetChar(key)
    f.who:SetText(L["For: %s"]:format(ns.ColorName(rec)))
end

local function parameters()
    local f = form
    local n = tonumber(f.num:GetText() or "")
    local kind = f.kind
    if kind == "level" then return { level = n } end
    if kind == "profession" then
        local prof
        for _, p in ipairs((ns.GetChar(ns.ViewKey()) or {}).professions or {}) do
            if p.name == f.profValue then prof = p end
        end
        return { name = prof and prof.name, skillLine = prof and prof.skillLine, icon = prof and prof.icon, rank = n }
    end
    if kind == "reputation" then
        local name
        for _, fac in ipairs(ns.Factions(ns.ViewKey())) do
            if fac.id == f.factionValue then name = fac.name end
        end
        return { faction = f.factionValue, name = name, standing = f.standingValue }
    end
    if kind == "gold" then return { amount = n and n * 10000, account = f.account:GetChecked() and ns.Store() ~= nil or nil } end
    if kind == "items" then
        return { item = ns.ParseItem(f.item:GetText()), count = n, account = f.account:GetChecked() and ns.Store() ~= nil or nil }
    end
    if kind == "quest" then
        local id = ns.ParseQuest(f.quest:GetText())
        return { quest = id, name = id and ns.QuestTitle(id) }
    end
    if kind == "manual" then return { text = f.text:GetText(), reset = f.resetValue or "none" } end
    return {}
end

local function create()
    form = CreateFrame("Frame", "EnfocaoNewGoalFrame", UIParent, "BackdropTemplate")
    form:SetSize(WIDTH, HEIGHT)
    form:SetFrameStrata("DIALOG")
    form:SetToplevel(true)
    form:SetClampedToScreen(true)
    ns.UI_Backdrop(form, 0.98, { ns.ACCENT[1], ns.ACCENT[2], ns.ACCENT[3], 1 })
    form:EnableMouse(true)
    form:SetMovable(true)
    form:RegisterForDrag("LeftButton")
    form:SetScript("OnDragStart", form.StartMoving)
    form:SetScript("OnDragStop", form.StopMovingOrSizing)
    tinsert(UISpecialFrames, "EnfocaoNewGoalFrame")
    local close = CreateFrame("Button", nil, form, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)
    local title = ns.UI_Text(form, "GameFontNormalLarge", L["New goal"])
    title:SetPoint("TOPLEFT", 16, -14)
    form.who = ns.UI_Text(form, "GameFontHighlight", "")
    form.who:SetPoint("TOPLEFT", 16, -38)

    form.kind = "level"
    label(form, L["Kind"], -66)
    form.kindDropdown = ns.UI_Dropdown(form, 190, function()
        local list = {}
        for _, t in ipairs(ns.GoalTypes()) do list[#list + 1] = { name = t.def.name, value = t.key } end
        return list
    end, function() return form.kind end, function(v)
        form.kind = v
        rebuild()
    end)
    form.kindDropdown:SetPoint("TOPLEFT", 166, -62)

    form.fields = {}
    local function field(w) form.fields[#form.fields + 1] = w return w end
    -- row 1 (y -100) and row 2 (y -134)
    form.numLabel = field(label(form, "", -134))
    form.num = field(numberBox(form, -134))

    form.profLabel = field(label(form, L["Profession"], -100))
    form.prof = field(ns.UI_Dropdown(form, 190, function()
        local list = {}
        local rec = ns.GetChar(ns.ViewKey())
        for _, p in ipairs(rec and rec.professions or {}) do
            list[#list + 1] = { name = ("%s (%d/%d)"):format(p.name, p.rank or 0, p.max or 0), value = p.name }
        end
        return list
    end, function() return form.profValue end, function(v) form.profValue = v end))
    form.prof:SetPoint("TOPLEFT", 166, -96)

    form.factionLabel = field(label(form, L["Faction"], -100))
    form.faction = field(ns.UI_Dropdown(form, 190, function()
        local list = {}
        for _, f in ipairs(ns.Factions(ns.ViewKey())) do list[#list + 1] = { name = f.name, value = f.id } end
        return list
    end, function() return form.factionValue end, function(v) form.factionValue = v end))
    form.faction:SetPoint("TOPLEFT", 166, -96)
    form.standingLabel = field(label(form, L["Standing to reach"], -134))
    form.standingValue = 6
    form.standing = field(ns.UI_Dropdown(form, 190, function()
        local list = {}
        for s = 5, 8 do list[#list + 1] = { name = ns.StandingName(s), value = s } end
        return list
    end, function() return form.standingValue end, function(v) form.standingValue = v end))
    form.standing:SetPoint("TOPLEFT", 166, -130)

    form.itemLabel = field(label(form, L["Item"], -100))
    form.item = field(ns.UI_EditBox(form, 190))
    form.item:SetPoint("TOPLEFT", 170, -98)
    form.itemName = field(ns.UI_Text(form, "GameFontDisableSmall", L["Shift-click an item, or type its name or id."], WIDTH - 40))
    form.itemName:SetPoint("TOPLEFT", 16, -162)
    form.item:SetScript("OnTextChanged", function(self)
        local id = ns.ParseItem(self:GetText())
        form.itemName:SetText(id and ("|cffffd100" .. ns.ItemName(id) .. "|r") or L["Shift-click an item, or type its name or id."])
    end)

    form.questLabel = field(label(form, L["Quest"], -100))
    form.quest = field(ns.UI_EditBox(form, 190))
    form.quest:SetPoint("TOPLEFT", 170, -98)
    form.questName = field(ns.UI_Text(form, "GameFontDisableSmall", L["Shift-click a quest in your quest log, or type its id."], WIDTH - 40))
    form.questName:SetPoint("TOPLEFT", 16, -130)
    form.quest:SetScript("OnTextChanged", function(self)
        local id = ns.ParseQuest(self:GetText())
        local name = id and ns.QuestTitle(id)
        form.questName:SetText(name and ("|cffffd100" .. name .. "|r") or L["Shift-click a quest in your quest log, or type its id."])
    end)

    form.textLabel = field(label(form, L["What"], -100))
    form.text = field(ns.UI_EditBox(form, 190))
    form.text:SetMaxLetters(80)
    form.text:SetPoint("TOPLEFT", 170, -98)
    form.resetLabel = field(label(form, L["Repeats"], -134))
    form.resetValue = "none"
    form.reset = field(ns.UI_Dropdown(form, 190, function()
        return { { name = L["Once"], value = "none" }, { name = L["Every day"], value = "daily" }, { name = L["Every week"], value = "weekly" } }
    end, function() return form.resetValue end, function(v) form.resetValue = v end))
    form.reset:SetPoint("TOPLEFT", 166, -130)

    form.account = field(ns.UI_Check(form, L["Count the whole account"], function() return false end, function() end, 200))
    form.account:SetPoint("TOPLEFT", 14, -190)

    form.error = ns.UI_Text(form, "GameFontHighlightSmall", "", WIDTH - 40)
    form.error:SetPoint("BOTTOMLEFT", 16, 50)
    form.error:SetTextColor(1, 0.4, 0.4)

    local add = ns.UI_Button(form, L["Set goal"], 140, function()
        local goal, why = ns.Goals_Add(ns.ViewKey(), form.kind, parameters())
        if not goal then
            form.error:SetText(why)
            return
        end
        form:Hide()
        ns.UI_Refresh(true)
    end)
    add:SetPoint("BOTTOMRIGHT", -16, 14)
    local cancel = ns.UI_Button(form, CANCEL or "Cancel", 100, function() form:Hide() end)
    cancel:SetPoint("RIGHT", add, "LEFT", -8, 0)

    -- shift-click a link into the item or quest box while it has the focus
    if hooksecurefunc and ChatEdit_InsertLink then
        hooksecurefunc("ChatEdit_InsertLink", function(link)
            if not (form and form:IsShown() and type(link) == "string") then return end
            if form.item:HasFocus() and link:find("item:", 1, true) then form.item:SetText(link) end
            if form.quest:HasFocus() and link:find("quest:", 1, true) then form.quest:SetText(link) end
        end)
    end
    form:Hide()
end

function ns.NewGoal_Show(kind)
    if not form then create() end
    form.kind = kind or form.kind
    for _, box in ipairs({ form.num, form.item, form.quest, form.text }) do box:SetText("") end
    form.account:SetChecked(false)
    form.kindDropdown.Refresh()
    local main = ns.UI_Frame and ns.UI_Frame()
    form:ClearAllPoints()
    if main and main:IsShown() then form:SetPoint("TOPLEFT", main, "TOPRIGHT", 4, 0) else form:SetPoint("CENTER") end
    rebuild()
    form:Show()
    form:Raise()
end

function ns.NewGoal_Frame() return form end
ns.NewGoal_Parameters = function() return parameters() end
