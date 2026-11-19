dofile("setupTests.lua")

-- The suggested goals: each advisor, how the player's style weighs them, what is never suggested (goals already set,
-- dismissed, left for later), accepting one, and the Suggestions view with its "Your style" form.

local NOW = 1800000000
local ns

local function start(opts, db, storeDB)
    WowMock.Reset()
    ns = LoadAddon(opts)
    StartAddon(ns, db or {}, storeDB)
    return ns
end

local function byId(list)
    local map = {}
    for _, s in ipairs(list) do map[s.id] = s end
    return map
end

describe("advisors", function()
    before_each(function() start() end)

    it("suggests the next milestone level, and why", function()
        local s = byId(ns.Advice_For(ns.MyKey()))["level:30"] -- the character is level 20
        assert.is_not_nil(s)
        assert.matches("10 levels away", s.why)
        assert.are.equal("level", s.goal.type)
    end)

    it("prefers leveling with the rested experience over the milestone (one level goal at a time)", function()
        WowMock.char.rested = 1200 -- 120% of the bar
        local list = ns.Advice_For(ns.MyKey())
        local ids = byId(list)
        assert.is_not_nil(ids["rested:21"])
        assert.is_nil(ids["level:30"])
        assert.matches("120%%", ids["rested:21"].why)
    end)

    it("saves for the mount between 30 and 40", function()
        WowMock.level = 34
        assert.is_not_nil(byId(ns.Advice_For(ns.MyKey())).mount)
        WowMock.level = 41
        assert.is_nil(byId(ns.Advice_For(ns.MyKey())).mount)
    end)

    it("raises professions behind the level, and the ones at the top of their rank", function()
        WowMock.char.professions = {
            [1] = { name = "Skinning", rank = 40, max = 150, skillLine = 393 },
            [2] = { name = "Leatherworking", rank = 150, max = 150, skillLine = 165 },
        }
        local ids = byId(ns.Advice_For(ns.MyKey()))
        assert.matches("could be at 100", ids["prof:Skinning:100"].why)
        assert.matches("Expert", ids["prof:Leatherworking:225"].why)
    end)

    it("suggests First Aid to whom hasn't learned it", function()
        WowMock.char.professions = { [1] = { name = "Mining", rank = 100, max = 150 } }
        assert.is_not_nil(byId(ns.Advice_For(ns.MyKey())).firstaid)
        WowMock.char.professions[6] = { name = "First Aid", rank = 100, max = 150 }
        assert.is_nil(byId(ns.Advice_For(ns.MyKey())).firstaid)
    end)

    it("pushes a reputation close to the next standing", function()
        WowMock.char.factions = { { factionID = 529, name = "Argent Dawn", reaction = 5, currentReactionThreshold = 3000,
            nextReactionThreshold = 9000, currentStanding = 8000 } } -- Friendly 5000/6000
        local s = byId(ns.Advice_For(ns.MyKey()))["rep:529:6"]
        assert.matches("83%% of the way to Honored", s.why)
    end)

    it("suggests the attunements the level allows, not the done ones", function()
        WowMock.level = 56
        local ids = byId(ns.Advice_For(ns.MyKey()))
        assert.is_not_nil(ids["att:mc"])
        assert.is_not_nil(ids["att:brd"])
        assert.is_nil(ids["att:bwl"]) -- level 58
        WowMock.char.quests[7848] = true
        assert.is_nil(byId(ns.Advice_For(ns.MyKey()))["att:mc"])
    end)

    it("spots a piece of gear far below the rest", function()
        WowMock.itemInfo = {}
        local levels = { [1] = 30, [3] = 30, [5] = 30, [7] = 30, [8] = 10 }
        local oldLink, oldLevel = _G.GetInventoryItemLink, _G.C_Item.GetDetailedItemLevelInfo
        _G.GetInventoryItemLink = function(_, slot) return levels[slot] and ("item:" .. slot) end
        _G.C_Item.GetDetailedItemLevelInfo = function(link) return levels[tonumber(link:match("item:(%d+)"))] end
        local s = byId(ns.Advice_For(ns.MyKey()))["gear:8"]
        _G.GetInventoryItemLink, _G.C_Item.GetDetailedItemLevelInfo = oldLink, oldLevel
        assert.matches("feet", s.why)
    end)
end)

