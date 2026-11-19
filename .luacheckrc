-- luacheck: Lua 5.1, the game's version. Runs in CI; locally:
--   luacheck -q -- Enfocao.lua Enfocao.test.lua Localization Modules test setupTests.lua
std = "lua51"
max_line_length = 170
codes = true

exclude_files = {
    "tools/",
    ".github/",
    "images/",
    ".claude/",
}

-- what the addon defines as globals
globals = {
    "EnfocaoDB",
    "SlashCmdList", "SLASH_ENFOCAO1", "SLASH_ENFOCAO2",
    StaticPopupDialogs = { other_fields = true },
}

-- the game's API and frames it uses
read_globals = {
    "CANCEL", "RaidNotice_AddMessage", "RaidWarningFrame", "SOUNDKIT", "ATTACHMENTS_MAX_RECEIVE", "ATTACHMENTS_MAX_SEND", "BANK_CONTAINER", "C_AddOns", "C_Bank", "C_Container", "C_CurrencyInfo",
    "C_DateAndTime", "BreakUpLargeNumbers", "C_Item", "CLASS_ICON_TCOORDS", "C_PlayerInfo", "C_QuestLog", "C_Reputation", "C_Spell", "C_SpellBook", "C_Timer", "CAMERA_MODIFICATION_TYPE_DISCARD", "CAMERA_TRANSITION_TYPE_IMMEDIATE", "CanMerchantRepair", "ChatEdit_InsertLink",
    "CLOSE", "CreateFrame", "CUSTOM_CLASS_COLORS", "Enum", "FACTION_ALLIANCE", "FACTION_BAR_COLORS", "FACTION_HORDE", "GameTooltip",
    "GameTooltip_Hide", "GetAddOnMetadata", "GetAverageItemLevel", "GetBindLocation", "GetCoinTextureString", "GetContainerItemInfo",
    "GetContainerNumSlots", "GetCursorPosition", "GetFactionInfo", "GetFactionInfoByID", "GetGuildBankItemInfo", "GetGuildBankItemLink",
    "GetGuildBankMoney", "GetGuildBankTabInfo", "GetGuildInfo", "GetInboxHeaderInfo", "GetInboxItem", "GetInboxItemLink",
    "GetInboxNumItems", "GetInventoryItemDurability", "GetInventoryItemID", "GetInventoryItemLink", "GetItemClassInfo", "GetItemCooldown",
    "GetItemCount", "GetItemInfo", "GetItemInfoInstant", "GetItemSubClassInfo", "GetLocale", "GetMaxLevelForPlayerExpansion",
    "GetMaxPlayerLevel", "GetMoney", "GetNumFactions", "GetNumGuildBankTabs", "GetNumSavedInstances", "GetProfessionInfo",
    "GetProfessions", "GetPVPLifetimeStats", "GetPVPRankInfo", "GetPVPThisWeekStats", "GetQuestResetTime", "GetRealmName",
    "GetRealZoneText", "GetRepairAllCost", "GetSavedInstanceInfo", "GetSendMailItem", "GetSendMailMoney", "GetSpellCooldown",
    "GetSpellInfo", "GetSubZoneText", "GetTime", "GetUnitName", "GetXPExhaustion", "GetZoneText", "geterrorhandler", "hooksecurefunc",
    "IsAddOnLoaded", "IsInGuild", "LOCALIZED_CLASS_NAMES_MALE", "IsLevelAtEffectiveMaxLevel", "IsXPUserDisabled", "IsMouseButtonDown", "IsPlayerSpell", "IsQuestFlaggedCompleted", "IsResting", "IsShiftKeyDown",
    "IsSpellKnown", "issecretvalue", "ITEM_QUALITY_COLORS", "MAX_GUILDBANK_SLOTS_PER_TAB", "MAX_PLAYER_LEVEL", "Minimap", "NO",
    "NUM_BAG_SLOTS", "NUM_BANKBAGSLOTS", "NUM_CHAT_WINDOWS", "QueryGuildBankTab", "RAID_CLASS_COLORS", "RequestRaidInfo",
    "RequestTimePlayed", "SendMail", "StaticPopup_Show", "strtrim", "TooltipDataProcessor", "tinsert", "UIParent", "UISpecialFrames",
    "UnitClass", "UnitFactionGroup", "UnitExists", "UnitFullName", "UnitIsPlayer", "UnitLevel", "UnitName", "UnitPVPRank", "UnitRace", "UnitSex", "UnitXP",
    "UnitXPMax", "UseContainerItem", "YES",
}

-- tests (busted): they define and change the simulated game's globals on purpose
files["**/*.test.lua"] = { std = "+busted", globals = { "_G" }, allow_defined_top = true, ignore = { "111", "112", "113", "121", "122" } }
files["setupTests.lua"] = { std = "+busted", allow_defined_top = true, ignore = { "111", "112", "113", "121", "122" } }
files["test/"] = { std = "+busted", allow_defined_top = true, ignore = { "111", "112", "113", "121", "122", "131", "212" } }
