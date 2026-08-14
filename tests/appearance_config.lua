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
assert(profile.roleLabelSize == 10 and profile.hotkeyFontSize == 9
    and profile.cooldownFontSize == 14,
    "appearance defaults must preserve the established text sizes")
assert(profile.roleColors.AOE[3] == 1 and profile.roleColors.BURST[1] == 1,
    "each contextual role must have an independent default color")

print("Appearance config OK: fonts, icon sizes, text sizes and role colors")
