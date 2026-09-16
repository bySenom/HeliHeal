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
local KEY_CLEAR_HOLD_SECONDS = 1.5
local MODIFIER_KEYS = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true }
local THEMED_OBJECTS = setmetatable({}, { __mode = "k" })

local function unpackColor(color)
    return color[1], color[2], color[3], color[4]
end

local function paletteRole(color)
    for role, palette in pairs(C) do
        if color == palette then return role end
    end
end

local function rememberTheme(object, property, color, alpha)
    local role = paletteRole(color)
    if not role then return end
    local state = THEMED_OBJECTS[object] or {}
    state[property] = role
    if property == "texture" then state.textureAlpha = alpha end
    THEMED_OBJECTS[object] = state
end

local function themeTexture(texture, color, alpha)
    rememberTheme(texture, "texture", color, alpha)
    texture:SetColorTexture(color[1], color[2], color[3], alpha or color[4])
end

local function backdrop(frame, background, border, edgeSize)
    background = background or C.panel
    border = border or C.border
    rememberTheme(frame, "background", background)
    rememberTheme(frame, "border", border)
    frame:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = edgeSize or 1 })
    frame:SetBackdropColor(unpackColor(background))
    frame:SetBackdropBorderColor(unpackColor(border))
end

local function text(parent, value, size, color, flags)
    local label = parent:CreateFontString(nil, "OVERLAY")
    color = color or C.text
    rememberTheme(label, "text", color)
    label:SetFont(FONT, size or 12, flags or "")
    label:SetText(value or "")
    label:SetTextColor(unpackColor(color))
    label:SetJustifyH("LEFT")
    return label
end

