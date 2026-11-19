local _, ns = ...

-- What is known about a character, the same way whether it comes from BakalaoStudios DataStore (optional: then the
-- other characters of the account are known too, and Enfocao can set them goals) or from the game, live (only the
-- playing character). Nothing else in the addon names the store.
--   ns.Store()            the store's API, or nil
--   ns.MyKey() / IsMe()   the playing character's key ("Name-Realm", as the store keys them)
--   ns.Characters()       { { key =, rec = } }: the store's characters, or the playing one alone
--   ns.GetChar(key)       a record: name, class, classLocal, level, xp, xpMax, maxLevel, money, faction,
--                         professions = { { name, rank, max, skillLine, primary } }  (live for the playing one)
--   ns.Reputation(key, factionID) -> { name, standing, cur, max } or nil
--   ns.ItemCount(key, itemID, account) -> how many (bags and bank; mail too with the store)
--   ns.QuestDone(key, questID) -> true / false / nil (unknown)
--   ns.Factions(key)      { { id =, name = } } the factions the character has met
--   ns.ViewKey() / SetViewKey(key)  the character the window shows

local MAX_LEVEL = 60

function ns.Store()
    local store = _G.BakalaoDataStore
    if type(store) == "table" and (store.version or 0) >= 1 then return store end
    return nil
end

function ns.MyKey()
    local store = ns.Store()
    if store then return store.MyKey() end
    return ns.PlayerName() .. "-" .. ns.RealmName()
end

function ns.IsMe(key)
    return key == ns.MyKey()
end

-- The playing character, read from the game now (what is cheap to read; reputations and items are asked when needed).
function ns.LiveRecord()
    local _, class = UnitClass("player")
    local level = ns.Num(UnitLevel("player")) or 1
    local xpMax = ns.Num(UnitXPMax("player"))
    local professions = {}
    if GetProfessions and GetProfessionInfo then
        local indices = { GetProfessions() }
        for slot = 1, 6 do
            local index = indices[slot]
            if index then
                local ok, name, icon, rank, maxRank, _, _, skillLine = pcall(GetProfessionInfo, index)
                if ok and name then
                    professions[#professions + 1] = { name = name, icon = icon, rank = ns.Num(rank), max = ns.Num(maxRank),
                        skillLine = skillLine, primary = slot <= 2 }
                end
            end
        end
    end
    return {
        name = ns.PlayerName(), class = class, classLocal = UnitClass("player"), faction = UnitFactionGroup("player"),
        level = level, xp = ns.Num(UnitXP("player")), xpMax = xpMax, maxLevel = level >= MAX_LEVEL,
        money = ns.Num(GetMoney()), professions = professions,
    }
end

function ns.GetChar(key)
    local store = ns.Store()
    if store then
        local rec = store.GetCharacter(key)
        if rec then return rec end
    end
    if ns.IsMe(key) then return ns.LiveRecord() end
    return nil
end

function ns.Characters()
    local store = ns.Store()
    if store then return store.Characters() end
    return { { key = ns.MyKey(), rec = ns.LiveRecord() } }
end

-- A reputation, live for the playing character (it doesn't need the store), saved for the others.
function ns.Reputation(key, factionID)
    if ns.IsMe(key) then
        local f = ns.FactionByID(factionID)
        if f and f.standing then return { name = f.name, standing = f.standing, cur = f.cur, max = f.max } end
    end
    local rec = ns.GetChar(key)
    return rec and rec.reps and rec.reps[factionID] or nil
end

-- The factions a character has met: the reputation window's list for the playing one, the saved ones for the rest.
function ns.Factions(key)
    local list, seen = {}, {}
    if ns.IsMe(key) then
        for i = 1, ns.FactionCount() do
            local f = ns.FactionByIndex(i)
            if f and f.id and not seen[f.id] and (not f.isHeader or f.hasRep) and f.standing then
                seen[f.id] = true
                list[#list + 1] = { id = f.id, name = f.name }
            end
        end
    end
    local rec = ns.GetChar(key)
    for id, r in pairs(rec and rec.reps or {}) do
        if type(id) == "number" and not seen[id] then
            seen[id] = true
            list[#list + 1] = { id = id, name = r.name }
        end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

local function liveItemCount(itemID)
    local f = (C_Item and C_Item.GetItemCount) or GetItemCount
    if not f then return 0 end
    local ok, n = pcall(f, itemID, true) -- bags and bank
    return ok and ns.Num(n) or 0
end

-- How many of an item a character has (bags and bank; with the store, its mailbox too), or the whole account.
function ns.ItemCount(key, itemID, account)
    local store = ns.Store()
    if account and store then return store.ItemHolders(itemID).total end
    if ns.IsMe(key) then
        local n = liveItemCount(itemID)
        local rec = store and store.GetCharacter(key)
        local mail = rec and rec.mail and rec.mail.items and rec.mail.items[itemID] or 0
        return n + mail
    end
    if store then
        for _, h in ipairs(store.ItemHolders(itemID).chars) do
            if h.key == key then return h.total end
        end
    end
    return 0
end

function ns.QuestDone(key, questID)
    if ns.IsMe(key) then
        if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
            local ok, done = pcall(C_QuestLog.IsQuestFlaggedCompleted, questID)
            if ok then return done == true end
        end
        if IsQuestFlaggedCompleted then return IsQuestFlaggedCompleted(questID) == true end
    end
    local store = ns.Store()
    if store then return store.QuestDone(key, questID) end
    return nil
end

-- An item's name and icon (the store remembers names the game's cache may not have yet).
function ns.ItemName(itemID)
    local store = ns.Store()
    if store then return store.ItemName(itemID) end
    return ns.ItemInfo(itemID) or ("item:%d"):format(itemID)
end

function ns.ItemIcon(itemID)
    local _, icon = ns.ItemInstant(itemID)
    return icon or 134400
end

-- The account's gold: every character the store knows, or the playing one.
function ns.AccountGold()
    local total = 0
    for _, c in ipairs(ns.Characters()) do total = total + (c.rec.money or 0) end
    return total
end

-- The last daily / weekly reset (for repeating goals): from the store, or from the game's countdown.
function ns.LastReset(kind)
    local store = ns.Store()
    if store then
        local at = store.LastReset(kind)
        if at then return at end
    end
    local nextAt = kind == "weekly" and ns.NextWeeklyReset() or ns.NextDailyReset()
    if not nextAt then return nil end
    return nextAt - (kind == "weekly" and 7 * 86400 or 86400)
end

function ns.ViewKey()
    local key = ns.settings.viewKey
    if key and ns.GetChar(key) then return key end
    return ns.MyKey()
end

function ns.SetViewKey(key)
    ns.settings.viewKey = (key ~= ns.MyKey()) and key or nil
end
