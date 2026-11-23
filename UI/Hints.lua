local _, ns = ...

local UI = ns.UI
local L = ns.L
local C = UI.COLORS
local W = ns.Widgets
local Actions = ns.Actions
local Press = ns.Press
local Placement = ns.Placement
local GetTime = GetTime

local CHIP_HEIGHT, CHIP_GAP, MAX_CHIPS = Placement.CHIP_HEIGHT, Placement.CHIP_GAP, Placement.MAX_CHIPS
local TICK = 0.1
local LINGER = 2
local WATCH = 15
local READY_TIME = 0.7
local GCD_WINDOW = 1.9

local FADE_IN, FADE_OUT = 0.2, 0.32
local RISE, DRIFT = 5, 4
local GLIDE_TIME, RESIZE_TIME, TINT_TIME = 0.2, 0.18, 0.2
local NUDGE_SCALE, NUDGE_TIME = 1.14, 0.18
local BLOOM_SCALE, BLOOM_TIME, BLOOM_ALPHA = 1.5, 0.5, 0.7

local BADGE_SIZE, BADGE_INSET, ICON_SIZE = 26, 2, 20
local TEXT_GAP, END_PAD, MAX_LABEL = 7, 12, 230
local TEXT_LEFT = BADGE_INSET + BADGE_SIZE + TEXT_GAP
local LABEL_SIZE = 14
local SCRIM_FEATHER, SCRIM_SLICE = 14, 29
local ICON_CROP = 0.1
local ICON_TINT = 0.92

local MEDIA = "Interface\\AddOns\\" .. ns.ADDON .. "\\Media\\"
local SCRIM_TEXTURE, RING_TEXTURE = MEDIA .. "Scrim", MEDIA .. "Ring"
local SOFT_TEXT = { 0.925, 0.910, 0.878, 1 }
local UNIT_TEXT = { 0.745, 0.725, 0.690, 1 }
local RING_TRACK = { 1, 1, 1, 0.16 }
local RING_SWEEP = { 0.925, 0.910, 0.878, 0.95 }
local RING_READY = { C.good[1], C.good[2], C.good[3], 0.95 }
local RING_POWER_ALPHA = 0.8

local TIME_SAMPLE = "59s"
local BOTH_GAP = "   "
local MISSING_SIGN = "−"
local SAMPLE_TIME = "6s"
local SAMPLE_MISSING = "12"
local SAMPLE_POWER, SAMPLE_COST = "RAGE", 30
local SAMPLE_ELAPSED, SAMPLE_TOTAL = 225, 600
local SAMPLE_ICONS = {
    "Interface\\Icons\\Ability_Warrior_SavageBlow",
    "Interface\\Icons\\Ability_Rogue_Ambush",
    "Interface\\Icons\\Ability_Warrior_Charge",
}

local chips = {}
local active = {}
local state = {}
local scratchColor = {}
local previewing = false
local optionsOpen, moving = false, false
local sinceTick = 0
local root = Placement.root
local ruler = UI.BoldText(root, LABEL_SIZE)
ruler:Hide()
local ticker = CreateFrame("Frame")
ticker:Hide()

local function ColorCode(color)
    return string.format("|cff%02x%02x%02x", color[1] * 255, color[2] * 255, color[3] * 255)
end

local UNIT_CODE = ColorCode(UNIT_TEXT)

local function CreateNudge(badge)
    local group = badge:CreateAnimationGroup()
    local scale = group:CreateAnimation("Scale")
    scale:SetScaleFrom(NUDGE_SCALE, NUDGE_SCALE)
    scale:SetScaleTo(1, 1)
    scale:SetDuration(NUDGE_TIME)
    scale:SetSmoothing("OUT")
    return group
end

