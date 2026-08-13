local addon = {}
local namespace = { media = { fallbackIcon = 134400 } }

LibStub = function()
    return { NewAddon = function() return addon end }
end

local now = 0
GetTime = function() return now end
IsControlKeyDown = function() return false end
IsAltKeyDown = function() return false end
IsShiftKeyDown = function() return false end
C_Spell = {
    GetSpellCooldown = function()
        return { startTime = now, duration = 1.0, isEnabled = true, modRate = 1 }
    end,
}
C_Timer = {
    NewTimer = function(_, callback)
        local timer = { callback = callback }
        function timer:Cancel() self.cancelled = true end
        return timer
    end,
}

assert(loadfile("AbilityLibrary.lua"))("HeliHeal", namespace)
assert(loadfile("Classes/Shaman.lua"))("HeliHeal", namespace)
assert(loadfile("Core.lua"))("HeliHeal", namespace)
assert(loadfile("Input.lua"))("HeliHeal", namespace)

addon.classToken = "SHAMAN"
addon.db = {
    profile = {
        rotationPreset = "shaman_totemic_mythicplus",
        healingMode = "standard",
        bindings = {
            healing_stream_combo = "BUTTON5",
            natures_swiftness = "SHIFT-1",
        },
    },
}
addon.db.profile.slots = namespace.AbilityLibrary:BuildPresetSlots(
    addon.db.profile.rotationPreset, addon.db.profile.bindings)
addon.sessionUses = {}
addon.sessionCharges = {}
addon.sessionSpendHistory = {}
addon.pendingAcknowledgements = {}
addon.heldInputKeys = {}
addon.inputLockedUntil = {}
addon.talentSnapshot = { available = true, mysticKnowledge = false }
addon.IsTalentActive = function(self, key) return self.talentSnapshot[key] == true end
addon.RefreshDisplay = function() end
addon.Print = function() end

local hstIndex = addon:GetSlotIndexByAbilityKey("healing_stream_combo")
local swiftnessIndex = addon:GetSlotIndexByAbilityKey("natures_swiftness")
local hst = addon:GetSlot(hstIndex)
local state = addon:GetChargeState(hstIndex, hst, now)
assert(state.baseCharges == 2 and state.bonusCharges == 0, "sequence must start at 2/2")

addon:AcknowledgeSlot(swiftnessIndex)
state = addon:GetChargeState(hstIndex, hst, now)
assert(state.baseCharges == 2 and state.bonusCharges == 1,
    "Nature's Swiftness must create one effective Stormstream use at 3/2")

now = 1
addon:ObserveInputKey("BUTTON5")
assert(addon:CommitObservedSpell(1267068), "Stormstream cast ID 1267068 must confirm BUTTON5")
state = addon:GetChargeState(hstIndex, hst, now)
assert(state.baseCharges == 2 and state.bonusCharges == 0,
    "Stormstream must consume only the synthetic use and leave exactly two normal HST charges")

now = 2
addon:ReleaseInputKey("BUTTON5")
addon.inputLockedUntil[hstIndex] = nil
addon:ObserveInputKey("BUTTON5")
assert(addon:CommitObservedSpell(5394), "normal Healing Stream cast must confirm with spell ID 5394")
state = addon:GetChargeState(hstIndex, hst, now)
assert(state.baseCharges == 1 and state.bonusCharges == 0,
    "the first normal HST after Stormstream must leave one normal charge")

now = 3
addon:ReleaseInputKey("BUTTON5")
addon.inputLockedUntil[hstIndex] = nil
addon:ObserveInputKey("BUTTON5")
assert(addon:CommitObservedSpell(5394), "second normal Healing Stream cast must confirm")
state = addon:GetChargeState(hstIndex, hst, now)
assert(state.baseCharges == 0 and state.bonusCharges == 0,
    "only two normal HST casts may remain after the Stormstream use")

print("Stormstream sequence OK: 2/2 -> 3/2 -> Stormstream -> exactly two normal HST uses")
