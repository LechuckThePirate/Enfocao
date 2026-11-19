dofile("setupTests.lua")

-- The goals: each kind's progress from the playing character's live data, when they are reached (and announced),
-- the manual ones and their resets, and with BakalaoStudios DataStore the other characters of the account.

local NOW = 1800000000
local ns

local function start(opts, db, storeDB)
    WowMock.Reset()
    ns = LoadAddon(opts)
    StartAddon(ns, db or {}, storeDB)
    return ns
end

local function printedSomething(pattern)
    for _, line in ipairs(WowMock.printed) do
        if line:find(pattern) then return true end
    end
    return false
end

describe("goals without the store (the playing character, live)", function()
    before_each(function() start() end)

    it("follows a level goal from where the character was", function()
        WowMock.char.xp, WowMock.char.xpMax = 500, 1000 -- level 20 and a half
        local goal = assert(ns.Goals_Add(ns.MyKey(), "level", { level = 22 }))
        assert.near(20.5, goal.p.start, 0.001)
        local p = ns.Goals_Progress(goal)
        assert.near(0, p.fraction, 0.001)
        assert.is_true(p.known)
        WowMock.level = 21
        p = ns.Goals_Progress(goal)
        assert.near(2 / 3, p.fraction, 0.001) -- from 20.5 to 21.5, of the way to 22
        assert.matches("21", p.status)
        WowMock.level = 22
        assert.are.equal(1, #ns.Goals_Check(NOW))
        assert.is_true(goal.done)
        assert.are.equal(NOW, goal.doneAt)
        assert.is_true(printedSomething("Goal reached"))
    end)

    it("refuses goals that make no sense", function()
        local goal, why = ns.Goals_Add(ns.MyKey(), "level", { level = 5 }) -- already past it
        assert.is_nil(goal)
        assert.are.equal("string", type(why))
        assert.is_nil(ns.Goals_Add(ns.MyKey(), "nonsense", {}))
        assert.is_nil(ns.Goals_Add("Nobody-Realm", "gold", { amount = 1 }))
    end)

    it("follows a profession", function()
        WowMock.char.professions = { [1] = { name = "Fishing", rank = 150, max = 225, skillLine = 356 } }
        local goal = assert(ns.Goals_Add(ns.MyKey(), "profession", { name = "Fishing", skillLine = 356, rank = 225 }))
        assert.are.equal("150 / 225", ns.Goals_Progress(goal).status)
        WowMock.char.professions[1].rank = 225
        ns.Goals_Check()
        assert.is_true(goal.done)
    end)

    it("follows a reputation on one scale across standings", function()
        WowMock.char.factions = { { factionID = 529, name = "Argent Dawn", reaction = 5, currentReactionThreshold = 3000,
            nextReactionThreshold = 9000, currentStanding = 6000 } } -- Friendly 3000/6000
        local goal = assert(ns.Goals_Add(ns.MyKey(), "reputation", { faction = 529, name = "Argent Dawn", standing = 6 }))
        assert.are.equal(6000, goal.p.start)
        assert.matches("Argent Dawn", ns.Goals_Title(goal))
        WowMock.char.factions[1].currentStanding = 7500 -- halfway to Honored
        assert.near(0.5, ns.Goals_Progress(goal).fraction, 0.001)
        WowMock.char.factions[1].reaction, WowMock.char.factions[1].currentStanding = 6, 9000
        ns.Goals_Check()
        assert.is_true(goal.done)
    end)

    it("follows gold and items", function()
        local gold = assert(ns.Goals_Add(ns.MyKey(), "gold", { amount = 200000 })) -- 20g, the character has 12g
        assert.are.equal("12g / 20g", ns.Goals_Progress(gold).status)
        WowMock.AddItem(0, 1, 12360, 4, { name = "Arcanite Bar" })
        local items = assert(ns.Goals_Add(ns.MyKey(), "items", { item = 12360, count = 10 }))
        assert.matches("Arcanite Bar", ns.Goals_Title(items))
        assert.are.equal("4 / 10", ns.Goals_Progress(items).status)
        WowMock.AddItem(0, 2, 12360, 6)
        WowMock.char.money = 250000
        assert.are.equal(2, #ns.Goals_Check())
    end)

    it("follows a quest", function()
        local goal = assert(ns.Goals_Add(ns.MyKey(), "quest", { quest = 7848, name = "Attunement to the Core" }))
        assert.is_false(goal.done)
        WowMock.char.quests[7848] = true
        ns.Goals_Check()
        assert.is_true(goal.done)
    end)

    it("ticks manual goals by hand, and repeating ones come back at the reset", function()
        -- the game's countdown to the daily reset, at NOW + 1 hour and every day after
        _G.C_DateAndTime.GetSecondsUntilDailyReset = function()
            local at = NOW + 3600
            while at <= WowMock.now do at = at + 86400 end
            return at - WowMock.now
        end
        local goal = assert(ns.Goals_Add(ns.MyKey(), "manual", { text = "Dailies", reset = "daily" }))
        ns.Goals_Check()
        assert.is_false(goal.done) -- never by itself
        WowMock.now = NOW + 100
        ns.Goals_Tick(goal.id)
        assert.is_true(goal.done)
        WowMock.now = NOW + 2 * 3600 -- the daily reset was at NOW + 3600
        ns.Goals_Check(WowMock.now)
        assert.is_false(goal.done)
    end)

    it("reopens and removes goals", function()
        local goal = assert(ns.Goals_Add(ns.MyKey(), "manual", { text = "x" }))
        ns.Goals_Tick(goal.id)
        assert.are.equal(1, #ns.Goals_For(ns.MyKey(), true))
        ns.Goals_Reopen(goal.id)
        assert.are.equal(1, #ns.Goals_For(ns.MyKey(), false))
        assert.is_true(ns.Goals_Remove(goal.id))
        assert.are.equal(0, #ns.Goals_All())
    end)

    it("knows only the playing character without the store", function()
        assert.is_nil(ns.Store())
        assert.are.equal(1, #ns.Characters())
        assert.are.equal("Tester-Realm", ns.Characters()[1].key)
    end)

    it("checks again when the game says something changed", function()
        local goal = assert(ns.Goals_Add(ns.MyKey(), "gold", { amount = 200000 }))
        WowMock.char.money = 300000
        FireEvent("PLAYER_MONEY")
        assert.is_true(goal.done)
    end)
end)

describe("goals with the store (the other characters too)", function()
    before_each(function()
        start({ store = true }, {}, { chars = { ["Alt-Realm"] = { name = "Alt", class = "MAGE", level = 30, xp = 0, xpMax = 1000,
            money = 50000, reps = { [529] = { name = "Argent Dawn", standing = 7, cur = 1000, max = 21000 } },
            quests = {}, professions = { { name = "Alchemy", rank = 200, max = 225 } } } } })
    end)

    it("sets and follows goals for another character", function()
        assert.is_not_nil(ns.Store())
        assert.are.equal(2, #ns.Characters())
        local level = assert(ns.Goals_Add("Alt-Realm", "level", { level = 40 }))
        assert.are.equal("level 30 (0%)", ns.Goals_Progress(level).status)
        local rep = assert(ns.Goals_Add("Alt-Realm", "reputation", { faction = 529, name = "Argent Dawn", standing = 8 }))
        assert.is_true(ns.Goals_Progress(rep).known)
        BakalaoDataStoreDB.chars["Alt-Realm"].level = 40
        ns.Goals_Check()
        assert.is_true(level.done)
    end)

    it("asks the store to follow a quest for every character", function()
        assert(ns.Goals_Add("Alt-Realm", "quest", { quest = 4321 }))
        assert.is_true(BakalaoDataStoreDB.watchedQuests[4321])
        assert.is_false(ns.Goals_Progress(ns.Goals_All()[1]).done)
        BakalaoDataStoreDB.chars["Alt-Realm"].quests[4321] = true
        ns.Goals_Check()
        assert.is_true(ns.Goals_All()[1].done)
    end)

    it("counts the whole account's gold and items", function()
        local gold = assert(ns.Goals_Add(ns.MyKey(), "gold", { amount = 1000000, account = true }))
        assert.are.equal("17g / 100g", ns.Goals_Progress(gold).status) -- 12g + 5g
        BakalaoDataStoreDB.chars["Alt-Realm"].bags = { [12360] = 7 }
        WowMock.AddItem(0, 1, 12360, 3, { name = "Arcanite Bar" })
        FireEvent("BAG_UPDATE_DELAYED")
        local items = assert(ns.Goals_Add(ns.MyKey(), "items", { item = 12360, count = 10, account = true }))
        ns.Goals_Check()
        assert.is_true(items.done)
    end)

    it("hears the store's changes", function()
        local goal = assert(ns.Goals_Add(ns.MyKey(), "gold", { amount = 200000 }))
        WowMock.char.money = 300000
        FireEvent("PLAYER_MONEY") -- the store saves it and tells
        assert.is_true(goal.done)
    end)
end)