local function CreateBloom(badge)
    local bloom = badge:CreateTexture(nil, "OVERLAY")
    bloom:SetTexture(RING_TEXTURE)
    bloom:SetAllPoints()
    bloom:SetVertexColor(C.good[1], C.good[2], C.good[3])
    bloom:SetAlpha(0)
    local group = bloom:CreateAnimationGroup()
    local scale = group:CreateAnimation("Scale")
    scale:SetScaleFrom(1, 1)
    scale:SetScaleTo(BLOOM_SCALE, BLOOM_SCALE)
    scale:SetDuration(BLOOM_TIME)
    scale:SetSmoothing("OUT")
    local fade = group:CreateAnimation("Alpha")
    fade:SetFromAlpha(BLOOM_ALPHA)
    fade:SetToAlpha(0)
    fade:SetDuration(BLOOM_TIME)
    fade:SetSmoothing("OUT")
    return group
end

local function CreateRing(badge)
    local ring = CreateFrame("Cooldown", nil, badge, "CooldownFrameTemplate")
    ring:SetAllPoints()
    ring:SetSwipeTexture(RING_TEXTURE)
    ring:SetSwipeColor(unpack(RING_SWEEP))
    ring:SetDrawEdge(false)
    ring:SetDrawBling(false)
    ring:SetHideCountdownNumbers(true)
    ring:SetReverse(true)
    return ring
end

local function CreateScrim(content)
    local scrim = content:CreateTexture(nil, "BACKGROUND")
    scrim:SetTexture(SCRIM_TEXTURE)
    scrim:SetTextureSliceMargins(SCRIM_SLICE, 0, SCRIM_SLICE, 0)
    scrim:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
    scrim:SetPoint("TOPLEFT", -SCRIM_FEATHER, SCRIM_FEATHER)
    scrim:SetPoint("BOTTOMRIGHT", SCRIM_FEATHER, -SCRIM_FEATHER)
end

local function CreateBadge(chip)
    local badge = CreateFrame("Frame", nil, chip.content)
    badge:SetSize(BADGE_SIZE, BADGE_SIZE)
    badge:SetPoint("LEFT", BADGE_INSET, 0)

    local track = badge:CreateTexture(nil, "BORDER")
    track:SetTexture(RING_TEXTURE)
    track:SetAllPoints()
    track:SetVertexColor(unpack(RING_TRACK))
    chip.tint = { track = track, from = RING_TRACK, to = RING_TRACK, current = { unpack(RING_TRACK) } }

    local icon = W.Circle(badge, "ARTWORK")
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:SetPoint("CENTER")
    icon:SetVertexColor(ICON_TINT, ICON_TINT, ICON_TINT)
    chip.icon = icon

    chip.ring = CreateRing(badge)
    chip.nudge = CreateNudge(badge)
    chip.bloom = CreateBloom(badge)
    return badge
end

local function CreateChip(index)
    local chip = CreateFrame("Frame", ns.ADDON .. "Hint" .. index, root)
    chip:SetSize(TEXT_LEFT + END_PAD, CHIP_HEIGHT)
    chip:Hide()
    chip.y, chip.rise = 0, 0
    chip.glide = { chip = chip }
    chip.sizing = { chip = chip }

    local content = CreateFrame("Frame", nil, chip)
    content:SetAllPoints()
    chip.content = content
    CreateScrim(content)
    local badge = CreateBadge(chip)

    local label = UI.BoldText(content, LABEL_SIZE, SOFT_TEXT)
    label:SetPoint("LEFT", badge, "RIGHT", TEXT_GAP, 0)
    label:SetWidth(MAX_LABEL)
    label:SetJustifyH("LEFT")
    chip.label = label
    return chip
end

for index = 1, MAX_CHIPS do
    chips[index] = CreateChip(index)
end

local function SyncRoot()
    for index = 1, MAX_CHIPS do
        if chips[index]:IsShown() then
            root:Show()
            return
        end
    end
    root:Hide()
end

local function ApplyPoint(chip)
    chip:ClearAllPoints()
    if Placement.growsUp then
        chip:SetPoint("BOTTOM", root, "BOTTOM", 0, chip.y + chip.rise)
    else
        chip:SetPoint("TOPLEFT", root, "TOPLEFT", 0, chip.rise - chip.y)
    end
end

local function ApplyGlide(glide, value)
    glide.chip.y = value
    ApplyPoint(glide.chip)
end

local function ApplyWidth(sizing, value)
    sizing.chip:SetWidth(value)
end

