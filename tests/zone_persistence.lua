local addon = {}
local namespace = {}

LibStub = function(name)
    assert(name == "AceAddon-3.0")
    return { NewAddon = function() return addon end }
end

local specializationID = 264
UnitClass = function() return "Tester", "SHAMAN" end
GetSpecialization = function() return specializationID and 1 or nil end
GetSpecializationInfo = function() return specializationID end

assert(loadfile("Core.lua"))("HeliHeal", namespace)

addon.classToken = "SHAMAN"
addon.specializationID = 264
addon.supportedClass = true
addon.db = { profile = { rotationPreset = "shaman_totemic_mythicplus" } }
addon.RefreshDisplay = function() end
addon:ResetRuntimeState()

addon.sessionUses[2] = 120
addon.sessionCharges[3] = { baseCharges = 1, bonusCharges = 0, nextRechargeAt = 138 }
addon.sessionTimedEffects.rejuvenation = { 132, 136 }
addon.pendingSwiftness = { slotIndex = 4, expiresAt = 135 }
addon.riptideRechargeRateUntil = 128

assert(addon:CaptureZoneRuntimeState(), "supported specs must capture zone runtime")
addon.sessionCharges[3].baseCharges = 0
addon:ResetRuntimeState()
assert(addon:RestoreZoneRuntimeState(), "matching character state must restore after a loading screen")
assert(addon.sessionUses[2] == 120 and addon.sessionCharges[3].baseCharges == 1
    and addon.sessionCharges[3].nextRechargeAt == 138,
    "cooldowns and charge recharge timers must survive the transition")
assert(addon.sessionTimedEffects.rejuvenation[2] == 136
    and addon.pendingSwiftness.expiresAt == 135 and addon.riptideRechargeRateUntil == 128,
    "tracked effects and specialization windows must survive the transition")

specializationID = nil
assert(not addon:RefreshPlayerSupport(false),
    "temporarily unavailable specialization data must not look like a spec change")
assert(addon.supportedClass and addon.specializationID == 264,
    "a loading screen must retain the last valid specialization")

assert(addon:CaptureZoneRuntimeState())
addon.specializationID = 263
addon.supportedClass = false
assert(not addon:RestoreZoneRuntimeState(), "runtime must not cross specialization boundaries")

print("zone_persistence.lua: OK")
