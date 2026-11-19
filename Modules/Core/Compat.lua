local _, ns = ...

-- What the game's API looks like on Forever (the retail engine with Classic content) and the older fallbacks:
-- the namespaced C_* call first, the old global after. Everything that reads the game goes through here, so a
-- missing piece is fixed in one place. Every answer is checked for secret values (ns.Num).

function ns.ItemInstant(itemID)
    local f = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if not f or not itemID then return nil end
    local ok, id, _, _, equipLoc, icon, classID, subclassID = pcall(f, itemID)
    if not ok then return nil end
    return id, icon, classID, subclassID, equipLoc
end

-- name, link, quality (nil while the item isn't cached)
function ns.ItemInfo(itemID)
    local f = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if not f or not itemID then return nil end
    local ok, name, link, quality = pcall(f, itemID)
    if not ok then return nil end
    return name, link, quality
end

function ns.ContainerNumSlots(bag)
    local f = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots
    if not f then return 0 end
    local ok, n = pcall(f, bag)
    return ok and ns.Num(n) or 0
end

-- itemID, count, link of a bag slot (nil when empty)
function ns.ContainerItem(bag, slot)
    if C_Container and C_Container.GetContainerItemInfo then
        local ok, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
        if ok and type(info) == "table" and info.itemID then
            return info.itemID, ns.Num(info.stackCount) or 1, info.hyperlink
        end
        return nil
    end
    if GetContainerItemInfo then
        local _, count, _, _, _, _, link, _, _, id = GetContainerItemInfo(bag, slot)
        if id then return id, count or 1, link end
    end
    return nil
end

-- The bags the character carries: the backpack, the four bag slots and Forever's reagent bag.
function ns.BagIDs()
    local ids = {}
    local last = NUM_BAG_SLOTS or 4
    for bag = 0, last do ids[#ids + 1] = bag end
    local reagent = Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag
    if reagent and reagent > last then ids[#ids + 1] = reagent end
    return ids
end

-- The modern bank (bank tabs through C_Bank, on Forever and Retail) or the old one (the bank container and its bags).
function ns.UsesModernBank()
    return C_Bank ~= nil and C_Bank.FetchPurchasedBankTabIDs ~= nil and Enum ~= nil and Enum.BankType ~= nil
end

local function bankTabs(bankType)
    local list = {}
    local ok, ids = pcall(C_Bank.FetchPurchasedBankTabIDs, bankType)
    if ok and type(ids) == "table" then
        for _, id in ipairs(ids) do list[#list + 1] = id end
    end
    return list
end

function ns.BankBagIDs()
    if ns.UsesModernBank() then return bankTabs(Enum.BankType.Character) end
    local ids = { BANK_CONTAINER or -1 }
    local first = (NUM_BAG_SLOTS or 4) + 1
    for bag = first, first + (NUM_BANKBAGSLOTS or 7) - 1 do ids[#ids + 1] = bag end
    return ids
end

-- The account-wide (warband) bank, when the client has one.
function ns.AccountBankBagIDs()
    if ns.UsesModernBank() and Enum.BankType.Account then return bankTabs(Enum.BankType.Account) end
    return {}
end

function ns.IsAddOnLoaded(name)
    local f = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
    if not f then return false end
    local ok, loaded = pcall(f, name)
    return ok and loaded and true or false
end

---------------------------------------------------------------------------------------------------
-- Spells and cooldowns
---------------------------------------------------------------------------------------------------
function ns.SpellName(spellID)
    if C_Spell and C_Spell.GetSpellName then
        local ok, name = pcall(C_Spell.GetSpellName, spellID)
        if ok and name then return name end
    end
    if GetSpellInfo then
        local ok, name = pcall(GetSpellInfo, spellID)
        if ok and name then return name end
    end
    return nil
end

function ns.SpellIcon(spellID)
    if C_Spell and C_Spell.GetSpellTexture then
        local ok, icon = pcall(C_Spell.GetSpellTexture, spellID)
        if ok and icon then return icon end
    end
    if GetSpellInfo then
        local ok, _, _, icon = pcall(GetSpellInfo, spellID)
        if ok and icon then return icon end
    end
    return nil
end

function ns.KnowsSpell(spellID)
    if IsPlayerSpell then
        local ok, known = pcall(IsPlayerSpell, spellID)
        if ok and known then return true end
    end
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        local ok, known = pcall(C_SpellBook.IsSpellKnown, spellID)
        if ok and known then return true end
    end
    if IsSpellKnown then
        local ok, known = pcall(IsSpellKnown, spellID)
        if ok and known then return true end
    end
    return false
end

-- start, duration (GetTime() seconds) of a spell's cooldown; nil when unknown or hidden.
function ns.SpellCooldown(spellID)
    if C_Spell and C_Spell.GetSpellCooldown then
        local ok, info = pcall(C_Spell.GetSpellCooldown, spellID)
        if ok and type(info) == "table" then return ns.Num(info.startTime), ns.Num(info.duration) end
    end
    if GetSpellCooldown then
        local ok, start, duration = pcall(GetSpellCooldown, spellID)
        if ok then return ns.Num(start), ns.Num(duration) end
    end
    return nil
end

function ns.ItemCooldown(itemID)
    local f = (C_Container and C_Container.GetItemCooldown) or GetItemCooldown
    if not f then return nil end
    local ok, start, duration = pcall(f, itemID)
    if ok then return ns.Num(start), ns.Num(duration) end
    return nil
end

-- The time() a cooldown ends, from GetTime()-based start and duration; nil when it isn't running (or is the
-- global cooldown).
function ns.CooldownReadyAt(start, duration)
    if not start or not duration or duration <= 2 or start <= 0 then return nil end
    local remaining = start + duration - GetTime()
    if remaining <= 0 then return nil end
    return ns.Now() + math.floor(remaining + 0.5)
end

---------------------------------------------------------------------------------------------------
-- Reputation: C_Reputation (retail engine) or the old globals, as one shape:
--   { id =, name =, isHeader =, hasRep =, standing = 1..8, cur =, max = }  (cur / max inside the current standing)
---------------------------------------------------------------------------------------------------
local function fromData(d)
    if type(d) ~= "table" or not d.name then return nil end
    local low = ns.Num(d.currentReactionThreshold) or 0
    local high = ns.Num(d.nextReactionThreshold) or low
    local value = ns.Num(d.currentStanding) or low
    return {
        id = d.factionID, name = d.name, isHeader = d.isHeader, hasRep = d.isHeaderWithRep,
        standing = ns.Num(d.reaction), cur = value - low, max = high - low,
    }
end

local function fromOld(name, standing, low, high, value, isHeader, hasRep, id)
    if not name then return nil end
    low, high, value = ns.Num(low) or 0, ns.Num(high) or 0, ns.Num(value) or 0
    return { id = id, name = name, isHeader = isHeader, hasRep = hasRep, standing = ns.Num(standing),
        cur = value - low, max = high - low }
end

function ns.FactionCount()
    if C_Reputation and C_Reputation.GetNumFactions then
        local ok, n = pcall(C_Reputation.GetNumFactions)
        if ok then return ns.Num(n) or 0 end
    end
    if GetNumFactions then return ns.Num(GetNumFactions()) or 0 end
    return 0
end

function ns.FactionByIndex(i)
    if C_Reputation and C_Reputation.GetFactionDataByIndex then
        local ok, d = pcall(C_Reputation.GetFactionDataByIndex, i)
        if ok then return fromData(d) end
    end
    if GetFactionInfo then
        local ok, name, _, standing, low, high, value, _, _, isHeader, _, hasRep, _, _, id = pcall(GetFactionInfo, i)
        if ok then return fromOld(name, standing, low, high, value, isHeader, hasRep, id) end
    end
    return nil
end

function ns.FactionByID(id)
    if C_Reputation and C_Reputation.GetFactionDataByID then
        local ok, d = pcall(C_Reputation.GetFactionDataByID, id)
        if ok then return fromData(d) end
    end
    if GetFactionInfoByID then
        local ok, name, _, standing, low, high, value, _, _, isHeader, _, hasRep = pcall(GetFactionInfoByID, id)
        if ok then return fromOld(name, standing, low, high, value, isHeader, hasRep, id) end
    end
    return nil
end

local STANDINGS = { "Hated", "Hostile", "Unfriendly", "Neutral", "Friendly", "Honored", "Revered", "Exalted" }
function ns.StandingName(standing)
    if not standing then return "-" end
    return _G["FACTION_STANDING_LABEL" .. standing] or ns.L[STANDINGS[standing] or "?"]
end

-- The game's colors for each standing.
local STANDING_COLORS = {
    { 0.8, 0.13, 0.13 }, { 0.8, 0.13, 0.13 }, { 0.75, 0.27, 0 }, { 0.9, 0.7, 0 },
    { 0, 0.6, 0.1 }, { 0, 0.6, 0.1 }, { 0, 0.6, 0.1 }, { 0, 0.6, 0.1 },
}
function ns.StandingColor(standing)
    local c = (FACTION_BAR_COLORS and FACTION_BAR_COLORS[standing or 0]) or nil
    if c then return c.r, c.g, c.b end
    c = STANDING_COLORS[standing or 4] or STANDING_COLORS[4]
    return c[1], c[2], c[3]
end

---------------------------------------------------------------------------------------------------
-- Resets of the daily and weekly lockouts (server time), as time() values.
---------------------------------------------------------------------------------------------------
function ns.NextDailyReset()
    if C_DateAndTime and C_DateAndTime.GetSecondsUntilDailyReset then
        local ok, s = pcall(C_DateAndTime.GetSecondsUntilDailyReset)
        s = ok and ns.Num(s)
        if s then return ns.Now() + s end
    end
    if GetQuestResetTime then
        local s = ns.Num(GetQuestResetTime())
        if s and s > 0 then return ns.Now() + s end
    end
    return nil
end

function ns.NextWeeklyReset()
    if C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset then
        local ok, s = pcall(C_DateAndTime.GetSecondsUntilWeeklyReset)
        s = ok and ns.Num(s)
        if s then return ns.Now() + s end
    end
    return nil
end

---------------------------------------------------------------------------------------------------
-- The character's name. On Forever two-word names ("Elsa Cacorchos") can come back cut, the second word passed
-- off as the realm: the longest answer of the three calls wins, as in Embolsao.
---------------------------------------------------------------------------------------------------
function ns.PlayerName()
    local name = UnitName("player") or "?"
    local full = GetUnitName and GetUnitName("player", false)
    if type(full) == "string" and #full > #name then name = full end
    if UnitFullName then
        local unitFull = UnitFullName("player")
        if type(unitFull) == "string" and #unitFull > #name then name = unitFull end
    end
    return name
end

function ns.RealmName()
    return ((GetRealmName and GetRealmName()) or ""):gsub("%s", "")
end

function ns.CoinString(copper)
    local f = (C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString) or GetCoinTextureString
    if f then
        local ok, text = pcall(f, copper)
        if ok and text then return text end
    end
    return ns.FormatMoney(copper)
end