local function ApplyFade(chip, value)
    chip:SetAlpha(value)
    chip.rise = chip.visible and (value - 1) * RISE or (1 - value) * DRIFT
    ApplyPoint(chip)
end

local function ApplyTint(tint, value)
    UI.LerpColor(tint.from, tint.to, value, scratchColor)
    for i = 1, 4 do tint.current[i] = scratchColor[i] end
    tint.track:SetVertexColor(unpack(tint.current))
end

local function SetRingColor(chip, color)
    local tint = chip.tint
    if tint.to == color then return end
    tint.from = { unpack(tint.current) }
    tint.to = color
    if chip:IsShown() then
        tint.tweenValue = 0
        UI.Tween(tint, 1, TINT_TIME, ApplyTint)
    else
        UI.SnapTween(tint, 1, ApplyTint)
    end
end

local function IsCertain(chip)
    return chip.message ~= nil or chip.readyUntil ~= nil or chip.realCooldown == true or chip.lacked == true
end

local function MoveChip(chip, position)
    local y = position * (CHIP_HEIGHT + CHIP_GAP)
    if chip.placed then
        UI.Tween(chip.glide, y, GLIDE_TIME, ApplyGlide)
    else
        chip.placed = true
        UI.SnapTween(chip.glide, y, ApplyGlide)
    end
end

local function Layout()
    local position = 0
    for pass = 1, 2 do
        for i = 1, #active do
            local chip = active[i]
            if chip.visible and IsCertain(chip) == (pass == 1) then
                MoveChip(chip, position)
                position = position + 1
            end
        end
    end
end

local function FinishFade(chip)
    if not chip.visible then
        chip:Hide()
        chip.placed = false
        chip.rise = 0
    end
    SyncRoot()
end

local function Reveal(chip)
    if chip.visible then return end
    chip.visible = true
    if not chip:IsShown() then
        chip.tweenValue = 0
        chip.rise = -RISE
        chip:SetAlpha(0)
        chip:Show()
    end
    root:Show()
    Layout()
    UI.Tween(chip, 1, FADE_IN, ApplyFade)
end

local function Conceal(chip)
    if not chip.visible then return end
    chip.visible = false
    Layout()
    UI.Tween(chip, 0, FADE_OUT, ApplyFade, FinishFade)
end

local function StartRing(chip, duration)
    if chip.ringRunning or not duration then return end
    chip.ringRunning = true
    chip.ring:SetCooldownFromDurationObject(duration)
end

local function StopRing(chip)
    if not chip.ringRunning then return end
    chip.ringRunning = false
    chip.ring:Clear()
end

local function Release(chip)
    for i = #active, 1, -1 do
        if active[i] == chip then
            table.remove(active, i)
            break
        end
    end
    chip.slot = nil
    StopRing(chip)
    Conceal(chip)
    if #active == 0 then ticker:Hide() end
end

local function OldestChip()
    local oldest = active[1]
    for i = 2, #active do
        if active[i].pressedAt < oldest.pressedAt then oldest = active[i] end
    end
    return oldest
end

local function FreeChip()
    for index = 1, MAX_CHIPS do
        if not chips[index].slot then return chips[index] end
    end
    local oldest = OldestChip()
    Release(oldest)
    return oldest
end

local function FindChip(slot)
    for i = 1, #active do
        if active[i].slot == slot then return active[i] end
    end
end

local function SetIcon(chip, texture)
    chip.icon:SetTexture(texture)
    chip.icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
end

