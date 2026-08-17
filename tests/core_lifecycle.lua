local addon = {}
local namespace = {}

LibStub = function(name)
    assert(name == "AceAddon-3.0")
    return {
        NewAddon = function()
            return addon
        end,
    }
end

local classToken = "SHAMAN"
local specializationID = 264
UnitClass = function() return "Tester", classToken end
GetSpecialization = function() return specializationID and 1 or nil end
GetSpecializationInfo = function() return specializationID end

assert(loadfile("Core.lua"))("HeliHeal", namespace)

assert(addon:RefreshPlayerSupport(false), "initial Restoration Shaman snapshot must be detected")
assert(addon.supportedClass and addon.specializationID == 264,
    "only Restoration Shaman must be supported for the Shaman class")

specializationID = 262
assert(addon:RefreshPlayerSupport(false) and not addon.supportedClass,
    "Elemental Shaman must not display a healing rotation")

classToken = "DRUID"
specializationID = 105
assert(addon:RefreshPlayerSupport(false) and addon.supportedClass,
    "Restoration Druid must be supported")

specializationID = 103
assert(addon:RefreshPlayerSupport(false) and not addon.supportedClass,
    "Feral Druid must not display a healing rotation")

classToken = "PALADIN"
specializationID = 65
assert(addon:RefreshPlayerSupport(false) and addon.supportedClass,
    "Holy Paladin must be supported")

specializationID = 66
assert(addon:RefreshPlayerSupport(false) and not addon.supportedClass,
    "Protection Paladin must not display a healing rotation")

classToken = "PRIEST"
specializationID = 257
assert(addon:RefreshPlayerSupport(false) and addon.supportedClass,
    "Holy Priest must be supported")

specializationID = 256
assert(addon:RefreshPlayerSupport(false) and addon.supportedClass,
    "Discipline Priest must be supported with its own priority pack")

specializationID = 258
assert(addon:RefreshPlayerSupport(false) and not addon.supportedClass,
    "Shadow Priest must not display a healing priority pack")

local cancelled = false
addon.pendingAcknowledgements = {
    [1] = { timer = { Cancel = function() cancelled = true end } },
}
addon.CancelPendingAcknowledgements = function(self)
    for slotIndex, pending in pairs(self.pendingAcknowledgements) do
        pending.timer:Cancel()
        self.pendingAcknowledgements[slotIndex] = nil
    end
end
addon.inputGeneration = 7
addon.heldInputKeys = { BUTTON5 = true }
addon.mouseHeldInputs = { Button5 = "BUTTON5" }
addon.inputLockedUntil = { [1] = 99 }
addon.recentSuccessfulSpells = { [5394] = 1 }
addon.lastObservedInputs = { BUTTON5 = 1 }
addon:ResetRuntimeState()

assert(cancelled, "runtime reset must cancel pending acknowledgement timers")
assert(addon.inputGeneration == 8, "runtime reset must invalidate stale asynchronous callbacks")
assert(not next(addon.heldInputKeys) and not next(addon.mouseHeldInputs),
    "runtime reset must clear keyboard and mouse held latches")
assert(not next(addon.inputLockedUntil) and not next(addon.recentSuccessfulSpells),
    "runtime reset must clear lockouts and instant-cast success cache")
assert(not next(addon.lastObservedInputs),
    "runtime reset must clear per-binding debounce timestamps")

print("Core lifecycle OK: healer-spec gating and complete local-state reset")
