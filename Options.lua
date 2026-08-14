local _, ns = ...
local HeliHeal = ns.addon
local L = ns.L or function(value, ...) return select("#", ...) > 0 and value:format(...) or value end

local C = {
    bg = { 0.025, 0.035, 0.045, 0.98 },
    sidebar = { 0.018, 0.026, 0.034, 0.99 },
    panel = { 0.045, 0.058, 0.07, 0.96 },
    panelHover = { 0.06, 0.078, 0.09, 0.98 },
    input = { 0.025, 0.038, 0.048, 1 },
    border = { 0.12, 0.17, 0.2, 1 },
    borderSoft = { 0.08, 0.12, 0.15, 1 },
    accent = { 0.02, 0.88, 0.7, 1 },
    accentDark = { 0.015, 0.35, 0.3, 1 },
    text = { 0.94, 0.97, 0.98, 1 },
    muted = { 0.49, 0.56, 0.6, 1 },
    dim = { 0.29, 0.35, 0.39, 1 },
    danger = { 0.94, 0.32, 0.36, 1 },
}

local WHITE = "Interface\\Buttons\\WHITE8X8"
local FONT = ns.media.font
local MODIFIER_KEYS = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true }

local function unpackColor(color)
    return color[1], color[2], color[3], color[4]
end

local function backdrop(frame, background, border, edgeSize)
    frame:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = edgeSize or 1 })
    frame:SetBackdropColor(unpackColor(background or C.panel))
    frame:SetBackdropBorderColor(unpackColor(border or C.border))
end

local function text(parent, value, size, color, flags)
    local label = parent:CreateFontString(nil, "OVERLAY")
    label:SetFont(FONT, size or 12, flags or "")
    label:SetText(value or "")
    label:SetTextColor(unpackColor(color or C.text))
    label:SetJustifyH("LEFT")
    return label
end

local function createButton(parent, labelText, width, height, primary)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(width or 130, height or 34)
    backdrop(button, primary and C.accentDark or C.input, primary and C.accent or C.border)
    button.label = text(button, labelText, 11, primary and C.text or C.muted, "OUTLINE")
    button.label:SetPoint("CENTER")
    button:SetScript("OnEnter", function(self)
        self:SetBackdropColor(unpackColor(primary and C.accentDark or C.panelHover))
        self:SetBackdropBorderColor(unpackColor(C.accent))
        self.label:SetTextColor(unpackColor(C.text))
    end)
    button:SetScript("OnLeave", function(self)
        self:SetBackdropColor(unpackColor(primary and C.accentDark or C.input))
        self:SetBackdropBorderColor(unpackColor(primary and C.accent or C.border))
        self.label:SetTextColor(unpackColor(primary and C.text or C.muted))
    end)
    return button
end

local function createEditBox(parent, width, placeholder)
    local box = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    box:SetSize(width, 34)
    box:SetAutoFocus(false)
    box:SetFont(FONT, 12, "")
    box:SetTextColor(unpackColor(C.text))
    box:SetTextInsets(10, 10, 0, 0)
    backdrop(box, C.input, C.border)
    box.placeholder = text(box, placeholder or "", 11, C.dim)
    box.placeholder:SetPoint("LEFT", 10, 0)
    box:SetScript("OnEditFocusGained", function(self)
        self:SetBackdropBorderColor(unpackColor(C.accent))
        self.placeholder:Hide()
    end)
    box:SetScript("OnEditFocusLost", function(self)
        self:SetBackdropBorderColor(unpackColor(C.border))
        self.placeholder:SetShown(self:GetText() == "")
    end)
    box:SetScript("OnTextChanged", function(self)
        self.placeholder:SetShown(not self:HasFocus() and self:GetText() == "")
    end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    return box
end

local function createToggle(parent, getValue, setValue)
    local toggle = CreateFrame("Button", nil, parent, "BackdropTemplate")
    toggle:SetSize(44, 22)
    toggle.getValue = getValue
    toggle.setValue = setValue
    backdrop(toggle, C.input, C.border)
    toggle.fill = toggle:CreateTexture(nil, "ARTWORK")
    toggle.fill:SetTexture(WHITE)
    toggle.fill:SetPoint("TOPLEFT", 2, -2)
    toggle.fill:SetPoint("BOTTOMRIGHT", -2, 2)
    toggle.thumb = toggle:CreateTexture(nil, "OVERLAY")
    toggle.thumb:SetTexture(WHITE)
    toggle.thumb:SetSize(16, 16)

    function toggle:Refresh()
        local active = self.getValue()
        self.fill:SetColorTexture(unpackColor(active and C.accentDark or C.input))
        self.thumb:ClearAllPoints()
        self.thumb:SetPoint(active and "RIGHT" or "LEFT", active and -3 or 3, 0)
        self.thumb:SetColorTexture(unpackColor(active and C.accent or C.dim))
        self:SetBackdropBorderColor(unpackColor(active and C.accent or C.border))
    end

    toggle:SetScript("OnClick", function(self)
        self.setValue(not self.getValue())
        self:Refresh()
    end)
    toggle:Refresh()
    return toggle
end

local function createSettingRow(parent, y, title, description)
    local row = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    row:SetPoint("TOPLEFT", 20, y)
    row:SetPoint("TOPRIGHT", -20, y)
    row:SetHeight(62)
    backdrop(row, C.panel, C.borderSoft)
    row.title = text(row, title, 12, C.text, "OUTLINE")
    row.title:SetPoint("LEFT", 18, 8)
    row.description = text(row, description, 10, C.muted)
    row.description:SetPoint("LEFT", 18, -10)
    return row
end

local function createSlider(parent, minValue, maxValue, step, getValue, setValue, formatter)
    local slider = CreateFrame("Slider", nil, parent)
    slider:SetSize(220, 18)
    slider:SetOrientation("HORIZONTAL")
    slider:SetMinMaxValues(minValue, maxValue)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)

    slider.track = slider:CreateTexture(nil, "BACKGROUND")
    slider.track:SetTexture(WHITE)
    slider.track:SetColorTexture(0.13, 0.17, 0.19, 1)
    slider.track:SetPoint("LEFT", 0, 0)
    slider.track:SetPoint("RIGHT", 0, 0)
    slider.track:SetHeight(4)

    slider.fill = slider:CreateTexture(nil, "ARTWORK")
    slider.fill:SetTexture(WHITE)
    slider.fill:SetColorTexture(unpackColor(C.accent))
    slider.fill:SetPoint("LEFT", slider.track, "LEFT")
    slider.fill:SetHeight(4)

    slider:SetThumbTexture(WHITE)
    local thumb = slider:GetThumbTexture()
    thumb:SetSize(12, 18)
    thumb:SetColorTexture(unpackColor(C.accent))

    slider.value = text(slider, "", 11, C.text, "OUTLINE")
    slider.value:SetPoint("LEFT", slider, "RIGHT", 14, 0)
    slider.value:SetWidth(54)

    slider:SetScript("OnValueChanged", function(self, value, userInput)
        local percent = (value - minValue) / (maxValue - minValue)
        self.fill:SetWidth(math.max(1, 220 * percent))
        self.value:SetText(formatter and formatter(value) or tostring(value))
        if userInput then
            setValue(value)
        end
    end)

    function slider:Refresh()
        self:SetValue(getValue())
    end
    slider:Refresh()
    return slider
end

