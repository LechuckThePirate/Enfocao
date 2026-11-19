dofile("setupTests.lua")

-- The whole addon loaded as the game loads it: the login line, the window and its views, the "new goal" form for each
-- kind, the "Today" window, the minimap button, the slash command and the translations.

local function start(opts, db, storeDB)
    WowMock.Reset()
    local ns = LoadAddon(opts)
    StartAddon(ns, db or {}, storeDB)
    return ns
end

describe("Enfocao", function()
    it("says how many goals are on at login, unless told to be quiet", function()
        start()
        assert.matches("no goals yet", WowMock.printed[#WowMock.printed])
        start(nil, { settings = { quiet = true } })
        assert.are.equal(0, #WowMock.printed)
    end)

    it("opens every view and draws the goals", function()
        local ns = start()
        ns.Goals_Add(ns.MyKey(), "manual", { text = "Learn to fish" })
        ns.Goals_Add(ns.MyKey(), "level", { level = 30 })
        for _, view in ipairs(ns.UI_Views()) do
            assert.has_no.errors(function() ns.UI_Show(view.key) end, view.key)
        end
        ns.UI_Show("goals")
        local t = ns.UI_Current().content.table
        assert.are.equal(2, #t.rows)
        for _, row in ipairs(t.rows) do assert.has_no.errors(function() row.tooltip(row, 1) end) end
        -- a click ticks the manual goal
        local manual
        for _, row in ipairs(t.rows) do if row.cells[1].text == "Learn to fish" then manual = row end end
        manual.onClick(manual, "LeftButton", WowMock.NewFrame("Button"))
        ns.UI_Show("achieved")
        assert.are.equal(1, #ns.UI_Current().content.table.rows)
    end)

    it("sets a goal of each kind from the form", function()
        local ns = start()
        WowMock.char.professions = { [1] = { name = "Fishing", rank = 75, max = 150, skillLine = 356 } }
        WowMock.char.factions = { { factionID = 529, name = "Argent Dawn", reaction = 4, currentReactionThreshold = 0,
            nextReactionThreshold = 3000, currentStanding = 10 } }
        WowMock.itemInfo[12360] = { name = "Arcanite Bar" }
        local cases = {
            { kind = "level", num = "30" },
            { kind = "profession", num = "150", set = function(form) form.profValue = "Fishing" end },
            { kind = "reputation", set = function(form) form.factionValue, form.standingValue = 529, 6 end },
            { kind = "gold", num = "100" },
            { kind = "items", num = "20", set = function(form) form.item:SetText("|cffffffff|Hitem:12360::|h[Arcanite Bar]|h|r") end },
            { kind = "quest", set = function(form) form.quest:SetText("7848") end },
            { kind = "manual", set = function(form) form.text:SetText("Learn to fish") end },
        }
        for _, case in ipairs(cases) do
            ns.NewGoal_Show(case.kind)
            local form = ns.NewGoal_Frame()
            if case.num then form.num:SetText(case.num) end
            if case.set then case.set(form) end
            local button = WowMock.Find(function(f) return f._parent == form and f._text == "Set goal" end)
            assert.has_no.errors(function() button:Click() end, case.kind)
        end
        assert.are.equal(#cases, #ns.Goals_All())
        local titles = {}
        for _, g in ipairs(ns.Goals_All()) do titles[#titles + 1] = ns.Goals_Title(g) end
        assert.are.same({ "Level 30", "Fishing to 150", "Honored with Argent Dawn", "Save 100g", "20 x Arcanite Bar",
            "Quest: #7848", "Learn to fish" }, titles)
    end)

    it("says why a goal can't be set", function()
        local ns = start()
        ns.NewGoal_Show("level")
        local form = ns.NewGoal_Frame()
        form.num:SetText("3")
        WowMock.Find(function(f) return f._parent == form and f._text == "Set goal" end):Click()
        assert.matches("Check the values", form.error:GetText())
        assert.are.equal(0, #ns.Goals_All())
    end)

    it("reads items and quests from links, ids and names", function()
        local ns = start({ store = true })
        assert.are.equal(12360, ns.ParseItem("|cffffffff|Hitem:12360::|h[Arcanite Bar]|h|r"))
        assert.are.equal(12360, ns.ParseItem(" 12360 "))
        BakalaoDataStoreDB.items[12360] = { n = "Arcanite Bar" }
        BakalaoDataStoreDB.chars["Tester-Realm"].bags = { [12360] = 1 }
        assert.are.equal(12360, ns.ParseItem("arcanite bar"))
        assert.is_nil(ns.ParseItem("no such thing"))
        assert.are.equal(7848, ns.ParseQuest("|cffffff00|Hquest:7848:60|h[Attunement to the Core]|h|r"))
    end)

    it("shows the playing character's goals in the \"Today\" window", function()
        local ns = start()
        assert.is_true(ns.Hud_Frame():IsShown())
        ns.Goals_Add(ns.MyKey(), "level", { level = 30 })
        ns.Goals_Add(ns.MyKey(), "manual", { text = "x" })
        ns.Hud_Refresh()
        local hud = ns.Hud_Frame()
        assert.is_true(hud.rows[1]:IsShown())
        assert.is_true(hud.rows[2]:IsShown())
        ns.settings.hudMax = 1
        ns.Hud_Refresh()
        assert.matches("%(%+1", hud.title:GetText())
        ns.Hud_SetShown(false)
        assert.is_false(hud:IsShown())
    end)

    it("shows the character picker only with other characters to pick", function()
        local ns = start({ store = true }, {}, { chars = { ["Alt-Realm"] = { name = "Alt", class = "MAGE", level = 5 } } })
        ns.UI_Show("goals")
        local frame = ns.UI_Frame()
        assert.is_true(frame.who:IsShown())
        ns.SetViewKey("Alt-Realm")
        assert.are.equal("Alt-Realm", ns.ViewKey())
        ns.SetViewKey(ns.MyKey())
        assert.are.equal("Tester-Realm", ns.ViewKey())
    end)

    it("answers the slash command and has its minimap menu", function()
        local ns = start()
        SlashCmdList.ENFOCAO("")
        assert.is_true(ns.UI_IsShown())
        SlashCmdList.ENFOCAO("achieved")
        assert.are.equal("achieved", ns.UI_Current().key)
        SlashCmdList.ENFOCAO("new")
        assert.is_true(ns.NewGoal_Frame():IsShown())
        SlashCmdList.ENFOCAO("prefs")
        assert.is_true(ns.Prefs_Frame():IsShown())
        SlashCmdList.ENFOCAO("hud")
        assert.is_false(ns.settings.hud)
        SlashCmdList.ENFOCAO("nonsense")
        assert.matches("Usage", WowMock.printed[#WowMock.printed])
        assert.is_true(#ns.Minimap_MenuOptions() >= 5)
        assert.matches("No goals", ns.Minimap_TooltipLines()[1][1])
    end)
end)

describe("Translations", function()
    it("has a Spanish text for every key", function()
        WowMock.Reset()
        local ns = LoadAddon()
        local missing = {}
        for _, path in ipairs(TocFiles()) do
            local text = assert(io.open(path, "r")):read("*a")
            for key in text:gmatch('L%["(.-[^\\])"%]') do
                key = key:gsub('\\"', '"')
                if not ns.L_ES[key] then missing[#missing + 1] = path .. ": " .. key end
            end
        end
        for _, name in ipairs({ "Hated", "Hostile", "Unfriendly", "Neutral", "Friendly", "Honored", "Revered", "Exalted" }) do
            if not ns.L_ES[name] then missing[#missing + 1] = name end
        end
        -- the texts the code passes through L at run time
        local dynamic = {}
        for _, m in ipairs(ns.MILESTONES) do dynamic[#dynamic + 1] = m.why end
        for _, r in pairs(ns.NEXT_RANK) do dynamic[#dynamic + 1] = r.name end
        for _, s in pairs(ns.SLOT_NAMES) do dynamic[#dynamic + 1] = s end
        for _, a in ipairs(ns.ATTUNEMENT_GOALS) do dynamic[#dynamic + 1] = a.name end
        for _, list in ipairs({ ns.PROFILE_STYLES, ns.PROFILE_LIKES, ns.PROFILE_SESSIONS }) do
            for _, o in ipairs(list) do
                dynamic[#dynamic + 1] = o.name
                if o.text then dynamic[#dynamic + 1] = o.text end
            end
        end
        for _, text in ipairs(dynamic) do
            if not ns.L_ES[text] then missing[#missing + 1] = text end
        end
        assert.are.same({}, missing)
    end)
end)
