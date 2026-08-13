local function loadLocale(locale)
    local namespace = { media = { fallbackIcon = 134400 } }
    GetLocale = function() return locale end
    assert(loadfile("Localization.lua"))("HeliHeal", namespace)
    return namespace
end

local german = loadLocale("deDE")
assert(german.L("Übersicht") == "Übersicht", "deDE must retain German UI text")
assert(german.L("What's New and Update History") == "Neuigkeiten und Update-Verlauf",
    "deDE must localize English changelog titles")
assert(not german.localeFallback, "deDE must be a native HeliHeal locale")

local english = loadLocale("enUS")
assert(english.L("Übersicht") == "Overview", "enUS must translate the German source key")
assert(english.L("Heilmodus: %s", "AoE") == "Healing mode: AoE",
    "formatted localization values must preserve arguments")
assert(not english.localeFallback, "enUS must be a native HeliHeal locale")

local french = loadLocale("frFR")
assert(french.L("Übersicht") == "Overview",
    "unsupported client locales must receive a complete English fallback, never German UI")
assert(french.localeFallback, "fallback locale must be visible in diagnostics")

local namespace = loadLocale("deDE")
C_Spell = {
    GetSpellInfo = function(spellID)
        assert(spellID == 61295)
        return { name = "Springflut", iconID = 12345 }
    end,
}
assert(loadfile("AbilityLibrary.lua"))("HeliHeal", namespace)
namespace.AbilityLibrary:RegisterAbility("riptide", { spellID = 61295, name = "Riptide" })
local resolved = namespace.AbilityLibrary:Resolve({ spellID = 61295, name = "Riptide", enabled = true })
assert(resolved.name == "Springflut" and resolved.icon == 12345,
    "Blizzard spell metadata must override hardcoded fallback names for every client locale")

print("Localization OK: deDE, enUS, fallback locale and Blizzard-localized spell names")
