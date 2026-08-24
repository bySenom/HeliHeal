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
assert(addon:GetChoiceBadgeBottomOffset(false, 9, 4) == 4,
    "the choice badge must sit just above the icons when ability names are hidden")
assert(addon:GetChoiceBadgeBottomOffset(true, 9, 4) == 15,
    "the choice badge must clear a visible ability name")
assert(addon:GetChoiceBadgeBottomOffset(true, 12, 10) == 24,
    "the choice badge must respect customized ability-name size and offset")
assert(addon:FormatHotkeyLabel("SHIFT-BUTTON1") == "S-M1",
    "modifier mouse bindings must use a compact HUD label")
assert(addon:FormatHotkeyLabel("CTRL-ALT-MOUSEWHEELDOWN") == "C-A-WD",
    "modifier mouse-wheel bindings must remain readable without widening the HUD")
assert(addon:FormatHotkeyLabel("R") == "R",
    "short keyboard bindings must remain unchanged")

local situationalPair = {
    { ability = { choiceGroup = "healing_filler" }, remaining = 0 },
    { ability = { choiceGroup = "healing_filler" }, remaining = 0 },
}
assert(addon:GetPrimaryChoiceGroup(situationalPair, "standard") == "healing_filler",
    "two ready abilities in one choice group must form a Standard-mode choice pair")
assert(not addon:GetPrimaryChoiceGroup(situationalPair, "aoe"),
    "explicit AoE mode must preserve its ordered priority instead of showing an equal choice")
situationalPair[2].remaining = 3
assert(not addon:GetPrimaryChoiceGroup(situationalPair, "standard"),
    "a cooling-down alternative must not form a ready choice pair")

addon.db = { profile = { autoManaMode = true } }
addon.Mana = { autoModeActive = true, current = 20000, maximum = 100000 }
addon.GetHealingMode = function() return "mana" end
assert(addon:ShouldShowAutomaticManaBadge(),
    "the HUD must identify an automatically activated Mana Saving mode")
addon.Mana.autoModeActive = false
assert(addon:ShouldShowAutomaticManaBadge(),
    "the HUD must expose the armed automatic mode and its estimate before activation")
addon.db.profile.autoManaMode = false
assert(not addon:ShouldShowAutomaticManaBadge(),
    "the automatic status badge must hide when the feature is disabled")

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