local function createButton(parent, labelText, width, height, primary)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(width or 130, height or 34)
    button.primary = primary == true
    button.selected = false
    backdrop(button, button.primary and C.accentDark or C.input, button.primary and C.accent or C.border)
    button.label = text(button, labelText, 11, button.primary and C.text or C.muted, "OUTLINE")
    button.label:SetPoint("CENTER")

    function button:RefreshVisualState(hovered)
        local active = self.primary or self.selected
        self:SetBackdropColor(unpackColor(active and C.accentDark
            or (hovered and C.panelHover or C.input)))
        self:SetBackdropBorderColor(unpackColor((active or hovered) and C.accent or C.border))
        self.label:SetTextColor(unpackColor((active or hovered) and C.text or C.muted))
    end

    function button:SetSelected(selected)
        self.selected = selected == true
        self:RefreshVisualState(self:IsMouseOver())
    end

    button:SetScript("OnEnter", function(self)
        self:RefreshVisualState(true)
    end)
    button:SetScript("OnLeave", function(self)
        self:RefreshVisualState(false)
    end)
    button:RefreshVisualState(false)
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
    themeTexture(slider.fill, C.accent)
    slider.fill:SetPoint("LEFT", slider.track, "LEFT")
    slider.fill:SetHeight(4)

    slider:SetThumbTexture(WHITE)
    local thumb = slider:GetThumbTexture()
    thumb:SetSize(12, 18)
    themeTexture(thumb, C.accent)

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
    menu:SetSize(230, 40)
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

    function selector:SetValues(newValues)
        values = newValues or {}
        menu:SetHeight(math.max(40, (#values * 32) + 8))
        for index, option in ipairs(values) do
            local optionButton = menu.options[index]
            if not optionButton then
                optionButton = CreateFrame("Button", nil, menu, "BackdropTemplate")
                optionButton:SetHeight(30)
                backdrop(optionButton, C.input, C.input)
                optionButton.label = text(optionButton, "", 11, C.text, "OUTLINE")
                optionButton.label:SetPoint("LEFT", 10, 0)
                optionButton:SetScript("OnClick", function(self)
                    setValue(self.option.value)
                    selector:Refresh()
                    closeMenu()
                end)
                optionButton:SetScript("OnEnter", function(self)
                    self:SetBackdropColor(unpackColor(C.panelHover))
                    self.label:SetTextColor(unpackColor(C.text))
                end)
                optionButton:SetScript("OnLeave", function()
                    selector:RefreshMenu()
                end)
                menu.options[index] = optionButton
            end
            optionButton.option = option
            optionButton:ClearAllPoints()
            optionButton:SetPoint("TOPLEFT", 4, -4 - ((index - 1) * 32))
            optionButton:SetPoint("TOPRIGHT", -4, -4 - ((index - 1) * 32))
            optionButton.label:SetText(option.label)
            optionButton.label:SetFont(option.font or FONT, 11, option.flags or "OUTLINE")
            optionButton:Show()
        end
        for index = #values + 1, #menu.options do
            menu.options[index]:Hide()
        end
        self:SetEnabled(#values > 0)
        self:SetAlpha(#values > 0 and 1 or 0.45)
        self.arrow:SetShown(#values > 0)
        self:Refresh()
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
        local fallback = values[1]
        self.label:SetText(fallback and fallback.label or L("KEINE PROFILE"))
        self.label:SetFont(fallback and fallback.font or FONT, 11, fallback and fallback.flags or "OUTLINE")
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
    selector:SetScript("OnSizeChanged", function(_, width) menu:SetWidth(width) end)
    selector:SetScript("OnHide", closeMenu)
    selector:SetValues(values)
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
    themeTexture(line, C.accent)
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

local function validThemeColor(value, fallback)
    if type(value) ~= "table" then value = fallback end
    local red = math.max(0, math.min(1, tonumber(value and (value.r or value[1])) or fallback[1]))
    local green = math.max(0, math.min(1, tonumber(value and (value.g or value[2])) or fallback[2]))
    local blue = math.max(0, math.min(1, tonumber(value and (value.b or value[3])) or fallback[3]))
    return red, green, blue
end

local function currentClassColor()
    if type(UnitClass) ~= "function" then return nil end
    local ok, _, classToken = pcall(UnitClass, "player")
    if not ok or not classToken then return nil end
    local palette = (CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[classToken])
        or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken])
    if not palette then return nil end
    return validThemeColor(palette, C.accent)
end

function HeliHeal:ResolveOptionsWindowTheme()
    local global = self.db and self.db.global or {}
    local defaults = ns.defaults.global
    local background = global.optionsWindowBackgroundColor or defaults.optionsWindowBackgroundColor
    local accent = global.optionsWindowAccentColor or defaults.optionsWindowAccentColor
    local backgroundR, backgroundG, backgroundB = validThemeColor(background, defaults.optionsWindowBackgroundColor)
    local accentR, accentG, accentB = validThemeColor(accent, defaults.optionsWindowAccentColor)
    if global.optionsWindowUseClassColor then
        local classR, classG, classB = currentClassColor()
        if classR then accentR, accentG, accentB = classR, classG, classB end
    end
    C.bg[1], C.bg[2], C.bg[3], C.bg[4] = backgroundR, backgroundG, backgroundB, 0.98
    C.accent[1], C.accent[2], C.accent[3], C.accent[4] = accentR, accentG, accentB, 1
    C.accentDark[1], C.accentDark[2], C.accentDark[3], C.accentDark[4] =
        accentR * 0.4, accentG * 0.4, accentB * 0.4, 1
end

function HeliHeal:ApplyOptionsWindowTheme()
    self:ResolveOptionsWindowTheme()
    for object, state in pairs(THEMED_OBJECTS) do
        if state.background and object.SetBackdropColor then
            object:SetBackdropColor(unpackColor(C[state.background]))
        end
        if state.border and object.SetBackdropBorderColor then
            object:SetBackdropBorderColor(unpackColor(C[state.border]))
        end
        if state.text and object.SetTextColor then
            object:SetTextColor(unpackColor(C[state.text]))
        end
        if state.texture and object.SetColorTexture then
            local color = C[state.texture]
            object:SetColorTexture(color[1], color[2], color[3], state.textureAlpha or color[4])
        end
    end
    if self.optionsWindow then self:RefreshOptionsUI() end
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

function HeliHeal:CancelKeyClearHold(button, restorePrompt)
    if not button then return end
    button.clearHoldElapsed = nil
    button:SetScript("OnUpdate", nil)
    if button.clearHoldProgress then
        button.clearHoldProgress:SetWidth(1)
        button.clearHoldProgress:Hide()
    end
    if restorePrompt and self.keyCaptureButton == button then
        button.label:SetText(L("TASTE DRÜCKEN • ESC HALTEN"))
    end
end

function HeliHeal:SetOptionsEscapeCloseEnabled(enabled)
    local window = self.optionsWindow
    local windowName = window and window:GetName()
    if not windowName or not UISpecialFrames then return end

    for index = #UISpecialFrames, 1, -1 do
        if UISpecialFrames[index] == windowName then
            table.remove(UISpecialFrames, index)
        end
    end
    if enabled then
        table.insert(UISpecialFrames, windowName)
    end
end

function HeliHeal:StartKeyClearHold(button, slotIndex)
    if not button or button.clearHoldElapsed then return end
    button.clearHoldElapsed = 0
    button.label:SetText(L("ESC HALTEN ZUM LÖSCHEN"))
    if button.clearHoldProgress then
        button.clearHoldProgress:SetWidth(1)
        button.clearHoldProgress:Show()
    end
    button:SetScript("OnUpdate", function(capture, elapsed)
        if HeliHeal.keyCaptureButton ~= capture then
            HeliHeal:CancelKeyClearHold(capture, false)
            return
        end
        capture.clearHoldElapsed = (capture.clearHoldElapsed or 0) + elapsed
        local progress = math.min(1, capture.clearHoldElapsed / KEY_CLEAR_HOLD_SECONDS)
        if capture.clearHoldProgress then
            capture.clearHoldProgress:SetWidth(math.max(1, (capture:GetWidth() - 2) * progress))
        end
        if progress >= 1 then
            HeliHeal:SetAbilityBinding(slotIndex, "")
            HeliHeal:EndKeyCapture()
        end
    end)
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
    self:SetOptionsEscapeCloseEnabled(false)
    button.label:SetText(L("TASTE DRÜCKEN • ESC HALTEN"))
    button:SetBackdropBorderColor(unpackColor(C.accent))
    button:SetScript("OnClick", nil)
    button:EnableKeyboard(true)
    button:SetPropagateKeyboardInput(false)
    button:EnableMouseWheel(true)

    local function commit(input, suppressCaptureClick)
        if not input then return end
        HeliHeal:SetAbilityBinding(slotIndex, input)
        HeliHeal:EndKeyCapture(suppressCaptureClick)
    end

    button:SetScript("OnKeyDown", function(capture, key)
        capture:SetPropagateKeyboardInput(false)
        if key == "ESCAPE" then
            HeliHeal:StartKeyClearHold(capture, slotIndex)
            return
        end
        commit(normalizeCapturedKey(key))
    end)
    button:SetScript("OnKeyUp", function(capture, key)
        capture:SetPropagateKeyboardInput(false)
        if key == "ESCAPE" then
            HeliHeal:CancelKeyClearHold(capture, true)
        end
    end)
    button:SetScript("OnMouseDown", function(_, mouseButton)
        commit(normalizeCapturedMouse(mouseButton), mouseButton == "LeftButton")
    end)
    button:SetScript("OnMouseWheel", function(_, delta)
        commit(withModifiers(delta > 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN"))
    end)
end

function HeliHeal:HandleKeyCaptureClick(button, slotIndex)
    if button.ignoreNextCaptureClick then
        button.ignoreNextCaptureClick = nil
        return
    end
    self:BeginKeyCapture(button, slotIndex)
end

function HeliHeal:EndKeyCapture(suppressCaptureClick)
    local button = self.keyCaptureButton
    if button then
        self:CancelKeyClearHold(button, false)
        button:EnableKeyboard(false)
        button:EnableMouseWheel(false)
        button:SetScript("OnKeyDown", nil)
        button:SetScript("OnKeyUp", nil)
        button:SetScript("OnMouseDown", nil)
        button:SetScript("OnMouseWheel", nil)
        -- BUTTON1 is captured on OnMouseDown, followed by OnClick for the same
        -- physical press. Consume exactly that click before capture can reopen.
        button.ignoreNextCaptureClick = suppressCaptureClick and true or nil
        button:SetScript("OnClick", button.captureOnClick)
        button:SetBackdropBorderColor(unpackColor(C.border))
    end
    self.keyCaptureButton = nil
    self.suspendInput = false
    self:SetOptionsEscapeCloseEnabled(true)
    self:RefreshOptionsUI()
end

function HeliHeal:BuildPrioritiesPage(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    local className = self.classToken == "DRUID" and "Restoration Druid 12.1"
        or (self.classToken == "PALADIN" and "Holy Paladin 12.1"
        or (self.classToken == "PRIEST" and (self.specializationID == 256
            and "Discipline Priest 12.1" or "Holy Priest 12.1")
        or (self.classToken == "MONK" and "Mistweaver Monk 12.1"
        or "Restoration Shaman 12.1")))
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
    } or self.classToken == "PRIEST" and self.specializationID == 256 and {
        { "disc_oracle_mythicplus", "ORACLE M+" },
        { "disc_oracle_raid", "ORACLE RAID" },
        { "disc_voidweaver_mythicplus", "VOIDWEAVER M+" },
        { "disc_voidweaver_raid", "VOIDWEAVER RAID" },
    } or self.classToken == "PRIEST" and {
        { "priest_archon_mythicplus", "ARCHON M+" },
        { "priest_archon_raid", "ARCHON RAID" },
        { "priest_oracle_mythicplus", "ORACLE M+" },
        { "priest_oracle_raid", "ORACLE RAID" },
    } or self.classToken == "MONK" and {
        { "monk_conduit_mythicplus", "CONDUIT M+" },
        { "monk_conduit_raid", "CONDUIT RAID" },
        { "monk_harmony_mythicplus", "HARMONY M+" },
        { "monk_harmony_raid", "HARMONY RAID" },
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
        button.presetLabel = presetLabel
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

    local settingsOffset = 110
    local assignmentRow = createSettingRow(page, -190,
        L("Automatische Rotationszuordnung"),
        L("Weise gespeicherte Blizzard-Talent-Builds direkt einem Preset und Modus zu."))
    assignmentRow:SetHeight(100)
    assignmentRow.title:ClearAllPoints()
    assignmentRow.title:SetPoint("TOPLEFT", 14, -10)
    assignmentRow.description:ClearAllPoints()
    assignmentRow.description:SetPoint("TOPLEFT", 14, -29)

    assignmentRow.buildCaption = text(assignmentRow, L("TALENT-BUILD"), 8, C.muted, "OUTLINE")
    assignmentRow.buildCaption:SetPoint("TOPLEFT", 14, -47)
    assignmentRow.presetCaption = text(assignmentRow, L("ROTATION"), 8, C.muted, "OUTLINE")
    assignmentRow.presetCaption:SetPoint("TOPLEFT", 212, -47)
    assignmentRow.modeCaption = text(assignmentRow, L("MODUS"), 8, C.muted, "OUTLINE")
    assignmentRow.modeCaption:SetPoint("TOPLEFT", 400, -47)

    assignmentRow.buildSelector = createDropdownSelector(assignmentRow, page, {},
        function() return page.assignmentConfigID end,
        function(value)
            page.assignmentConfigID = value
            page.loadedAssignmentConfigID = nil
            self:RefreshOptionsUI()
        end)
    assignmentRow.buildSelector:SetSize(190, 30)
    assignmentRow.buildSelector:SetPoint("TOPLEFT", 14, -61)

    local presetOptions = {}
    for _, preset in ipairs(presets) do
        presetOptions[#presetOptions + 1] = { value = preset[1], label = preset[2] }
    end
    assignmentRow.presetSelector = createDropdownSelector(assignmentRow, page, presetOptions,
        function() return page.assignmentPreset end,
        function(value) page.assignmentPreset = value end)
    assignmentRow.presetSelector:SetSize(180, 30)
    assignmentRow.presetSelector:SetPoint("TOPLEFT", 212, -61)

    local modeOptions = {}
    for _, mode in ipairs(modes) do
        modeOptions[#modeOptions + 1] = { value = mode[1], label = mode[2] }
    end
    assignmentRow.modeSelector = createDropdownSelector(assignmentRow, page, modeOptions,
        function() return page.assignmentMode end,
        function(value) page.assignmentMode = value end)
    assignmentRow.modeSelector:SetSize(116, 30)
    assignmentRow.modeSelector:SetPoint("TOPLEFT", 400, -61)

    assignmentRow.assignButton = createButton(assignmentRow, L("ZUWEISEN"), 82, 30, false)
    assignmentRow.assignButton:SetPoint("TOPLEFT", 524, -61)
    assignmentRow.assignButton:SetScript("OnClick", function()
        self:SetTalentBuildBinding(page.assignmentConfigID, page.assignmentPreset, page.assignmentMode)
    end)
    assignmentRow.removeButton = createButton(assignmentRow, L("LÖSCHEN"), 86, 30, false)
    assignmentRow.removeButton:SetPoint("TOPLEFT", 614, -61)
    assignmentRow.removeButton:SetScript("OnClick", function()
        self:UnlinkTalentBuild(page.assignmentConfigID)
    end)
    page.assignmentRow = assignmentRow

    if self.classToken == "SHAMAN" and self.specializationID == 264 then
        local manaRow = createSettingRow(page, -300,
            L("Automatischer Mana-Sparmodus"),
            L("Nutzt die gespeicherte lokale Mana-Schätzung; eine manuelle Kalibrierung ist nur optional."))
        manaRow.betaBadge = CreateFrame("Frame", nil, manaRow, "BackdropTemplate")
        manaRow.betaBadge:SetSize(38, 16)
        manaRow.betaBadge:SetPoint("LEFT", manaRow.title, "RIGHT", 8, 0)
        backdrop(manaRow.betaBadge, C.accentDark, C.accent)
        manaRow.betaBadge.label = text(manaRow.betaBadge, "BETA", 8, C.text, "OUTLINE")
        manaRow.betaBadge.label:SetPoint("CENTER", 0, 0)
        local threshold = createSlider(manaRow, 20, 30, 1,
            function() return self.db.profile.autoManaThreshold or 25 end,
            function(value) self.db.profile.autoManaThreshold = math.floor(value + 0.5) end,
            function(value) return ("%d%%"):format(math.floor(value + 0.5)) end)
        threshold:SetPoint("RIGHT", -150, 0)
        local autoToggle = createToggle(manaRow,
            function() return self.db.profile.autoManaMode == true end,
            function(value)
                self.db.profile.autoManaMode = value
                if self.Mana then self.Mana:SetAutoModeEnabled(value) end
            end)
        autoToggle:SetPoint("RIGHT", -20, 0)
        page.manaAutoToggle = autoToggle
        page.manaThresholdSlider = threshold
        settingsOffset = settingsOffset + 72
    end

    local priorityHeader = text(page, "PRIO", 9, C.muted, "OUTLINE")
    priorityHeader:SetPoint("TOPLEFT", 34, -198 - settingsOffset)
    local abilityHeader = text(page, L("FESTE GUIDE-FÄHIGKEIT"), 9, C.muted, "OUTLINE")
    abilityHeader:SetPoint("TOPLEFT", 126, -198 - settingsOffset)
    local bindingHeader = text(page, L("BEOBACHTETER ACTIONBAR-HOTKEY"), 9, C.muted, "OUTLINE")
    bindingHeader:SetPoint("TOPLEFT", 494, -198 - settingsOffset)

    local priorityScroll = CreateFrame("ScrollFrame", nil, page, "UIPanelScrollFrameTemplate")
    priorityScroll:SetPoint("TOPLEFT", 18, -210 - settingsOffset)
    priorityScroll:SetPoint("BOTTOMRIGHT", -30, 46)
    local priorityContent = CreateFrame("Frame", nil, priorityScroll)
    priorityContent:SetWidth(1)
    priorityContent:SetHeight(1)
    priorityScroll:SetScrollChild(priorityContent)
    priorityScroll:SetScript("OnSizeChanged", function(_, width)
        priorityContent:SetWidth(math.max(1, width))
    end)
    page.priorityScroll = priorityScroll
    page.priorityContent = priorityContent

    page.slotRows = {}
    for slotIndex = 1, math.max(11, #(self.db.profile.slots or {})) do
        local capturedSlotIndex = slotIndex
        local row = CreateFrame("Frame", nil, priorityContent, "BackdropTemplate")
        row:SetPoint("TOPLEFT", 10, -4 - ((slotIndex - 1) * 37))
        row:SetPoint("TOPRIGHT", -10, -4 - ((slotIndex - 1) * 37))
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
        row.key.clearHoldProgress = row.key:CreateTexture(nil, "ARTWORK")
        row.key.clearHoldProgress:SetTexture(WHITE)
        themeTexture(row.key.clearHoldProgress, C.accent, 0.3)
        row.key.clearHoldProgress:SetPoint("TOPLEFT", 1, -1)
        row.key.clearHoldProgress:SetPoint("BOTTOMLEFT", 1, 1)
        row.key.clearHoldProgress:SetWidth(1)
        row.key.clearHoldProgress:Hide()
        row.key.captureOnClick = function(button) self:HandleKeyCaptureClick(button, capturedSlotIndex) end
        row.key:SetScript("OnClick", row.key.captureOnClick)
        page.slotRows[slotIndex] = row
    end

    local clearBindingHint = text(page,
        L("Hotkey-Feld anklicken und ESC 1,5 Sekunden halten, um die Belegung zu entfernen."),
        10, C.muted)
    clearBindingHint:SetPoint("BOTTOMLEFT", 28, 20)

    return page
end

function HeliHeal:BuildStylePage(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    setPageHeader(page, L("HUD-Elemente"), L("Reduziere die Anzeige auf das Wesentliche oder aktiviere einzelne Details."))

    page.categoryButtons = {}
    for index, category in ipairs({
        { "visibility", L("SICHTBARKEIT") },
        { "icons", L("ICONS & LAYOUT") },
        { "hotkey", L("HOTKEY") },
        { "text", L("TEXT") },
        { "colors", L("FARBEN") },
        { "support", L("DEF WINDOW") },
    }) do
        local categoryKey = category[1]
        local tab = createButton(page, category[2], 112, 32, false)
        tab:SetPoint("TOPLEFT", 20 + ((index - 1) * 120), -104)
        tab:SetScript("OnClick", function() page:SelectCategory(categoryKey) end)
        tab:SetScript("OnEnter", function(button)
            button:SetBackdropBorderColor(unpackColor(C.accent))
            button.label:SetTextColor(unpackColor(C.text))
        end)
        tab:SetScript("OnLeave", function(button)
            local active = HeliHeal.selectedStyleCategory == categoryKey
            button:SetBackdropColor(unpackColor(active and C.accentDark or C.input))
            button:SetBackdropBorderColor(unpackColor(active and C.accent or C.border))
            button.label:SetTextColor(unpackColor(active and C.text or C.muted))
        end)
        page.categoryButtons[categoryKey] = tab
    end

    local definitions = {
        { L("Panel-Hintergrund"), L("Dunkler gemeinsamer Hintergrund um alle Icons."), "showPanelBackground" },
        { L("HeliHeal-Header"), L("Zeigt die Überschrift über der Priority-Leiste."), "showHeader" },
        { L("Fähigkeitsname"), L("Blendet den Namen der Fähigkeit am Icon ein."), "showAbilityName" },
        { L("Prioritätsbadge"), L("Zeigt P1 bis P5 direkt auf dem jeweiligen Icon."), "showPriorityBadge" },
        { L("Icon-Rahmen"), L("Schmaler Rahmen und Schatten um jedes Spell-Icon."), "showIconBorder" },
        { L("Hotkey"), L("Zeigt den beobachteten Input unter dem Icon."), "showHotkey" },
        { L("Rollen-Hinweis"), L("Zeigt AOE, SINGLE, BURST oder SAVE mittig auf passenden Heilfähigkeiten."), "showRoleLabel" },
        { L("Situationsauswahl"), L("Zeigt gleichwertige situative Fähigkeiten als ODER-Auswahl an."), "showChoiceIndicator" },
        { L("Cooldown-Zahl"), L("Zeigt den lokal simulierten Cooldown mittig auf dem Icon."), "showCooldown" },
        { L("DEF / Utility-Fenster"), L("Zeigt Paladin-Defensiv-, externe Schutz- und Bewegungsfähigkeiten als separate Bereitschaftsleiste."), "showSupportWindow" },
        { L("Dispel-Cooldown am Mauszeiger"), L("Zeigt nach einem bestätigten Dispel dessen lokalen Cooldown neben der Maus."), "showDispelCursor" },
    }

    local scroll = CreateFrame("ScrollFrame", nil, page)
    scroll:SetPoint("TOPLEFT", 0, -146)
    scroll:SetPoint("BOTTOMRIGHT", -24, 12)
    scroll:EnableMouseWheel(true)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetWidth(1)
    content:SetHeight(1)
    scroll:SetScrollChild(content)

    local track = page:CreateTexture(nil, "BACKGROUND")
    track:SetTexture(WHITE)
    themeTexture(track, C.borderSoft)
    track:SetPoint("TOPRIGHT", -13, -152)
    track:SetPoint("BOTTOMRIGHT", -13, 18)
    track:SetWidth(3)

    local thumb = page:CreateTexture(nil, "ARTWORK")
    thumb:SetTexture(WHITE)
    themeTexture(thumb, C.accent)
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
    page.categoryRows = { visibility = {}, icons = {}, hotkey = {}, text = {}, colors = {}, support = {} }
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
        page.categoryRows.visibility[#page.categoryRows.visibility + 1] = row
    end

    local function addControlRow(category, titleText, descriptionText, control, rightInset)
        local row = createSettingRow(content, 0, titleText, descriptionText)
        control:SetParent(row)
        control:SetPoint("RIGHT", -(rightInset or 20), 0)
        bindWheel(row)
        bindWheel(control)
        page.refreshers[#page.refreshers + 1] = control
        page.categoryRows[category][#page.categoryRows[category] + 1] = row
        return row
    end

    local function addSlider(category, titleText, descriptionText, key, minValue, maxValue, step, formatter)
        local slider = createSlider(content, minValue, maxValue, step,
            function() return self.db.profile[key] end,
            function(value)
                self.db.profile[key] = value
                self:RefreshDisplay()
            end,
            formatter)
        -- The value label occupies 68 pixels to the right of the slider.
        -- Reserve that space explicitly so it remains inside the setting card.
        addControlRow(category, L(titleText), L(descriptionText), slider, 88)
        return slider
    end

    local function pixels(value) return ("%d px"):format(value) end
    local function signedPixels(value) return ("%+d px"):format(value) end
    local function percent(value) return ("%d%%"):format(math.floor((value * 100) + 0.5)) end

    local orientationSelector = createDropdownSelector(content, page, {
        { value = "HORIZONTAL", label = L("Horizontal") },
        { value = "VERTICAL", label = L("Vertikal") },
    }, function() return self.db.profile.supportWindowOrientation end,
        function(value)
            self.db.profile.supportWindowOrientation = value
            self:RefreshDisplay()
        end)
    addControlRow("support", L("DEF-Ausrichtung"),
        L("Ordnet die DEF- und Utility-Fähigkeiten waagerecht oder senkrecht an."), orientationSelector)

    for _, definition in ipairs({
        { "supportWindowShowPanelBackground", "DEF-Panel-Hintergrund", "Zeigt einen eigenen Hintergrund um das DEF-Fenster." },
        { "supportWindowShowHeader", "DEF-Header", "Zeigt die Überschrift DEF / UTILITY in diesem Fenster." },
        { "supportWindowShowAbilityName", "DEF-Fähigkeitsnamen", "Zeigt die Fähigkeitsnamen nur im DEF-Fenster." },
        { "supportWindowShowIconBorder", "DEF-Icon-Rahmen", "Zeigt Rahmen und Schatten nur an den DEF-Icons." },
        { "supportWindowShowHotkey", "DEF-Hotkeys", "Zeigt die beobachteten Tasten nur im DEF-Fenster." },
        { "supportWindowShowCooldown", "DEF-Cooldowns", "Zeigt lokale Timer und Aufladungen nur im DEF-Fenster." },
    }) do
        local settingKey, titleText, descriptionText = definition[1], definition[2], definition[3]
        local toggle = createToggle(content,
            function() return self.db.profile[settingKey] end,
            function(value)
                self.db.profile[settingKey] = value
                self:RefreshDisplay()
            end)
        addControlRow("support", L(titleText), L(descriptionText), toggle)
    end

    addSlider("support", "DEF-Fenster-Skalierung", "Skaliert dieses Fenster unabhängig von der Hauptleiste.",
        "supportWindowScale", 0.6, 1.8, 0.05, percent)
    addSlider("support", "DEF-Icon-Breite", "Breite der Icons in diesem Fenster.",
        "supportWindowIconWidth", 24, 128, 1, pixels)
    addSlider("support", "DEF-Icon-Höhe", "Höhe der Icons in diesem Fenster.",
        "supportWindowIconHeight", 24, 128, 1, pixels)
    addSlider("support", "DEF-Icon-Zoom", "Zoomt die Textur nur in den DEF-Icons.",
        "supportWindowIconZoom", 0.7, 1.6, 0.05, percent)
    addSlider("support", "DEF-Abstand", "Abstand zwischen den DEF-Icons.",
        "supportWindowSpacing", 0, 40, 1, pixels)
    addSlider("support", "DEF-Icons X", "Verschiebt die Icon-Gruppe innerhalb des DEF-Fensters horizontal.",
        "supportWindowIconOffsetX", -40, 40, 1, signedPixels)
    addSlider("support", "DEF-Icons Y", "Verschiebt die Icon-Gruppe innerhalb des DEF-Fensters vertikal.",
        "supportWindowIconOffsetY", -40, 40, 1, signedPixels)
    addSlider("support", "DEF-Icon-Innenabstand", "Abstand zwischen DEF-Textur und Rahmen.",
        "supportWindowIconInset", 0, 12, 1, pixels)
    addSlider("support", "DEF-Panel-Innenabstand X", "Horizontaler Innenraum des DEF-Fensters.",
        "supportWindowPaddingX", 0, 40, 1, pixels)
    addSlider("support", "DEF-Panel-Innenabstand Y", "Vertikaler Innenraum des DEF-Fensters.",
        "supportWindowPaddingY", 0, 40, 1, pixels)
    addSlider("support", "DEF-Panel-Deckkraft", "Deckkraft des eigenen DEF-Hintergrunds.",
        "supportWindowPanelBackgroundAlpha", 0, 1, 0.05, percent)

    local fontOptions = {}
    for _, key in ipairs(ns.media.fontOrder or {}) do
        local entry = ns.media.fonts and ns.media.fonts[key]
        if entry then fontOptions[#fontOptions + 1] = { value = key, label = entry.name, font = entry.path } end
    end
    local fontSelector = createDropdownSelector(content, page, fontOptions,
        function() return self.db.profile.hudFont end,
        function(value) self.db.profile.hudFont = value; self:RefreshDisplay() end)
    addControlRow("text", L("HUD-Schriftart"), L("Wählt die Schriftart für alle Texte im Priority-HUD."), fontSelector)

    local outlineSelector = createDropdownSelector(content, page, {
        { value = "NONE", label = L("Ohne Kontur"), flags = "" },
        { value = "OUTLINE", label = L("Normale Kontur"), flags = "OUTLINE" },
        { value = "THICKOUTLINE", label = L("Starke Kontur"), flags = "THICKOUTLINE" },
    }, function() return self.db.profile.hudFontOutline end,
        function(value) self.db.profile.hudFontOutline = value; self:RefreshDisplay() end)
    addControlRow("text", L("Textkontur"), L("Legt die Lesbarkeit aller Texte auf den Spell-Icons fest."), outlineSelector)

    addSlider("icons", "Haupt-Icon-Breite", "Breite der aktuell empfohlenen Fähigkeit.",
        "primaryIconWidth", 32, 160, 1, pixels)
    addSlider("icons", "Haupt-Icon-Höhe", "Höhe der aktuell empfohlenen Fähigkeit.",
        "primaryIconHeight", 32, 160, 1, pixels)
    addSlider("icons", "Haupt-Icon-Zoom", "Vergrößert oder verkleinert den sichtbaren Ausschnitt im Haupt-Icon.",
        "primaryIconZoom", 0.7, 1.6, 0.05, percent)
    addSlider("icons", "Haupt-Icon X", "Verschiebt das Haupt-Icon horizontal innerhalb des HUDs.",
        "primaryIconOffsetX", -40, 40, 1, signedPixels)
    addSlider("icons", "Haupt-Icon Y", "Verschiebt das Haupt-Icon vertikal innerhalb des HUDs.",
        "primaryIconOffsetY", -40, 40, 1, signedPixels)
    addSlider("icons", "Folge-Icon-Breite", "Breite der vier nachfolgenden Empfehlungen.",
        "secondaryIconWidth", 24, 128, 1, pixels)
    addSlider("icons", "Folge-Icon-Höhe", "Höhe der vier nachfolgenden Empfehlungen.",
        "secondaryIconHeight", 24, 128, 1, pixels)
    addSlider("icons", "Folge-Icon-Zoom", "Vergrößert oder verkleinert den sichtbaren Ausschnitt der Folge-Icons.",
        "secondaryIconZoom", 0.7, 1.6, 0.05, percent)
    addSlider("icons", "Folge-Icons X", "Verschiebt die gesamte Gruppe der Folge-Icons horizontal.",
        "secondaryIconOffsetX", -40, 40, 1, signedPixels)
    addSlider("icons", "Folge-Icons Y", "Verschiebt die gesamte Gruppe der Folge-Icons vertikal.",
        "secondaryIconOffsetY", -40, 40, 1, signedPixels)
    addSlider("icons", "Icon-Innenabstand", "Abstand zwischen Icon-Textur und ihrem Rahmen.",
        "iconInset", 0, 12, 1, pixels)
    addSlider("icons", "Panel-Innenabstand X", "Horizontaler Innenraum des HUD-Hintergrunds.",
        "panelPaddingX", 0, 40, 1, pixels)
    addSlider("icons", "Panel-Innenabstand Y", "Vertikaler Innenraum des HUD-Hintergrunds.",
        "panelPaddingY", 0, 40, 1, pixels)
    addSlider("icons", "Panel-Deckkraft", "Deckkraft des gemeinsamen HUD-Hintergrunds.",
        "panelBackgroundAlpha", 0, 1, 0.05, percent)
    addSlider("icons", "Dispel-Icon-Größe", "Größe der Dispel-Cooldown-Anzeige am Mauszeiger.",
        "dispelCursorSize", 20, 80, 1, pixels)
    addSlider("icons", "Dispel-Cursor X", "Horizontaler Abstand der Dispel-Anzeige zum Mauszeiger.",
        "dispelCursorOffsetX", -100, 100, 1, signedPixels)
    addSlider("icons", "Dispel-Cursor Y", "Vertikaler Abstand der Dispel-Anzeige zum Mauszeiger.",
        "dispelCursorOffsetY", -100, 100, 1, signedPixels)

    addSlider("hotkey", "Hotkey-Textgröße", "Größe der Tastenbezeichnung unter dem Icon.",
        "hotkeyFontSize", 7, 20, 1, pixels)
    addSlider("hotkey", "Hotkey X", "Verschiebt jede Hotkey-Box horizontal relativ zu ihrem Icon.",
        "hotkeyOffsetX", -80, 80, 1, signedPixels)
    addSlider("hotkey", "Hotkey Y", "Verschiebt jede Hotkey-Box vertikal relativ zu ihrem Icon.",
        "hotkeyOffsetY", -40, 40, 1, signedPixels)
    addSlider("hotkey", "Hotkey-Box-Höhe", "Mindesthöhe der Hotkey-Box.",
        "hotkeyBadgeHeight", 12, 44, 1, pixels)
    addSlider("hotkey", "Hotkey-Mindestbreite", "Kleinste Breite der Hotkey-Box; längere Bindings wachsen automatisch.",
        "hotkeyBadgeMinWidth", 20, 180, 1, pixels)
    addSlider("hotkey", "Hotkey-Textabstand", "Zusätzlicher horizontaler Platz um den Hotkey-Text.",
        "hotkeyBadgePadding", 0, 60, 1, pixels)
    local compactHotkeys = createToggle(content,
        function() return self.db.profile.compactHotkeys ~= false end,
        function(value)
            self.db.profile.compactHotkeys = value
            self:RefreshDisplay()
        end)
    addControlRow("hotkey", L("Kompakte Hotkeys"),
        L("Kürzt Modifier und Maustasten im HUD, zum Beispiel SHIFT-BUTTON1 zu S-M1."), compactHotkeys)

    addSlider("text", "Cooldown-Textgröße", "Größe des lokalen Timers und der Aufladungsanzeige.",
        "cooldownFontSize", 10, 30, 1, pixels)
    addSlider("text", "Cooldown X", "Verschiebt Timer und Aufladungen horizontal im Icon.",
        "cooldownOffsetX", -80, 80, 1, signedPixels)
    addSlider("text", "Cooldown Y", "Verschiebt Timer und Aufladungen vertikal im Icon.",
        "cooldownOffsetY", -80, 80, 1, signedPixels)
    addSlider("text", "Rollen-Textgröße", "Größe von AOE, SINGLE, BURST und SAVE.",
        "roleLabelSize", 7, 24, 1, pixels)
    addSlider("text", "Rollen-Position X", "Verschiebt den Rollen-Hinweis horizontal im Icon.",
        "roleLabelOffsetX", -80, 80, 1, signedPixels)
    addSlider("text", "Rollen-Position Y", "Verschiebt den Rollen-Hinweis vertikal im Icon.",
        "roleLabelOffsetY", -80, 80, 1, signedPixels)
    addSlider("text", "Prioritäts-Textgröße", "Größe der P1-bis-P5-Anzeige.",
        "priorityFontSize", 7, 20, 1, pixels)
    addSlider("text", "Priorität X", "Verschiebt das Prioritätsbadge horizontal.",
        "priorityOffsetX", -80, 80, 1, signedPixels)
    addSlider("text", "Priorität Y", "Verschiebt das Prioritätsbadge vertikal.",
        "priorityOffsetY", -80, 80, 1, signedPixels)
    addSlider("text", "Namens-Textgröße", "Größe des Fähigkeitsnamens.",
        "abilityNameFontSize", 7, 20, 1, pixels)
    addSlider("text", "Namens-Breite", "Maximale Breite des Fähigkeitsnamens.",
        "abilityNameWidth", 40, 240, 1, pixels)
    addSlider("text", "Name X", "Verschiebt den Fähigkeitsnamen horizontal.",
        "abilityNameOffsetX", -100, 100, 1, signedPixels)
    addSlider("text", "Name Y", "Verschiebt den Fähigkeitsnamen vertikal.",
        "abilityNameOffsetY", -40, 60, 1, signedPixels)
    addSlider("text", "Header-Textgröße", "Größe der HeliHeal-Überschrift.",
        "headerFontSize", 7, 20, 1, pixels)
    addSlider("text", "Header X", "Verschiebt die HeliHeal-Überschrift horizontal.",
        "headerOffsetX", -80, 80, 1, signedPixels)
    addSlider("text", "Header Y", "Verschiebt die HeliHeal-Überschrift vertikal.",
        "headerOffsetY", -50, 30, 1, signedPixels)

    local function colorValue(key)
        return self.db.profile[key] or ns.defaults.profile[key]
    end
    local function colorSetter(key)
        return function(red, green, blue)
            self.db.profile[key] = { red, green, blue }
            self:RefreshDisplay()
        end
    end

    local function optionsColorValue(key)
        return self.db.global[key] or ns.defaults.global[key]
    end
    local function optionsColorSetter(key)
        return function(red, green, blue)
            self.db.global[key] = { red, green, blue }
            self:ApplyOptionsWindowTheme()
        end
    end

    local optionsBackground = createColorSwatch(content, 112, L("FENSTER"),
        function() return optionsColorValue("optionsWindowBackgroundColor") end,
        optionsColorSetter("optionsWindowBackgroundColor"))
    addControlRow("colors", L("Optionsfenster-Hintergrund"),
        L("Ändert die Grundfarbe dieses Einstellungsfensters."), optionsBackground)

    local optionsAccent = createColorSwatch(content, 112, L("AKZENT"),
        function() return optionsColorValue("optionsWindowAccentColor") end,
        optionsColorSetter("optionsWindowAccentColor"))
    addControlRow("colors", L("Optionsfenster-Akzent"),
        L("Farbe für aktive Schaltflächen, Linien und Markierungen im Optionsfenster."), optionsAccent)

    local classColorToggle = createToggle(content,
        function() return self.db.global.optionsWindowUseClassColor == true end,
        function(value)
            self.db.global.optionsWindowUseClassColor = value == true
            self:ApplyOptionsWindowTheme()
        end)
    addControlRow("colors", L("Klassenfarbe verwenden"),
        L("Verwendet die aktuelle Spielerklasse als Akzentfarbe; die eigene Akzentfarbe bleibt gespeichert."),
        classColorToggle)

    local accentColor = createColorSwatch(content, 112, L("AKZENT"),
        function() return colorValue("accentColor") end, colorSetter("accentColor"))
    addControlRow("colors", L("HUD-Akzentfarbe"), L("Farbe für aktive Icon-Rahmen und die obere Akzentlinie."), accentColor)

    local panelColor = createColorSwatch(content, 112, L("PANEL"),
        function() return colorValue("panelBackgroundColor") end, colorSetter("panelBackgroundColor"))
    addControlRow("colors", L("Panel-Farbe"), L("Hintergrundfarbe des gemeinsamen HUD-Panels."), panelColor)

    local panelBorderColor = createColorSwatch(content, 112, L("RAHMEN"),
        function() return colorValue("panelBorderColor") end, colorSetter("panelBorderColor"))
    addControlRow("colors", L("Panel-Rahmenfarbe"), L("Farbe der äußeren Panel-Kante."), panelBorderColor)

    local iconBackgroundColor = createColorSwatch(content, 112, L("ICON"),
        function() return colorValue("iconBackgroundColor") end, colorSetter("iconBackgroundColor"))
    addControlRow("colors", L("Icon-Hintergrundfarbe"), L("Farbe hinter den einzelnen Fähigkeitstexturen."), iconBackgroundColor)

    local hotkeyBackgroundColor = createColorSwatch(content, 112, L("HOTKEY BG"),
        function() return colorValue("hotkeyBackgroundColor") end, colorSetter("hotkeyBackgroundColor"))
    addControlRow("colors", L("Hotkey-Hintergrundfarbe"), L("Hintergrundfarbe jeder Hotkey-Box."), hotkeyBackgroundColor)

    local hotkeyColor = createColorSwatch(content, 112, L("HOTKEY"),
        function() return colorValue("hotkeyColor") end, colorSetter("hotkeyColor"))
    addControlRow("colors", L("Hotkey-Farbe"), L("Textfarbe der beobachteten Tastenbelegung."), hotkeyColor)

    local cooldownColor = createColorSwatch(content, 112, L("TIMER"),
        function() return colorValue("cooldownColor") end, colorSetter("cooldownColor"))
    addControlRow("colors", L("Cooldown-Farbe"), L("Textfarbe für Timer, Aufladungen und Abdeckungszähler."), cooldownColor)

    local abilityNameColor = createColorSwatch(content, 112, L("NAME"),
        function() return colorValue("abilityNameColor") end, colorSetter("abilityNameColor"))
    addControlRow("colors", L("Namens-Farbe"), L("Textfarbe der Fähigkeitsnamen."), abilityNameColor)

    local headerColor = createColorSwatch(content, 112, L("HEADER"),
        function() return colorValue("headerColor") end, colorSetter("headerColor"))
    addControlRow("colors", L("Header-Farbe"), L("Textfarbe der HeliHeal-Überschrift."), headerColor)

    local priorityColor = createColorSwatch(content, 112, L("PRIO"),
        function() return colorValue("priorityColor") end, colorSetter("priorityColor"))
    addControlRow("colors", L("Prioritäts-Farbe"), L("Textfarbe der P1-bis-P5-Anzeige."), priorityColor)

    local roleRow = createSettingRow(content, 0, L("Rollenfarben"), L("Eigene Farben für jeden Heilungs-Kontext."))
    bindWheel(roleRow)
    page.categoryRows.colors[#page.categoryRows.colors + 1] = roleRow
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
    local resetRow = createSettingRow(content, 0, L("HUD-Optik zurücksetzen"), L("Setzt alle Elementgrößen, Positionen, Zoomwerte und Farben zurück."))
    bindWheel(resetRow)
    page.categoryRows.colors[#page.categoryRows.colors + 1] = resetRow
    local resetAppearance = createButton(resetRow, L("OPTIK RESET"), 150, 32, false)
    resetAppearance:SetPoint("RIGHT", -20, 0)
    bindWheel(resetAppearance)
    resetAppearance:SetScript("OnClick", function()
        local profile = self.db.profile
        local defaults = ns.defaults.profile
        for _, key in ipairs({ "hudFont", "hudFontOutline", "primaryIconSize", "secondaryIconSize", "compactHotkeys",
            "primaryIconWidth", "primaryIconHeight", "primaryIconZoom", "primaryIconOffsetX", "primaryIconOffsetY",
            "secondaryIconWidth", "secondaryIconHeight", "secondaryIconZoom", "secondaryIconOffsetX", "secondaryIconOffsetY",
            "iconInset", "panelPaddingX", "panelPaddingY", "panelBackgroundAlpha",
            "supportWindowScale", "supportWindowOrientation", "supportWindowSpacing",
            "supportWindowIconWidth", "supportWindowIconHeight", "supportWindowIconZoom",
            "supportWindowIconOffsetX", "supportWindowIconOffsetY", "supportWindowIconInset",
            "supportWindowPaddingX", "supportWindowPaddingY", "supportWindowPanelBackgroundAlpha",
            "supportWindowShowPanelBackground", "supportWindowShowHeader", "supportWindowShowAbilityName",
            "supportWindowShowIconBorder", "supportWindowShowHotkey", "supportWindowShowCooldown",
            "dispelCursorSize", "dispelCursorOffsetX", "dispelCursorOffsetY",
            "roleLabelSize", "roleLabelOffsetX", "roleLabelOffsetY",
            "hotkeyFontSize", "hotkeyOffsetX", "hotkeyOffsetY", "hotkeyBadgeHeight", "hotkeyBadgeMinWidth",
            "hotkeyBadgePadding", "cooldownFontSize", "cooldownOffsetX", "cooldownOffsetY",
            "priorityFontSize", "priorityOffsetX", "priorityOffsetY", "abilityNameFontSize", "abilityNameWidth",
            "abilityNameOffsetX", "abilityNameOffsetY", "headerFontSize", "headerOffsetX", "headerOffsetY" }) do
            profile[key] = defaults[key]
        end
        for _, key in ipairs({ "accentColor", "panelBackgroundColor", "panelBorderColor", "iconBackgroundColor",
            "hotkeyBackgroundColor", "hotkeyColor", "cooldownColor", "abilityNameColor", "headerColor", "priorityColor" }) do
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
    function page:SelectCategory(category)
        if category == "typography" then category = "text" end
        if category == "sizing" then category = "icons" end
        if not self.categoryRows[category] then category = "visibility" end
        HeliHeal.selectedStyleCategory = category
        for categoryKey, rows in pairs(self.categoryRows) do
            for _, row in ipairs(rows) do row:SetShown(categoryKey == category) end
            local tab = self.categoryButtons[categoryKey]
            local active = categoryKey == category
            tab:SetBackdropColor(unpackColor(active and C.accentDark or C.input))
            tab:SetBackdropBorderColor(unpackColor(active and C.accent or C.border))
            tab.label:SetTextColor(unpackColor(active and C.text or C.muted))
        end
        local rows = self.categoryRows[category]
        for index, row in ipairs(rows) do
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 20, -6 - ((index - 1) * 68))
            row:SetPoint("TOPRIGHT", -20, -6 - ((index - 1) * 68))
        end
        content:SetHeight(math.max(1, (#rows * 68) + 6))
        scroll:SetVerticalScroll(0)
        updateScroll()
    end
    page:SelectCategory(self.selectedStyleCategory or "visibility")
    page.scroll = scroll
    page.updateScroll = updateScroll
    return page
end

function HeliHeal:BuildProfilesPage(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    setPageHeader(page, L("Profile & Reset"), L("Separate Konfigurationen über AceDB verwalten oder sicher zurücksetzen."))

    local activeCard = CreateFrame("Frame", nil, page, "BackdropTemplate")
    activeCard:SetPoint("TOPLEFT", 20, -110)
    activeCard:SetPoint("TOPRIGHT", -20, -110)
    activeCard:SetHeight(100)
    backdrop(activeCard, C.panel, C.accentDark)
    local activeBar = activeCard:CreateTexture(nil, "ARTWORK")
    activeBar:SetTexture(WHITE)
    themeTexture(activeBar, C.accent)
    activeBar:SetPoint("TOPLEFT")
    activeBar:SetPoint("BOTTOMLEFT")
    activeBar:SetWidth(3)

    local profileCaption = text(activeCard, L("AKTIVES PROFIL"), 9, C.accent, "OUTLINE")
    profileCaption:SetPoint("TOPLEFT", 20, -17)
    page.profileName = text(activeCard, "", 24, C.text, "OUTLINE")
    page.profileName:SetPoint("TOPLEFT", profileCaption, "BOTTOMLEFT", 0, -8)
    local profileHint = text(activeCard, L("Alle Änderungen werden in diesem Profil gespeichert."), 9, C.muted)
    profileHint:SetPoint("TOPLEFT", page.profileName, "BOTTOMLEFT", 1, -6)

    local existingLabel = text(activeCard, L("VORHANDENE PROFILE"), 9, C.muted, "OUTLINE")
    existingLabel:SetPoint("TOPRIGHT", -20, -18)
    local profileOptions = {}
    local profileSelector = createDropdownSelector(activeCard, page, profileOptions,
        function() return self.db:GetCurrentProfile() end,
        function(value) self.db:SetProfile(value) end)
    profileSelector:SetSize(300, 34)
    profileSelector:SetPoint("TOPRIGHT", -20, -42)
    page.profileSelector = profileSelector

    local createCard = CreateFrame("Frame", nil, page, "BackdropTemplate")
    createCard:SetPoint("TOPLEFT", 20, -222)
    createCard:SetPoint("TOPRIGHT", -20, -222)
    createCard:SetHeight(112)
    backdrop(createCard, C.panel, C.borderSoft)
    local createLabel = text(createCard, L("NEUES PROFIL"), 10, C.accent, "OUTLINE")
    createLabel:SetPoint("TOPLEFT", 20, -16)
    local createHint = text(createCard, L("Erstelle eine leere Konfiguration oder kopiere das aktuell aktive Profil."), 9, C.muted)
    createHint:SetPoint("TOPLEFT", createLabel, "BOTTOMLEFT", 0, -6)
    page.profileInput = createEditBox(createCard, 250, L("Profilname"))
    page.profileInput:SetPoint("TOPLEFT", 20, -61)
    local create = createButton(createCard, L("LEER ERSTELLEN"), 142, 34, false)
    create:SetPoint("LEFT", page.profileInput, "RIGHT", 10, 0)
    local duplicate = createButton(createCard, L("AKTUELLES KOPIEREN"), 174, 34, true)
    duplicate:SetPoint("LEFT", create, "RIGHT", 8, 0)

    local function requestedProfileName()
        local name = page.profileInput:GetText():match("^%s*(.-)%s*$")
        return name ~= "" and name or nil
    end
    local function profileExists(name)
        for _, profileName in ipairs(self.db:GetProfiles()) do
            if profileName == name then return true end
        end
        return false
    end
    local function clearProfileInput()
        page.profileInput:SetText("")
        page.profileInput:ClearFocus()
    end
    create:SetScript("OnClick", function()
        local name = requestedProfileName()
        if not name then return end
        if profileExists(name) then self:Print(L("Profil '%s' existiert bereits.", name)); return end
        self.db:SetProfile(name)
        clearProfileInput()
    end)
    duplicate:SetScript("OnClick", function()
        local name = requestedProfileName()
        if not name then return end
        if profileExists(name) then self:Print(L("Profil '%s' existiert bereits.", name)); return end
        local sourceProfile = self.db:GetCurrentProfile()
        self.db:SetProfile(name)
        self.db:CopyProfile(sourceProfile)
        clearProfileInput()
    end)
    page.profileInput:SetScript("OnEnterPressed", function() duplicate:Click() end)

    local maintenance = CreateFrame("Frame", nil, page, "BackdropTemplate")
    maintenance:SetPoint("TOPLEFT", 20, -346)
    maintenance:SetPoint("TOPRIGHT", -20, -346)
    maintenance:SetHeight(126)
    backdrop(maintenance, C.panel, C.borderSoft)
    local maintenanceCaption = text(maintenance, L("WARTUNG & RESET"), 10, C.accent, "OUTLINE")
    maintenanceCaption:SetPoint("TOPLEFT", 20, -16)
    local actions = {
        { L("TIMER RESET"), L("Nur lokale Timer"), function() self:ResetSession() end },
        { L("HOTKEYS RESET"), L("Alle Klassen-Hotkeys"), function() self:ResetSlots() end },
        { L("PROFIL RESET"), L("Aktives Profil"), function() self.db:ResetProfile() end },
        { L("UI NEU LADEN"), L("Interface aktualisieren"), function()
            if C_UI and C_UI.Reload then C_UI.Reload() else ReloadUI() end
        end },
    }
    for index, action in ipairs(actions) do
        local callback = action[3]
        local actionButton = createButton(maintenance, action[1], 164, 34, index == 4)
        actionButton:SetPoint("TOPLEFT", 20 + ((index - 1) * 177), -48)
        actionButton:SetScript("OnClick", callback)
        local description = text(maintenance, action[2], 8, C.muted)
        description:SetPoint("TOP", actionButton, "BOTTOM", 0, -8)
    end

    local dangerCard = CreateFrame("Frame", nil, page, "BackdropTemplate")
    dangerCard:SetPoint("TOPLEFT", 20, -484)
    dangerCard:SetPoint("TOPRIGHT", -20, -484)
    dangerCard:SetHeight(82)
    backdrop(dangerCard, { 0.065, 0.025, 0.03, 0.92 }, C.danger)
    local deleteLabel = text(dangerCard, L("GEFAHRENBEREICH"), 9, C.danger, "OUTLINE")
    deleteLabel:SetPoint("TOPLEFT", 20, -17)
    local deleteHint = text(dangerCard, L("Löscht ein nicht aktives Profil dauerhaft."), 9, C.muted)
    deleteHint:SetPoint("TOPLEFT", deleteLabel, "BOTTOMLEFT", 0, -7)
    local deleteSelection
    local deleteSelector = createDropdownSelector(dangerCard, page, {},
        function() return deleteSelection end,
        function(value)
            deleteSelection = value
            page.pendingDeleteProfile = nil
            page.deleteButton.label:SetText(L("PROFIL LÖSCHEN"))
        end)
    deleteSelector:SetSize(220, 34)
    deleteSelector:SetPoint("RIGHT", -202, 0)
    page.deleteSelector = deleteSelector
    page.deleteButton = createButton(dangerCard, L("PROFIL LÖSCHEN"), 170, 34, false)
    backdrop(page.deleteButton, C.input, C.danger)
    page.deleteButton:SetPoint("RIGHT", -20, 0)
    page.deleteButton:SetScript("OnEnter", function(button)
        button:SetBackdropColor(0.12, 0.035, 0.045, 1)
        button:SetBackdropBorderColor(unpackColor(C.danger))
        button.label:SetTextColor(unpackColor(C.text))
    end)
    page.deleteButton:SetScript("OnLeave", function(button)
        button:SetBackdropColor(unpackColor(C.input))
        button:SetBackdropBorderColor(unpackColor(C.danger))
        button.label:SetTextColor(unpackColor(C.muted))
    end)
    page.deleteButton:SetScript("OnClick", function(button)
        if not deleteSelection then return end
        if page.pendingDeleteProfile ~= deleteSelection then
            page.pendingDeleteProfile = deleteSelection
            button.label:SetText(L("LÖSCHEN BESTÄTIGEN"))
            button:SetBackdropBorderColor(unpackColor(C.danger))
            return
        end
        self.db:DeleteProfile(deleteSelection)
        deleteSelection = nil
        page.pendingDeleteProfile = nil
        button.label:SetText(L("PROFIL LÖSCHEN"))
        button:SetBackdropBorderColor(unpackColor(C.danger))
        page:RefreshProfiles()
    end)

    function page:RefreshProfiles()
        local profiles = HeliHeal.db:GetProfiles({})
        table.sort(profiles, function(a, b) return a:lower() < b:lower() end)
        local options = {}
        local deleteOptions = {}
        local current = HeliHeal.db:GetCurrentProfile()
        for _, profileName in ipairs(profiles) do
            options[#options + 1] = { value = profileName, label = profileName }
            if profileName ~= current then deleteOptions[#deleteOptions + 1] = { value = profileName, label = profileName } end
        end
        page.profileName:SetText(current)
        profileSelector:SetValues(options)
        local stillValid = false
        for _, option in ipairs(deleteOptions) do if option.value == deleteSelection then stillValid = true break end end
        if not stillValid then deleteSelection = deleteOptions[1] and deleteOptions[1].value or nil end
        deleteSelector:SetValues(deleteOptions)
        page.deleteButton:SetEnabled(deleteSelection ~= nil)
        page.deleteButton:SetAlpha(deleteSelection and 1 or 0.45)
        page.pendingDeleteProfile = nil
        page.deleteButton.label:SetText(L("PROFIL LÖSCHEN"))
    end
    page:RefreshProfiles()
    return page
end

local function changelogText(entry)
    local lines = {}
    for _, change in ipairs(entry.changes or {}) do
        lines[#lines + 1] = "• " .. L(change)
    end
    return table.concat(lines, "\n")
end

function HeliHeal:BuildProcsPage(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    setPageHeader(page, "Background Procs", "One Blizzard buff-bar source per proc. No separate cooldown HUD.")
    local hint = text(page, "Add each proc to Blizzard Tracked Buff Bars and enable Hide When Inactive.\nKeep the source items intact. UNKNOWN means no reliable observation; stacks are not tracked.", 11, C.muted)
    hint:SetPoint("TOPLEFT", 28, -102)
    hint:SetPoint("TOPRIGHT", -28, -102)
    hint:SetWordWrap(true)
    local input = createEditBox(page, 220, "Proc spell ID")
    input:SetPoint("TOPLEFT", 28, -152)
    local add = createButton(page, "ADD PROC", 140, 34, true)
    add:SetPoint("LEFT", input, "RIGHT", 10, 0)
    local feedback = text(page, "", 10, C.muted)
    feedback:SetPoint("LEFT", add, "RIGHT", 10, 0)
    local scroll = CreateFrame("ScrollFrame", nil, page, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 28, -204)
    scroll:SetPoint("BOTTOMRIGHT", -48, 22)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetWidth(680)
    content:SetHeight(1)
    scroll:SetScrollChild(content)
    local rows = {}
    function page:RefreshProcs()
        local tracker = HeliHeal.ProcTracker
        for _, row in ipairs(rows) do row:Hide() end
        for index, entry in ipairs(tracker:GetProcEntries()) do
            local row = rows[index]
            if not row then
                row = CreateFrame("Frame", nil, content, "BackdropTemplate")
                row:SetSize(680, 68)
                backdrop(row, C.panel, C.borderSoft)
                row.icon = row:CreateTexture(nil, "ARTWORK")
                row.icon:SetSize(36, 36)
                row.icon:SetPoint("LEFT", 12, 0)
                row.title = text(row, "", 12, C.text)
                row.title:SetPoint("TOPLEFT", 60, -12)
                row.status = text(row, "", 10, C.muted)
                row.status:SetPoint("TOPLEFT", 60, -36)
                row.remove = createButton(row, "REMOVE", 88, 28)
                row.remove:SetPoint("RIGHT", -10, 0)
                row.remove:SetScript("OnClick", function()
                    tracker:RemoveProc(row.key)
                    page:RefreshProcs()
                end)
                rows[index] = row
            end
            local state, reason = tracker:GetProcState(entry.key)
            row.key = entry.key
            row:SetPoint("TOPLEFT", 0, -(index - 1) * 76)
            row.title:SetText((entry.name or "Proc") .. "  [" .. entry.spellID .. "]")
            row.status:SetText(state .. " — " .. reason)
            row.icon:SetTexture(C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(entry.spellID) or 134400)
            row.remove:SetShown(entry.key ~= "infusion_of_light")
            row:Show()
        end
        content:SetHeight(math.max(1, #tracker:GetProcEntries() * 76))
    end
    add:SetScript("OnClick", function()
        local ok = HeliHeal.ProcTracker:AddProc(input:GetText())
        feedback:SetText(ok and "Added" or "Invalid / duplicate ID, or limit reached")
        if ok then input:SetText(""); input:ClearFocus() end
        page:RefreshProcs()
    end)
    page:SetScript("OnShow", function() page:RefreshProcs() end)
    page:SetScript("OnUpdate", function(_, elapsed)
        page.procElapsed = (page.procElapsed or 0) + elapsed
        if page.procElapsed >= 0.5 then page.procElapsed = 0; page:RefreshProcs() end
    end)
    return page
end

function HeliHeal:BuildSnapshotsPage(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    setPageHeader(page, L("Rotations-Snapshots"),
        L("Verdächtige festhängende Zustände lokal speichern, prüfen und kopieren."))

    local toolbar = CreateFrame("Frame", nil, page, "BackdropTemplate")
    toolbar:SetPoint("TOPLEFT", 28, -105)
    toolbar:SetPoint("TOPRIGHT", -28, -105)
    toolbar:SetHeight(58)
    backdrop(toolbar, C.panel, C.borderSoft)
    local hint = text(toolbar,
        L("Automatisch nach 3 Blizzard-Fehlschlägen oder 6 gleichen Primär-Inputs und 3 Sekunden ohne Bestätigung. Keine Health-, Target- oder Aura-Daten."),
        9, C.muted)
    hint:SetPoint("LEFT", 15, 0)
    hint:SetPoint("RIGHT", -300, 0)
    hint:SetWordWrap(true)

    local capture = createButton(toolbar, L("JETZT AUFNEHMEN"), 138, 30, false)
    capture:SetPoint("RIGHT", -146, 0)
    local clear = createButton(toolbar, L("ALLE LÖSCHEN"), 132, 30, false)
    clear:SetPoint("RIGHT", -8, 0)
    clear:SetBackdropBorderColor(unpackColor(C.danger))

    local listPanel = CreateFrame("Frame", nil, page, "BackdropTemplate")
    listPanel:SetPoint("TOPLEFT", 28, -175)
    listPanel:SetPoint("BOTTOMLEFT", 28, 22)
    listPanel:SetWidth(236)
    backdrop(listPanel, C.panel, C.borderSoft)
    local listTitle = text(listPanel, L("GESPEICHERTE FEHLER"), 9, C.accent, "OUTLINE")
    listTitle:SetPoint("TOPLEFT", 12, -12)
    page.countLabel = text(listPanel, "", 9, C.muted, "OUTLINE")
    page.countLabel:SetPoint("TOPRIGHT", -12, -12)

    local listScroll = CreateFrame("ScrollFrame", nil, listPanel, "UIPanelScrollFrameTemplate")
    listScroll:SetPoint("TOPLEFT", 8, -36)
    listScroll:SetPoint("BOTTOMRIGHT", -28, 8)
    local listContent = CreateFrame("Frame", nil, listScroll)
    listContent:SetWidth(196)
    listContent:SetHeight(1)
    listScroll:SetScrollChild(listContent)
    page.snapshotRows = {}

    local reportPanel = CreateFrame("Frame", nil, page, "BackdropTemplate")
    reportPanel:SetPoint("TOPLEFT", listPanel, "TOPRIGHT", 12, 0)
    reportPanel:SetPoint("BOTTOMRIGHT", -28, 22)
    backdrop(reportPanel, C.panel, C.borderSoft)
    page.reportTitle = text(reportPanel, L("SNAPSHOT AUSWÄHLEN"), 11, C.text, "OUTLINE")
    page.reportTitle:SetPoint("TOPLEFT", 14, -12)
    local copyHint = text(reportPanel, L("In den Bericht klicken, dann Strg+A und Strg+C drücken."), 9, C.muted)
    copyHint:SetPoint("TOPRIGHT", -14, -13)

    local reportScroll = CreateFrame("ScrollFrame", nil, reportPanel, "UIPanelScrollFrameTemplate")
    reportScroll:SetPoint("TOPLEFT", 12, -38)
    reportScroll:SetPoint("BOTTOMRIGHT", -30, 12)
    local report = CreateFrame("EditBox", nil, reportScroll)
    report:SetMultiLine(true)
    report:SetAutoFocus(false)
    report:SetFont(FONT, 10, "")
    report:SetTextColor(unpackColor(C.text))
    report:SetWidth(430)
    report:SetTextInsets(5, 5, 5, 5)
    report:SetJustifyH("LEFT")
    report:SetJustifyV("TOP")
    report:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    report:SetScript("OnTextChanged", function(self)
        self:SetHeight(math.max(1, (self:GetNumLines() or 1) * 14 + 14))
    end)
    reportScroll:SetScrollChild(report)
    page.report = report

    function page:SelectSnapshot(snapshotID)
        self.selectedSnapshotID = snapshotID
        local selected
        for _, snapshot in ipairs(HeliHeal:GetRotationSnapshots()) do
            if snapshot.id == snapshotID then selected = snapshot break end
        end
        self.report:SetText(selected and selected.report or L("Noch keine Snapshots gespeichert."))
        self.report:SetCursorPosition(0)
        self.reportTitle:SetText(selected
            and ((selected.capturedAt or L("Unbekannte Zeit")) .. " • " .. (selected.abilityName or "?"))
            or L("KEIN SNAPSHOT"))
        for _, row in ipairs(self.snapshotRows) do
            row:SetSelected(row.snapshot and row.snapshot.id == snapshotID)
        end
    end

    function page:RefreshSnapshots(preferredID)
        local snapshots = HeliHeal:GetRotationSnapshots()
        self.countLabel:SetText(tostring(#snapshots) .. "/20")
        for index = 1, math.max(#snapshots, #self.snapshotRows) do
            local row = self.snapshotRows[index]
            if not row then
                row = createButton(listContent, "", 196, 48, false)
                row.label:ClearAllPoints()
                row.label:SetPoint("TOPLEFT", 10, -8)
                row.label:SetPoint("RIGHT", -8, 0)
                row.label:SetJustifyH("LEFT")
                row.time = text(row, "", 8, C.dim)
                row.time:SetPoint("BOTTOMLEFT", 10, 7)
                row:SetScript("OnClick", function(button)
                    if button.snapshot then page:SelectSnapshot(button.snapshot.id) end
                end)
                self.snapshotRows[index] = row
            end
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 0, -((index - 1) * 54))
            row.snapshot = snapshots[index]
            if row.snapshot then
                row.label:SetText(row.snapshot.abilityName or L("Unbekannte Fähigkeit"))
                row.time:SetText(row.snapshot.capturedAt or L("Unbekannte Zeit"))
                row:Show()
            else
                row:Hide()
            end
        end
        listContent:SetHeight(math.max(1, #snapshots * 54))
        local selectedID = preferredID or self.selectedSnapshotID
        local valid = false
        for _, snapshot in ipairs(snapshots) do if snapshot.id == selectedID then valid = true break end end
        if not valid then selectedID = snapshots[1] and snapshots[1].id end
        self:SelectSnapshot(selectedID)
    end

    capture:SetScript("OnClick", function()
        local snapshot = HeliHeal:CaptureRotationSnapshot("Manual snapshot", { inputKey = "manual" }, GetTime())
        page:RefreshSnapshots(snapshot.id)
    end)
    clear:SetScript("OnClick", function(button)
        if not button.confirming then
            button.confirming = true
            button.label:SetText(L("LÖSCHEN BESTÄTIGEN"))
            return
        end
        button.confirming = nil
        button.label:SetText(L("ALLE LÖSCHEN"))
        HeliHeal:ClearRotationSnapshots()
    end)
    page:SetScript("OnShow", function() page:RefreshSnapshots() end)
    page:RefreshSnapshots()
    return page
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

function HeliHeal:BuildFAQPage(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    setPageHeader(page, L("FAQ & Spielhilfe"),
        L("Kurze Antworten zur Anzeige und zur Spielweise deiner Spezialisierung."))

    local controls = CreateFrame("Frame", nil, page, "BackdropTemplate")
    controls:SetPoint("TOPLEFT", 28, -105)
    controls:SetPoint("TOPRIGHT", -28, -105)
    controls:SetHeight(46)
    backdrop(controls, C.panel, C.borderSoft)

    local entries = ns.FAQ and ns.FAQ:GetEntries(self.classToken, self.specializationID) or {}
    local summary = text(controls, (L("%d THEMEN • SPELL-GUIDE")):format(#entries), 9, C.muted, "OUTLINE")
    summary:SetPoint("LEFT", 14, 0)

    local expandAll = createButton(controls, L("ALLE ÖFFNEN"), 118, 26, false)
    expandAll:SetPoint("RIGHT", -142, 0)
    local collapseAll = createButton(controls, L("ALLE SCHLIESSEN"), 132, 26, false)
    collapseAll:SetPoint("RIGHT", -6, 0)

    local scroll = CreateFrame("ScrollFrame", nil, page, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 28, -161)
    scroll:SetPoint("BOTTOMRIGHT", -48, 22)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetWidth(1)
    scroll:SetScrollChild(content)

    local cards = {}
    local sections = {}
    local sectionOrder = {}
    local specializationKey = tostring(self.specializationID or 0)
    self.faqOpenTopics = self.faqOpenTopics or {}
    self.faqOpenSections = self.faqOpenSections or {}

    local function spellInfo(spellID)
        if not spellID or not C_Spell or type(C_Spell.GetSpellInfo) ~= "function" then return nil, nil end
        local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
        if not ok or type(info) ~= "table" then return nil, nil end
        return info.name, info.iconID
    end

    local function entryIcon(entry)
        local _, icon = spellInfo(entry.spellIDs and entry.spellIDs[1])
        return icon or entry.icon or "Interface\\Icons\\INV_Misc_QuestionMark"
    end

    for _, entry in ipairs(entries) do
        local answer = L(entry.answer)
        local card = CreateFrame("Frame", nil, content, "BackdropTemplate")
        card:SetHeight(62)
        backdrop(card, C.panel, C.borderSoft)
        card.entry = entry
        card.entryKey = specializationKey .. ":" .. entry.question
        card.expanded = self.faqOpenTopics[card.entryKey] == true
        card.collapsedHeight = 62

        card.accent = card:CreateTexture(nil, "ARTWORK")
        themeTexture(card.accent, C.accent)
        card.accent:SetPoint("TOPLEFT", 0, -8)
        card.accent:SetPoint("BOTTOMLEFT", 0, 8)
        card.accent:SetWidth(2)
        card.accent:SetAlpha(card.expanded and 1 or 0.35)

        local iconFrame = CreateFrame("Frame", nil, card, "BackdropTemplate")
        iconFrame:SetSize(38, 38)
        iconFrame:SetPoint("TOPLEFT", 14, -12)
        backdrop(iconFrame, C.input, C.border)
        card.icon = iconFrame:CreateTexture(nil, "ARTWORK")
        card.icon:SetPoint("TOPLEFT", 2, -2)
        card.icon:SetPoint("BOTTOMRIGHT", -2, 2)
        card.icon:SetTexture(entryIcon(entry))
        card.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        local question = text(card, L(entry.question), 12, C.text, "OUTLINE")
        question:SetPoint("TOPLEFT", iconFrame, "TOPRIGHT", 12, -1)
        question:SetPoint("RIGHT", -54, 0)
        question:SetHeight(18)
        question:SetWordWrap(false)
        card.question = question

        local tag = text(card, L(entry.tag or "GUIDE"), 8, C.muted, "OUTLINE")
        tag:SetPoint("TOPLEFT", question, "BOTTOMLEFT", 0, -6)
        card.tag = tag

        local toggle = CreateFrame("Button", nil, card, "BackdropTemplate")
        toggle:SetSize(28, 28)
        toggle:SetPoint("TOPRIGHT", -14, -17)
        backdrop(toggle, C.input, C.border)
        toggle.label = text(toggle, "+", 17, C.accent, "OUTLINE")
        toggle.label:SetPoint("CENTER", 0, 0)

        local body = text(card, answer, 10, C.text)
        body:SetPoint("TOPLEFT", 64, -68)
        body:SetJustifyH("LEFT")
        body:SetJustifyV("TOP")
        body:SetWordWrap(true)
        card.body = body

        if entry.spellIDs and #entry.spellIDs > 0 then
            local related = text(card, L("ZUGEHÖRIGE ZAUBER"), 8, C.muted, "OUTLINE")
            card.related = related

            card.spells = {}
            for _, spellID in ipairs(entry.spellIDs) do
                local currentSpellID = spellID
                local spellName, spellIcon = spellInfo(currentSpellID)
                local spell = CreateFrame("Button", nil, card, "BackdropTemplate")
                spell:SetHeight(30)
                backdrop(spell, C.input, C.borderSoft)
                local texture = spell:CreateTexture(nil, "ARTWORK")
                texture:SetSize(24, 24)
                texture:SetPoint("LEFT", 3, 0)
                texture:SetTexture(spellIcon or "Interface\\Icons\\INV_Misc_QuestionMark")
                texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                local name = text(spell, spellName or ("#" .. currentSpellID), 9, C.text)
                name:SetPoint("LEFT", texture, "RIGHT", 6, 0)
                name:SetPoint("RIGHT", -6, 0)
                name:SetWordWrap(false)
                spell:SetScript("OnEnter", function(self)
                    self:SetBackdropColor(unpackColor(C.panelHover))
                    self:SetBackdropBorderColor(unpackColor(C.accent))
                    if GameTooltip and type(GameTooltip.SetSpellByID) == "function" then
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                        GameTooltip:SetSpellByID(currentSpellID)
                        GameTooltip:Show()
                    end
                end)
                spell:SetScript("OnLeave", function(self)
                    self:SetBackdropColor(unpackColor(C.input))
                    self:SetBackdropBorderColor(unpackColor(C.borderSoft))
                    if GameTooltip then GameTooltip:Hide() end
                end)
                card.spells[#card.spells + 1] = spell
            end
        end

        local hit = CreateFrame("Button", nil, card)
        hit:SetPoint("TOPLEFT")
        hit:SetPoint("TOPRIGHT")
        hit:SetHeight(62)

        cards[#cards + 1] = card
        local group = entry.group or "ALLGEMEIN"
        if not sections[group] then
            sections[group] = { group = group, cards = {} }
            sectionOrder[#sectionOrder + 1] = sections[group]
        end
        sections[group].cards[#sections[group].cards + 1] = card

        function card:RefreshExpandedLayout(width)
            if not self.expanded then
                self:SetHeight(self.collapsedHeight)
                return
            end
            local innerWidth = math.max(220, (tonumber(width) or self:GetWidth() or 700) - 84)
            self.body:SetWidth(innerWidth)
            local bodyHeight = math.max(30, math.ceil(self.body:GetStringHeight() or 0))
            self.body:SetHeight(bodyHeight)
            local height = 68 + bodyHeight + 18
            local spells = self.spells or {}
            if #spells > 0 then
                self.related:ClearAllPoints()
                self.related:SetPoint("TOPLEFT", 64, -(68 + bodyHeight + 10))
                local columns = innerWidth >= 570 and 3 or (innerWidth >= 360 and 2 or 1)
                local gap = 6
                local spellWidth = math.floor((innerWidth - ((columns - 1) * gap)) / columns)
                local top = 68 + bodyHeight + 30
                for spellIndex, spell in ipairs(spells) do
                    local column = (spellIndex - 1) % columns
                    local row = math.floor((spellIndex - 1) / columns)
                    spell:ClearAllPoints()
                    spell:SetWidth(spellWidth)
                    spell:SetPoint("TOPLEFT", 64 + (column * (spellWidth + gap)), -(top + (row * 36)))
                end
                height = top + (math.ceil(#spells / columns) * 36) + 10
            end
            self:SetHeight(math.max(self.collapsedHeight, height))
        end

        function card:SetExpanded(expanded, remember)
            self.expanded = expanded == true
            self.body:SetShown(self.expanded)
            if self.related then self.related:SetShown(self.expanded) end
            for _, spell in ipairs(self.spells or {}) do spell:SetShown(self.expanded) end
            toggle.label:SetText(self.expanded and "−" or "+")
            self:SetBackdropColor(unpackColor(self.expanded and C.panelHover or C.panel))
            self:SetBackdropBorderColor(unpackColor(self.expanded and C.accentDark or C.borderSoft))
            self.accent:SetAlpha(self.expanded and 1 or 0.35)
            self.question:SetTextColor(unpackColor(self.expanded and C.accent or C.text))
            if remember ~= false then
                HeliHeal.faqOpenTopics[self.entryKey] = self.expanded or nil
            end
            self:RefreshExpandedLayout(content:GetWidth())
        end
        local function toggleCard() card:SetExpanded(not card.expanded); page:RefreshFAQLayout() end
        hit:SetScript("OnClick", toggleCard)
        toggle:SetScript("OnClick", toggleCard)
        hit:SetScript("OnEnter", function() if not card.expanded then card:SetBackdropColor(unpackColor(C.panelHover)) end end)
        hit:SetScript("OnLeave", function() if not card.expanded then card:SetBackdropColor(unpackColor(C.panel)) end end)
        card:SetExpanded(card.expanded, false)
    end

    for _, sectionData in ipairs(sectionOrder) do
        local currentSection = sectionData
        currentSection.key = specializationKey .. ":" .. currentSection.group
        currentSection.expanded = self.faqOpenSections[currentSection.key] ~= false
        local header = CreateFrame("Button", nil, content, "BackdropTemplate")
        header:SetHeight(40)
        backdrop(header, C.input, C.borderSoft)
        header.icon = text(header, currentSection.expanded and "−" or "+", 16, C.accent, "OUTLINE")
        header.icon:SetPoint("LEFT", 14, 0)
        header.title = text(header, L(currentSection.group), 10, C.text, "OUTLINE")
        header.title:SetPoint("LEFT", 40, 1)
        header.count = text(header, (L("%d THEMEN • SPELL-GUIDE")):format(#currentSection.cards), 9, C.muted, "OUTLINE")
        header.count:SetPoint("RIGHT", -15, 0)
        currentSection.header = header
        currentSection.icon = header.icon
        currentSection.title = header.title

        function currentSection:SetExpanded(expanded, remember)
            self.expanded = expanded == true
            self.icon:SetText(self.expanded and "−" or "+")
            self.header:SetBackdropBorderColor(unpackColor(self.expanded and C.accentDark or C.borderSoft))
            self.title:SetTextColor(unpackColor(self.expanded and C.accent or C.text))
            if remember ~= false then
                HeliHeal.faqOpenSections[self.key] = self.expanded
            end
            for _, card in ipairs(self.cards) do card:SetShown(self.expanded) end
        end
        header:SetScript("OnClick", function() currentSection:SetExpanded(not currentSection.expanded); page:RefreshFAQLayout() end)
        header:SetScript("OnEnter", function(self) self:SetBackdropColor(unpackColor(C.panelHover)) end)
        header:SetScript("OnLeave", function(self) self:SetBackdropColor(unpackColor(C.input)) end)
        currentSection:SetExpanded(currentSection.expanded, false)
    end

    function page:RefreshFAQLayout()
        local offset = 0
        local contentWidth = math.max(1, content:GetWidth())
        for _, sectionData in ipairs(sectionOrder) do
            local header = sectionData.header
            header:ClearAllPoints()
            header:SetPoint("TOPLEFT", 0, -offset)
            header:SetPoint("TOPRIGHT", 0, -offset)
            offset = offset + 48
            if sectionData.expanded then
                for _, card in ipairs(sectionData.cards) do
                    card:RefreshExpandedLayout(contentWidth)
                    card:ClearAllPoints()
                    card:SetPoint("TOPLEFT", 8, -offset)
                    card:SetPoint("TOPRIGHT", -8, -offset)
                    offset = offset + card:GetHeight() + 8
                end
            end
            offset = offset + 6
        end
        content:SetHeight(math.max(1, offset))
    end

    local function setAllExpanded(expanded)
        for _, sectionData in ipairs(sectionOrder) do sectionData:SetExpanded(true) end
        for _, card in ipairs(cards) do card:SetExpanded(expanded) end
        page:RefreshFAQLayout()
    end
    expandAll:SetScript("OnClick", function() setAllExpanded(true) end)
    collapseAll:SetScript("OnClick", function() setAllExpanded(false) end)

    scroll:SetScript("OnSizeChanged", function(_, width)
        content:SetWidth(math.max(1, width))
        page:RefreshFAQLayout()
    end)
    page:SetScript("OnShow", function() page:RefreshFAQLayout() end)
    content:SetWidth(math.max(1, scroll:GetWidth()))
    page:RefreshFAQLayout()
    page.scroll = scroll
    page.cards = cards
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
        themeTexture(line, C.accent)
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
    self:ResolveOptionsWindowTheme()
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

    local function fitToScreen()
        local availableWidth = math.max(1, (UIParent:GetWidth() or 1040) - 24)
        local availableHeight = math.max(1, (UIParent:GetHeight() or 700) - 24)
        local requestedScale = math.max(0.65, math.min(1.35,
            tonumber(HeliHeal.db.global.optionsWindowScale) or ns.defaults.global.optionsWindowScale))
        window:SetScale(math.min(requestedScale, availableWidth / 1040, availableHeight / 700))
    end
    window:RegisterEvent("DISPLAY_SIZE_CHANGED")
    window:RegisterEvent("UI_SCALE_CHANGED")
    window:SetScript("OnEvent", fitToScreen)
    fitToScreen()

    window:SetScript("OnDragStart", function(self) self:StartMoving() end)
    window:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    window:SetScript("OnHide", function()
        if window.resizeGrip then window.resizeGrip:SetScript("OnUpdate", nil) end
        HeliHeal:EndKeyCapture()
        HeliHeal:HideWhatsNewModal(true)
        window.performanceLastCPU = nil
        window.performanceLastTime = nil
    end)

    local accentTop = window:CreateTexture(nil, "ARTWORK")
    accentTop:SetTexture(WHITE)
    themeTexture(accentTop, C.accent)
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
    themeTexture(separator, C.borderSoft)
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
        faq = self:BuildFAQPage(window.pagesHost),
        snapshots = self:BuildSnapshotsPage(window.pagesHost),
        procs = self:BuildProcsPage(window.pagesHost),
        changelog = self:BuildChangelogPage(window.pagesHost),
    }
    window.priorityPages = { [self.specializationID or 0] = window.pages.priorities }
    window.prioritiesSpecializationID = self.specializationID
    window.faqPages = { [self.specializationID or 0] = window.pages.faq }
    window.faqSpecializationID = self.specializationID

    window.navButtons = {}
    local navigation = {
        { "overview", L("ÜBERSICHT"), L("Anzeige & Verhalten") },
        { "style", L("HUD-ELEMENTE"), L("Icon, Hotkey & Cooldown") },
        { "priorities", L("PRIORITÄTEN"), L("Fähigkeiten & Inputs") },
        { "profiles", L("PROFILE & RESET"), L("Konfiguration verwalten") },
        { "faq", L("FAQ & GUIDE"), L("Spielweise & Ziele") },
        { "snapshots", L("SNAPSHOTS"), L("Rotations-Diagnose") },
        { "procs", "PROCS", "Background sources" },
        { "changelog", L("UPDATE-VERLAUF"), L("Was ist neu?") },
    }
    for index, item in ipairs(navigation) do
        local nav = CreateFrame("Button", nil, sidebar, "BackdropTemplate")
        nav:SetPoint("TOPLEFT", 14, -144 - ((index - 1) * 57))
        nav:SetPoint("TOPRIGHT", -14, -144 - ((index - 1) * 57))
        nav:SetHeight(50)
        backdrop(nav, C.sidebar, C.sidebar)
        nav.indicator = nav:CreateTexture(nil, "ARTWORK")
        nav.indicator:SetTexture(WHITE)
        themeTexture(nav.indicator, C.accent)
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
    themeTexture(statusDot, C.accent)
    statusDot:SetSize(7, 7)
    statusDot:SetPoint("BOTTOMLEFT", 22, 74)
    local status = text(sidebar, L("SECURE INPUT TRACKER"), 9, C.muted, "OUTLINE")
    status:SetPoint("LEFT", statusDot, "RIGHT", 8, 0)
    local privacy = text(sidebar, L("NO COMBAT DATA"), 9, C.dim)
    privacy:SetPoint("TOPLEFT", status, "BOTTOMLEFT", 0, -7)
    local performance = text(sidebar, "", 8, C.dim, "OUTLINE")
    performance:SetPoint("TOPLEFT", privacy, "BOTTOMLEFT", 0, -7)
    performance:SetWidth(200)
    performance:SetJustifyH("LEFT")
    window.performanceLabel = performance

    local function readableNumber(value)
        if type(value) ~= "number" then return nil end
        if type(issecretvalue) == "function" then
            local ok, secret = pcall(issecretvalue, value)
            if not ok or secret then return nil end
        end
        if type(canaccessvalue) == "function" then
            local ok, accessible = pcall(canaccessvalue, value)
            if not ok or not accessible then return nil end
        end
        return value
    end

    local function formatMemory(kilobytes)
        kilobytes = readableNumber(kilobytes)
        if not kilobytes then return L("nicht verfügbar") end
        if kilobytes >= 1024 then return ("%.2f MB"):format(kilobytes / 1024) end
        return ("%.0f KB"):format(kilobytes)
    end

    function window:RefreshPerformanceStats()
        local memoryKB
        if type(UpdateAddOnMemoryUsage) == "function" and type(GetAddOnMemoryUsage) == "function" then
            pcall(UpdateAddOnMemoryUsage)
            local ok, value = pcall(GetAddOnMemoryUsage, "HeliHeal")
            if ok then memoryKB = readableNumber(value) end
        end
        local memoryText = formatMemory(memoryKB)

        local profiling = false
        if type(GetCVarBool) == "function" then
            local profilingOK, profilingValue = pcall(GetCVarBool, "scriptProfile")
            profiling = profilingOK and profilingValue == true
        end
        if not profiling or type(UpdateAddOnCPUUsage) ~= "function" or type(GetAddOnCPUUsage) ~= "function" then
            self.performanceLabel:SetText(L("CPU: Profiling aus • Speicher: %s", memoryText))
            self.performanceLastCPU = nil
            self.performanceLastTime = nil
            return
        end

        pcall(UpdateAddOnCPUUsage)
        local ok, value = pcall(GetAddOnCPUUsage, "HeliHeal")
        local cpuMS = ok and readableNumber(value)
        local clock = type(GetTimePreciseSec) == "function" and GetTimePreciseSec or GetTime
        local clockOK, clockValue = type(clock) == "function" and pcall(clock)
        local now = clockOK and readableNumber(clockValue)
        local cpuPercent
        if cpuMS and now and self.performanceLastCPU and self.performanceLastTime
            and now > self.performanceLastTime and cpuMS >= self.performanceLastCPU then
            cpuPercent = ((cpuMS - self.performanceLastCPU) / ((now - self.performanceLastTime) * 1000)) * 100
            cpuPercent = math.max(0, math.min(999, cpuPercent))
        end
        self.performanceLastCPU = cpuMS
        self.performanceLastTime = now
        if cpuPercent then
            self.performanceLabel:SetText(L("CPU: %.2f%% • Speicher: %s", cpuPercent, memoryText))
        else
            self.performanceLabel:SetText(L("CPU: misst… • Speicher: %s", memoryText))
        end
    end

    window.performanceElapsed = 0
    window:SetScript("OnUpdate", function(self, elapsed)
        self.performanceElapsed = self.performanceElapsed + elapsed
        if self.performanceElapsed >= 3 then
            self.performanceElapsed = 0
            self:RefreshPerformanceStats()
        end
    end)

    local bottom = CreateFrame("Frame", nil, window, "BackdropTemplate")
    bottom:SetPoint("BOTTOMLEFT", sidebar, "BOTTOMRIGHT", 0, 1)
    bottom:SetPoint("BOTTOMRIGHT", -1, 1)
    bottom:SetHeight(57)
    backdrop(bottom, C.sidebar, C.borderSoft)
    local help = text(bottom, L("/hh öffnet dieses Fenster  •  ESC schließt es"), 10, C.muted)
    help:SetPoint("LEFT", 22, 0)
    local close = createButton(bottom, L("SCHLIESSEN"), 150, 36, true)
    close:SetPoint("RIGHT", -32, 0)
    close:SetScript("OnClick", function() window:Hide() end)

    local resizeGrip = CreateFrame("Button", nil, window)
    resizeGrip:SetSize(22, 22)
    resizeGrip:SetPoint("BOTTOMRIGHT", -2, 2)
    resizeGrip:SetFrameLevel(window:GetFrameLevel() + 30)
    resizeGrip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeGrip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeGrip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resizeGrip:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" then return end
        local cursorX, cursorY = GetCursorPosition()
        resizeGrip.resizeStartX = cursorX
        resizeGrip.resizeStartY = cursorY
        resizeGrip.resizeStartScale = window:GetScale()
        resizeGrip:SetScript("OnUpdate", function(grip)
            local currentX, currentY = GetCursorPosition()
            local uiScale = UIParent:GetEffectiveScale() or 1
            if uiScale <= 0 then uiScale = 1 end
            local horizontal = ((currentX - grip.resizeStartX) / uiScale) / 520
            local vertical = ((grip.resizeStartY - currentY) / uiScale) / 350
            local requestedScale = math.max(0.65, math.min(1.35,
                grip.resizeStartScale + ((horizontal + vertical) * 0.5)))
            local maxScale = math.min(1.35,
                math.max(1, (UIParent:GetWidth() or 1040) - 24) / 1040,
                math.max(1, (UIParent:GetHeight() or 700) - 24) / 700)
            window:SetScale(math.min(requestedScale, maxScale))
        end)
    end)
    resizeGrip:SetScript("OnMouseUp", function(_, button)
        if button ~= "LeftButton" then return end
        resizeGrip:SetScript("OnUpdate", nil)
        HeliHeal.db.global.optionsWindowScale = window:GetScale()
        fitToScreen()
    end)
    window.resizeGrip = resizeGrip

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

function HeliHeal:EnsurePriorityOptionsForSpecialization()
    local window = self.optionsWindow
    if not window then return end
    local specializationKey = self.specializationID or 0
    if window.prioritiesSpecializationID ~= self.specializationID then
        local current = window.pages.priorities
        if current then current:Hide() end
        local priorityPage = window.priorityPages[specializationKey]
        if not priorityPage then
            priorityPage = self:BuildPrioritiesPage(window.pagesHost)
            window.priorityPages[specializationKey] = priorityPage
        end
        window.pages.priorities = priorityPage
        window.prioritiesSpecializationID = self.specializationID
        priorityPage:SetShown(self.selectedOptionsPage == "priorities")
    end
    if window.faqSpecializationID ~= self.specializationID then
        local currentFAQ = window.pages.faq
        if currentFAQ then currentFAQ:Hide() end
        local faqPage = window.faqPages[specializationKey]
        if not faqPage then
            faqPage = self:BuildFAQPage(window.pagesHost)
            window.faqPages[specializationKey] = faqPage
        end
        window.pages.faq = faqPage
        window.faqSpecializationID = self.specializationID
        faqPage:SetShown(self.selectedOptionsPage == "faq")
    end
end

function HeliHeal:RefreshOptionsUI()
    local window = self.optionsWindow
    if not window then return end
    self:EnsurePriorityOptionsForSpecialization()

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
    if window.pages.profiles.RefreshProfiles then window.pages.profiles:RefreshProfiles() end
    if window.pages.snapshots.RefreshSnapshots then window.pages.snapshots:RefreshSnapshots() end

    local prioritiesPage = window.pages.priorities
    for presetKey, button in pairs(prioritiesPage.presetButtons or {}) do
        local active = presetKey == self.db.profile.rotationPreset
        button:SetSelected(active)
    end

    for modeKey, button in pairs(prioritiesPage.modeButtons or {}) do
        local active = modeKey == self:GetHealingMode()
        button:SetSelected(active)
    end
    local assignmentRow = prioritiesPage.assignmentRow
    if assignmentRow then
        local builds = self:GetTalentBuildsForCurrentSpec()
        local activeConfigID = self:GetActiveTalentBuildInfo()
        local buildOptions, valid = {}, {}
        for _, build in ipairs(builds) do
            valid[build.configID] = true
            buildOptions[#buildOptions + 1] = {
                value = build.configID,
                label = build.active and ("[" .. L("AKTIV") .. "] " .. build.name) or build.name,
            }
        end
        if not valid[prioritiesPage.assignmentConfigID] then
            prioritiesPage.assignmentConfigID = valid[activeConfigID] and activeConfigID
                or (builds[1] and builds[1].configID)
            prioritiesPage.loadedAssignmentConfigID = nil
        end
        assignmentRow.buildSelector:SetValues(buildOptions)

        if prioritiesPage.loadedAssignmentConfigID ~= prioritiesPage.assignmentConfigID then
            local selectedBinding = self:GetTalentBuildBinding(prioritiesPage.assignmentConfigID)
            prioritiesPage.assignmentPreset = selectedBinding and selectedBinding.rotationPreset
                or self.db.profile.rotationPreset
            prioritiesPage.assignmentMode = selectedBinding and selectedBinding.healingMode
                or self:GetHealingMode()
            prioritiesPage.loadedAssignmentConfigID = prioritiesPage.assignmentConfigID
        end
        assignmentRow.presetSelector:Refresh()
        assignmentRow.modeSelector:Refresh()

        local binding = self:GetTalentBuildBinding(prioritiesPage.assignmentConfigID)
        if binding then
            local presetButton = prioritiesPage.presetButtons[binding.rotationPreset]
            local modeButton = prioritiesPage.modeButtons[binding.healingMode]
            local presetLabel = presetButton and presetButton.presetLabel or binding.rotationPreset
            local modeLabel = modeButton and modeButton.label:GetText() or binding.healingMode
            assignmentRow.description:SetText(L("Verknüpft mit %s • %s", presetLabel, modeLabel))
        else
            assignmentRow.description:SetText(L("Noch nicht verknüpft. Preset und Modus wählen, dann verknüpfen."))
        end
        local hasBuild = prioritiesPage.assignmentConfigID ~= nil
        assignmentRow.assignButton:SetEnabled(hasBuild)
        assignmentRow.assignButton:SetAlpha(hasBuild and 1 or 0.45)
        assignmentRow.removeButton:SetEnabled(binding ~= nil)
        assignmentRow.removeButton:SetAlpha(binding and 1 or 0.45)
    end
    if prioritiesPage.manaAutoToggle then prioritiesPage.manaAutoToggle:Refresh() end
    if prioritiesPage.manaThresholdSlider then prioritiesPage.manaThresholdSlider:Refresh() end


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
                local y = -4 - ((visiblePriority - 1) * 37)
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", 10, y)
                row:SetPoint("TOPRIGHT", -10, y)
                row.priority:SetText(("%02d"):format(visiblePriority))
            end
            row.icon:SetTexture(ability.icon)
            row.icon:SetDesaturated(false)
            row.abilityName:SetText(ability.name)
            if ability.trackedDuration > 0 then
                local goal = self:GetTrackedGoal(ability)
                row.cooldownLabel:SetText(L("Lokale Laufzeit: %ss • Ziel: %d", ability.trackedDuration, goal))
            elseif (ability.recommendationLockout or 0) > 0 then
                row.cooldownLabel:SetText(L("Lokale Empfehlungspause: %ss", formatSeconds(ability.recommendationLockout)))
            else
                local holyLightTalents = ability.abilityKey == "paladin_holy_light"
                    and self:GetPaladinHolyLightTalentSummary() or nil
                row.cooldownLabel:SetText(holyLightTalents
                    or (ability.cooldown > 0 and L("Lokaler CD: %ss", formatSeconds(ability.cooldown))
                        or L("Filler • kein lokaler CD")))
            end
            local bindingKey = slot.derivedBindingFrom or slot.abilityKey
            local conflict = conflictsByAbility[bindingKey]
            if conflict then
                row.cooldownLabel:SetText(row.cooldownLabel:GetText() .. " • " .. L("HOTKEY DOPPELT"))
                row.cooldownLabel:SetTextColor(unpackColor(C.danger))
                row:SetBackdropBorderColor(unpackColor(C.danger))
            else
                row.cooldownLabel:SetTextColor(unpackColor(C.muted))
                row:SetBackdropBorderColor(unpackColor(C.borderSoft))
            end
            local derivedSourceEnabled = false
            local derivedSourceAbility
            if slot.derivedBindingFrom then
                local sourceIndex = self:GetSlotIndexByAbilityKey(slot.derivedBindingFrom)
                derivedSourceAbility = sourceIndex and self:GetSlot(sourceIndex)
                derivedSourceEnabled = derivedSourceAbility and derivedSourceAbility.enabled or false
            end
            if slot.derivedBindingFrom and derivedSourceEnabled then
                row.key.label:SetText(L("WIE %s", derivedSourceAbility.name or slot.derivedBindingFrom))
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
    if prioritiesPage.priorityContent then
        prioritiesPage.priorityContent:SetHeight(math.max(1, visiblePriority * 37 + 8))
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
    self.optionsWindow.performanceElapsed = 0
    if self.optionsWindow.RefreshPerformanceStats then self.optionsWindow:RefreshPerformanceStats() end
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
