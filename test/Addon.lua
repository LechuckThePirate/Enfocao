-- Loading the addon in tests, as the game does: the files in TOC order with (name, ns). The store (BakalaoStudios
-- DataStore, an optional dependency) is loaded first only when asked: LoadAddon({ store = true }) loads it from the
-- folder beside this repo (../BakalaoStudios_DataStore, checked out there by CI too). StartAddon(ns, db, storeDB)
-- simulates entering the game.
local STORE_DIR = "../BakalaoStudios_DataStore/"

local function tocFiles(dir, toc)
    local files = {}
    for line in io.lines(dir .. toc) do
        line = line:gsub("\r", ""):gsub("%s+$", "")
        if line ~= "" and not line:match("^##") and line:match("%.lua$") then
            files[#files + 1] = dir .. (line:gsub("\\", "/"))
        end
    end
    return files
end

function TocFiles()
    return tocFiles("", "Enfocao.toc")
end

function LoadAddon(opts)
    opts = opts or {}
    _G.BakalaoDataStore = nil
    local store
    if opts.store then
        store = {}
        for _, f in ipairs(tocFiles(STORE_DIR, "BakalaoStudios_DataStore.toc")) do
            assert(loadfile(f))("BakalaoStudios_DataStore", store)
        end
    end
    local ns = {}
    for _, f in ipairs(TocFiles()) do
        assert(loadfile(f))("Enfocao", ns)
    end
    ns.store = store
    return ns
end

-- Every frame that registered the event and has an OnEvent receives it (as if the game fired it).
function FireEvent(event, ...)
    for _, f in ipairs(WowMock.frames) do
        local handler = f._scripts.OnEvent
        if handler and f._events and f._events[event] then handler(f, event, ...) end
    end
end

function StartAddon(ns, db, storeDB)
    EnfocaoDB = db
    if ns.store then
        BakalaoDataStoreDB = storeDB or {}
        FireEvent("ADDON_LOADED", "BakalaoStudios_DataStore")
    end
    FireEvent("ADDON_LOADED", "Enfocao")
    FireEvent("PLAYER_ENTERING_WORLD")
    return ns
end
