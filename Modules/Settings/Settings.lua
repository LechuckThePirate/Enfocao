local _, ns = ...

-- Settings for the whole account (EnfocaoDB.settings). A key that was never set reads as its default, so a checkbox
-- can store a plain true / false.
ns.DEFAULTS = {
    quiet = false,          -- no chat line at login
    scale = 1,              -- the window's size
    artAlpha = 0.22,        -- the picture behind the window's views
    hud = true,             -- the small "Today" window with the playing character's plan for today
    hudLocked = false,      -- it can't be dragged
    hudMax = 5,             -- how many steps it lists
    sound = true,           -- a sound when a goal is reached
    centerMessage = true,   -- and a message in the middle of the screen
}

function ns.InitSettings()
    EnfocaoDB.settings = EnfocaoDB.settings or {}
    local store = EnfocaoDB.settings
    ns.settings = setmetatable({}, {
        __index = function(_, key)
            local value = store[key]
            if value == nil then return ns.DEFAULTS[key] end
            return value
        end,
        __newindex = function(_, key, value) store[key] = value end,
    })
end

-- Back to the defaults (positions included).
function ns.ResetSettings()
    for key in pairs(EnfocaoDB.settings) do EnfocaoDB.settings[key] = nil end
    if ns.ApplySettings then ns.ApplySettings() end
end
