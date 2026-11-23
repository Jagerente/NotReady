local _, ns = ...

local IsSecret = ns.IsSecret
local GetCursorPosition = GetCursorPosition

local Placement = {
    ANCHOR_WIDTH = 180,
    CHIP_HEIGHT = 30,
    CHIP_GAP = 6,
    MAX_CHIPS = 3,
    OFFSET_KEYS = {
        cursor = { x = "cursorX", y = "cursorY" },
        nameplate = { x = "plateX", y = "plateY" },
    },
    growsUp = false,
}
Placement.STACK_HEIGHT = Placement.MAX_CHIPS * (Placement.CHIP_HEIGHT + Placement.CHIP_GAP) - Placement.CHIP_GAP
ns.Placement = Placement

local OFFSET_KEYS = Placement.OFFSET_KEYS

local TARGET = "target"
local CENTER = "CENTER"
local PERCENT = 100
local SPARE_HEIGHT = Placement.STACK_HEIGHT - Placement.CHIP_HEIGHT

local attachedPlate
local moving = false

local root = CreateFrame("Frame", ns.ADDON .. "Anchor", UIParent)
root:SetSize(Placement.ANCHOR_WIDTH, Placement.CHIP_HEIGHT)
root:SetFrameStrata("MEDIUM")
root:SetMovable(true)
root:Hide()
Placement.root = root

local function SetGrowth(growsUp)
    if Placement.growsUp == growsUp then return end
    Placement.growsUp = growsUp
    ns.Fire("PLACEMENT_CHANGED")
end

local function PrepareAnchor(clamped, growsUp)
    root:ClearAllPoints()
    root:SetClampedToScreen(clamped)
    root:SetClampRectInsets(0, 0, growsUp and SPARE_HEIGHT or 0, growsUp and 0 or -SPARE_HEIGHT)
end

local function FollowCursor()
    local x, y = GetCursorPosition()
    local effective, scale = root:GetEffectiveScale(), root:GetScale()
    root:ClearAllPoints()
    root:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT",
        x / effective + ns.db.cursorX / scale, y / effective + ns.db.cursorY / scale)
end

local function IsBehindCamera(plate)
    local token = plate.unitToken or plate.namePlateUnitToken
    local manager = C_NamePlateManager
    if not (token and manager and manager.IsNamePlateUnitBehindCamera) then return false end
    local behind = manager.IsNamePlateUnitBehindCamera(token)
    return not IsSecret(behind) and behind == true
end

local function TargetPlate()
    if not UnitExists(TARGET) then return nil end
    local plate = C_NamePlate.GetNamePlateForUnit(TARGET)
    if not plate then return nil end
    local visible = plate:IsVisible()
    if not IsSecret(visible) and not visible then return nil end
    if IsBehindCamera(plate) then return nil end
    return plate
end

local function Attach(plate)
    attachedPlate = plate
    PrepareAnchor(plate == nil, true)
    local scale = root:GetScale()
    if plate then
        root:SetPoint("BOTTOM", plate, "TOP", ns.db.plateX / scale, ns.db.plateY / scale)
    else
        root:SetPoint(CENTER, UIParent, CENTER, ns.db.spot.x / scale, ns.db.spot.y / scale)
    end
    SetGrowth(true)
end

function Placement.Refresh()
    if moving or ns.db.place ~= "nameplate" then return end
    local plate = TargetPlate()
    if plate ~= attachedPlate then Attach(plate) end
end

local function Apply()
    local place = moving and "spot" or ns.db.place
    root:ClearAllPoints()
    root:SetFrameStrata(moving and "DIALOG" or "MEDIUM")
    root:SetScale(ns.db.size / PERCENT)
    local follow = place == "cursor" and FollowCursor or nil
    root:SetScript("OnUpdate", follow)
    root:SetScript("OnShow", follow)
    if place == "cursor" then
        attachedPlate = nil
        PrepareAnchor(true, false)
        SetGrowth(false)
        FollowCursor()
    elseif place == "nameplate" then
        Attach(TargetPlate())
    else
        Attach(nil)
    end
end

function Placement.CenterOffset()
    local x, y = root:GetCenter()
    local centerX, centerY = UIParent:GetCenter()
    local ratio = root:GetEffectiveScale() / UIParent:GetEffectiveScale()
    return x * ratio - centerX, y * ratio - centerY
end

function Placement.SetSpot(x, y)
    local spot = ns.db.spot
    spot.x, spot.y = x, y
    ns.Fire("SETTING_CHANGED", "spot")
end

function Placement.ResetPosition()
    local db, defaults = ns.db, ns.DEFAULTS
    local keys = OFFSET_KEYS[db.place]
    if keys then db[keys.x], db[keys.y] = defaults[keys.x], defaults[keys.y] end
    if db.place ~= "cursor" then db.spot.x, db.spot.y = defaults.spot.x, defaults.spot.y end
    ns.Fire("SETTING_CHANGED", "spot")
end

function Placement.IsDefaultPosition()
    local db, defaults = ns.db, ns.DEFAULTS
    local keys = OFFSET_KEYS[db.place]
    if keys and (db[keys.x] ~= defaults[keys.x] or db[keys.y] ~= defaults[keys.y]) then return false end
    return db.place == "cursor" or (db.spot.x == defaults.spot.x and db.spot.y == defaults.spot.y)
end

local APPLIES = { place = true, size = true, spot = true, cursorX = true, cursorY = true, plateX = true, plateY = true }

ns.Listen("DB_READY", Apply)
ns.Listen("SETTING_CHANGED", function(key)
    if key == nil or APPLIES[key] then Apply() end
end)
ns.Listen("MOVE_MODE", function(active)
    moving = active
    Apply()
end)
ns.RegisterEvent("PLAYER_TARGET_CHANGED", Placement.Refresh)
ns.RegisterEvent("NAME_PLATE_UNIT_ADDED", Placement.Refresh)
ns.RegisterEvent("NAME_PLATE_UNIT_REMOVED", Placement.Refresh)