local function createDropdownSelector(parent, menuParent, values, getValue, setValue)
    local selector = CreateFrame("Button", nil, parent, "BackdropTemplate")
    selector:SetSize(230, 34)
    backdrop(selector, C.input, C.border)
    selector.label = text(selector, "", 11, C.text, "OUTLINE")
    selector.label:SetPoint("LEFT", 12, 0)
    selector.label:SetPoint("RIGHT", -34, 0)
    selector.arrow = text(selector, "▾", 13, C.accent, "OUTLINE")
    selector.arrow:SetPoint("RIGHT", -12, 1)

    local dismiss = CreateFrame("Button", nil, menuParent)
    dismiss:SetAllPoints()
    dismiss:SetFrameLevel(menuParent:GetFrameLevel() + 40)
    dismiss:Hide()

    local menu = CreateFrame("Frame", nil, menuParent, "BackdropTemplate")
    menu:SetSize(230, (#values * 32) + 8)
    menu:SetFrameLevel(menuParent:GetFrameLevel() + 41)
    menu:SetClampedToScreen(true)
    backdrop(menu, C.sidebar, C.accentDark)
    menu:Hide()
    menu.options = {}

    local function closeMenu()
        menu:Hide()
        dismiss:Hide()
        selector.arrow:SetText("▾")
    end
    dismiss:SetScript("OnClick", closeMenu)

    for index, option in ipairs(values) do
        local optionButton = CreateFrame("Button", nil, menu, "BackdropTemplate")
        optionButton:SetPoint("TOPLEFT", 4, -4 - ((index - 1) * 32))
        optionButton:SetPoint("TOPRIGHT", -4, -4 - ((index - 1) * 32))
        optionButton:SetHeight(30)
        backdrop(optionButton, C.input, C.input)
        optionButton.label = text(optionButton, option.label, 11, C.text, option.flags or "OUTLINE")
        optionButton.label:SetFont(option.font or FONT, 11, option.flags or "OUTLINE")
        optionButton.label:SetPoint("LEFT", 10, 0)
        optionButton:SetScript("OnClick", function()
            setValue(option.value)
            selector:Refresh()
            closeMenu()
        end)
        optionButton:SetScript("OnEnter", function(self)
            self:SetBackdropColor(unpackColor(C.panelHover))
            self.label:SetTextColor(unpackColor(C.text))
        end)
        optionButton:SetScript("OnLeave", function(self)
            selector:RefreshMenu()
        end)
        menu.options[index] = optionButton
    end

    function selector:RefreshMenu()
        local selected = getValue()
        for index, option in ipairs(values) do
            local active = option.value == selected
            local optionButton = menu.options[index]
            optionButton:SetBackdropColor(unpackColor(active and C.accentDark or C.input))
            optionButton:SetBackdropBorderColor(unpackColor(active and C.accent or C.input))
            optionButton.label:SetTextColor(unpackColor(active and C.accent or C.text))
        end
    end

    function selector:Refresh()
        local selected = getValue()
        for _, option in ipairs(values) do
            if option.value == selected then
                self.label:SetText(option.label)
                self.label:SetFont(option.font or FONT, 11, option.flags or "OUTLINE")
                self:RefreshMenu()
                return
            end
        end
        self.label:SetText(values[1].label)
        self.label:SetFont(values[1].font or FONT, 11, values[1].flags or "OUTLINE")
        self:RefreshMenu()
    end

    selector:SetScript("OnClick", function(self)
        if menu:IsShown() then
            closeMenu()
            return
        end
        menu:ClearAllPoints()
        local menuHeight = menu:GetHeight()
        local selectorBottom = self:GetBottom()
        local parentBottom = menuParent:GetBottom()
        if selectorBottom and parentBottom and (selectorBottom - parentBottom) >= (menuHeight + 8) then
            menu:SetPoint("TOPRIGHT", self, "BOTTOMRIGHT", 0, -4)
        else
            menu:SetPoint("BOTTOMRIGHT", self, "TOPRIGHT", 0, 4)
        end
        self:RefreshMenu()
        dismiss:Show()
        menu:Show()
        self.arrow:SetText("▴")
    end)
    selector:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(unpackColor(C.accent)) end)
    selector:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(unpackColor(C.border)) end)
    selector:SetScript("OnHide", closeMenu)
    selector:Refresh()
    return selector
end

local function createColorSwatch(parent, width, caption, getColor, setColor)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(width or 112, 34)
    backdrop(button, C.input, C.border)
    button.swatch = button:CreateTexture(nil, "ARTWORK")
    button.swatch:SetPoint("LEFT", 6, 0)
    button.swatch:SetSize(22, 22)
    button.label = text(button, caption or L("FARBE"), 9, C.text, "OUTLINE")
    button.label:SetPoint("LEFT", button.swatch, "RIGHT", 7, 0)

    function button:Refresh()
        local color = getColor() or { 1, 1, 1 }
        self.swatch:SetColorTexture(color[1] or 1, color[2] or 1, color[3] or 1, 1)
    end

    button:SetScript("OnClick", function(self)
        local color = getColor() or { 1, 1, 1 }
        local original = { color[1] or 1, color[2] or 1, color[3] or 1 }
        local function apply()
            local red, green, blue = ColorPickerFrame:GetColorRGB()
            setColor(red, green, blue)
            self:Refresh()
        end
        local function cancel()
            setColor(original[1], original[2], original[3])
            self:Refresh()
        end
        if ColorPickerFrame.SetupColorPickerAndShow then
            ColorPickerFrame:SetupColorPickerAndShow({
                r = original[1], g = original[2], b = original[3],
                swatchFunc = apply,
                cancelFunc = cancel,
            })
        else
            ColorPickerFrame.func = apply
            ColorPickerFrame.cancelFunc = cancel
            ColorPickerFrame:SetColorRGB(original[1], original[2], original[3])
            ColorPickerFrame:Show()
        end
    end)
    button:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(unpackColor(C.accent)) end)
    button:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(unpackColor(C.border)) end)
    button:Refresh()
    return button
end

local function setPageHeader(page, titleText, subtitleText)
    local titleLabel = text(page, titleText, 26, C.text, "OUTLINE")
    titleLabel:SetPoint("TOPLEFT", 28, -26)
    local subtitle = text(page, subtitleText, 11, C.muted)
    subtitle:SetPoint("TOPLEFT", titleLabel, "BOTTOMLEFT", 1, -9)
    local line = page:CreateTexture(nil, "ARTWORK")
    line:SetTexture(WHITE)
    line:SetColorTexture(unpackColor(C.accent))
    line:SetPoint("TOPLEFT", 28, -88)
    line:SetPoint("TOPRIGHT", -28, -88)
    line:SetHeight(2)
end

local MOUSE_BUTTON_KEYS = {
    LeftButton = "BUTTON1",
    RightButton = "BUTTON2",
    MiddleButton = "BUTTON3",
}

