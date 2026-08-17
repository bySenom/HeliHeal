local addon = {}
local namespace = { media = { fallbackIcon = 134400 } }

LibStub = function(name)
    assert(name == "AceAddon-3.0")
    return { NewAddon = function() return addon end }
end
GetTime = function() return 100 end
InCombatLockdown = function() return false end
C_AddOns = { GetAddOnMetadata = function(_, field) return field == "Version" and "test" or nil end }
GetBuildInfo = function() return "12.1", "12.1.0" end

assert(loadfile("AbilityLibrary.lua"))("HeliHeal", namespace)
assert(loadfile("Classes/Shaman.lua"))("HeliHeal", namespace)
assert(loadfile("Core.lua"))("HeliHeal", namespace)

local profile = {
    healingMode = "AOE",
    primaryIconSize = 77,
    secondaryIconSize = 41,
    bindings = {},
    slots = {
        { spellID = 5394, inputKey = " button5 " },
    },
}
addon.db = { profile = profile }
assert(addon:MigrateProfile(profile), "legacy profile must migrate exactly once")
assert(profile.schemaVersion == 3 and profile.rotationDataVersion == 12112,
    "migration must stamp the schema and rotation data versions")
assert(profile.primaryIconWidth == 77 and profile.primaryIconHeight == 77
    and profile.secondaryIconWidth == 41 and profile.secondaryIconHeight == 41,
    "migration must preserve legacy icon sizes as independent dimensions")
assert(profile.bindings.healing_stream_combo == "BUTTON5" and profile.healingMode == "aoe",
    "migration must preserve and normalize legacy bindings and modes")
assert(not addon:MigrateProfile(profile), "current profiles must not migrate repeatedly")

profile.rotationPreset = "shaman_totemic_mythicplus"
profile.bindings = { healing_stream_combo = "BUTTON5", riptide = "BUTTON5", healing_rain = "SHIFT-5" }
profile.slots = namespace.AbilityLibrary:BuildPresetSlots(profile.rotationPreset, profile.bindings)
local chainIndex = addon:GetSlotIndexByAbilityKey("chain_heal")
local waveIndex = addon:GetSlotIndexByAbilityKey("healing_wave")
assert(addon:GetSlot(chainIndex).roleLabel == "AOE" and addon:GetSlot(waveIndex).roleLabel == "SINGLE",
    "Shaman filler role labels must survive preset resolution")
local conflicts = addon:GetBindingConflicts()
assert(#conflicts == 1 and conflicts[1].inputKey == "BUTTON5",
    "two independent abilities on one key must be reported")
assert(conflicts[1].abilityKeys.healing_stream_combo and conflicts[1].abilityKeys.riptide,
    "conflict must identify both independent abilities")
assert(not conflicts[1].abilityKeys.downpour,
    "derived bindings must never create a false conflict")

addon.sessionUses = { [1] = 60, [3] = 95 }
addon.sessionCharges = {}
addon.sessionSpendHistory = {}
addon.sessionTimedEffects = {}
addon.pendingAcknowledgements = { [1] = {} }
addon.recentSuccessfulSpells = { [5394] = 99 }
addon.heldInputKeys = { BUTTON5 = true }
addon.mouseHeldInputs = { Button5 = "BUTTON5" }
addon.inputLockedUntil = { [1] = 105 }
addon.unleashConsumptionHistory = {}
addon.RefreshDisplay = function() end
assert(addon:ReconcileOutOfCombatState(true), "out-of-combat reconciliation must run")
assert(not addon.sessionUses[1] and addon.sessionUses[3] == 95,
    "reconciliation must expire finished cooldowns without deleting active estimates")
assert(not next(addon.pendingAcknowledgements) and not next(addon.heldInputKeys),
    "reconciliation must clear stale input observations and held-key latches")

local report = addon:BuildDiagnosticReport()
assert(report:find("version=test", 1, true) and report:find("conflicts=BUTTON5", 1, true),
    "diagnostic report must include version and binding conflicts")
assert(not report:find("health", 1, true) and not report:find("target", 1, true),
    "diagnostic report must remain independent of combat-unit data")

print("Profile integrity OK: migration, conflicts, reconciliation and diagnostics")
