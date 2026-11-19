local ADDON, ns = ...
local L = ns.L

-- Addon entry point: loaded last, once the modules are in. On load the saved variables are prepared and the goals
-- start listening; on entering the world they are checked and a line says how many are on.

function ns.ApplySettings()
    ns.Minimap_Init()
    ns.UI_ApplyScale()
    ns.Hud_Refresh()
    ns.UI_Refresh(true)
    ns.Prefs_Refresh()
end

local function onLoaded()
    EnfocaoDB = EnfocaoDB or {}
    ns.db = EnfocaoDB
    ns.InitSettings()
    ns.Goals_Init()
    ns.Minimap_Init()
end

local started = false
local function onEnterWorld()
    if started then return end
    started = true
    -- a moment later: the store (when installed) has looked at the character by then
    C_Timer.After(3, function()
        ns.SafeCall(ns.Goals_Check)
        ns.Hud_Refresh()
        if ns.settings.quiet then return end
        local n = #ns.Goals_For(ns.MyKey(), false)
        local text = n == 0 and L["no goals yet: /enfocao new"] or (n == 1 and L["1 goal on: /enfocao"] or L["%d goals on: /enfocao"]:format(n))
        print(("|cffd94fb0Enfocao!!|r v%s -- %s"):format(ns.Version(), text))
    end)
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("ADDON_LOADED")
boot:RegisterEvent("PLAYER_ENTERING_WORLD")
boot:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON then return end
        onLoaded()
    elseif event == "PLAYER_ENTERING_WORLD" and ns.db then
        ns.SafeCall(onEnterWorld)
    end
end)

SLASH_ENFOCAO1 = "/enfocao"
SLASH_ENFOCAO2 = "/enf"
SlashCmdList.ENFOCAO = function(msg)
    local command = strtrim(msg or ""):lower()
    if command == "" or command == "show" then
        ns.UI_Toggle()
    elseif command == "new" then
        ns.NewGoal_Show()
    elseif command == "hud" then
        ns.Hud_SetShown(not ns.settings.hud)
    elseif command == "prefs" or command == "options" or command == "config" then
        ns.Prefs_Toggle()
    elseif command == "minimap" then
        ns.Minimap_Toggle()
    elseif command == "about" then
        ns.About_Show()
    elseif command == "version" then
        ns.Print("v" .. ns.Version())
    else
        local found = false
        for _, view in ipairs(ns.UI_Views()) do
            if view.key == command then
                ns.UI_Show(view.key)
                found = true
            end
        end
        if not found then ns.Print(L["Usage: /enfocao | new | goals | achieved | hud | prefs | minimap | about | version"]) end
    end
end