local function withModifiers(input)
    local parts = {}
    if IsControlKeyDown() then parts[#parts + 1] = "CTRL" end
    if IsAltKeyDown() then parts[#parts + 1] = "ALT" end
    if IsShiftKeyDown() then parts[#parts + 1] = "SHIFT" end
    parts[#parts + 1] = input
    return table.concat(parts, "-")
end

local function normalizeCapturedKey(key)
    if not key or MODIFIER_KEYS[key] then return nil end
    return withModifiers(key:upper())
end

local function normalizeCapturedMouse(mouseButton)
    if not mouseButton then return nil end
    local bindingKey = MOUSE_BUTTON_KEYS[mouseButton]
    if not bindingKey then
        local number = mouseButton:match("^Button(%d+)$")
        bindingKey = number and ("BUTTON" .. number) or mouseButton:upper()
    end
    return withModifiers(bindingKey)
end

local function formatSeconds(value)
    value = tonumber(value) or 0
    local rounded = math.floor(value + 0.5)
    if math.abs(value - rounded) < 0.05 then return tostring(rounded) end
    return ("%.1f"):format(value)
end

function HeliHeal:BuildOverviewPage(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    setPageHeader(page, L("Übersicht"), L("Anzeige, Verhalten und Größe des statischen Priority-Trackers."))

    local enabledRow = createSettingRow(page, -110, L("Tracker anzeigen"), L("Blendet die HeliHeal-Prioritätsleiste ein oder aus."))
    local enabledToggle = createToggle(enabledRow,
        function() return self.db.profile.enabled end,
        function(value) self.db.profile.enabled = value; self:ApplyDisplaySettings() end)
    enabledToggle:SetPoint("RIGHT", -20, 0)

    local lockRow = createSettingRow(page, -180, L("Position sperren"), L("Verhindert das versehentliche Verschieben der Anzeige."))
    local lockToggle = createToggle(lockRow,
        function() return self.db.profile.locked end,
        function(value) self.db.profile.locked = value; self:ApplyDisplaySettings() end)
    lockToggle:SetPoint("RIGHT", -20, 0)

    local scaleRow = createSettingRow(page, -250, L("UI-Skalierung"), L("Skaliert die vollständige Priority-Anzeige."))
    local scaleSlider = createSlider(scaleRow, 0.6, 1.8, 0.05,
        function() return self.db.profile.scale end,
        function(value) self.db.profile.scale = value; self:ApplyDisplaySettings() end,
        function(value) return ("%.0f%%"):format(value * 100) end)
    scaleSlider:SetPoint("RIGHT", -74, 0)

    local spacingRow = createSettingRow(page, -320, L("Icon-Abstand"), L("Bestimmt den Abstand zwischen Empfehlung und Folgeslots."))
    local spacingSlider = createSlider(spacingRow, 0, 24, 1,
        function() return self.db.profile.spacing end,
        function(value) self.db.profile.spacing = value; self:RefreshDisplay() end,
        function(value) return ("%d px"):format(value) end)
    spacingSlider:SetPoint("RIGHT", -74, 0)

    local languageRow = createSettingRow(page, -390, L("Sprache"), L("Standard: WoW-Clientsprache. Ein Wechsel lädt die UI neu."))
    page.languageButtons = {}
    local languages = {
        { "auto", L("CLIENTSPRACHE"), 125 },
        { "deDE", L("DEUTSCH"), 92 },
        { "enUS", "ENGLISH", 92 },
    }
    local previous
    for index = #languages, 1, -1 do
        local language = languages[index]
        local button = createButton(languageRow, language[2], language[3], 32, false)
        if previous then
            button:SetPoint("RIGHT", previous, "LEFT", -8, 0)
        else
            button:SetPoint("RIGHT", -16, 0)
        end
        button:SetScript("OnClick", function() self:SetLanguageMode(language[1]) end)
        page.languageButtons[language[1]] = button
        previous = button
    end

    local reset = createButton(page, L("LOKALE TIMER ZURÜCKSETZEN"), 210, 38, false)
    reset:SetPoint("BOTTOMLEFT", 28, 28)
    reset:SetScript("OnClick", function() self:ResetSession() end)
    local center = createButton(page, L("ANZEIGE ZENTRIEREN"), 180, 38, true)
    center:SetPoint("LEFT", reset, "RIGHT", 12, 0)
    center:SetScript("OnClick", function()
        local profile = self.db.profile
        profile.point, profile.relativePoint, profile.x, profile.y = "CENTER", "CENTER", 0, -165
        self:ApplyDisplaySettings()
    end)

    page.refreshers = { enabledToggle, lockToggle, scaleSlider, spacingSlider }
    return page
end

function HeliHeal:BeginKeyCapture(button, slotIndex)
    if InCombatLockdown and InCombatLockdown() then
        self:Print(L("Inputs können während des Kampfes nicht neu belegt werden."))
        return
    end

    if self.keyCaptureButton and self.keyCaptureButton ~= button then
        self:EndKeyCapture()
    end

    self.suspendInput = true
    self.keyCaptureButton = button
    button.label:SetText(L("TASTE DRÜCKEN …"))
    button:SetBackdropBorderColor(unpackColor(C.accent))
    button:SetScript("OnClick", nil)
    button:EnableKeyboard(true)
    button:SetPropagateKeyboardInput(false)
    button:EnableMouseWheel(true)

    local function commit(input)
        if not input then return end
        HeliHeal:SetAbilityBinding(slotIndex, input)
        HeliHeal:EndKeyCapture()
        HeliHeal:RefreshOptionsUI()
    end

    button:SetScript("OnKeyDown", function(capture, key)
        capture:SetPropagateKeyboardInput(false)
        if key == "ESCAPE" then
            HeliHeal:EndKeyCapture()
            return
        end
        commit(normalizeCapturedKey(key))
    end)
    button:SetScript("OnMouseDown", function(_, mouseButton)
        commit(normalizeCapturedMouse(mouseButton))
    end)
    button:SetScript("OnMouseWheel", function(_, delta)
        commit(withModifiers(delta > 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN"))
    end)
end

function HeliHeal:EndKeyCapture()
    local button = self.keyCaptureButton
    if button then
        button:EnableKeyboard(false)
        button:EnableMouseWheel(false)
        button:SetScript("OnKeyDown", nil)
        button:SetScript("OnMouseDown", nil)
        button:SetScript("OnMouseWheel", nil)
        -- BUTTON1 is captured on OnMouseDown. Restore the normal handler on
        -- the next frame so the same physical click cannot reopen capture via
        -- the following OnClick event.
        C_Timer.After(0, function()
            if button and button.captureOnClick then
                button:SetScript("OnClick", button.captureOnClick)
            end
        end)
        button:SetBackdropBorderColor(unpackColor(C.border))
    end
    self.keyCaptureButton = nil
    self.suspendInput = false
    self:RefreshOptionsUI()
end

function HeliHeal:BuildPrioritiesPage(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    local className = self.classToken == "DRUID" and "Restoration Druid 12.1"
        or (self.classToken == "PALADIN" and "Holy Paladin 12.1" or "Restoration Shaman 12.1")
    setPageHeader(page, className, L("Standard bleibt das Guide-Paket; Kontextmodi verändern nur dessen lokale Reihenfolge."))

    page.presetButtons = {}
    local presets = self.classToken == "DRUID" and {
        { "druid_wildstalker_mythicplus", "WILDSTALKER M+" },
        { "druid_wildstalker_raid", "WILDSTALKER RAID" },
        { "druid_keeper_mythicplus", "KEEPER M+" },
        { "druid_keeper_raid", "KEEPER RAID" },
    } or self.classToken == "PALADIN" and {
        { "paladin_herald_mythicplus", "HERALD M+" },
        { "paladin_herald_raid", "HERALD RAID" },
        { "paladin_lightsmith_mythicplus", "LIGHTSMITH M+" },
        { "paladin_lightsmith_raid", "LIGHTSMITH RAID" },
    } or {
        { "shaman_totemic_mythicplus", "TOTEMIC M+" },
        { "shaman_totemic_raid", "TOTEMIC RAID" },
        { "shaman_farseer_mythicplus", "FARSEER M+" },
        { "shaman_farseer_raid", "FARSEER RAID" },
    }
    for index, preset in ipairs(presets) do
        local presetKey = preset[1]
        local presetLabel = preset[2]
        local button = createButton(page, presetLabel, 168, 34, false)
        button:SetPoint("TOPLEFT", 28 + ((index - 1) * 180), -108)
        button:SetScript("OnClick", function() self:SetRotationPreset(presetKey) end)
        page.presetButtons[presetKey] = button
    end


    page.modeButtons = {}
    local modes = {
        { "standard", "STANDARD" },
        { "aoe", "AOE" },
        { "single", L("EINZELZIEL") },
        { "mana", L("MANA SPAREN") },
    }
    for index, mode in ipairs(modes) do
        local modeKey = mode[1]
        local button = createButton(page, mode[2], 168, 30, false)
        button:SetPoint("TOPLEFT", 28 + ((index - 1) * 180), -150)
        button:SetScript("OnClick", function() self:SetHealingMode(modeKey) end)
        page.modeButtons[modeKey] = button
    end

    local priorityHeader = text(page, "PRIO", 9, C.muted, "OUTLINE")
    priorityHeader:SetPoint("TOPLEFT", 34, -198)
    local abilityHeader = text(page, L("FESTE GUIDE-FÄHIGKEIT"), 9, C.muted, "OUTLINE")
    abilityHeader:SetPoint("TOPLEFT", 126, -198)
    local bindingHeader = text(page, L("BEOBACHTETER ACTIONBAR-HOTKEY"), 9, C.muted, "OUTLINE")
    bindingHeader:SetPoint("TOPLEFT", 494, -198)

    page.slotRows = {}
    for slotIndex = 1, 11 do
        local capturedSlotIndex = slotIndex
        local row = CreateFrame("Frame", nil, page, "BackdropTemplate")
        row:SetPoint("TOPLEFT", 28, -214 - ((slotIndex - 1) * 37))
        row:SetPoint("TOPRIGHT", -28, -214 - ((slotIndex - 1) * 37))
        row:SetHeight(34)
        backdrop(row, C.panel, C.borderSoft)

        row.priority = text(row, ("%02d"):format(slotIndex), 15, slotIndex == 1 and C.accent or C.text, "OUTLINE")
        row.priority:SetPoint("LEFT", 12, 0)
        row.priority:SetWidth(42)

        row.iconFrame = CreateFrame("Frame", nil, row, "BackdropTemplate")
        row.iconFrame:SetSize(28, 28)
        row.iconFrame:SetPoint("LEFT", 58, 0)
        backdrop(row.iconFrame, C.input, C.border)
        row.icon = row.iconFrame:CreateTexture(nil, "ARTWORK")
        row.icon:SetPoint("TOPLEFT", 3, -3)
        row.icon:SetPoint("BOTTOMRIGHT", -3, 3)
        row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        row.abilityName = text(row, "", 12, C.text, "OUTLINE")
        row.abilityName:SetPoint("LEFT", 112, 7)
        row.cooldownLabel = text(row, "", 9, C.muted)
        row.cooldownLabel:SetPoint("LEFT", 112, -11)

        row.key = createButton(row, "", 210, 28, false)
        row.key:SetPoint("RIGHT", -9, 0)
        row.key.captureOnClick = function(button) self:BeginKeyCapture(button, capturedSlotIndex) end
        row.key:SetScript("OnClick", row.key.captureOnClick)
        page.slotRows[slotIndex] = row
    end

    return page
end

function HeliHeal:BuildStylePage(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    setPageHeader(page, L("HUD-Elemente"), L("Reduziere die Anzeige auf das Wesentliche oder aktiviere einzelne Details."))

    local definitions = {
        { L("Panel-Hintergrund"), L("Dunkler gemeinsamer Hintergrund um alle Icons."), "showPanelBackground" },
        { L("HeliHeal-Header"), L("Zeigt die Überschrift über der Priority-Leiste."), "showHeader" },
        { L("Fähigkeitsname"), L("Blendet den Namen der Fähigkeit am Icon ein."), "showAbilityName" },
        { L("Prioritätsbadge"), L("Zeigt P1 bis P5 direkt auf dem jeweiligen Icon."), "showPriorityBadge" },
        { L("Icon-Rahmen"), L("Schmaler Rahmen und Schatten um jedes Spell-Icon."), "showIconBorder" },
        { L("Hotkey"), L("Zeigt den beobachteten Input unter dem Icon."), "showHotkey" },
        { L("Rollen-Hinweis"), L("Zeigt AOE, SINGLE, BURST oder SAVE mittig auf passenden Heilfähigkeiten."), "showRoleLabel" },
        { L("Cooldown-Zahl"), L("Zeigt den lokal simulierten Cooldown mittig auf dem Icon."), "showCooldown" },
    }

    local scroll = CreateFrame("ScrollFrame", nil, page)
    scroll:SetPoint("TOPLEFT", 0, -104)
    scroll:SetPoint("BOTTOMRIGHT", -24, 12)
    scroll:EnableMouseWheel(true)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetWidth(1)
    content:SetHeight(1)
    scroll:SetScrollChild(content)

    local track = page:CreateTexture(nil, "BACKGROUND")
    track:SetTexture(WHITE)
    track:SetColorTexture(unpackColor(C.borderSoft))
    track:SetPoint("TOPRIGHT", -13, -110)
    track:SetPoint("BOTTOMRIGHT", -13, 18)
    track:SetWidth(3)

    local thumb = page:CreateTexture(nil, "ARTWORK")
    thumb:SetTexture(WHITE)
    thumb:SetColorTexture(unpackColor(C.accent))
    thumb:SetWidth(3)

    local function updateScroll()
        local viewportHeight = math.max(1, scroll:GetHeight())
        local contentHeight = math.max(viewportHeight, content:GetHeight())
        local maxScroll = math.max(0, contentHeight - viewportHeight)
        local current = math.max(0, math.min(maxScroll, scroll:GetVerticalScroll()))
        if current ~= scroll:GetVerticalScroll() then scroll:SetVerticalScroll(current) end
        local trackHeight = math.max(1, track:GetHeight())
        local thumbHeight = math.max(40, trackHeight * (viewportHeight / contentHeight))
        local travel = math.max(0, trackHeight - thumbHeight)
        thumb:SetHeight(thumbHeight)
        thumb:ClearAllPoints()
        thumb:SetPoint("TOP", track, "TOP", 0, maxScroll > 0 and -(current / maxScroll) * travel or 0)
        track:SetShown(maxScroll > 0)
        thumb:SetShown(maxScroll > 0)
    end

    local function scrollByWheel(_, delta)
        local maxScroll = math.max(0, content:GetHeight() - scroll:GetHeight())
        scroll:SetVerticalScroll(math.max(0, math.min(maxScroll, scroll:GetVerticalScroll() - (delta * 54))))
        updateScroll()
    end
    scroll:SetScript("OnMouseWheel", scrollByWheel)
    scroll:SetScript("OnSizeChanged", function(_, width)
        content:SetWidth(width)
        updateScroll()
    end)
    scroll:SetScript("OnShow", function()
        content:SetWidth(math.max(1, scroll:GetWidth()))
        updateScroll()
    end)

    local function bindWheel(control)
        control:EnableMouseWheel(true)
        control:SetScript("OnMouseWheel", scrollByWheel)
    end

    page.refreshers = {}
    for index, definition in ipairs(definitions) do
        local row = createSettingRow(content, -6 - ((index - 1) * 68), definition[1], definition[2])
        local settingKey = definition[3]
        local toggle = createToggle(row,
            function() return self.db.profile[settingKey] end,
            function(value)
                self.db.profile[settingKey] = value
                self:RefreshDisplay()
            end)
        toggle:SetPoint("RIGHT", -20, 0)
        bindWheel(row)
        bindWheel(toggle)
        page.refreshers[#page.refreshers + 1] = toggle
    end

    local nextY = -6 - (#definitions * 68)
    local styleSection = text(content, L("SCHRIFT, GRÖSSE & FARBEN"), 10, C.accent, "OUTLINE")
    styleSection:SetPoint("TOPLEFT", 20, nextY - 10)
    nextY = nextY - 38

    local function addControlRow(titleText, descriptionText, control)
        local row = createSettingRow(content, nextY, titleText, descriptionText)
        control:SetParent(row)
        control:SetPoint("RIGHT", -20, 0)
        bindWheel(row)
        bindWheel(control)
        page.refreshers[#page.refreshers + 1] = control
        nextY = nextY - 68
        return row
    end

    local fontOptions = {}
    for _, key in ipairs(ns.media.fontOrder or {}) do
        local entry = ns.media.fonts and ns.media.fonts[key]
        if entry then fontOptions[#fontOptions + 1] = { value = key, label = entry.name, font = entry.path } end
    end
    local fontSelector = createDropdownSelector(content, page, fontOptions,
        function() return self.db.profile.hudFont end,
        function(value) self.db.profile.hudFont = value; self:RefreshDisplay() end)
    addControlRow(L("HUD-Schriftart"), L("Wählt die Schriftart für alle Texte im Priority-HUD."), fontSelector)

    local outlineSelector = createDropdownSelector(content, page, {
        { value = "NONE", label = L("Ohne Kontur"), flags = "" },
        { value = "OUTLINE", label = L("Normale Kontur"), flags = "OUTLINE" },
        { value = "THICKOUTLINE", label = L("Starke Kontur"), flags = "THICKOUTLINE" },
    }, function() return self.db.profile.hudFontOutline end,
        function(value) self.db.profile.hudFontOutline = value; self:RefreshDisplay() end)
    addControlRow(L("Textkontur"), L("Legt die Lesbarkeit aller Texte auf den Spell-Icons fest."), outlineSelector)

    local primarySize = createSlider(content, 48, 96, 1,
        function() return self.db.profile.primaryIconSize end,
        function(value) self.db.profile.primaryIconSize = value; self:RefreshDisplay() end,
        function(value) return ("%d px"):format(value) end)
    addControlRow(L("Haupt-Icon-Größe"), L("Größe der aktuell empfohlenen Fähigkeit."), primarySize)

    local secondarySize = createSlider(content, 32, 72, 1,
        function() return self.db.profile.secondaryIconSize end,
        function(value) self.db.profile.secondaryIconSize = value; self:RefreshDisplay() end,
        function(value) return ("%d px"):format(value) end)
    addControlRow(L("Folge-Icon-Größe"), L("Größe der vier nachfolgenden Empfehlungen."), secondarySize)

    local roleSize = createSlider(content, 7, 18, 1,
        function() return self.db.profile.roleLabelSize end,
        function(value) self.db.profile.roleLabelSize = value; self:RefreshDisplay() end,
        function(value) return ("%d px"):format(value) end)
    addControlRow(L("Rollen-Textgröße"), L("Größe von AOE, SINGLE, BURST und SAVE."), roleSize)

    local roleOffset = createSlider(content, -12, 12, 1,
        function() return self.db.profile.roleLabelOffsetY end,
        function(value) self.db.profile.roleLabelOffsetY = value; self:RefreshDisplay() end,
        function(value) return ("%+d px"):format(value) end)
    addControlRow(L("Rollen-Position"), L("Verschiebt den Rollen-Hinweis vertikal im Icon."), roleOffset)

    local hotkeySize = createSlider(content, 7, 16, 1,
        function() return self.db.profile.hotkeyFontSize end,
        function(value) self.db.profile.hotkeyFontSize = value; self:RefreshDisplay() end,
        function(value) return ("%d px"):format(value) end)
    addControlRow(L("Hotkey-Textgröße"), L("Größe der Tastenbezeichnung unter dem Icon."), hotkeySize)

    local cooldownSize = createSlider(content, 10, 24, 1,
        function() return self.db.profile.cooldownFontSize end,
        function(value) self.db.profile.cooldownFontSize = value; self:RefreshDisplay() end,
        function(value) return ("%d px"):format(value) end)
    addControlRow(L("Cooldown-Textgröße"), L("Größe des lokalen Timers und der Aufladungsanzeige."), cooldownSize)

    local nameSize = createSlider(content, 7, 16, 1,
        function() return self.db.profile.abilityNameFontSize end,
        function(value) self.db.profile.abilityNameFontSize = value; self:RefreshDisplay() end,
        function(value) return ("%d px"):format(value) end)
    addControlRow(L("Namens-Textgröße"), L("Größe von Fähigkeitsname und optionalem Header."), nameSize)

    local function colorValue(key)
        return self.db.profile[key] or ns.defaults.profile[key]
    end
    local function colorSetter(key)
        return function(red, green, blue)
            self.db.profile[key] = { red, green, blue }
            self:RefreshDisplay()
        end
    end

    local accentColor = createColorSwatch(content, 112, L("AKZENT"),
        function() return colorValue("accentColor") end, colorSetter("accentColor"))
    addControlRow(L("HUD-Akzentfarbe"), L("Farbe für aktive Rahmen, Header und Prioritätsbadge."), accentColor)

    local hotkeyColor = createColorSwatch(content, 112, L("HOTKEY"),
        function() return colorValue("hotkeyColor") end, colorSetter("hotkeyColor"))
    addControlRow(L("Hotkey-Farbe"), L("Textfarbe der beobachteten Tastenbelegung."), hotkeyColor)

    local cooldownColor = createColorSwatch(content, 112, L("TIMER"),
        function() return colorValue("cooldownColor") end, colorSetter("cooldownColor"))
    addControlRow(L("Cooldown-Farbe"), L("Textfarbe für Timer, Aufladungen und Abdeckungszähler."), cooldownColor)

    local roleRow = createSettingRow(content, nextY, L("Rollenfarben"), L("Eigene Farben für jeden Heilungs-Kontext."))
    bindWheel(roleRow)
    local previousSwatch
    for _, role in ipairs({ "AOE", "SINGLE", "BURST", "SAVE" }) do
        local roleKey = role
        local swatch = createColorSwatch(roleRow, 86, roleKey,
            function() return (self.db.profile.roleColors or ns.defaults.profile.roleColors)[roleKey] end,
            function(red, green, blue)
                local current = self.db.profile.roleColors or ns.defaults.profile.roleColors
                local updated = {}
                for existingRole, source in pairs(current) do
                    updated[existingRole] = { source[1], source[2], source[3] }
                end
                updated[roleKey] = { red, green, blue }
                self.db.profile.roleColors = updated
                self:RefreshDisplay()
            end)
        if previousSwatch then
            swatch:SetPoint("RIGHT", previousSwatch, "LEFT", -7, 0)
        else
            swatch:SetPoint("RIGHT", -16, 0)
        end
        bindWheel(swatch)
        page.refreshers[#page.refreshers + 1] = swatch
        previousSwatch = swatch
    end
    nextY = nextY - 68

    local resetRow = createSettingRow(content, nextY, L("HUD-Optik zurücksetzen"), L("Setzt nur Schrift, Größen und Farben auf HeliHeal-Standard zurück."))
    bindWheel(resetRow)
    local resetAppearance = createButton(resetRow, L("OPTIK RESET"), 150, 32, false)
    resetAppearance:SetPoint("RIGHT", -20, 0)
    bindWheel(resetAppearance)
    resetAppearance:SetScript("OnClick", function()
        local profile = self.db.profile
        local defaults = ns.defaults.profile
        for _, key in ipairs({ "hudFont", "hudFontOutline", "primaryIconSize", "secondaryIconSize",
            "roleLabelSize", "roleLabelOffsetY", "hotkeyFontSize", "cooldownFontSize", "abilityNameFontSize" }) do
            profile[key] = defaults[key]
        end
        for _, key in ipairs({ "accentColor", "hotkeyColor", "cooldownColor" }) do
            local source = defaults[key]
            profile[key] = { source[1], source[2], source[3] }
        end
        profile.roleColors = {}
        for role, source in pairs(defaults.roleColors) do
            profile.roleColors[role] = { source[1], source[2], source[3] }
        end
        self:RefreshDisplay()
        self:RefreshOptionsUI()
    end)
    nextY = nextY - 68

    content:SetHeight(math.abs(nextY) + 8)
    updateScroll()
    page.scroll = scroll
    page.updateScroll = updateScroll
    return page
end

function HeliHeal:BuildProfilesPage(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    setPageHeader(page, L("Profile & Reset"), L("Separate Konfigurationen über AceDB verwalten oder sicher zurücksetzen."))

    local profileCard = CreateFrame("Frame", nil, page, "BackdropTemplate")
    profileCard:SetPoint("TOPLEFT", 28, -116)
    profileCard:SetPoint("TOPRIGHT", -28, -116)
    profileCard:SetHeight(150)
    backdrop(profileCard, C.panel, C.borderSoft)
    local profileCaption = text(profileCard, L("AKTIVES PROFIL"), 10, C.accent, "OUTLINE")
    profileCaption:SetPoint("TOPLEFT", 20, -18)
    page.profileName = text(profileCard, "", 22, C.text, "OUTLINE")
    page.profileName:SetPoint("TOPLEFT", profileCaption, "BOTTOMLEFT", 0, -12)
    local switchLabel = text(profileCard, L("Profilname eingeben, um ein Profil anzulegen oder zu wechseln:"), 10, C.muted)
    switchLabel:SetPoint("BOTTOMLEFT", 20, 50)
    page.profileInput = createEditBox(profileCard, 260, L("Profilname"))
    page.profileInput:SetPoint("BOTTOMLEFT", 20, 12)
    local switch = createButton(profileCard, L("PROFIL ÖFFNEN"), 150, 34, true)
    switch:SetPoint("LEFT", page.profileInput, "RIGHT", 10, 0)
    switch:SetScript("OnClick", function()
        local name = page.profileInput:GetText():match("^%s*(.-)%s*$")
        if name ~= "" then
            self.db:SetProfile(name)
            page.profileInput:SetText("")
            page.profileInput:ClearFocus()
        end
    end)
    page.profileInput:SetScript("OnEnterPressed", function() switch:Click() end)

    local safety = createSettingRow(page, -294, L("Cooldown-Simulation zurücksetzen"), L("Entfernt nur die lokalen Laufzeittimer; deine Fähigkeiten bleiben erhalten."))
    local resetSession = createButton(safety, L("TIMER RESET"), 130, 32, false)
    resetSession:SetPoint("RIGHT", -16, 0)
    resetSession:SetScript("OnClick", function() self:ResetSession() end)

    local resetSlots = createSettingRow(page, -364, L("Alle Klassen-Hotkeys löschen"), L("Entfernt nur deine hinterlegten Inputs; das feste 12.1-Prioritätspaket bleibt erhalten."))
    local resetPriorities = createButton(resetSlots, L("HOTKEYS RESET"), 160, 32, false)
    resetPriorities:SetPoint("RIGHT", -16, 0)
    resetPriorities:SetScript("OnClick", function() self:ResetSlots() end)

    local resetProfile = createSettingRow(page, -434, L("Komplettes Profil zurücksetzen"), L("Setzt Anzeige, Position und Prioritäten des aktiven Profils zurück."))
    local resetAll = createButton(resetProfile, L("PROFIL RESET"), 130, 32, false)
    resetAll:SetPoint("RIGHT", -16, 0)
    resetAll:SetScript("OnClick", function() self.db:ResetProfile() end)

    local reload = createButton(page, "RELOAD UI", 140, 38, true)
    reload:SetPoint("BOTTOMLEFT", 28, 28)
    reload:SetScript("OnClick", function()
        if C_UI and C_UI.Reload then C_UI.Reload() else ReloadUI() end
    end)
    return page
end

local function changelogText(entry)
    local lines = {}
    for _, change in ipairs(entry.changes or {}) do
        lines[#lines + 1] = "• " .. L(change)
    end
    return table.concat(lines, "\n")
end

function HeliHeal:BuildChangelogPage(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    setPageHeader(page, L("Update-Verlauf"), L("Alle wichtigen Änderungen bleiben lokal und jederzeit einsehbar."))

    local scroll = CreateFrame("ScrollFrame", nil, page, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 28, -108)
    scroll:SetPoint("BOTTOMRIGHT", -48, 22)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetWidth(700)
    scroll:SetScrollChild(content)

    local offset = 0
    for index, entry in ipairs(ns.changelog.entries) do
        local cardHeight = 78 + (#(entry.changes or {}) * 18)
        local card = CreateFrame("Frame", nil, content, "BackdropTemplate")
        card:SetPoint("TOPLEFT", 0, -offset)
        card:SetPoint("TOPRIGHT", 0, -offset)
        card:SetHeight(cardHeight)
        backdrop(card, index == 1 and C.panelHover or C.panel, index == 1 and C.accentDark or C.borderSoft)

        local version = text(card, "v" .. entry.version, 13, index == 1 and C.accent or C.text, "OUTLINE")
        version:SetPoint("TOPLEFT", 18, -15)
        local titleLabel = text(card, L(entry.title), 10, C.muted)
        titleLabel:SetPoint("LEFT", version, "RIGHT", 12, 0)
        local body = text(card, changelogText(entry), 10, C.text)
        body:SetPoint("TOPLEFT", version, "BOTTOMLEFT", 0, -12)
        body:SetPoint("RIGHT", -18, 0)
        body:SetJustifyH("LEFT")
        body:SetJustifyV("TOP")

        offset = offset + cardHeight + 10
    end
    content:SetHeight(math.max(1, offset))
    page.scroll = scroll
    return page
end

function HeliHeal:HideWhatsNewModal(markSeen)
    local modal = self.optionsWindow and self.optionsWindow.whatsNewModal
    if not modal then return end
    if markSeen and modal.version then self:MarkChangelogSeen(modal.version) end
    modal:Hide()
end

function HeliHeal:ShowWhatsNewModal()
    local window = self.optionsWindow
    if not window then return end
    local version = self:GetAddonVersion()
    local entry = ns.changelog:GetEntry(version) or ns.changelog.entries[1]
    if not entry then return end

    local modal = window.whatsNewModal
    if not modal then
        modal = CreateFrame("Frame", nil, window, "BackdropTemplate")
        modal:SetAllPoints()
        modal:SetFrameLevel(window:GetFrameLevel() + 40)
        modal:EnableMouse(true)
        backdrop(modal, { 0, 0, 0, 0.78 }, { 0, 0, 0, 0 })

        local card = CreateFrame("Frame", nil, modal, "BackdropTemplate")
        card:SetSize(610, 390)
        card:SetPoint("CENTER")
        backdrop(card, C.bg, C.accentDark, 2)
        modal.card = card

        local caption = text(card, L("NEU IN HELIHEAL"), 10, C.accent, "OUTLINE")
        caption:SetPoint("TOPLEFT", 28, -26)
        card.versionLabel = text(card, "", 25, C.text, "OUTLINE")
        card.versionLabel:SetPoint("TOPLEFT", caption, "BOTTOMLEFT", 0, -10)
        card.titleLabel = text(card, "", 11, C.muted)
        card.titleLabel:SetPoint("TOPLEFT", card.versionLabel, "BOTTOMLEFT", 1, -8)

        local line = card:CreateTexture(nil, "ARTWORK")
        line:SetTexture(WHITE)
        line:SetColorTexture(unpackColor(C.accent))
        line:SetPoint("TOPLEFT", 28, -113)
        line:SetPoint("TOPRIGHT", -28, -113)
        line:SetHeight(2)

        card.body = text(card, "", 12, C.text)
        card.body:SetPoint("TOPLEFT", 30, -140)
        card.body:SetPoint("TOPRIGHT", -30, -140)
        card.body:SetJustifyH("LEFT")
        card.body:SetJustifyV("TOP")

        local history = createButton(card, L("UPDATE-VERLAUF"), 180, 36, false)
        history:SetPoint("BOTTOMLEFT", 28, 24)
        history:SetScript("OnClick", function()
            HeliHeal:HideWhatsNewModal(true)
            HeliHeal:SelectOptionsPage("changelog")
        end)
        local done = createButton(card, L("VERSTANDEN"), 150, 36, true)
        done:SetPoint("BOTTOMRIGHT", -28, 24)
        done:SetScript("OnClick", function() HeliHeal:HideWhatsNewModal(true) end)

        local close = createButton(card, "×", 32, 32, false)
        close:SetPoint("TOPRIGHT", -16, -16)
        close.label:SetFont(FONT, 20, "OUTLINE")
        close:SetScript("OnClick", function() HeliHeal:HideWhatsNewModal(true) end)
        window.whatsNewModal = modal
    end

    modal.version = entry.version
    modal.card.versionLabel:SetText("v" .. entry.version)
    modal.card.titleLabel:SetText(L(entry.title))
    modal.card.body:SetText(changelogText(entry))
    modal:Show()
end

function HeliHeal:CreateModernOptions()
    local window = CreateFrame("Frame", "HeliHealOptionsWindow", UIParent, "BackdropTemplate")
    window:SetSize(1040, 700)
    window:SetPoint("CENTER")
    window:SetFrameStrata("DIALOG")
    window:SetClampedToScreen(true)
    window:SetMovable(true)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    backdrop(window, C.bg, C.border)
    window:Hide()
    table.insert(UISpecialFrames, window:GetName())

    window:SetScript("OnDragStart", function(self) self:StartMoving() end)
    window:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    window:SetScript("OnHide", function()
        HeliHeal:EndKeyCapture()
        HeliHeal:HideWhatsNewModal(true)
    end)

    local accentTop = window:CreateTexture(nil, "ARTWORK")
    accentTop:SetTexture(WHITE)
    accentTop:SetColorTexture(unpackColor(C.accent))
    accentTop:SetPoint("TOPLEFT", 1, -1)
    accentTop:SetPoint("TOPRIGHT", -1, -1)
    accentTop:SetHeight(2)

    local sidebar = CreateFrame("Frame", nil, window, "BackdropTemplate")
    sidebar:SetPoint("TOPLEFT", 1, -3)
    sidebar:SetPoint("BOTTOMLEFT", 1, 1)
    sidebar:SetWidth(244)
    backdrop(sidebar, C.sidebar, C.borderSoft)

    local logo = CreateFrame("Frame", nil, sidebar, "BackdropTemplate")
    logo:SetSize(52, 52)
    logo:SetPoint("TOPLEFT", 24, -24)
    backdrop(logo, C.accentDark, C.accent, 2)
    local logoText = text(logo, "H", 30, C.accent, "OUTLINE")
    logoText:SetPoint("CENTER", 0, 1)
    local brand = text(sidebar, "HeliHeal", 22, C.text, "OUTLINE")
    brand:SetPoint("LEFT", logo, "RIGHT", 13, 5)
    local version = text(sidebar, "MIDNIGHT  •  v" .. self:GetAddonVersion(), 9, C.muted, "OUTLINE")
    version:SetPoint("TOPLEFT", brand, "BOTTOMLEFT", 1, -7)

    local separator = sidebar:CreateTexture(nil, "ARTWORK")
    separator:SetTexture(WHITE)
    separator:SetColorTexture(unpackColor(C.borderSoft))
    separator:SetPoint("TOPLEFT", 18, -96)
    separator:SetPoint("TOPRIGHT", -18, -96)
    separator:SetHeight(1)

    local section = text(sidebar, L("KONFIGURATION"), 9, C.accent, "OUTLINE")
    section:SetPoint("TOPLEFT", 22, -122)

    window.pagesHost = CreateFrame("Frame", nil, window)
    window.pagesHost:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 0, 0)
    window.pagesHost:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -1, 58)

    window.pages = {
        overview = self:BuildOverviewPage(window.pagesHost),
        style = self:BuildStylePage(window.pagesHost),
        priorities = self:BuildPrioritiesPage(window.pagesHost),
        profiles = self:BuildProfilesPage(window.pagesHost),
        changelog = self:BuildChangelogPage(window.pagesHost),
    }

    window.navButtons = {}
    local navigation = {
        { "overview", L("ÜBERSICHT"), L("Anzeige & Verhalten") },
        { "style", L("HUD-ELEMENTE"), L("Icon, Hotkey & Cooldown") },
        { "priorities", L("PRIORITÄTEN"), L("Fähigkeiten & Inputs") },
        { "profiles", L("PROFILE & RESET"), L("Konfiguration verwalten") },
        { "changelog", L("UPDATE-VERLAUF"), L("Was ist neu?") },
    }
    for index, item in ipairs(navigation) do
        local nav = CreateFrame("Button", nil, sidebar, "BackdropTemplate")
        nav:SetPoint("TOPLEFT", 14, -144 - ((index - 1) * 66))
        nav:SetPoint("TOPRIGHT", -14, -144 - ((index - 1) * 66))
        nav:SetHeight(56)
        backdrop(nav, C.sidebar, C.sidebar)
        nav.indicator = nav:CreateTexture(nil, "ARTWORK")
        nav.indicator:SetTexture(WHITE)
        nav.indicator:SetColorTexture(unpackColor(C.accent))
        nav.indicator:SetPoint("TOPLEFT", 0, -5)
        nav.indicator:SetPoint("BOTTOMLEFT", 0, 5)
        nav.indicator:SetWidth(3)
        nav.title = text(nav, item[2], 11, C.muted, "OUTLINE")
        nav.title:SetPoint("TOPLEFT", 16, -11)
        nav.subtitle = text(nav, item[3], 9, C.dim)
        nav.subtitle:SetPoint("TOPLEFT", nav.title, "BOTTOMLEFT", 0, -6)
        nav:SetScript("OnClick", function() self:SelectOptionsPage(item[1]) end)
        nav:SetScript("OnEnter", function(button)
            if self.selectedOptionsPage ~= item[1] then
                button:SetBackdropColor(unpackColor(C.panel))
                button.title:SetTextColor(unpackColor(C.text))
            end
        end)
        nav:SetScript("OnLeave", function(button)
            if self.selectedOptionsPage ~= item[1] then
                button:SetBackdropColor(unpackColor(C.sidebar))
                button.title:SetTextColor(unpackColor(C.muted))
            end
        end)
        window.navButtons[item[1]] = nav
    end

    local statusDot = sidebar:CreateTexture(nil, "ARTWORK")
    statusDot:SetTexture(WHITE)
    statusDot:SetColorTexture(unpackColor(C.accent))
    statusDot:SetSize(7, 7)
    statusDot:SetPoint("BOTTOMLEFT", 22, 48)
    local status = text(sidebar, L("SECURE INPUT TRACKER"), 9, C.muted, "OUTLINE")
    status:SetPoint("LEFT", statusDot, "RIGHT", 8, 0)
    local privacy = text(sidebar, L("NO COMBAT DATA"), 9, C.dim)
    privacy:SetPoint("TOPLEFT", status, "BOTTOMLEFT", 0, -7)

    local bottom = CreateFrame("Frame", nil, window, "BackdropTemplate")
    bottom:SetPoint("BOTTOMLEFT", sidebar, "BOTTOMRIGHT", 0, 1)
    bottom:SetPoint("BOTTOMRIGHT", -1, 1)
    bottom:SetHeight(57)
    backdrop(bottom, C.sidebar, C.borderSoft)
    local help = text(bottom, L("/hh öffnet dieses Fenster  •  ESC schließt es"), 10, C.muted)
    help:SetPoint("LEFT", 22, 0)
    local close = createButton(bottom, L("SCHLIESSEN"), 150, 36, true)
    close:SetPoint("RIGHT", -18, 0)
    close:SetScript("OnClick", function() window:Hide() end)

    local x = createButton(window, "×", 36, 36, false)
    x:SetPoint("TOPRIGHT", -14, -14)
    x.label:SetFont(FONT, 22, "OUTLINE")
    x:SetFrameLevel(window:GetFrameLevel() + 20)
    x:SetScript("OnClick", function() window:Hide() end)

    self.optionsWindow = window
    self:SelectOptionsPage("overview")
end

function HeliHeal:SelectOptionsPage(pageKey)
    if not self.optionsWindow then return end
    self.selectedOptionsPage = pageKey
    for key, page in pairs(self.optionsWindow.pages) do
        page:SetShown(key == pageKey)
        local nav = self.optionsWindow.navButtons[key]
        local active = key == pageKey
        nav.indicator:SetShown(active)
        nav:SetBackdropColor(unpackColor(active and C.panel or C.sidebar))
        nav:SetBackdropBorderColor(unpackColor(active and C.borderSoft or C.sidebar))
        nav.title:SetTextColor(unpackColor(active and C.text or C.muted))
        nav.subtitle:SetTextColor(unpackColor(active and C.accent or C.dim))
    end
    self:RefreshOptionsUI()
end

function HeliHeal:RefreshOptionsUI()
    local window = self.optionsWindow
    if not window then return end

    local overview = window.pages.overview
    for _, control in ipairs(overview.refreshers or {}) do
        control:Refresh()
    end
    for mode, button in pairs(overview.languageButtons or {}) do
        local active = mode == self:GetLanguageMode()
        button:SetBackdropBorderColor(unpackColor(active and C.accent or C.border))
        button.label:SetTextColor(unpackColor(active and C.accent or C.muted))
    end
    for _, control in ipairs(window.pages.style.refreshers or {}) do
        control:Refresh()
    end

    local prioritiesPage = window.pages.priorities
    for presetKey, button in pairs(prioritiesPage.presetButtons or {}) do
        local active = presetKey == self.db.profile.rotationPreset
        button:SetBackdropBorderColor(unpackColor(active and C.accent or C.border))
        button.label:SetTextColor(unpackColor(active and C.accent or C.muted))
    end

    for modeKey, button in pairs(prioritiesPage.modeButtons or {}) do
        local active = modeKey == self:GetHealingMode()
        button:SetBackdropBorderColor(unpackColor(active and C.accent or C.border))
        button.label:SetTextColor(unpackColor(active and C.accent or C.muted))
    end


    local conflictsByAbility = {}
    for _, conflict in ipairs(self:GetBindingConflicts()) do
        for abilityKey in pairs(conflict.abilityKeys) do conflictsByAbility[abilityKey] = conflict end
    end

    local visiblePriority = 0
    for slotIndex, row in ipairs(prioritiesPage.slotRows or {}) do
        local slot = self.db.profile.slots[slotIndex]
        if slot then
            local ability = ns.AbilityLibrary:Resolve(slot)
            ability = self:GetSlot(slotIndex) or ability
            if ability.enabled then
                visiblePriority = visiblePriority + 1
                local y = -214 - ((visiblePriority - 1) * 37)
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", 28, y)
                row:SetPoint("TOPRIGHT", -28, y)
                row.priority:SetText(("%02d"):format(visiblePriority))
            end
            row.icon:SetTexture(ability.icon)
            row.icon:SetDesaturated(false)
            row.abilityName:SetText(ability.name)
            if ability.trackedDuration > 0 then
                local goal = self:GetTrackedGoal(ability)
                row.cooldownLabel:SetText(L("Lokale Laufzeit: %ss • Ziel: %d", ability.trackedDuration, goal))
            else
                row.cooldownLabel:SetText(ability.cooldown > 0 and L("Lokaler CD: %ss", formatSeconds(ability.cooldown)) or L("Filler • kein lokaler CD"))
            end
            local conflict = conflictsByAbility[slot.abilityKey]
            if conflict then
                row.cooldownLabel:SetText(row.cooldownLabel:GetText() .. " • " .. L("HOTKEY DOPPELT"))
                row.cooldownLabel:SetTextColor(unpackColor(C.danger))
                row:SetBackdropBorderColor(unpackColor(C.danger))
            else
                row.cooldownLabel:SetTextColor(unpackColor(C.muted))
                row:SetBackdropBorderColor(unpackColor(C.borderSoft))
            end
            if slot.derivedBindingFrom then
                row.key.label:SetText(L("WIE HEALING RAIN"))
                row.key:SetScript("OnClick", nil)
                row.key:SetBackdropBorderColor(unpackColor(C.borderSoft))
                row.key.label:SetTextColor(unpackColor(C.muted))
            else
                local keyLabel = slot.inputKey and slot.inputKey ~= "" and slot.inputKey or L("HOTKEY HINTERLEGEN")
                row.key.label:SetText(conflict and (keyLabel .. " • " .. L("DOPPELT")) or keyLabel)
                row.key:SetScript("OnClick", row.key.captureOnClick)
                row.key:SetBackdropBorderColor(unpackColor(conflict and C.danger or C.border))
                row.key.label:SetTextColor(unpackColor(conflict and C.danger or C.muted))
            end
            row:SetShown(ability.enabled)
        else
            row:Hide()
        end
    end

    window.pages.profiles.profileName:SetText(self.db:GetCurrentProfile())
end

function HeliHeal:SetupOptions()
    self:CreateModernOptions()
end

function HeliHeal:ShowOptions(suppressWhatsNew)
    if not self.optionsWindow then
        self:CreateModernOptions()
    end
    self.optionsWindow:Show()
    self.optionsWindow:Raise()
    self:RefreshOptionsUI()
    if not suppressWhatsNew and self:ShouldShowWhatsNew() then
        self:ShowWhatsNewModal()
    end
end

function HeliHeal:ShowChangelogHistory()
    self:ShowOptions(true)
    self:SelectOptionsPage("changelog")
    self:MarkChangelogSeen()
end
