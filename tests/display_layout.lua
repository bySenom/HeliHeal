local addon = {}
local namespace = {
    addon = addon,
    media = {
        font = "Fonts\\FRIZQT__.TTF",
        fonts = {},
    },
}

assert(loadfile("Display.lua"))("HeliHeal", namespace)

assert(addon:GetHotkeyBadgeOverhang(46, 70) == 12,
    "a badge wider than its icon must expose half of the extra width on each side")
assert(addon:GetHotkeyBadgeOverhang(62, 46) == 0,
    "a badge narrower than its icon must not add layout overhang")
assert(addon:GetBadgeAwareSpacing(46, 70, 46, 70, 7) == 26,
    "adjacent wide badges must receive enough room to avoid overlap")
assert(addon:GetBadgeAwareSpacing(46, 46, 46, 46, 12) == 12,
    "configured spacing must remain unchanged when badges already fit")
assert(addon:GetBadgeAwareSpacing(46, 70, 46, 70, 30) == 30,
    "configured spacing must win when it is larger than the required badge gap")
assert(addon:FormatHotkeyLabel("SHIFT-BUTTON1") == "S-M1",
    "modifier mouse bindings must use a compact HUD label")
assert(addon:FormatHotkeyLabel("CTRL-ALT-MOUSEWHEELDOWN") == "C-A-WD",
    "modifier mouse-wheel bindings must remain readable without widening the HUD")
assert(addon:FormatHotkeyLabel("R") == "R",
    "short keyboard bindings must remain unchanged")

GetCursorPosition = function() return 200, 100 end
UIParent = { GetEffectiveScale = function() return 2 end }
addon.db = {
    profile = {
        dispelCursorOffsetX = 24,
        dispelCursorOffsetY = -24,
    },
}
local positionUpdates = 0
local cursorFrame = {
    ClearAllPoints = function() end,
    SetPoint = function(_, point, parent, relativePoint, x, y)
        assert(point == "CENTER" and parent == UIParent and relativePoint == "BOTTOMLEFT")
        assert(x == 124 and y == 26, "cursor coordinates must account for UI scale and offsets")
        positionUpdates = positionUpdates + 1
    end,
}
assert(addon:UpdateDispelCursorPosition(cursorFrame),
    "the dispel cursor must accept a valid cursor position")
assert(addon:UpdateDispelCursorPosition(cursorFrame) and positionUpdates == 1,
    "an unchanged cursor must not trigger redundant layout work")

print("display layout model: ok")
