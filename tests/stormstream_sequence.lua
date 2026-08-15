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
addon.talentSnapshot = { available = true, mysticKnowledge = false, unleashLife = true }
addon.IsTalentActive = function(self, key) return self.talentSnapshot[key] == true end
addon.RefreshDisplay = function() end
addon.Print = function() end

local hstIndex = addon:GetSlotIndexByAbilityKey("healing_stream_combo")
local swiftnessIndex = addon:GetSlotIndexByAbilityKey("natures_swiftness")
local hst = addon:GetSlot(hstIndex)
assert(hst.cooldown == 17, "Healing Stream Totem must recharge every 17 seconds")
local state = addon:GetChargeState(hstIndex, hst, now)
assert(state.baseCharges == 2 and state.bonusCharges == 0, "sequence must start at 2/2")

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

local unleashIndex = addon:GetSlotIndexByAbilityKey("unleash_life")
assert(addon.db.profile.slots[unleashIndex].inputKey == "SHIFT-4",
    "the Unleash Life regression must exercise a modifier binding")
now = 4
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

print("Stormstream sequence OK: 2/2 -> 3/2 -> Stormstream -> exactly two normal HST uses")
