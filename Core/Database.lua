local _, ns = ...

local DEFAULTS = {
    locale = "auto",
    place = "spot",
    spot = { x = 0, y = -115 },
    cursorX = 18,
    cursorY = -14,
    plateX = 0,
    plateY = 8,
    size = 135,
    showReady = true,
    showOther = true,
    minimap = { hide = false, angle = 130 },
    lastPage = "hints",
}

ns.DEFAULTS = DEFAULTS

local function ApplyDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            target[key] = ApplyDefaults(type(target[key]) == "table" and target[key] or {}, value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
    return target
end

local function DropRetired(target, defaults)
    for key in pairs(target) do
        if defaults[key] == nil then target[key] = nil end
    end
    return target
end

ns.Listen("INIT", function()
    NotReadyDB = ApplyDefaults(DropRetired(NotReadyDB or {}, DEFAULTS), DEFAULTS)
    ns.db = NotReadyDB
    ns.Fire("DB_READY")
end)

function ns.Set(key, value)
    if ns.db[key] == value then return end
    ns.db[key] = value
    ns.Fire("SETTING_CHANGED", key, value)
end

function ns.ResetSettings()
    wipe(ns.db)
    ApplyDefaults(ns.db, DEFAULTS)
    ns.Fire("SETTING_CHANGED")
end
