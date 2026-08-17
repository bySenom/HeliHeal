local namespace = {
    addon = {},
    L = function(value) return value end,
    media = { font = "Fonts\\FRIZQT__.TTF" },
}

assert(loadfile("Options.lua"))("HeliHeal", namespace)

local addon = namespace.addon
local scripts = {}
local button = {
    label = { SetText = function() end },
    EnableKeyboard = function() end,
    EnableMouseWheel = function() end,
    SetPropagateKeyboardInput = function() end,
    SetBackdropBorderColor = function() end,
    SetScript = function(_, event, handler) scripts[event] = handler end,
}

local captureStarts = 0
addon.BeginKeyCapture = function()
    captureStarts = captureStarts + 1
end
button.captureOnClick = function(clicked)
    addon:HandleKeyCaptureClick(clicked, 1)
end

addon.RefreshOptionsUI = function()
    -- Mirrors the priority-page refresher, which restores the regular handler.
    button:SetScript("OnClick", button.captureOnClick)
end
addon.keyCaptureButton = button
addon.suspendInput = true

addon:EndKeyCapture(true)
assert(button.ignoreNextCaptureClick == true,
    "capturing LeftButton must arm a one-click guard")

scripts.OnClick(button)
assert(captureStarts == 0 and button.ignoreNextCaptureClick == nil,
    "the OnClick paired with the captured LeftButton must be consumed")

scripts.OnClick(button)
assert(captureStarts == 1,
    "the following deliberate click must open key capture normally")

addon.keyCaptureButton = button
addon:EndKeyCapture(false)
scripts.OnClick(button)
assert(captureStarts == 2,
    "keyboard and wheel capture must not consume the next deliberate click")

print("Key capture OK: BUTTON1 commit does not reopen or clear its binding")
