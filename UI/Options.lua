local _, ns = ...

local UI = ns.UI
local L = ns.L
local C = UI.COLORS
local T = UI.TEXT
local W = ns.Widgets

local Options = {}
ns.Options = Options

local WIDTH, HEIGHT = 380, 478
local MARGIN = 14
local HEADER_HEIGHT, TABS_HEIGHT, BODY_GAP = 38, 26, 10
local HEADER_GLYPH_HEIGHT, HEADER_GLYPH_GAP = 16, 8
local SETTINGS_GLYPH_HEIGHT = 20
local TAB_PAD, MIN_TAB_PAD, TAB_GAP = 8, 4, 4
local PAGE_WIDTH = WIDTH - MARGIN * 2
local CONTENT_INSET = 8
local SECTION_GAP = 10
local ROW_GAP = 10
local TOGGLE_GAP = 6
local COLUMN_GAP = 16
local COLUMN_WIDTH = (PAGE_WIDTH - COLUMN_GAP) / 2
local WINDOW_OFFSET_X = -320
local RESET_CONFIRM_SECONDS = 3
local SIZE_MIN, SIZE_MAX = 60, 200
local OFFSET_LIMIT = 300

local window
local pages = {}
local tabButtons = {}
local tabPad = TAB_PAD
local currentPage

local function Setting(key)
    return function() return ns.db[key] end, function(value) ns.Set(key, value) end
end

