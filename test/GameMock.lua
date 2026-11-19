-- The part of the simulated game Alterao reads: the character, its bags and bank, mail, lockouts, reputations,
-- professions and quests. WowMock.char is what the playing character is (reset with WowMock.Reset); the tests
-- change its fields.

local function resetChar()
    WowMock.now = 1800000000 -- time()
    WowMock.char = {
        name = "Tester", realm = "Realm", xp = 500, xpMax = 1000, rested = 200, money = 123456,
        zone = "Stormwind City", subzone = "Trade District", bind = "Goldshire", guild = nil,
        resting = true, ilvl = 42.4, durability = {}, played = 3600 * 30, playedLevel = 1200,
        professions = {}, factions = {}, saved = {}, quests = {}, currencies = {},
    }
    -- bags[bag][slot] = { id =, count =, bound = }; bank bags the same (-1 and 5..11)
    WowMock.bags = { [0] = {}, [1] = {}, [2] = {}, [3] = {}, [4] = {} }
    WowMock.bagSize = { [0] = 16, [1] = 10, [2] = 10, [3] = 10, [4] = 10, [-1] = 24 }
    -- inbox = { { sender =, money =, cod =, daysLeft =, items = { { id =, count = } } } }
    WowMock.inbox = {}
    WowMock.sendItems = {}
    WowMock.cooldowns = {} -- [spellID or "item:id"] = { start, duration }
    WowMock.addons = {}
    WowMock.itemInfo = {} -- [id] = { name =, quality =, classID =, subclassID = }
    WowMock.used = {}
    WowMock.playedRequested, WowMock.raidInfoRequested = nil, nil
end
resetChar()
local baseReset = WowMock.Reset
WowMock.Reset = function()
    baseReset()
    resetChar()
end

time = function(t) if t then return os.time(t) end return WowMock.now end
date = os.date
geterrorhandler = function() return function(err) error(err, 0) end end
NUM_BAG_SLOTS = 4
NUM_BANKBAGSLOTS = 7
BANK_CONTAINER = -1
ITEM_QUALITY_COLORS = { [1] = { r = 1, g = 1, b = 1, hex = "|cffffffff" }, [2] = { r = 0.1, g = 1, b = 0, hex = "|cff1eff00" } }
RAID_CLASS_COLORS.ROGUE = { r = 1, g = 0.96, b = 0.41 }

UnitXP = function() return WowMock.char.xp end
UnitXPMax = function() return WowMock.char.xpMax end
GetXPExhaustion = function() return WowMock.char.rested end
IsResting = function() return WowMock.char.resting end
GetMoney = function() return WowMock.char.money end
GetRealZoneText = function() return WowMock.char.zone end
GetSubZoneText = function() return WowMock.char.subzone end
GetBindLocation = function() return WowMock.char.bind end
GetGuildInfo = function() return WowMock.char.guild, WowMock.char.guild and "Member" end
IsInGuild = function() return WowMock.char.guild ~= nil end
GetAverageItemLevel = function() return WowMock.char.ilvl, WowMock.char.ilvl end
GetInventoryItemDurability = function(slot)
    local d = WowMock.char.durability[slot]
    if d then return d[1], d[2] end
end
UnitSex = function() return 2 end
UnitName = function(token)
    if token == "player" or token == nil then return WowMock.char.name end
    local u = WowMock.units[token]
    return u and u.name
end
UnitFullName = function() return WowMock.char.name, WowMock.char.realm end
GetUnitName = function() return WowMock.char.name end
GetRealmName = function() return WowMock.char.realm end
GetMaxPlayerLevel = function() return 60 end
RequestTimePlayed = function() WowMock.playedRequested = true end
RequestRaidInfo = function() WowMock.raidInfoRequested = true end
CanMerchantRepair = function() return WowMock.char.repair ~= nil end
GetRepairAllCost = function() return WowMock.char.repair or 0, true end

GetProfessions = function()
    local p = WowMock.char.professions
    return p[1] and 1 or nil, p[2] and 2 or nil, nil, p[4] and 4 or nil, p[5] and 5 or nil, p[6] and 6 or nil
end
GetProfessionInfo = function(index)
    local p = WowMock.char.professions[index]
    if p then return p.name, p.icon or 1, p.rank, p.max, 0, 0, p.skillLine or index end
end

C_CurrencyInfo = {
    GetCurrencyListSize = function() return #WowMock.char.currencies end,
    GetCurrencyListInfo = function(i) return WowMock.char.currencies[i] end,
    GetCoinTextureString = function(c) return tostring(c) .. "c" end,
}

local function itemName(id)
    local info = WowMock.itemInfo[id]
    return info and info.name or ("Item" .. id)
end

local function slotOf(bag, slot)
    local b = WowMock.bags[bag]
    return b and b[slot]
