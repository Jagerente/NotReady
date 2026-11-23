local _, ns = ...

local Actions = ns.Actions
local GetTime = GetTime

local Press = { lastCast = 0 }
ns.Press = Press

local PLAYER = "player"
local ERROR_WINDOW = 0.4

local shownByNumbers = {}
local slot
local pressedAt = 0
local pressPending = false
local errorPending

local function MarkShownByNumbers(...)
    for i = 1, select("#", ...) do
        local message = select(i, ...)
        if message then shownByNumbers[message] = true end
    end
end

MarkShownByNumbers(
    SPELL_FAILED_NOT_READY, SPELL_FAILED_ITEM_NOT_READY, SPELL_FAILED_SPELL_IN_PROGRESS,
    ERR_ABILITY_COOLDOWN, ERR_ITEM_COOLDOWN, ERR_SPELL_COOLDOWN,
    ERR_OUT_OF_MANA, ERR_OUT_OF_RAGE, ERR_OUT_OF_ENERGY, ERR_OUT_OF_FOCUS
)

local function JudgePress()
    pressPending = false
    if Press.lastCast >= pressedAt or Actions.IsQueued(slot) then
        ns.Fire("ACTION_ACCEPTED", slot)
    else
        ns.Fire("ACTION_REFUSED", slot)
    end
end

local function ReportError()
    local message = errorPending
    errorPending = nil
    if slot and GetTime() - pressedAt <= ERROR_WINDOW then
        ns.Fire("ACTION_BLOCKED", slot, message)
    end
end

local settle = CreateFrame("Frame")
settle:Hide()
settle:SetScript("OnUpdate", function(self)
    self:Hide()
    if pressPending then JudgePress() end
    if errorPending then ReportError() end
end)

hooksecurefunc("UseAction", function(action)
    if GetCursorInfo() then return end
    slot, pressedAt, pressPending = action, GetTime(), true
    settle:Show()
end)

ns.RegisterUnitEvent("UNIT_SPELLCAST_SENT", PLAYER, function()
    Press.lastCast = GetTime()
end)

ns.RegisterEvent("UI_ERROR_MESSAGE", function(_, message)
    if ns.IsSecret(message) or shownByNumbers[message] then return end
    errorPending = message
    settle:Show()
end)
