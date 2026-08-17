local addon = {}
local namespace = { media = { fallbackIcon = 134400 } }

LibStub = function()
    return { NewAddon = function() return addon end }
end

local now = 0
GetTime = function() return now end

assert(loadfile("AbilityLibrary.lua"))("HeliHeal", namespace)
assert(loadfile("Classes/Priest.lua"))("HeliHeal", namespace)
assert(loadfile("Core.lua"))("HeliHeal", namespace)
assert(loadfile("Display.lua"))("HeliHeal", namespace)

addon.classToken = "PRIEST"
addon.specializationID = 257
addon.db = {
    profile = {
        rotationPreset = "priest_archon_mythicplus",
        healingMode = "standard",
        bindings = {},
    },
}
addon.db.profile.slots = namespace.AbilityLibrary:BuildPresetSlots(addon.db.profile.rotationPreset, {})
addon:ResetRuntimeState()
addon.talentSnapshot = {
    available = true,
    priestArchon = true,
    priestOracle = false,
    priestSanctify = true,
    priestPrayerOfHealing = true,
    priestChastise = true,
    priestUltimateSerenity = false,
    priestMiracleWorker = true,
    priestEternalSanctity = true,
    priestHolyCelerity = true,
    priestVoiceHarmony = true,
    priestLightNaaru = true,
    priestLightNaaruRank = 2,
    priestProphetInsight = false,
    priestApotheosis = true,
    priestDivineHymn = true,
    priestGuardianSpirit = true,
}
addon.IsTalentActive = function(self, key)
    return self.talentSnapshot.available and self.talentSnapshot[key] == true
end
addon.GetTalentRank = function(self, key)
    return tonumber(self.talentSnapshot[key .. "Rank"])
        or (self:IsTalentActive(key) and 1 or 0)
end
addon.RefreshDisplay = function() end
addon.RefreshOptionsUI = function() end
addon.Print = function() end

local serenityIndex = addon:GetSlotIndexByAbilityKey("priest_holy_word_serenity")
local sanctifyIndex = addon:GetSlotIndexByAbilityKey("priest_holy_word_sanctify")
local flashIndex = addon:GetSlotIndexByAbilityKey("priest_flash_heal")
local prayerIndex = addon:GetSlotIndexByAbilityKey("priest_prayer_of_healing")
local mendingIndex = addon:GetSlotIndexByAbilityKey("priest_prayer_of_mending")
local apotheosisIndex = addon:GetSlotIndexByAbilityKey("priest_apotheosis")
local haloIndex = addon:GetSlotIndexByAbilityKey("priest_halo")

assert(addon:GetSlot(serenityIndex).cooldown == 45 and addon:GetSlot(serenityIndex).maxCharges == 2,
    "Holy Celerity and Miracle Worker must produce two 45-second Serenity charges")
assert(addon:GetSlot(sanctifyIndex).cooldown == 45 and addon:GetSlot(sanctifyIndex).maxCharges == 2,
    "Holy Celerity and Miracle Worker must produce two 45-second Sanctify charges")
assert(addon:GetSlot(mendingIndex).cooldown == 12 and addon:GetSlot(mendingIndex).maxCharges == 1,
    "Archon Prayer of Mending must retain its correct 12-second single charge")
assert(addon:GetSlot(haloIndex).enabled and addon:GetSlot(haloIndex).cooldown == 60,
    "Archon Halo must use its Midnight 60-second cooldown")

local order = addon:GetDisplayOrder(now)
assert(order[1].ability.abilityKey == "priest_holy_word_serenity",
    "a capped Serenity charge must be spent before a ready Apotheosis")
addon:AcknowledgeSlot(serenityIndex)
local serenityState = addon:GetChargeState(serenityIndex, addon:GetSlot(serenityIndex), now)
assert(serenityState.baseCharges == 1 and serenityState.nextRechargeAt == 45,
    "spending Serenity must start its 45-second recharge")
order = addon:GetDisplayOrder(now)
assert(order[1].ability.abilityKey == "priest_holy_word_sanctify",
    "a capped Sanctify charge must be spent before Apotheosis while Serenity is held at one")
addon:AcknowledgeSlot(flashIndex)
assert(math.abs(serenityState.nextRechargeAt - 37.8) < 0.001,
    "Flash Heal must reduce Serenity by 6 seconds plus two Light of the Naaru ranks")

addon:AcknowledgeSlot(sanctifyIndex)
local sanctifyState = addon:GetChargeState(sanctifyIndex, addon:GetSlot(sanctifyIndex), now)
addon:AcknowledgeSlot(prayerIndex)
assert(math.abs(sanctifyState.nextRechargeAt - 37.8) < 0.001,
    "Prayer of Healing must reduce Sanctify by the talented 7.2 seconds")

now = 5
addon:AcknowledgeSlot(apotheosisIndex)
assert(serenityState.baseCharges == 2 and not serenityState.nextRechargeAt
    and sanctifyState.baseCharges == 2 and not sanctifyState.nextRechargeAt,
    "Apotheosis with Miracle Worker must grant one Holy Word charge")
assert(addon.priestApotheosisUntil == 37,
    "Eternal Sanctity must extend the 20-second Apotheosis window to 32 seconds")
addon:AcknowledgeSlot(serenityIndex)
addon:AcknowledgeSlot(flashIndex)
serenityState = addon:GetChargeState(serenityIndex, addon:GetSlot(serenityIndex), now)
assert(math.abs(serenityState.nextRechargeAt - 28.4) < 0.001,
    "Apotheosis must triple the talented Flash Heal cooldown reduction")

addon:SetRotationPreset("priest_oracle_mythicplus")
addon.talentSnapshot.priestArchon = false
addon.talentSnapshot.priestOracle = true
addon.talentSnapshot.priestProphetInsight = true
addon.talentSnapshot.priestUltimateSerenity = true
addon.talentSnapshot.priestSanctify = false
serenityIndex = addon:GetSlotIndexByAbilityKey("priest_holy_word_serenity")
sanctifyIndex = addon:GetSlotIndexByAbilityKey("priest_holy_word_sanctify")
mendingIndex = addon:GetSlotIndexByAbilityKey("priest_prayer_of_mending")
assert(addon:GetSlot(serenityIndex).cooldown == 40,
    "Holy Celerity and Prophet's Insight must reduce Oracle Serenity to 40 seconds")
assert(addon:GetSlot(mendingIndex).maxCharges == 2,
    "Oracle Guiding Light must grant the second Prayer of Mending charge")
assert(not addon:GetSlot(sanctifyIndex).enabled and not addon:GetSlotIndexByAbilityKey("priest_halo"),
    "Ultimate Serenity must hide Sanctify and Oracle presets must not include Halo")

addon:ResetRuntimeState()
addon:AcknowledgeSlot(serenityIndex)
addon:AcknowledgeSlot(addon:GetSlotIndexByAbilityKey("priest_prayer_of_healing"))
local ultimateState = addon:GetChargeState(serenityIndex, addon:GetSlot(serenityIndex), now)
assert(math.abs(ultimateState.nextRechargeAt - 37.8) < 0.001,
    "Ultimate Serenity must redirect Prayer of Healing cooldown reduction to Serenity")

print("priest_rotation.lua: OK")
