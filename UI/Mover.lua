local _, ns = ...

local UI = ns.UI
local C = UI.COLORS
local T = UI.TEXT
local W = ns.Widgets
local Placement = ns.Placement

local Mover = {}
ns.Mover = Mover

local BAR_HEIGHT, BAR_TOP, BAR_PAD, BAR_GAP = 44, 120, 14, 8
local ZONE_PAD, ZONE_SLICE, ZONE_LEVEL = 10, 12, 20
local ZONE_ALPHA, ZONE_HOVER_ALPHA, ZONE_HOVER_TIME = 0.65, 1, 0.14
local SNAP_DISTANCE = 12
local GUIDE_WIDTH = 1
local GUIDE_COLOR = { C.accent[1], C.accent[2], C.accent[3], 0.7 }
local ZONE_TEXTURE = "Interface\\AddOns\\" .. ns.ADDON .. "\\Media\\Zone"

local bar, zone, guide
local savedX, savedY
local keep = false

local function UpdateGuide()
    local x = Placement.CenterOffset()
    guide:SetShown(math.abs(x) <= SNAP_DISTANCE)
end

local function StartDrag()
    zone:SetScript("OnUpdate", UpdateGuide)
    Placement.root:StartMoving()
end

local function StopDrag()
    local root = Placement.root
    zone:SetScript("OnUpdate", nil)
    guide:Hide()
    root:StopMovingOrSizing()
    root:SetUserPlaced(false)
    local x, y = Placement.CenterOffset()
    if math.abs(x) <= SNAP_DISTANCE then x = 0 end
    Placement.SetSpot(math.floor(x + 0.5), math.floor(y + 0.5))
end

local function CreateZone()
    local root = Placement.root
    zone = CreateFrame("Frame", nil, root)
    zone:SetSize(Placement.ANCHOR_WIDTH + ZONE_PAD * 2, Placement.STACK_HEIGHT + ZONE_PAD * 2)
    zone:SetPoint("BOTTOM", root, "BOTTOM", 0, -ZONE_PAD)
    zone:SetFrameLevel(root:GetFrameLevel() + ZONE_LEVEL)
    zone:EnableMouse(true)
    zone:Hide()

    local art = zone:CreateTexture(nil, "BACKGROUND")
    art:SetTexture(ZONE_TEXTURE)
    art:SetTextureSliceMargins(ZONE_SLICE, ZONE_SLICE, ZONE_SLICE, ZONE_SLICE)
    art:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
    art:SetAllPoints()
    art:SetVertexColor(C.accent[1], C.accent[2], C.accent[3])
    art:SetAlpha(ZONE_ALPHA)

    local hover = { tweenValue = ZONE_ALPHA }
    local function ApplyHover(_, value) art:SetAlpha(value) end
    zone:SetScript("OnEnter", function() UI.Tween(hover, ZONE_HOVER_ALPHA, ZONE_HOVER_TIME, ApplyHover) end)
    zone:SetScript("OnLeave", function() UI.Tween(hover, ZONE_ALPHA, ZONE_HOVER_TIME, ApplyHover) end)
    W.DragHandle(zone, StartDrag, StopDrag)
end

local function CreateGuide()
    guide = CreateFrame("Frame", nil, UIParent)
    guide:SetFrameStrata("DIALOG")
    guide:SetWidth(GUIDE_WIDTH)
    guide:SetPoint("TOP", UIParent, "TOP")
    guide:SetPoint("BOTTOM", UIParent, "BOTTOM")
    guide:Hide()
    UI.Fill(guide, GUIDE_COLOR)
end

local function Finish()
    zone:Hide()
    guide:Hide()
    if not keep then Placement.SetSpot(savedX, savedY) end
    C_Timer.After(0, function()
        ns.Options.Open()
        ns.Fire("MOVE_MODE", false)
    end)
end

local function CreateBar()
    bar = CreateFrame("Frame", ns.ADDON .. "MoveBar", UIParent)
    bar:SetHeight(BAR_HEIGHT)
    bar:SetPoint("TOP", UIParent, "TOP", 0, -BAR_TOP)
    bar:SetFrameStrata("FULLSCREEN_DIALOG")
    bar:EnableMouse(true)
    bar:Hide()
    UI.Fill(bar, C.window)

    local text = UI.Text(bar, T.body, C.text)
    text:SetPoint("LEFT", BAR_PAD, 0)
    W.Bind(text, "MOVE_HINT")
    local done = W.Button(bar, "MOVE_DONE", function()
        keep = true
        bar:Hide()
    end, "primary")
    done:SetPoint("RIGHT", -BAR_PAD, 0)
    local cancel = W.Button(bar, "MOVE_CANCEL", function() bar:Hide() end)
    cancel:SetPoint("RIGHT", done, "LEFT", -BAR_GAP, 0)

    local function Fit()
        bar:SetWidth(math.ceil(text:GetStringWidth()) + done:GetWidth() + cancel:GetWidth() + BAR_GAP + BAR_PAD * 3)
    end
    Fit()
    W.AfterLocale(Fit)
    bar:SetScript("OnHide", Finish)
    tinsert(UISpecialFrames, bar:GetName())
end

function Mover.Start()
    if not bar then
        CreateZone()
        CreateGuide()
        CreateBar()
    end
    if bar:IsShown() then return end
    savedX, savedY = ns.db.spot.x, ns.db.spot.y
    keep = false
    ns.Fire("MOVE_MODE", true)
    ns.Options.Close()
    zone:Show()
    bar:Show()
end