describe("what is never suggested", function()
    before_each(function() start() end)

    it("leaves out kinds already set as goals", function()
        ns.Goals_Add(ns.MyKey(), "level", { level = 25 })
        assert.is_nil(byId(ns.Advice_For(ns.MyKey()))["level:30"])
    end)

    it("forgets dismissed suggestions and brings back the postponed ones in a few days", function()
        ns.Advice_Dismiss(ns.MyKey(), "level:30")
        assert.is_nil(byId(ns.Advice_For(ns.MyKey()))["level:30"])
        WowMock.char.professions = { [1] = { name = "Mining", rank = 100, max = 150 } }
        ns.Advice_Later(ns.MyKey(), "firstaid", NOW)
        assert.is_nil(byId(ns.Advice_For(ns.MyKey(), NOW + 86400)).firstaid)
        assert.is_not_nil(byId(ns.Advice_For(ns.MyKey(), NOW + 4 * 86400)).firstaid)
        ns.Advice_Reset(ns.MyKey())
        assert.is_not_nil(byId(ns.Advice_For(ns.MyKey()))["level:30"])
    end)

    it("turns an accepted suggestion into a goal", function()
        local s = byId(ns.Advice_For(ns.MyKey()))["level:30"]
        local goal = ns.Advice_Accept(ns.MyKey(), s)
        assert.are.equal("Level 30", ns.Goals_Title(goal))
        assert.is_nil(byId(ns.Advice_For(ns.MyKey()))["level:30"])
    end)
end)

describe("the player's style", function()
    before_each(function() start() end)

    it("weighs what is liked up and the rest down, and tilts by style", function()
        assert.are.equal(1, ns.Profile_Weight({ gear = true })) -- no style set: no opinion
        ns.Profile_Save("minmax", { professions = true }, "long")
        assert.near(1.4, ns.Profile_Weight({ gear = true }), 0.001) -- gear isn't a like: only the tilt
        assert.near(1.1 * 1.3, ns.Profile_Weight({ professions = true }), 0.001)
        assert.near(0.7, ns.Profile_Weight({ reputation = true }), 0.001)
        ns.Profile_Save("chill", {}, "short")
        assert.near(0.6, ns.Profile_Weight({ gear = true }), 0.001)
    end)

    it("reorders the suggestions", function()
        WowMock.char.professions = { [1] = { name = "Skinning", rank = 40, max = 150 } }
        ns.Profile_Save("balanced", { professions = true }, "hour")
        local first = ns.Advice_For(ns.MyKey())[1]
        assert.are.equal("profession", first.goal.type)
        ns.Profile_Save("balanced", { leveling = true }, "hour")
        assert.are.equal("level", ns.Advice_For(ns.MyKey())[1].goal.type)
    end)
end)

describe("the Suggestions view and the style form", function()
    it("asks the style the first time, then lists and accepts suggestions", function()
        local ns2 = start()
        ns2.UI_Show("suggestions")
        local form = ns2.Profile_Frame()
        assert.is_true(form:IsShown())
        -- pick min-maxer, professions, long sessions, save
        for _, b in ipairs(form.style.chips) do if b.key == "minmax" then b:Click() end end
        for _, b in ipairs(form.likes) do if b.key == "professions" then b:Click() end end
        WowMock.Find(function(f) return f._parent == form and f._text == "Save" end):Click()
        assert.are.equal("minmax", ns2.Profile().style)
        assert.is_true(ns2.Profile().likes.professions)
        local content = ns2.UI_Current().content
        assert.matches("Min%-maxer", content.style:GetText())
        local before = #ns2.Goals_All()
        content.rows[1].accept:Click()
        assert.are.equal(before + 1, #ns2.Goals_All())
        content.rows[1].dismiss:Click()
        content.rows[1].later:Click()
    end)

    it("works for another character with the store", function()
        local ns2 = start({ store = true }, { profile = { style = "balanced", likes = {}, session = "hour", set = 1 } },
            { chars = { ["Alt-Realm"] = { name = "Alt", class = "MAGE", level = 33, money = 10000, xpMax = 1000, rested = 0,
                faction = "Horde", professions = {} } } })
        local ids = byId(ns2.Advice_For("Alt-Realm"))
        assert.is_not_nil(ids.mount)
        assert.is_not_nil(ids["level:40"])
    end)
end)