local function SetPower(chip, token, amount)
    local color = token and UI.POWER_COLORS[token] or SOFT_TEXT
    local name = token and (L["POWER_" .. token] or _G[token]) or ""
    local digits = string.rep("0", #tostring(math.floor(amount or 0)))
    chip.missingFormat = ColorCode(color) .. MISSING_SIGN .. "%s|r " .. UNIT_CODE .. name .. "|r"
    chip.bothFormat = "%s" .. BOTH_GAP .. chip.missingFormat
    chip.missingSample = MISSING_SIGN .. digits .. " " .. name
    chip.bothSample = TIME_SAMPLE .. BOTH_GAP .. chip.missingSample
    chip.powerRing = { color[1], color[2], color[3], RING_POWER_ALPHA }
end

local function OpenChip(slot)
    local chip = FreeChip()
    chip.slot = slot
    chip.message, chip.readyUntil = nil, nil
    chip.realCooldown, chip.lacked = false, false
    SetIcon(chip, C_ActionBar.GetActionTexture(slot))
    local powerType, amount, token = Actions.Cost(slot)
    chip.powerType, chip.powerAmount = powerType, amount
    SetPower(chip, token, amount)
    table.insert(active, 1, chip)
    return chip
end

local function TextWidth(text)
    ruler:SetText(text)
    return math.ceil(ruler:GetStringWidth())
end

local function FitChip(chip, sample)
    if chip.fitted == sample then return end
    chip.fitted = sample
    local width = TEXT_LEFT + math.min(TextWidth(sample), MAX_LABEL) + END_PAD
    if chip:IsShown() then
        UI.Tween(chip.sizing, width, RESIZE_TIME, ApplyWidth)
    else
        UI.SnapTween(chip.sizing, width, ApplyWidth)
    end
end

local function PaintTime(chip, text, alpha)
    chip.label:SetTextColor(unpack(SOFT_TEXT))
    chip.label:SetText(text)
    SetRingColor(chip, RING_TRACK)
    FitChip(chip, TIME_SAMPLE)
    chip.content:SetAlpha(alpha)
end

local function PaintNote(chip, text)
    chip.label:SetTextColor(unpack(SOFT_TEXT))
    chip.label:SetText(text)
    SetRingColor(chip, RING_TRACK)
    FitChip(chip, text)
    chip.content:SetAlpha(1)
end

local function PaintMissing(chip, known, missing)
    if not known then
        PaintNote(chip, L.NOT_ENOUGH)
        return
    end
    chip.label:SetTextColor(unpack(SOFT_TEXT))
    chip.label:SetFormattedText(chip.missingFormat, missing)
    SetRingColor(chip, chip.powerRing)
    FitChip(chip, chip.missingSample)
    chip.content:SetAlpha(1)
end

local function PaintBoth(chip, text, known, missing)
    if not known then
        PaintTime(chip, text, 1)
        return
    end
    chip.label:SetTextColor(unpack(SOFT_TEXT))
    chip.label:SetFormattedText(chip.bothFormat, text, missing)
    SetRingColor(chip, RING_TRACK)
    FitChip(chip, chip.bothSample)
    chip.content:SetAlpha(1)
end

local function PaintReady(chip)
    StopRing(chip)
    chip.label:SetTextColor(unpack(C.good))
    chip.label:SetText(L.READY)
    SetRingColor(chip, RING_READY)
    FitChip(chip, L.READY)
    chip.content:SetAlpha(1)
end

local function MissingOf(chip)
    if not chip.powerType then return false end
    return Actions.MissingPower(chip.powerType, chip.powerAmount)
end

local function PaintWaiting(chip)
    local hasTime, text, alpha, duration = false, nil, nil, nil
    if state.onCooldown then hasTime, text, alpha, duration = Actions.Cooldown(chip.slot) end
    local showTime = hasTime and (chip.realCooldown or not state.lacking)
    if showTime then
        StartRing(chip, duration)
    else
        StopRing(chip)
    end
    if showTime and state.lacking then
        PaintBoth(chip, text, MissingOf(chip))
    elseif showTime then
        PaintTime(chip, text, chip.realCooldown and 1 or alpha)
    else
        PaintMissing(chip, MissingOf(chip))
    end
end

local function NoteCertainty(chip, now)
    local before = IsCertain(chip)
    if state.lacking then chip.lacked = true end
    if state.onCooldown and now - Press.lastCast >= GCD_WINDOW then chip.realCooldown = true end
    if IsCertain(chip) ~= before then Layout() end
end

local function FinishWaiting(chip, now, age)
    if state.usable and ns.db.showReady and age <= WATCH and (chip.realCooldown or chip.lacked) then
        chip.readyUntil = now + READY_TIME
        PaintReady(chip)
        Reveal(chip)
        Layout()
        chip.bloom:Restart()
    else
        Release(chip)
    end
end

local function UpdateChip(chip, now)
    local age = now - chip.pressedAt
    if chip.readyUntil then
        if now >= chip.readyUntil then Release(chip) end
        return
    end
    if chip.message then
        if age > LINGER then Release(chip) end
        return
    end
    Actions.Read(chip.slot, state)
    NoteCertainty(chip, now)
    if not state.onCooldown and not state.lacking then
        FinishWaiting(chip, now, age)
    elseif age > WATCH then
        Release(chip)
    elseif age <= LINGER then
        PaintWaiting(chip)
        Reveal(chip)
    else
        Conceal(chip)
    end
end

ticker:SetScript("OnUpdate", function(_, elapsed)
    sinceTick = sinceTick + elapsed
    if sinceTick < TICK then return end
    sinceTick = 0
    Placement.Refresh()
    local now = GetTime()
    for i = #active, 1, -1 do
        UpdateChip(active[i], now)
    end
end)

local function OnRefused(slot)
    if previewing then return end
    Actions.Read(slot, state)
    if not state.onCooldown and not state.lacking then return end
    local chip = FindChip(slot)
    if chip then
        if chip.visible then chip.nudge:Restart() end
    else
        chip = OpenChip(slot)
    end
    chip.message, chip.readyUntil = nil, nil
    chip.pressedAt = GetTime()
    Placement.Refresh()
    UpdateChip(chip, chip.pressedAt)
    ticker:Show()
end

local function OnBlocked(slot, message)
    if previewing or not ns.db.showOther then return end
    Actions.Read(slot, state)
    local now = GetTime()
    if state.lacking or (state.onCooldown and now - Press.lastCast >= GCD_WINDOW) then return end
    local chip = FindChip(slot) or OpenChip(slot)
    chip.message = (message:gsub("%.$", ""))
    chip.readyUntil = nil
    chip.pressedAt = now
    StopRing(chip)
    PaintNote(chip, chip.message)
    Placement.Refresh()
    Reveal(chip)
    Layout()
    ticker:Show()
end

local function OnAccepted(slot)
    if previewing then return end
    local chip = FindChip(slot)
    if chip then Release(chip) end
end

local function ClearChips()
    for i = #active, 1, -1 do
        Release(active[i])
    end
end

local function AddSample(index)
    local chip = chips[index]
    chip.slot = index
    chip.message, chip.readyUntil = L.SAMPLE_REASON, nil
    chip.pressedAt = 0
    SetIcon(chip, SAMPLE_ICONS[index])
    active[#active + 1] = chip
    return chip
end

local function ShowSamples()
    ClearChips()
    local timed = AddSample(1)
    timed.ringRunning = true
    timed.ring:SetCooldown(GetTime() - SAMPLE_ELAPSED, SAMPLE_TOTAL)
    PaintTime(timed, SAMPLE_TIME, 1)
    local power = AddSample(2)
    SetPower(power, SAMPLE_POWER, SAMPLE_COST)
    PaintMissing(power, true, SAMPLE_MISSING)
    if ns.db.showOther then PaintNote(AddSample(3), L.SAMPLE_REASON) end
    for i = 1, #active do
        Reveal(active[i])
    end
    Layout()
end

local function SyncPreview()
    local shown = optionsOpen or moving
    if shown == previewing then return end
    previewing = shown
    if shown then
        ShowSamples()
    else
        ClearChips()
    end
end

ns.Listen("ACTION_REFUSED", OnRefused)
ns.Listen("ACTION_BLOCKED", OnBlocked)
ns.Listen("ACTION_ACCEPTED", OnAccepted)
ns.Listen("PLACEMENT_CHANGED", Layout)
ns.Listen("OPTIONS_SHOWN", function(open)
    optionsOpen = open
    SyncPreview()
end)
ns.Listen("MOVE_MODE", function(active)
    moving = active
    SyncPreview()
end)
ns.Listen("LOCALE_CHANGED", function()
    if previewing then ShowSamples() end
end)
ns.Listen("SETTING_CHANGED", function(key)
    if previewing and (key == "showOther" or key == nil) then ShowSamples() end
end)
