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
assert(loadfile("Display.lua"))("HeliHeal", namespace)

addon.classToken = "SHAMAN"
addon.db = {
    profile = {
        rotationPreset = "shaman_totemic_mythicplus",
        healingMode = "standard",
        bindings = {
            healing_stream_combo = "BUTTON5",
            natures_swiftness = "SHIFT-3",
            unleash_life = "SHIFT-4",
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
addon.talentSnapshot = {
    available = true,
    mysticKnowledge = false,
    unleashLife = true,
    totemicMomentum = true,
}
addon.IsTalentActive = function(self, key) return self.talentSnapshot[key] == true end
addon.RefreshDisplay = function() end
addon.Print = function() end

local hstIndex = addon:GetSlotIndexByAbilityKey("healing_stream_combo")
local swiftnessIndex = addon:GetSlotIndexByAbilityKey("natures_swiftness")
local hst = addon:GetSlot(hstIndex)
assert(hst.cooldown == 17, "Totemic Momentum must reduce Healing Stream Totem to 17 seconds")
addon.talentSnapshot.totemicMomentum = false
assert(addon:GetSlot(hstIndex).cooldown == 20,
    "Farseer without Totemic Momentum must keep the 20-second base recharge")
addon.talentSnapshot.totemicMomentum = true
hst = addon:GetSlot(hstIndex)
local state = addon:GetChargeState(hstIndex, hst, now)
assert(state.baseCharges == 2 and state.bonusCharges == 0, "sequence must start at 2/2")

assert(addon:RecordPlayerSpellSucceeded(1267068),
    "an unreadable random Stormstream proc must still be recognized when the player uses it")
state = addon:GetChargeState(hstIndex, hst, now)
assert(state.baseCharges == 2 and state.bonusCharges == 0,
    "an observed random Stormstream cast must not consume a normal Healing Stream charge")

now = 1
local swiftnessSlot = addon:GetSlot(swiftnessIndex)
assert(swiftnessSlot.confirmOnPlayerSuccess,
    "Nature's Swiftness must accept its off-GCD player success without relying on the action hook")
assert(addon:RecordPlayerSpellSucceeded(378081),
    "Nature's Swiftness success must confirm the configured SHIFT-3 recommendation directly")
assert(addon.pendingSwiftness and addon.pendingSwiftness.slotIndex == swiftnessIndex,
    "confirmed Nature's Swiftness must arm its local consumer state")
for _, item in ipairs(addon:GetDisplayOrder(now)) do
    assert(item.ability.abilityKey ~= "natures_swiftness",
        "confirmed Nature's Swiftness must immediately leave the recommendations")
end
state = addon:GetChargeState(hstIndex, hst, now)
assert(state.baseCharges == 2 and state.bonusCharges == 1,
    "Nature's Swiftness must create one effective Stormstream use at 3/2")

now = 2
addon:ObserveInputKey("BUTTON5")
assert(addon:CommitObservedSpell(1267068), "Stormstream cast ID 1267068 must confirm BUTTON5")
state = addon:GetChargeState(hstIndex, hst, now)
assert(state.baseCharges == 2 and state.bonusCharges == 0,
    "Stormstream must consume only the synthetic use and leave exactly two normal HST charges")

now = 3
addon:ReleaseInputKey("BUTTON5")
addon.inputLockedUntil[hstIndex] = nil
addon:ObserveInputKey("BUTTON5")
assert(addon:CommitObservedSpell(5394), "normal Healing Stream cast must confirm with spell ID 5394")
state = addon:GetChargeState(hstIndex, hst, now)
assert(state.baseCharges == 1 and state.bonusCharges == 0,
    "the first normal HST after Stormstream must leave one normal charge")

now = 4
addon:ReleaseInputKey("BUTTON5")
addon.inputLockedUntil[hstIndex] = nil
addon:ObserveInputKey("BUTTON5")
assert(addon:CommitObservedSpell(5394), "second normal Healing Stream cast must confirm")
state = addon:GetChargeState(hstIndex, hst, now)
assert(state.baseCharges == 0 and state.bonusCharges == 0,
    "only two normal HST casts may remain after the Stormstream use")

local unleashIndex = addon:GetSlotIndexByAbilityKey("unleash_life")
assert(addon.db.profile.slots[unleashIndex].inputKey == "SHIFT-4",
    "the Unleash Life regression must exercise a modifier binding")
now = 5
assert(addon:RecordPlayerSpellSucceeded(73685),
    "Unleash Life success must confirm directly when its action hook is missed")
assert(addon.sessionUses[unleashIndex] == now and addon.pendingUnleash,
    "confirmed Unleash Life must start its cooldown and arm the local consumer state")
local unleashOrder = addon:GetDisplayOrder(now)
assert(unleashOrder[1].ability.abilityKey ~= "unleash_life",
    "confirmed Unleash Life must immediately leave the ready recommendation")
local unleashPreview
for _, item in ipairs(unleashOrder) do
    if item.ability.abilityKey == "unleash_life" then unleashPreview = item end
end
assert(not unleashPreview or unleashPreview.remaining > 0,
    "Unleash Life may remain only as an explicitly cooling-down preview")

now = 6
assert(addon:RecordPlayerSpellSucceeded(188196),
    "a successful Lightning Bolt must consume an armed shaman Nature's Swiftness")
assert(not addon.pendingSwiftness and addon.sessionUses[swiftnessIndex] == now,
    "shaman Nature's Swiftness cooldown must begin on its confirmed Nature-spell consumer")

-- Assisted Combat can emit the instant consumer before its off-GCD
-- Nature's Swiftness success. The two successes still belong to one button
-- action and must start the cooldown without waiting for another Nature cast.
addon.pendingSwiftness = nil
addon.sessionUses[swiftnessIndex] = nil
addon.recentAssistedSwiftnessConsumer = nil
C_ActionBar = {
    IsAssistedCombatAction = function(slotID) return slotID == 1 end,
    GetActionBarPage = function() return 1 end,
}
C_AssistedCombat = { GetNextCastSpell = function() return 1064 end }
now = 10
assert(addon:ObserveAssistedCombatBinding("ACTIONBUTTON1"),
    "the test action must be recognized as One Button Assistant")
assert(addon:RecordPlayerSpellSucceeded(1064),
    "the OBA consumer must be confirmed even when Swiftness reports later")
assert(not addon.pendingSwiftness and addon.sessionUses[swiftnessIndex] == nil,
    "the consumer alone must not invent an armed Swiftness state")
now = 10.05
assert(addon:RecordPlayerSpellSucceeded(378081),
    "the delayed off-GCD Swiftness success must still be confirmed")
assert(not addon.pendingSwiftness and addon.sessionUses[swiftnessIndex] == 10,
    "the delayed Swiftness event must start its cooldown at the correlated OBA consumer")

print("Stormstream sequence OK: 2/2 -> 3/2 -> Stormstream -> exactly two normal HST uses")
