local namespace = {
    addon = {},
    L = function(value) return value end,
    media = { font = "Fonts\\FRIZQT__.TTF" },
}

assert(loadfile("Options.lua"))("HeliHeal", namespace)

local addon = namespace.addon
local beginKeyCapture = addon.BeginKeyCapture
UISpecialFrames = { "OtherWindow", "HeliHealOptionsWindow" }
addon.optionsWindow = { GetName = function() return "HeliHealOptionsWindow" end }
local scripts = {}
local button = {
    label = { SetText = function() end },
    EnableKeyboard = function() end,
    EnableMouseWheel = function() end,
    SetPropagateKeyboardInput = function() end,
    SetBackdropBorderColor = function() end,
    GetWidth = function() return 210 end,
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

local progressWidth, progressShown = 0, false
button.clearHoldProgress = {
    SetWidth = function(_, width) progressWidth = width end,
    Show = function() progressShown = true end,
    Hide = function() progressShown = false end,
}
local clearedBinding
addon.SetAbilityBinding = function(_, slotIndex, binding)
    assert(slotIndex == 3, "clear hold must target the captured ability slot")
    clearedBinding = binding
end
addon.RefreshOptionsUI = function() end
addon.BeginKeyCapture = beginKeyCapture
addon:BeginKeyCapture(button, 3)
assert(#UISpecialFrames == 1 and UISpecialFrames[1] == "OtherWindow",
    "key capture must temporarily disable the options window's global Escape close")
scripts.OnKeyDown(button, "ESCAPE")
assert(progressShown and scripts.OnUpdate,
    "holding Escape must start the visible clear progress")
scripts.OnUpdate(button, 0.75)
assert(clearedBinding == nil and progressWidth > 1,
    "a partial hold must animate without clearing the binding")
scripts.OnKeyUp(button, "ESCAPE")
assert(not progressShown and clearedBinding == nil,
    "releasing Escape early must cancel the clear operation")
assert(#UISpecialFrames == 1,
    "releasing Escape early must keep the window protected while capture remains active")

scripts.OnKeyDown(button, "ESCAPE")
scripts.OnUpdate(button, 1.5)
assert(clearedBinding == "" and addon.keyCaptureButton == nil,
    "holding Escape for 1.5 seconds must clear and close capture")
assert(#UISpecialFrames == 2 and UISpecialFrames[2] == "HeliHealOptionsWindow",
    "ending capture must restore the options window's normal Escape close behavior")

print("Key capture OK: BUTTON1 guard and hold-Escape clearing")