end
C_Container = {
    GetContainerNumSlots = function(bag) return WowMock.bags[bag] and (WowMock.bagSize[bag] or 10) or 0 end,
    GetContainerItemInfo = function(bag, slot)
        local s = slotOf(bag, slot)
        if s then
            return { itemID = s.id, stackCount = s.count or 1, isBound = s.bound,
                hyperlink = "|cffffffff|Hitem:" .. s.id .. "::|h[" .. itemName(s.id) .. "]|h|r" }
        end
    end,
    GetContainerNumFreeSlots = function(bag)
        local n = WowMock.bagSize[bag] or 10
        for _ in pairs(WowMock.bags[bag] or {}) do n = n - 1 end
        return n
    end,
    GetItemCooldown = function(id)
        local c = WowMock.cooldowns["item:" .. id]
        if c then return c[1], c[2], 1 end
        return 0, 0, 1
    end,
    UseContainerItem = function(bag, slot) table.insert(WowMock.used, { bag, slot }) end,
}

-- WowMock.AddItem(bag, slot, id, count, info): puts an item in a bag slot (a bank bag too)
function WowMock.AddItem(bag, slot, id, count, info)
    WowMock.bags[bag] = WowMock.bags[bag] or {}
    WowMock.bags[bag][slot] = { id = id, count = count or 1 }
    if info then WowMock.itemInfo[id] = info end
end

C_Item = {
    GetItemInfo = function(id)
        local i = WowMock.itemInfo[id]
        if i then return i.name, "|cffffffff|Hitem:" .. id .. "|h[" .. i.name .. "]|h|r", i.quality or 1 end
    end,
    GetItemInfoInstant = function(id)
        local i = WowMock.itemInfo[id] or {}
        return id, nil, nil, nil, "icon" .. id, i.classID, i.subclassID
    end,
    GetItemCount = function(id)
        local n = 0
        for bag = 0, 4 do
            for _, s in pairs(WowMock.bags[bag] or {}) do
                if s.id == id then n = n + (s.count or 1) end
            end
        end
        return n
    end,
    GetItemSubClassInfo = function() return nil end,
    GetItemClassInfo = function() return nil end,
}
GetInventoryItemID = function(_, slot) return WowMock.inventory[slot] end
GetInventoryItemLink = function() return nil end

C_Spell = {
    GetSpellName = function(id) return "Spell" .. id end,
    GetSpellTexture = function(id) return "icon" .. id end,
    GetSpellCooldown = function(id)
        local c = WowMock.cooldowns[id]
        if c then return { startTime = c[1], duration = c[2], isEnabled = true } end
        return { startTime = 0, duration = 0 }
    end,
}

GetNumSavedInstances = function() return #WowMock.char.saved end
GetSavedInstanceInfo = function(i)
    local s = WowMock.char.saved[i]
    if s then
        return s.name, s.id or i, s.reset, 0, true, false, 0, s.isRaid ~= false, s.players or 40,
            s.difficulty or "40 Player", s.bosses or 10, s.killed or 0
    end
end

C_Reputation = {
    GetNumFactions = function() return #WowMock.char.factions end,
    GetFactionDataByIndex = function(i) return WowMock.char.factions[i] end,
    GetFactionDataByID = function(id)
        for _, f in ipairs(WowMock.char.factions) do
            if f.factionID == id then return f end
        end
    end,
}
C_QuestLog = { IsQuestFlaggedCompleted = function(id) return WowMock.char.quests[id] == true end }
C_DateAndTime = {
    GetSecondsUntilDailyReset = function() return 3600 end,
    GetSecondsUntilWeeklyReset = function() return 2 * 86400 end,
}

GetInboxNumItems = function() return #WowMock.inbox, #WowMock.inbox end
GetInboxHeaderInfo = function(i)
    local m = WowMock.inbox[i]
    return nil, nil, m.sender, m.subject, m.money or 0, m.cod or 0, m.daysLeft or 30, m.items ~= nil and #m.items > 0
end
GetInboxItem = function(i, a)
    local it = WowMock.inbox[i].items and WowMock.inbox[i].items[a]
    if it then return "Item" .. it.id, it.id, "icon", it.count or 1, 1, true end
end
GetSendMailItem = function(i)
    local it = WowMock.sendItems[i]
    if it then return "Item" .. it.id, it.id, "icon", it.count or 1 end
end
GetSendMailMoney = function() return WowMock.sendMoney or 0 end
SendMail = function(to) WowMock.sentTo = to end

C_AddOns.IsAddOnLoaded = function(name) return WowMock.addons[name] == true end
StaticPopupDialogs = {}
StaticPopup_Show = function(name, arg)
    WowMock.popup = { name = name, arg = arg }
    return {}
end
YES, NO = "Yes", "No"

IsPlayerSpell = function(id) return WowMock.spells[id] == true end
