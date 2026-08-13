local addon = {}
local namespace = {}

LibStub = function(name)
    assert(name == "AceAddon-3.0")
    return { NewAddon = function() return addon end }
end
C_AddOns = {
    GetAddOnMetadata = function(addonName, field)
        assert(addonName == "HeliHeal" and field == "Version")
        return "0.8.5-alpha.1"
    end,
}

assert(loadfile("Changelog.lua"))("HeliHeal", namespace)
assert(loadfile("Core.lua"))("HeliHeal", namespace)

addon.db = {
    global = { lastSeenChangelogVersion = "0.8.4-alpha.1" },
    profile = {},
}

assert(namespace.changelog.currentVersion == addon:GetAddonVersion(),
    "TOC-facing addon version and local changelog version must match")
assert(namespace.changelog:GetEntry(addon:GetAddonVersion()),
    "current addon version must have a local changelog entry")
assert(addon:ShouldShowWhatsNew(), "a newer version must request the one-time popup")
addon:MarkChangelogSeen()
assert(not addon:ShouldShowWhatsNew(), "closing the popup must mark the current version as seen")

addon.db.profile = { name = "another profile" }
assert(not addon:ShouldShowWhatsNew(),
    "seen state must remain account-wide and independent from AceDB profiles")

print("Changelog OK: current entry, one-time popup state and account-wide persistence")
