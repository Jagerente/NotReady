local _, ns = ...

local Actions = {}
ns.Actions = Actions

local Plain = ns.Plain
local IsSecret = ns.IsSecret
local UnitPowerMax = UnitPowerMax
local UnitPowerPercent = UnitPowerPercent

local PLAYER = "player"
local GCD_LIMIT = 1.65
local CEILING_NUDGE = 0.999
local DECIMALS_BELOW = 3
local MINUTES_FROM, HOURS_FROM = 61, 3601

local missingCurves = {}

local function CreateRealCooldownCurve()
    local curve = C_CurveUtil.CreateCurve()
    curve:SetType(Enum.LuaCurveType.Step)
    curve:AddPoint(0, 0)
    curve:AddPoint(GCD_LIMIT, 1)
    return curve
end

local function CreateTimeFormatter()
    local bands = C_CurveUtil.CreateCurve()
    bands:SetType(Enum.LuaCurveType.Step)
    bands:AddPoint(0, Enum.SecondsFormatterInterval.Seconds)
    bands:AddPoint(MINUTES_FROM, Enum.SecondsFormatterInterval.Minutes)
    bands:AddPoint(HOURS_FROM, Enum.SecondsFormatterInterval.Hours)
    local formatter = C_StringUtil.CreateSecondsFormatter()
    formatter:SetDefaultAbbreviation(Enum.SecondsFormatterAbbreviation.OneLetter)
    formatter:SetMinInterval(Enum.SecondsFormatterInterval.Seconds)
    formatter:SetMaxIntervalCurve(bands)
    formatter:SetDesiredUnitCount(1)
    formatter:SetMillisecondsThreshold(DECIMALS_BELOW)
    formatter:SetRounding(Enum.SecondsFormatterRounding.RoundUp)
    formatter:SetStripIntervalWhitespace(Enum.SecondsFormatterIntervalWhitespace.Strip)
    return formatter
end

local realCooldownCurve = CreateRealCooldownCurve()
local timeFormatter = CreateTimeFormatter()

function Actions.Read(slot, state)
    local cooldown = C_ActionBar.GetActionCooldown(slot)
    local usable, lacking = C_ActionBar.IsUsableAction(slot)
    state.onCooldown = cooldown ~= nil and cooldown.isActive == true
    state.usable = Plain(usable) == true
    state.lacking = Plain(lacking) == true
end

function Actions.IsQueued(slot)
    return Plain(C_ActionBar.IsCurrentAction(slot)) == true
end

function Actions.Cooldown(slot)
    local duration = C_ActionBar.GetActionCooldownDuration(slot)
    if not duration then return false end
    return true, duration:FormatRemainingDuration(timeFormatter), duration:EvaluateTotalDuration(realCooldownCurve), duration
end

local function SpellOf(slot)
    local kind, id, subType = GetActionInfo(slot)
    if kind == "spell" or (kind == "macro" and subType == "spell") then return Plain(id) end
    return Plain(C_ActionBar.GetSpell(slot))
end

function Actions.Cost(slot)
    local spellID = SpellOf(slot)
    local costs = spellID and spellID ~= 0 and C_Spell.GetSpellPowerCost(spellID)
    if not costs then return nil end
    for i = 1, #costs do
        local cost = costs[i]
        local amount = cost.minCost > 0 and cost.minCost or cost.cost
        if amount > 0 and (cost.requiredAuraID == 0 or cost.hasRequiredAura) then
            return cost.type, amount, cost.name
        end
    end
end

local function MissingCurve(amount, maximum)
    local byAmount = missingCurves[maximum]
    if not byAmount then
        byAmount = {}
        missingCurves[maximum] = byAmount
    end
    local curve = byAmount[amount]
    if curve then return curve end
    local affordableAt = math.min(amount / maximum, 1)
    curve = C_CurveUtil.CreateCurve()
    curve:SetType(Enum.LuaCurveType.Linear)
    curve:AddPoint(0, amount + CEILING_NUDGE)
    curve:AddPoint(affordableAt, amount - affordableAt * maximum + CEILING_NUDGE)
    if affordableAt < 1 then curve:AddPoint(1, CEILING_NUDGE) end
    byAmount[amount] = curve
    return curve
end

function Actions.MissingPower(powerType, amount)
    local maximum = UnitPowerMax(PLAYER, powerType)
    if IsSecret(maximum) or not maximum or maximum <= 0 then return false end
    local missing = UnitPowerPercent(PLAYER, powerType, false, MissingCurve(amount, maximum))
    return true, C_StringUtil.TruncateWhenZero(missing)
end
