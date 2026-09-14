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
local global = namespace.defaults.global
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
    and profile.hotkeyBadgePadding == 16 and profile.compactHotkeys == true
    and profile.abilityNameWidth == 106,
    "element boxes must expose stable customizable defaults")
assert(profile.panelPaddingX == 2 and profile.panelPaddingY == 2
    and profile.panelBackgroundAlpha == 0.92,
    "panel padding and opacity must preserve the established presentation")
assert(profile.showSupportWindow == true and profile.supportWindowScale == 1
    and profile.supportWindowY == -250 and profile.supportWindowOrientation == "HORIZONTAL",
    "the separate Paladin support window must have stable visible defaults")
assert(profile.supportWindowIconWidth == 46 and profile.supportWindowIconHeight == 46
    and profile.spacing == 3 and profile.supportWindowSpacing == 3
    and profile.supportWindowIconZoom == 1,
    "the support window must expose its own layout defaults")
assert(profile.supportWindowShowIconBorder == true and profile.supportWindowShowHotkey == true
    and profile.supportWindowShowCooldown == true
    and profile.supportWindowShowHeader == false,
    "the support window must expose independent element visibility")
assert(profile.panelBackgroundColor[1] == 0.018 and profile.abilityNameColor[1] == 1.0
    and profile.headerColor[2] == 0.88 and profile.priorityColor[2] == 0.88,
    "panel and text elements must expose independent default colors")
assert(profile.roleColors.AOE[3] == 1 and profile.roleColors.BURST[1] == 1,
    "each contextual role must have an independent default color")
assert(global.optionsWindowScale == 1 and global.optionsWindowUseClassColor == false,
    "options window scale and class-color mode must have stable account-wide defaults")
assert(global.optionsWindowBackgroundColor[1] == 0.025
    and global.optionsWindowAccentColor[2] == 0.88,
    "options window background and accent colors must be persisted independently")

local optionsFile = assert(io.open("Options.lua", "rb"))
local optionsSource = optionsFile:read("*a")
optionsFile:close()
local displayFile = assert(io.open("Display.lua", "rb"))
local displaySource = displayFile:read("*a")
displayFile:close()
assert(optionsSource:find("optionsWindowScale", 1, true)
    and optionsSource:find('resizeGrip:SetScript%("OnMouseDown"'),
    "options window must expose a persisted bottom-right scale grip")
assert(optionsSource:find("optionsWindowUseClassColor", 1, true)
    and optionsSource:find("RAID_CLASS_COLORS", 1, true),
    "options window must support a persisted player-class accent")
assert(optionsSource:find('L%("GEFAHRENBEREICH"%)')
    and optionsSource:find("activeBar", 1, true)
    and optionsSource:find('L%("UI NEU LADEN"%)'),
    "profile management must separate active, maintenance and destructive actions visually")
assert(displaySource:find("profile%.showPanelBackground")
    and displaySource:find("profile%.iconBackgroundColor")
    and displaySource:find("profile%.abilityNameColor")
    and displaySource:find("profile%.headerColor")
    and displaySource:find("profile%.iconInset")
    and displaySource:find("profile%.hotkeyOffsetX")
    and displaySource:find("profile%.cooldownOffsetX")
    and displaySource:find("profile%.supportWindowOrientation == \"VERTICAL\"")
    and displaySource:find("profile%.supportWindowIconWidth")
    and displaySource:find("frame:SetScale%(profile%.supportWindowScale or 1%)"),
    "the Paladin support window must expose independent orientation, dimensions and scale")
assert(optionsSource:find('L%("DEF WINDOW"%)')
    and optionsSource:find("supportWindowShowHotkey", 1, true)
    and optionsSource:find("supportWindowPanelBackgroundAlpha", 1, true),
    "the options window must expose the independent DEF window controls")

print("Appearance config OK: independent dimensions, positions, zoom, text and colors")
