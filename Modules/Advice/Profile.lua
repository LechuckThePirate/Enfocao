local _, ns = ...

-- The player's style ("Your style"), asked the first time the suggestions open and changed whenever: how they play,
-- what they like and how long they usually play. It weighs the suggestions: what they like goes up, what they don't
-- goes down, and the style tilts some kinds (a min-maxer sees gear and attunements sooner). Account-wide:
--   EnfocaoDB.profile = { style = "chill" | "balanced" | "minmax", likes = { [interest] = true }, session = "short" |
--   "hour" | "long", set = time() }   (session is for the daily plan to come)

ns.PROFILE_STYLES = {
    { key = "chill", name = "Chill", text = "I play to have a good time, no rush" },
    { key = "balanced", name = "Balanced", text = "A bit of everything, at my own pace" },
    { key = "minmax", name = "Min-maxer", text = "I want to be as efficient as possible" },
}

-- What a player can like; `tags` are the suggestions' tags it covers.
ns.PROFILE_LIKES = {
    { key = "leveling", name = "Questing and leveling", tags = { leveling = true } },
    { key = "dungeons", name = "Dungeons", tags = { dungeons = true } },
    { key = "raids", name = "Raids", tags = { raids = true } },
    { key = "pvp", name = "PvP", tags = { pvp = true } },
    { key = "professions", name = "Professions", tags = { professions = true } },
    { key = "gold", name = "Making gold", tags = { gold = true } },
    { key = "reputation", name = "Reputations", tags = { reputation = true } },
    { key = "alts", name = "Playing alts", tags = { alts = true } },
    { key = "collecting", name = "Collecting", tags = { collecting = true } },
}

ns.PROFILE_SESSIONS = {
    { key = "short", name = "Short sessions (under an hour)" },
    { key = "hour", name = "About an hour" },
    { key = "long", name = "Long sessions" },
}

-- How the style tilts each tag.
local STYLE_TILT = {
    chill = { gear = 0.6, raids = 0.8, gold = 0.9, reputation = 1.1, collecting = 1.2 },
    balanced = {},
    minmax = { gear = 1.4, raids = 1.2, dungeons = 1.1, professions = 1.1, gold = 1.1 },
}

local LIKED, NOT_LIKED = 1.3, 0.7

function ns.Profile()
    return ns.db.profile
end

function ns.Profile_IsSet()
    return ns.db.profile ~= nil and ns.db.profile.set ~= nil
end

function ns.Profile_Save(style, likes, session)
    ns.db.profile = { style = style or "balanced", likes = likes or {}, session = session or "hour", set = ns.Now() }
end

-- The weight of a suggestion with these tags: the style's tilt times liked / not liked (only when some likes were
-- picked: no likes means no opinion).
function ns.Profile_Weight(tags)
    local profile = ns.db.profile
    if not profile or not tags then return 1 end
    local weight = 1
    local tilt = STYLE_TILT[profile.style] or {}
    local anyLike = next(profile.likes or {}) ~= nil
    local liked, known = false, false
    for tag in pairs(tags) do
        weight = weight * (tilt[tag] or 1)
        for _, like in ipairs(ns.PROFILE_LIKES) do
            if like.tags[tag] then
                known = true
                if profile.likes[like.key] then liked = true end
            end
        end
    end
    if anyLike and known then weight = weight * (liked and LIKED or NOT_LIKED) end
    return weight
end
