local ADDON, ns = ...

-- Small helpers every module uses: printing, the event dispatcher, safe calls, debouncing and the formatting of
-- money, durations and character names.

function ns.Print(...)
    print("|cffd94fb0Enfocao!!|r:", ...)
end

function ns.Version()
    local getMeta = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
    return getMeta and getMeta(ADDON, "Version") or "?"
end

-- "Secret values": Forever (like Retail 12.x) hides some numbers from addons. A secret can be handed to a widget
-- but comparing it or doing arithmetic with it is a Lua error, so every value read from the game that is compared
-- or saved goes through this first.
function ns.IsSecret(value)
    return issecretvalue ~= nil and issecretvalue(value) == true
end

-- A number from the game, or nil when it is missing or hidden.
function ns.Num(value)
    if value == nil or ns.IsSecret(value) or type(value) ~= "number" then return nil end
    return value
end

-- Runs f; an error is shown the game's way (the error frame, BugSack...) but doesn't stop the caller, so a client
-- that lacks one API only loses that one piece of information.
-- (The arguments go through a closure: the game's xpcall passes extra arguments on, plain Lua 5.1's doesn't.)
local unpackArgs = unpack or table.unpack -- luacheck: ignore 143
function ns.SafeCall(f, ...)
    local handler = geterrorhandler and geterrorhandler() or print
    local n, args = select("#", ...), { ... }
    return xpcall(function() return f(unpackArgs(args, 1, n)) end, handler)
end

---------------------------------------------------------------------------------------------------
-- Events: every module registers through ns.On; one frame dispatches them. An event the client doesn't know is
-- skipped (registering an unknown event is an error on some clients).
---------------------------------------------------------------------------------------------------
local handlers = {}
local dispatcher = CreateFrame("Frame")
dispatcher:SetScript("OnEvent", function(_, event, ...)
    for _, fn in ipairs(handlers[event] or {}) do
        ns.SafeCall(fn, event, ...)
    end
end)

function ns.On(event, fn)
    if not handlers[event] then
        if not pcall(dispatcher.RegisterEvent, dispatcher, event) then return false end
        handlers[event] = {}
    end
    table.insert(handlers[event], fn)
    return true
end

-- Calls fn once, `delay` seconds after the last of a burst of calls with the same id.
local pending = {}
function ns.Debounce(id, delay, fn)
    if pending[id] then return end
    pending[id] = true
    C_Timer.After(delay, function()
        pending[id] = nil
        ns.SafeCall(fn)
    end)
end

---------------------------------------------------------------------------------------------------
-- Tables and time
---------------------------------------------------------------------------------------------------
function ns.Copy(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for k, v in pairs(value) do copy[k] = ns.Copy(v) end
    return copy
end

function ns.Now()
    return time()
end

-- The local calendar day of a time, as "2026-11-18" (sorts as text).
function ns.DayKey(t)
    return date("%Y-%m-%d", t or ns.Now())
end

---------------------------------------------------------------------------------------------------
-- Formatting
---------------------------------------------------------------------------------------------------
local GOLD, SILVER, COPPER = "|cffffd100", "|cffc7c7cf", "|cffeda55f"

-- 1234567 -> "123g 45s 67c" with the coins' colors. `short` leaves the copper out when there is gold, and the
-- silver too past 1000 gold. Thousands of gold get separators.
function ns.FormatMoney(copper, short)
    copper = ns.Num(copper)
    if not copper then return "-" end
    local negative = copper < 0
    copper = math.abs(math.floor(copper))
    local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
    local parts = {}
    if g > 0 then
        local text = tostring(g):reverse():gsub("(%d%d%d)", "%1."):reverse():gsub("^%.", "")
        parts[#parts + 1] = GOLD .. text .. "|rg"
    end
    if s > 0 and not (short and g >= 1000) then parts[#parts + 1] = SILVER .. s .. "|rs" end
    if c > 0 and not (short and g > 0) then parts[#parts + 1] = COPPER .. c .. "|rc" end
    if #parts == 0 then parts[1] = COPPER .. "0|rc" end
    return (negative and "-" or "") .. table.concat(parts, " ")
end

-- Seconds -> "3d 4h", "4h 12m", "12m", "<1m".
function ns.FormatDuration(seconds)
    seconds = ns.Num(seconds)
    if not seconds then return "-" end
    if seconds < 60 then return "<1m" end
    local d = math.floor(seconds / 86400)
    local h = math.floor(seconds / 3600) % 24
    local m = math.floor(seconds / 60) % 60
    if d > 0 then return h > 0 and ("%dd %dh"):format(d, h) or ("%dd"):format(d) end
    if h > 0 then return m > 0 and ("%dh %dm"):format(h, m) or ("%dh"):format(h) end
    return ("%dm"):format(m)
end

-- A time in the past -> "3d 4h ago" (or "now").
function ns.FormatAgo(t)
    if not t then return "-" end
    local elapsed = ns.Now() - t
    if elapsed < 60 then return ns.L["now"] end
    return ns.L["%s ago"]:format(ns.FormatDuration(elapsed))
end

-- A long played time -> "12d 3h".
function ns.FormatPlayed(seconds)
    seconds = ns.Num(seconds)
    if not seconds then return "-" end
    return ns.FormatDuration(seconds)
end

local FALLBACK_COLOR = { r = 0.8, g = 0.8, b = 0.8 }
function ns.ClassColor(class)
    local colors = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS) or {}
    local c = colors[class or ""] or FALLBACK_COLOR
    return c.r, c.g, c.b, ("ff%02x%02x%02x"):format(math.floor(c.r * 255), math.floor(c.g * 255), math.floor(c.b * 255))
end

function ns.ColorName(record)
    if not record then return "?" end
    local _, _, _, hex = ns.ClassColor(record.class)
    return "|c" .. hex .. (record.name or "?") .. "|r"
end

-- "Fewer than / more than" colors for percentages: red (0) -> yellow -> green (1).
function ns.Gradient(fraction)
    fraction = math.max(0, math.min(1, fraction or 0))
    if fraction < 0.5 then return 1, fraction * 2, 0.1 end
    return 2 - fraction * 2, 1, 0.1
end

function ns.Hex(r, g, b)
    return ("|cff%02x%02x%02x"):format(math.floor(r * 255), math.floor(g * 255), math.floor(b * 255))
end
