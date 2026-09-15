local addon = {}
local namespace = { addon = addon }

local now = 0
GetTime = function() return now end
GetServerTime = function() return 1789473600 end
date = function() return "2026-09-15 12:00:00" end

assert(loadfile("Snapshots.lua"))("HeliHeal", namespace)

addon.db = {
    global = { rotationSnapshots = {} },
    profile = {
        rotationPreset = "paladin_lightsmith_mythicplus",
        healingMode = "standard",
    },
}
addon.classToken = "PALADIN"
addon.specializationID = 65
addon.supportedClass = true
addon.sessionHolyPower = 3
addon.pendingAcknowledgements = {}
addon.sessionUses = {}
addon.sessionCharges = {}
addon.sessionTimedEffects = {}
addon.sessionSpendHistory = {}
addon.paladinArmamentExpirations = {}
addon.paladinNextArmamentType = "bulwark"
addon.talentSnapshot = { available = true, configID = 123, solidarity = true }
addon.GetHealingMode = function(self) return self.db.profile.healingMode end
addon.GetPaladinInfusionCharges = function() return 1 end
addon.BuildDiagnosticReport = function() return "version=1.0.1; preset=paladin_lightsmith_mythicplus" end

local ability = { abilityKey = "paladin_holy_shock", spellID = 20473, name = "Holy Shock" }
local order = {
    { slotIndex = 3, ability = ability, remaining = 0, charges = 1 },
    { slotIndex = 5, ability = { abilityKey = "paladin_judgment", spellID = 275773, name = "Judgment" }, remaining = 0 },
}
addon.GetDisplayOrder = function() return order end

for attempt = 1, 5 do
    now = (attempt - 1) * 0.5
    assert(not addon:TrackRotationInputAttempt("BUTTON5", 3, now),
        "a snapshot must not be captured before the repeated-input threshold")
end
now = 2.5
assert(addon:TrackRotationInputAttempt("BUTTON5", 3, now),
    "six stable primary inputs inside four seconds must capture a snapshot")
assert(#addon.db.global.rotationSnapshots == 1, "automatic capture must persist one account-wide snapshot")
local snapshot = addon.db.global.rotationSnapshots[1]
assert(snapshot.report:find("suspected stuck rotation", 1, true)
    and snapshot.report:find("Holy Shock", 1, true)
    and snapshot.report:find("holyPower=3", 1, true)
    and snapshot.report:find("solidarity", 1, true),
    "the report must contain classification, recommendations, runtime state, and active talents")

now = 3
assert(not addon:TrackRotationInputAttempt("BUTTON5", 3, now)
    and #addon.db.global.rotationSnapshots == 1,
    "one unchanged candidate must not create duplicate snapshot spam")
addon:ResetRotationStuckCandidate()
assert(addon.rotationStuckCandidate == nil,
    "a confirmed cast can clear the diagnostic candidate without altering persisted snapshots")

order[1] = { slotIndex = 5, ability = order[2].ability, remaining = 0 }
now = 3.5
assert(not addon:TrackRotationInputAttempt("BUTTON5", 3, now)
    and addon.rotationStuckCandidate == nil,
    "a different primary recommendation must clear the stuck candidate")

local manual = addon:CaptureRotationSnapshot("Manual snapshot", { inputKey = "manual" }, now)
assert(manual.reason == "Manual snapshot" and #addon.db.global.rotationSnapshots == 2,
    "manual capture must use the same persisted report format")

for index = 1, 25 do
    now = now + 1
    addon:CaptureRotationSnapshot("cap test " .. index, {}, now)
end
assert(#addon.db.global.rotationSnapshots == 20, "snapshot storage must be capped at twenty records")
addon:ClearRotationSnapshots()
assert(#addon.db.global.rotationSnapshots == 0, "clear must remove all locally stored snapshots")

print("Rotation snapshots OK: stable-input detection, diagnostic export, dedupe and storage cap")
