local namespace = {}

assert(loadfile("Namespace.lua"))("HeliHeal", namespace)
namespace.AbilityLibrary = {
    BuildPresetSlots = function(_, presetKey, bindings)
        assert(presetKey == "shaman_totemic_mythicplus" and type(bindings) == "table")
        return {}
    end,
}
assert(loadfile("Defaults.lua"))("HeliHeal", namespace)

local profile = namespace.defaults.profile
assert(namespace.media.fonts.friz.path == "Fonts\\FRIZQT__.TTF"
    and #namespace.media.fontOrder == 4,
    "HUD font catalog must expose stable built-in WoW fonts")
assert(profile.primaryIconSize == 62 and profile.secondaryIconSize == 46,
    "appearance defaults must preserve the established icon sizes")
assert(profile.primaryIconWidth == 62 and profile.primaryIconHeight == 62
    and profile.secondaryIconWidth == 46 and profile.secondaryIconHeight == 46,
    "independent icon dimensions must preserve the established square layout")
assert(profile.primaryIconZoom == 1 and profile.secondaryIconZoom == 1
    and profile.primaryIconOffsetX == 0 and profile.secondaryIconOffsetY == 0,
    "icon zoom and group offsets must retain the established appearance")
assert(profile.roleLabelSize == 10 and profile.hotkeyFontSize == 9
    and profile.cooldownFontSize == 14,
    "appearance defaults must preserve the established text sizes")
assert(profile.hotkeyBadgeHeight == 18 and profile.hotkeyBadgeMinWidth == 46
    and profile.hotkeyBadgePadding == 16 and profile.abilityNameWidth == 106,
    "element boxes must expose stable customizable defaults")
assert(profile.panelPaddingX == 2 and profile.panelPaddingY == 2
    and profile.panelBackgroundAlpha == 0.92,
    "panel padding and opacity must preserve the established presentation")
assert(profile.panelBackgroundColor[1] == 0.018 and profile.abilityNameColor[1] == 1.0
    and profile.headerColor[2] == 0.88 and profile.priorityColor[2] == 0.88,
    "panel and text elements must expose independent default colors")
assert(profile.roleColors.AOE[3] == 1 and profile.roleColors.BURST[1] == 1,
    "each contextual role must have an independent default color")

print("Appearance config OK: independent dimensions, positions, zoom, text and colors")
