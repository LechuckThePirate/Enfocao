dofile("setupTests.lua")

-- Today's plan (sized to the session, stretches of the goals, chores of the account, a new one each day), the
-- templates, the advisors for battlegrounds, the epic mount and alts, and the family's optional addons.

local NOW = 1800000000
local ns

local function start(opts, db, storeDB)
    WowMock.Reset()
    ns = LoadAddon(opts)
    StartAddon(ns, db or {}, storeDB)
    return ns
end

local function goalSteps(plan)
    local n = 0
    for _, s in ipairs(plan.steps) do if s.kind == "goal" then n = n + 1 end end
    return n
end

local function byId(list)
    local map = {}
    for _, s in ipairs(list) do map[s.id] = s end
    return map
end

describe("today's plan", function()
    before_each(function() start() end)

    it("plans a stretch of as many goals as the session allows, the closest to done first", function()
        WowMock.char.professions = { [1] = { name = "Skinning", rank = 40, max = 150, skillLine = 393 } }
        ns.Goals_Add(ns.MyKey(), "level", { level = 30 })
        ns.Goals_Add(ns.MyKey(), "profession", { name = "Skinning", skillLine = 393, rank = 150 })
        ns.Goals_Add(ns.MyKey(), "gold", { amount = 100 * 10000 })
        ns.Profile_Save("balanced", {}, "short")
        local plan = ns.Plan_New(ns.MyKey()) and ns.Plan_For(ns.MyKey())
        assert.are.equal(1, goalSteps(plan))
        assert.are.equal(45, plan.minutes)
        ns.Profile_Save("balanced", {}, "long")
        ns.Plan_New(ns.MyKey())
        plan = ns.Plan_For(ns.MyKey())
        assert.are.equal(3, goalSteps(plan))
        for _, s in ipairs(plan.steps) do assert.are.equal("string", type(s.text)) end
    end)

    it("marks a step done when its stretch is, and says when the whole plan is", function()
        WowMock.char.professions = { [1] = { name = "Skinning", rank = 40, max = 150, skillLine = 393 } }
        ns.Profile_Save("balanced", {}, "short")
        ns.Goals_Add(ns.MyKey(), "profession", { name = "Skinning", skillLine = 393, rank = 150 })
        ns.Plan_New(ns.MyKey())
        local step = ns.Plan_For(ns.MyKey()).steps[1]
        assert.matches("Raise Skinning by 18 points", step.text)
        assert.is_false(step.done)
        WowMock.char.professions[1].rank = 49
        assert.near(0.5, ns.Plan_For(ns.MyKey()).steps[1].fraction, 0.01)
        WowMock.char.professions[1].rank = 58
        assert.is_true(ns.Plan_For(ns.MyKey()).steps[1].done)
        assert.is_true(ns.Plan_Check())
        assert.matches("plan is done", WowMock.printed[#WowMock.printed])
        assert.is_false(ns.Plan_Check()) -- said once
    end)

    it("ticks manual goals, takes in new goals, leaves out skipped steps and starts again the next day", function()
        local manual = ns.Goals_Add(ns.MyKey(), "manual", { text = "Learn to fish" })
        ns.Plan_New(ns.MyKey())
        local plan = ns.Plan_For(ns.MyKey())
        assert.are.equal(1, #plan.steps)
        ns.Plan_Tick(ns.MyKey(), plan.steps[1].id)
        assert.is_true(ns.Goals_Get(manual.id).done)
        assert.is_true(ns.Plan_For(ns.MyKey()).steps[1].done)
        -- a goal set later joins
        ns.Goals_Add(ns.MyKey(), "level", { level = 30 })
        plan = ns.Plan_For(ns.MyKey())
        assert.are.equal(2, #plan.steps)
        ns.Plan_Skip(ns.MyKey(), plan.steps[2].id)
        assert.are.equal(1, #ns.Plan_For(ns.MyKey()).steps)
        -- the next day, a new plan (the level goal is back)
        local tomorrow = ns.Plan_For(ns.MyKey(), NOW + 86400)
        assert.are.equal(1, goalSteps(tomorrow))
    end)

    it("offers the best suggestions as ideas when nothing is planned", function()
        local plan = ns.Plan_For(ns.MyKey())
        assert.are.equal(0, #plan.steps)
        assert.is_true(#plan.ideas > 0)
        ns.UI_Show("today")
        local rows = ns.UI_Current().content.table.rows
        assert.are.equal(#plan.ideas, #rows)
        rows[1].onClick(rows[1], "LeftButton", WowMock.NewFrame("Button"))
        assert.are.equal(1, #ns.Goals_All())
    end)

    it("lists the account's chores with the store: cooldowns ready and mail about to run out", function()
        start({ store = true }, {}, { chars = { ["Alt-Realm"] = { name = "Alt", class = "MAGE", level = 50,
            cooldowns = { transmute = { name = "Transmute", alert = true } },
            mail = { count = 1, expiresAt = NOW + 86400 } } } })
        local plan = ns.Plan_For(ns.MyKey())
        local texts = {}
        for _, s in ipairs(plan.steps) do texts[#texts + 1] = s.text end
        assert.matches("Alt: Transmute is ready", table.concat(texts, "|"))
        assert.matches("Alt: mail runs out", table.concat(texts, "|"))
        ns.Plan_Tick(ns.MyKey(), plan.steps[1].id)
        assert.is_true(ns.Plan_For(ns.MyKey()).steps[1].done)
    end)

    it("shows the plan in the \"Today\" window", function()
        ns.Goals_Add(ns.MyKey(), "manual", { text = "x" })
        ns.Hud_Refresh()
        local hud = ns.Hud_Frame()
        assert.is_true(hud.rows[1]:IsShown())
        assert.matches("0/1", hud.title:GetText())
    end)
end)

describe("templates", function()
    before_each(function() start() end)

    it("sets only what the character still needs, and remembers the template", function()
        WowMock.level = 56
        local found
        for _, e in ipairs(ns.Templates_For(ns.MyKey())) do if e.template.id == "mc" then found = e end end
        assert.are.equal(3, #found.goals)
        assert.are.equal(3, ns.Template_Apply(ns.MyKey(), found.template))
        for _, g in ipairs(ns.Goals_All()) do assert.are.equal("mc", g.group) end
        for _, e in ipairs(ns.Templates_For(ns.MyKey())) do assert.are_not.equal("mc", e.template.id) end
        -- Onyxia now only adds its attunement: the level goal is set already
        for _, e in ipairs(ns.Templates_For(ns.MyKey())) do
            if e.template.id == "ony" then assert.are.equal(1, #e.goals) end
        end
        assert.has_no.errors(function() ns.UI_Show("goals") end)
    end)

    it("leaves out what is done: a quest completed", function()
        WowMock.level = 58
        WowMock.char.quests[7761] = true
        local bwl
        for _, e in ipairs(ns.Templates_For(ns.MyKey())) do if e.template.id == "bwl" then bwl = e end end
        assert.are.equal(2, #bwl.goals) -- level 60 and the seal
    end)

    it("sets a template from its view", function()
        ns.UI_Show("templates")
        local rows = ns.UI_Current().content.table.rows
        assert.is_true(#rows > 0)
        rows[1].onClick(rows[1], "LeftButton", WowMock.NewFrame("Button"))
        assert.is_true(#ns.Goals_All() > 0)
        assert.matches("goals set", WowMock.printed[#WowMock.printed])
    end)
end)

describe("more advisors", function()
    it("opens the battlegrounds the level allows", function()
        start()
        local ids = byId(ns.Advice_For(ns.MyKey())) -- level 20
        assert.is_not_nil(ids["bg:wsg:5"])
        assert.is_not_nil(ids["bg:ab:5"])
        assert.is_nil(ids["bg:av:5"])
        assert.matches("Warsong Gulch", ids["bg:wsg:5"].why)
    end)

    it("saves for the epic mount at 60", function()
        start()
        WowMock.level = 60
        assert.is_not_nil(byId(ns.Advice_For(ns.MyKey())).epicmount)
    end)

    it("suggests playing an alt with its rested full, and a profession the account lacks", function()
        start({ store = true }, {}, { chars = { ["Alt-Realm"] = { name = "Alt", class = "MAGE", level = 30, xp = 0,
            xpMax = 1000, rested = 1500, restedAt = NOW, resting = true, faction = "Alliance",
            professions = { { name = "Mining", rank = 100, max = 150, skillLine = 186, primary = true } } } } })
        WowMock.char.professions = { [1] = { name = "Herbalism", rank = 100, max = 150, skillLine = 182 } }
        local ids = byId(ns.Advice_For(ns.MyKey()))
        local alt = ids["alt:rested:Alt-Realm"]
        assert.is_not_nil(alt)
        assert.are.equal("Alt-Realm", alt.key)
        assert.is_not_nil(ids["account:333"]) -- nobody enchants
        local goal = ns.Advice_Accept(ns.MyKey(), alt)
        assert.are.equal("Alt-Realm", goal.char)
        assert.is_nil(byId(ns.Advice_For(ns.MyKey()))["alt:rested:Alt-Realm"])
        assert.has_no.errors(function() ns.UI_Show("suggestions") end)
    end)
end)

describe("the family's addons", function()
    after_each(function() _G.CompletaoAPI, _G.FabrikaoAPI = nil, nil end)

    it("adds their entries to a goal's menu only when installed", function()
        start()
        local quest = ns.Goals_Add(ns.MyKey(), "quest", { quest = 7848 })
        local items = ns.Goals_Add(ns.MyKey(), "items", { item = 12360, count = 5 })
        assert.are.equal(0, #ns.Goals_AddonOptions(quest))
        local shown, recipes
        _G.CompletaoAPI = { version = 1, HasQuest = function(id) return id == 7848 end, ShowQuest = function(id) shown = id end }
        _G.FabrikaoAPI = { version = 1, ShowRecipesUsing = function(id) recipes = id end }
        ns.Goals_AddonOptions(quest)[1].run()
        ns.Goals_AddonOptions(items)[1].run()
        assert.are.equal(7848, shown)
        assert.are.equal(12360, recipes)
    end)
end)
