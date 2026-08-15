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

print("display layout model: ok")
