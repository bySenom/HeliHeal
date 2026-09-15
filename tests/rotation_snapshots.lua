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
addon.inputGeneration = 1
addon.pendingAcknowledgements = { [3] = { observedAt = 0, generation = 1 } }
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

for attempt = 1, 6 do
    now = (attempt - 1) * 0.2
    assert(not addon:TrackRotationInputAttempt("BUTTON5", 3, now),
        "rapid spam during a normal cast must not create a snapshot")
end
assert(#addon.db.global.rotationSnapshots == 0,
    "six inputs without the three-second acknowledgement grace must be ignored")
now = 3
assert(addon:TrackRotationInputAttempt("BUTTON5", 3, now),
    "continued stable input after three seconds without acknowledgement must capture a snapshot")
assert(#addon.db.global.rotationSnapshots == 1, "automatic capture must persist one account-wide snapshot")
local snapshot = addon.db.global.rotationSnapshots[1]
assert(snapshot.report:find("suspected stuck rotation", 1, true)
    and snapshot.report:find("Holy Shock", 1, true)
    and snapshot.report:find("holyPower=3", 1, true)
    and snapshot.report:find("solidarity", 1, true),
    "the report must contain classification, recommendations, runtime state, and active talents")

now = 3.2
assert(not addon:TrackRotationInputAttempt("BUTTON5", 3, now)
    and #addon.db.global.rotationSnapshots == 1,
    "one unchanged candidate must not create duplicate snapshot spam")
addon.sessionHolyPower = 4
addon.lastAutomaticRotationSnapshot.capturedAt = now
addon.pendingAcknowledgements = { [3] = { observedAt = now, generation = 1 } }
addon:ResetRotationStuckCandidate()
addon:TrackRotationInputAttempt("BUTTON5", 3, now)
addon:RecordRotationInputFailure(3, 20473, now + 0.1)
addon:RecordRotationInputFailure(3, 20473, now + 0.2)
addon:RecordRotationInputFailure(3, 20473, now + 0.3)
assert(#addon.db.global.rotationSnapshots == 1,
    "the same primary ability must not create another snapshot when unrelated state changes")
addon:ResetRotationStuckCandidate()
assert(addon.rotationStuckCandidate == nil,
    "a confirmed cast can clear the diagnostic candidate without altering persisted snapshots")

order[1] = { slotIndex = 5, ability = order[2].ability, remaining = 0 }
now = 3.5
assert(not addon:TrackRotationInputAttempt("BUTTON5", 3, now)
    and addon.rotationStuckCandidate == nil,
    "a different primary recommendation must clear the stuck candidate")

order[1] = { slotIndex = 3, ability = ability, remaining = 0, charges = 1 }
addon.pendingAcknowledgements = { [9] = { observedAt = 0, generation = 1 } }
for attempt = 1, 8 do
    now = 4 + (attempt * 0.4)
    addon:TrackRotationInputAttempt("BUTTON5", 3, now)
end
assert(#addon.db.global.rotationSnapshots == 1,
    "an acknowledgement for another slot must never validate a stuck candidate")

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

now = 50
addon.sessionHolyPower = 0
addon.lastAutomaticRotationSnapshot = nil
addon.pendingAcknowledgements = { [3] = { observedAt = now, generation = 1 } }
for attempt = 1, 6 do
    addon:TrackRotationInputAttempt("BUTTON5", 3, now + ((attempt - 1) * 0.2))
end
assert(addon:RecordRotationAcknowledgementTimeout(3, addon.pendingAcknowledgements[3], now + 5),
    "six attempts without any Blizzard result must snapshot when acknowledgement expires")
assert(addon.db.global.rotationSnapshots[1].reason:find("timed out", 1, true),
    "timeout snapshots must identify the missing cast-result path")
addon:ClearRotationSnapshots()

now = 100
addon.sessionHolyPower = 4
addon.lastAutomaticRotationSnapshot = nil
addon.pendingAcknowledgements = { [3] = { observedAt = now, generation = 1 } }
addon:TrackRotationInputAttempt("BUTTON5", 3, now)
assert(not addon:RecordRotationInputFailure(3, 20473, now)
    and not addon:RecordRotationInputFailure(3, 20473, now + 0.2),
    "one or two Blizzard failures must not create a noisy snapshot")
assert(addon:RecordRotationInputFailure(3, 20473, now + 0.4),
    "three matching Blizzard failures must capture a cooldown-mismatch candidate")
assert(#addon.db.global.rotationSnapshots == 1
    and addon.db.global.rotationSnapshots[1].report:find("failures=3", 1, true)
    and addon.db.global.rotationSnapshots[1].reason:find("Blizzard repeatedly rejected", 1, true),
    "the failure snapshot must preserve its strong trigger evidence")

local armament = {
    abilityKey = "paladin_holy_armament", spellID = 432472, name = "Sacred Weapon",
    maxCharges = 2, cooldown = 60,
}
order[1] = { slotIndex = 1, ability = armament, remaining = 0, charges = 1 }
addon.sessionCharges[1] = { baseCharges = 1, bonusCharges = 0, nextRechargeAt = now + 50 }
addon.GetSlot = function(_, slotIndex) return slotIndex == 1 and armament or ability end
addon.GetChargeState = function(self, slotIndex) return self.sessionCharges[slotIndex] end
addon.pendingAcknowledgements = { [1] = { observedAt = now, generation = 1 } }
addon.lastAutomaticRotationSnapshot = nil
addon:ResetRotationStuckCandidate()
addon:TrackRotationInputAttempt("2", 1, now)
assert(not addon:RecordRotationInputFailure(1, 432472, now + 0.1)
        and not addon:RecordRotationInputFailure(1, 432472, now + 0.2),
    "a charged ability must retain its local charge before the third matching rejection")
assert(addon:RecordRotationInputFailure(1, 432472, now + 0.3)
        and addon.sessionCharges[1].baseCharges == 0
        and addon.sessionCharges[1].nextRechargeAt == now + 50
        and addon.sessionCharges[1].rejectedChargeReconciliations == 1,
    "three rejected charged-ability attempts must reconcile one phantom charge without restarting recharge")

print("Rotation snapshots OK: stable-input detection, diagnostic export, dedupe and storage cap")
