local _, ns = ...
local L = ns.L

-- The family's other addons, all optional: when one is installed, a goal's menu gets an entry that opens it where it
-- helps. Nothing else in Enfocao names them.
--   Completao!!  a quest goal (an attunement...): its chain, in Completao's window (CompletaoAPI.ShowQuest)
--   Fabrikao!!   an items goal: how to craft the item, when a recipe makes it (FabrikaoAPI.HasRecipeFor / ShowRecipeFor),
--                and the recipes that use it (FabrikaoAPI.ShowRecipesUsing)

local function api(name)
    local t = _G[name]
    if type(t) == "table" and (t.version or 0) >= 1 then return t end
    return nil
end

-- The extra menu entries for a goal: { { name =, run = } } (empty without the addons).
function ns.Goals_AddonOptions(goal)
    local options = {}
    local completao = api("CompletaoAPI")
    if goal.type == "quest" and completao and completao.HasQuest(goal.p.quest) then
        options[#options + 1] = { name = L["Show the chain in Completao!!"], run = function() completao.ShowQuest(goal.p.quest) end }
    end
    local fabrikao = api("FabrikaoAPI")
    -- (HasRecipeFor / ShowRecipeFor came after the first version: older Fabrikao installs don't have them)
    if goal.type == "items" and fabrikao and fabrikao.ShowRecipeFor and fabrikao.HasRecipeFor
        and fabrikao.HasRecipeFor(goal.p.item) then
        options[#options + 1] = { name = L["How to craft it (Fabrikao!!)"], run = function() fabrikao.ShowRecipeFor(goal.p.item) end }
    end
    if goal.type == "items" and fabrikao and fabrikao.ShowRecipesUsing then
        options[#options + 1] = { name = L["Recipes that use it (Fabrikao!!)"], run = function() fabrikao.ShowRecipesUsing(goal.p.item) end }
    end
    return options
end