local function Track(page, widget)
    page.widgets[#page.widgets + 1] = widget
    return widget
end

local function AddToggle(page, key, label, desc, gap)
    local get, set = Setting(key)
    return page.stack:Add(Track(page, W.Toggle(page.content, PAGE_WIDTH, { label = label, desc = desc, get = get, set = set })), gap)
end

local function AddSlider(page, key, label, min, max, format)
    local get, set = Setting(key)
    return page.stack:Add(Track(page, W.Slider(page.content, PAGE_WIDTH, {
        label = label, min = min, max = max, step = 1, get = get, set = set, format = format,
    })))
end

local function AddSegmented(page, key, label, items, gap)
    local get, set = Setting(key)
    return page.stack:Add(Track(page, W.Segmented(page.content, PAGE_WIDTH, {
        label = label, count = #items, get = get, set = set,
        items = function()
            local list = {}
            for i, item in ipairs(items) do
                list[i] = { value = item.value, text = L[item.key] }
            end
            return list
        end,
    })), gap)
end

local function AddHeading(page, key)
    return page.stack:Add(W.Heading(page.content, PAGE_WIDTH, key), #page.stack.frames > 0 and SECTION_GAP or 0)
end

local function NewPage(id)
    local scroll = W.Scroll(window.body)
    scroll:SetAllPoints(window.body)
    scroll:Hide()
    local page = { id = id, scroll = scroll, content = scroll.content, widgets = {} }
    page.stack = W.Stack(page.content, CONTENT_INSET)
    pages[id] = page
    return page
end

local function RefreshPage(page, animate)
    for _, widget in ipairs(page.widgets) do
        widget:Refresh(animate)
    end
    if page.OnShow then page:OnShow() end
end

local function AddConfirmButton(page, key, confirmKey, action, gap)
    local button
    local function Disarm()
        button.armed = false
        button.text:SetText(L[key])
        button:Fit()
    end
    button = W.Button(page.content, key, function(self)
        if self.armed then
            Disarm()
            action()
            return
        end
        self.armed = true
        self.text:SetText(L[confirmKey])
        self:Fit()
        C_Timer.After(RESET_CONFIRM_SECONDS, function()
            if self.armed then Disarm() end
        end)
    end, "danger", PAGE_WIDTH)
    page.stack:Add(button, gap)
    return button
end

local function FormatPercent(value)
    return string.format("%d%%", value)
end

local LANGUAGE_ITEMS = {}
for i, code in ipairs(ns.LANGUAGES) do
    LANGUAGE_ITEMS[i] = { value = code, key = "LANGUAGE_" .. code }
end

local PLACES = {
    { value = "cursor", key = "PLACE_cursor" },
    { value = "nameplate", key = "PLACE_nameplate" },
    { value = "spot", key = "PLACE_spot" },
}

local OFFSET_KEYS = ns.Placement.OFFSET_KEYS

local CHOOSE_KEYS = {
    spot = "SPOT_CHOOSE",
    nameplate = "SPOT_CHOOSE_PLATE",
}

local function ShiftLimit(axis)
    if OFFSET_KEYS[ns.db.place] then return OFFSET_LIMIT end
    local size = axis == "x" and UIParent:GetWidth() or UIParent:GetHeight()
    return math.floor(size / 2)
end

local function ReadShift(axis)
    local keys = OFFSET_KEYS[ns.db.place]
    if keys then return ns.db[keys[axis]] end
    return ns.db.spot[axis]
end

local function WriteShift(axis, value)
    local keys = OFFSET_KEYS[ns.db.place]
    if keys then
        ns.Set(keys[axis], value)
        return
    end
    local spot = ns.db.spot
    ns.Placement.SetSpot(axis == "x" and value or spot.x, axis == "y" and value or spot.y)
end

local function CreateShift(parent, axis, label)
    local opts = {
        label = label, min = -OFFSET_LIMIT, max = OFFSET_LIMIT, step = 1, origin = 0,
        get = function() return ReadShift(axis) end,
        set = function(value) WriteShift(axis, value) end,
    }
    local slider = W.Slider(parent, COLUMN_WIDTH, opts)
    local paint = slider.Refresh
    function slider:Refresh(animate)
        local limit = ShiftLimit(axis)
        opts.min, opts.max = -limit, limit
        paint(self, animate)
    end
    slider:Refresh()
    return slider
end

local function AddShifts(page)
    local row = CreateFrame("Frame", nil, page.content)
    local right = CreateShift(row, "x", "OFFSET_X")
    local up = CreateShift(row, "y", "OFFSET_Y")
    right:SetPoint("LEFT")
    up:SetPoint("RIGHT")
    row:SetSize(PAGE_WIDTH, right:GetHeight())
    function row:Refresh(animate)
        right:Refresh(animate)
        up:Refresh(animate)
    end
    page.stack:Add(Track(page, row), ROW_GAP)
end

local function AddSpotButtons(page)
    local row = CreateFrame("Frame", nil, page.content)
    local choose = W.Button(row, nil, ns.Mover.Start, "soft", COLUMN_WIDTH)
    choose:SetPoint("LEFT")
    local reset = W.Button(row, "RESET_POSITION", ns.Placement.ResetPosition)
    row:SetSize(PAGE_WIDTH, choose:GetHeight())
    function row:Refresh()
        local chooseKey = CHOOSE_KEYS[ns.db.place]
        local moved = not ns.Placement.IsDefaultPosition()
        choose:SetShown(chooseKey ~= nil)
        if chooseKey then choose.text:SetText(L[chooseKey]) end
        reset:ClearAllPoints()
        reset:SetPoint("RIGHT")
        if chooseKey then
            reset:SetPoint("LEFT", choose, "RIGHT", COLUMN_GAP, 0)
        else
            reset:SetPoint("LEFT")
        end
        reset:EnableMouse(moved)
        reset:SetStyle(moved and "default" or "idle")
    end
    row:Refresh()
    W.AfterLocale(function() row:Refresh() end)
    page.stack:Add(Track(page, row), ROW_GAP)
end

local function BuildHints()
    local page = NewPage("hints")
    AddHeading(page, "SECTION_PLACE")
    AddSegmented(page, "place", nil, PLACES)
    AddShifts(page)
    AddSpotButtons(page)

    AddHeading(page, "SECTION_LOOK")
    AddSlider(page, "size", "SIZE", SIZE_MIN, SIZE_MAX, FormatPercent)
    AddToggle(page, "showReady", "SHOW_READY", "SHOW_READY_DESC", TOGGLE_GAP)
    AddToggle(page, "showOther", "SHOW_OTHER", "SHOW_OTHER_DESC")

    AddHeading(page, "SECTION_OTHER")
    page.stack:Add(Track(page, W.Toggle(page.content, PAGE_WIDTH, {
        label = "MINIMAP_BUTTON",
        get = function() return not ns.db.minimap.hide end,
        set = ns.MinimapButton.SetShown,
    })))
    AddSegmented(page, "locale", "LANGUAGE", LANGUAGE_ITEMS, SECTION_GAP)
    AddConfirmButton(page, "RESET", "RESET_CONFIRM", ns.ResetSettings, ROW_GAP)
end

local function BuildAbout()
    ns.About.Build(NewPage("about"), PAGE_WIDTH)
end

local DEFAULT_PAGE = "hints"
local TABS = {
    { id = "hints", key = "NAV_HINTS", build = BuildHints },
    { id = "about", key = "NAV_ABOUT", build = BuildAbout },
}

local function FindTab(id)
    for _, entry in ipairs(TABS) do
        if entry.id == id then return entry end
    end
end

local underline = { x = 0, width = 0, motion = {} }

local function SetUnderline(x, width)
    underline.x, underline.width = x, width
    window.tabUnderline:SetPoint("BOTTOMLEFT", window.tabBar, "BOTTOMLEFT", x, 0)
    window.tabUnderline:SetWidth(math.max(1, width))
end

local function MoveUnderline(button, animate)
    local toX, toWidth = button.offset + tabPad, button:GetWidth() - tabPad * 2
    if not animate then
        UI.SnapTween(underline.motion, 1, function() SetUnderline(toX, toWidth) end)
        return
    end
    local fromX, fromWidth = underline.x, underline.width
    underline.motion.tweenValue = 0
    UI.Tween(underline.motion, 1, 0.2, function(_, t)
        SetUnderline(UI.Lerp(fromX, toX, t), UI.Lerp(fromWidth, toWidth, t))
    end)
end

local function ShowPage(id, animate)
    if not FindTab(id) then id = DEFAULT_PAGE end
    local page = pages[id]
    if not page then
        FindTab(id).build()
        page = pages[id]
    end
    if currentPage and currentPage ~= page then
        currentPage.scroll:Hide()
    end
    currentPage = page
    RefreshPage(page)
    page.scroll:ScrollTo(0, false)
    if animate then
        UI.FadeIn(page.scroll, 0.14)
    else
        page.scroll:Show()
        page.scroll:SetAlpha(1)
    end
    for index, entry in ipairs(TABS) do
        local button = tabButtons[index]
        local selected = entry.id == id
        button.text:SetTextColor(unpack(selected and C.text or C.muted))
        if selected then MoveUnderline(button, animate) end
    end
    ns.db.lastPage = id
end

local function FitTabPad()
    local textWidth = 0
    for _, button in ipairs(tabButtons) do textWidth = textWidth + math.ceil(button.text:GetStringWidth()) end
    local spaces = #tabButtons - 1
    local spare = WIDTH - MARGIN * 2 - textWidth - spaces * TAB_GAP
    return math.max(MIN_TAB_PAD, math.min(TAB_PAD, math.floor(spare / (spaces * 2))))
end

local function LayoutTabs()
    tabPad = FitTabPad()
    local x = -tabPad
    for _, button in ipairs(tabButtons) do
        button:SetWidth(math.ceil(button.text:GetStringWidth()) + tabPad * 2)
        button:ClearAllPoints()
        button:SetPoint("BOTTOMLEFT", x, 0)
        button.offset = x
        x = x + button:GetWidth() + TAB_GAP
    end
    if currentPage then
        for index, entry in ipairs(TABS) do
            if entry.id == currentPage.id then MoveUnderline(tabButtons[index], false) end
        end
    end
end

local function CreateTabs()
    local bar = CreateFrame("Frame", nil, window)
    bar:SetPoint("TOPLEFT", MARGIN, -HEADER_HEIGHT)
    bar:SetPoint("TOPRIGHT", -MARGIN, -HEADER_HEIGHT)
    bar:SetHeight(TABS_HEIGHT)
    window.tabBar = bar
    local baseline = bar:CreateTexture(nil, "BACKGROUND")
    baseline:SetColorTexture(1, 1, 1, 0.05)
    baseline:SetHeight(1)
    baseline:SetPoint("BOTTOMLEFT")
    baseline:SetPoint("BOTTOMRIGHT")
    local line = bar:CreateTexture(nil, "OVERLAY")
    line:SetColorTexture(unpack(C.accent))
    line:SetHeight(2)
    window.tabUnderline = line

    for index, entry in ipairs(TABS) do
        local button = CreateFrame("Button", nil, bar)
        button:SetHeight(TABS_HEIGHT)
        button.text = UI.Text(button, T.body, C.muted)
        button.text:SetPoint("CENTER", 0, 1)
        W.Bind(button.text, entry.key)
        button:SetScript("OnClick", function() ShowPage(entry.id, true) end)
        button:SetScript("OnEnter", function(self) self.text:SetTextColor(unpack(C.text)) end)
        button:SetScript("OnLeave", function(self)
            if currentPage ~= pages[entry.id] then self.text:SetTextColor(unpack(C.muted)) end
        end)
        tabButtons[index] = button
    end
    LayoutTabs()
    W.AfterLocale(LayoutTabs)
end

local function CreateHeader()
    local header = CreateFrame("Frame", nil, window)
    header:SetPoint("TOPLEFT")
    header:SetPoint("TOPRIGHT")
    header:SetHeight(HEADER_HEIGHT)
    header:EnableMouse(true)
    W.DragHandle(header, function() window:StartMoving() end, function() window:StopMovingOrSizing() end)

    local glyph = UI.AddonGlyph(header, HEADER_GLYPH_HEIGHT)
    glyph:SetPoint("LEFT", MARGIN, -2)
    local title = UI.BoldText(header, T.title, C.text)
    title:SetPoint("LEFT", glyph, "RIGHT", HEADER_GLYPH_GAP, 0)
    title:SetText(ns.TITLE)
    local version = UI.Text(header, T.caption, C.faint)
    version:SetPoint("BOTTOMLEFT", title, "BOTTOMRIGHT", 6, 0)
    version:SetText(ns.VERSION)

    local close = CreateFrame("Button", nil, header)
    close:SetSize(24, 24)
    close:SetPoint("RIGHT", -MARGIN + 6, -2)
    local cross = UI.Text(close, 18, C.muted)
    cross:SetPoint("CENTER", 0, 1)
    cross:SetText("×")
    close:SetScript("OnClick", Options.Close)
    close:SetScript("OnEnter", function() cross:SetTextColor(unpack(C.text)) end)
    close:SetScript("OnLeave", function() cross:SetTextColor(unpack(C.muted)) end)

end

local function CreateAnimations()
    local open = window:CreateAnimationGroup()
    local fadeIn = open:CreateAnimation("Alpha")
    fadeIn:SetFromAlpha(0)
    fadeIn:SetToAlpha(1)
    fadeIn:SetDuration(0.16)
    fadeIn:SetSmoothing("OUT")
    local grow = open:CreateAnimation("Scale")
    grow:SetScaleFrom(0.97, 0.97)
    grow:SetScaleTo(1, 1)
    grow:SetDuration(0.18)
    grow:SetSmoothing("OUT")
    window.openAnimation = open

    local close = window:CreateAnimationGroup()
    local fadeOut = close:CreateAnimation("Alpha")
    fadeOut:SetFromAlpha(1)
    fadeOut:SetToAlpha(0)
    fadeOut:SetDuration(0.12)
    fadeOut:SetSmoothing("IN")
    close:SetScript("OnFinished", function() window:Hide() end)
    window.closeAnimation = close
end

local function CreateWindow()
    window = CreateFrame("Frame", ns.ADDON .. "OptionsFrame", UIParent)
    window:SetSize(WIDTH, HEIGHT)
    window:SetPoint("CENTER", WINDOW_OFFSET_X, 0)
    window:SetFrameStrata("DIALOG")
    window:SetToplevel(true)
    window:SetMovable(true)
    window:SetClampedToScreen(true)
    window:EnableMouse(true)
    window:Hide()
    UI.Fill(window, C.window)
    tinsert(UISpecialFrames, window:GetName())

    CreateHeader()
    CreateTabs()

    local body = CreateFrame("Frame", nil, window)
    body:SetPoint("TOPLEFT", MARGIN - CONTENT_INSET, -HEADER_HEIGHT - TABS_HEIGHT - BODY_GAP)
    body:SetPoint("BOTTOMRIGHT", -MARGIN + CONTENT_INSET, MARGIN)
    window.body = body

    CreateAnimations()
    window:SetScript("OnHide", function() ns.Fire("OPTIONS_SHOWN", false) end)
end

function Options.Open(pageId)
    if not window then CreateWindow() end
    window.closeAnimation:Stop()
    if not window:IsShown() then
        window:Show()
        window.openAnimation:Restart()
        ns.Fire("OPTIONS_SHOWN", true)
    end
    ShowPage(pageId or currentPage and currentPage.id or ns.db.lastPage or DEFAULT_PAGE, false)
end

function Options.Close()
    if not window or not window:IsShown() then return end
    window.openAnimation:Stop()
    window.closeAnimation:Restart()
end

function Options.Toggle(pageId)
    if window and window:IsShown() and (not pageId or currentPage == pages[pageId]) then
        Options.Close()
    else
        Options.Open(pageId)
    end
end

ns.Listen("SETTING_CHANGED", function()
    if window and window:IsShown() and currentPage then
        RefreshPage(currentPage, true)
    end
end)

local function RegisterSettingsCategory()
    if not (Settings and Settings.RegisterCanvasLayoutCategory) then return end
    local panel = CreateFrame("Frame")
    panel:Hide()
    local glyph = UI.AddonGlyph(panel, SETTINGS_GLYPH_HEIGHT)
    glyph:SetPoint("TOPLEFT", 16, -16)
    local title = UI.Text(panel, 20, C.text)
    title:SetPoint("LEFT", glyph, "RIGHT", HEADER_GLYPH_GAP, 0)
    title:SetText(ns.TITLE)
    local desc = UI.Text(panel, T.body, C.muted)
    desc:SetPoint("TOPLEFT", glyph, "BOTTOMLEFT", 0, -10)
    W.Bind(desc, "SETTINGS_DESC")
    local open = W.Button(panel, "SETTINGS_OPEN", function() Options.Open() end, "primary")
    open:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -16)
    local category = Settings.RegisterCanvasLayoutCategory(panel, ns.TITLE)
    Settings.RegisterAddOnCategory(category)
end

ns.Listen("LOGIN", RegisterSettingsCategory)
