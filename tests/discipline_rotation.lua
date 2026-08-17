local addon = {}
local namespace = { media = { fallbackIcon = 134400 } }

LibStub = function()
    return { NewAddon = function() return addon end }
end

local now = 0
GetTime = function() return now end

assert(loadfile("AbilityLibrary.lua"))("HeliHeal", namespace)
assert(loadfile("Classes/Priest.lua"))("HeliHeal", namespace)
assert(loadfile("Classes/DisciplinePriest.lua"))("HeliHeal", namespace)
assert(loadfile("Core.lua"))("HeliHeal", namespace)
assert(loadfile("Input.lua"))("HeliHeal", namespace)
assert(loadfile("Display.lua"))("HeliHeal", namespace)

addon.classToken = "PRIEST"
addon.specializationID = 256
addon.cachedSpellHaste = 20
addon.db = { profile = {
    rotationPreset = "disc_oracle_mythicplus",
    rotationDataVersion = 12111,
    healingMode = "standard",
    bindings = {
        disc_power_word_radiance = "R",
        disc_power_word_shield = "S",
    },
} }
addon.db.profile.slots = namespace.AbilityLibrary:BuildPresetSlots(
    addon.db.profile.rotationPreset, addon.db.profile.bindings)
assert(#addon.db.profile.slots == 10,
    "Discipline presets must expose every bindable static ability without overflowing the options page")
addon:ResetRuntimeState()
addon.talentSnapshot = {
    available = true,
    priestOracle = true,
    discVoidweaver = false,
    discEvangelism = true,
    discVoidShield = true,
    discLightsPromise = true,
    discBrightPupil = true,
    discUltimatePenitence = true,
    discPowerWordBarrier = false,
    discPainSuppression = true,
}
addon.IsTalentActive = function(self, key)
    return self.talentSnapshot.available and self.talentSnapshot[key] == true
end
addon.GetTalentRank = function(self, key) return self:IsTalentActive(key) and 1 or 0 end
addon.RefreshDisplay = function() end
addon.RefreshOptionsUI = function() end
addon.Print = function() end

local radianceIndex = addon:GetSlotIndexByAbilityKey("disc_power_word_radiance")
local penanceIndex = addon:GetSlotIndexByAbilityKey("disc_penance")
local mindBlastIndex = addon:GetSlotIndexByAbilityKey("disc_mind_blast")
local evangelismIndex = addon:GetSlotIndexByAbilityKey("disc_evangelism")
local ultimateIndex = addon:GetSlotIndexByAbilityKey("disc_ultimate_penitence")
local barrierIndex = addon:GetSlotIndexByAbilityKey("disc_power_word_barrier")
local painSuppressionIndex = addon:GetSlotIndexByAbilityKey("disc_pain_suppression")
local shadowWordDeathIndex = addon:GetSlotIndexByAbilityKey("disc_shadow_word_death")
local smiteIndex = addon:GetSlotIndexByAbilityKey("disc_smite")
local shieldIndex = addon:GetSlotIndexByAbilityKey("disc_power_word_shield")

assert(addon:GetSlot(radianceIndex).cooldown == 12.5 and addon:GetSlot(radianceIndex).maxCharges == 2,
    "Bright Pupil, Light's Promise and 20% haste must produce two 12.5-second Radiance charges")
assert(addon:GetSlot(penanceIndex).cooldown == 7.5 and addon:GetSlot(penanceIndex).maxCharges == 2,
    "Oracle and 20% haste must produce two 7.5-second Penance charges")
assert(addon:GetSlot(mindBlastIndex).cooldown == 7.5,
    "Mind Blast's 9-second base cooldown must scale with cached haste")
assert(addon:GetSlot(evangelismIndex).cooldown == 90,
    "Evangelism must use its 90-second Midnight cooldown")
assert(addon:GetSlot(painSuppressionIndex).cooldown == 180,
    "Pain Suppression must use its three-minute Midnight cooldown")
assert(addon:GetSlot(shadowWordDeathIndex).cooldown == 20,
    "Shadow Word: Death must use its 20-second Midnight cooldown")
assert(addon:GetSlot(ultimateIndex).enabled and not addon:GetSlot(barrierIndex).enabled,
    "the selected Ultimate Penitence choice must hide Power Word: Barrier")
assert(addon:GetSlot(ultimateIndex).cooldown == 240,
    "Ultimate Penitence must use its four-minute cooldown")
assert(addon:GetSlot(barrierIndex).cooldown == 180,
    "Power Word: Barrier must retain its three-minute cooldown when selected")
assert(addon:SlotAcceptsSpell(addon.db.profile.slots[smiteIndex], 450215),
    "the Smite binding must confirm its Void Blast action-bar override")
assert(addon:SlotAcceptsSpell(addon.db.profile.slots[radianceIndex], 246097),
    "Radiance must accept its instant Midnight override cast")
assert(addon:SlotAcceptsSpell(addon.db.profile.slots[shieldIndex], 1253593),
    "Power Word: Shield must accept the Master the Darkness Void Shield override")

local order = addon:GetDisplayOrder(now)
assert(order[1].ability.abilityKey == "disc_evangelism",
    "the standard Discipline priority must begin its static ramp with Evangelism")

addon:ObserveInputKey("R")
assert(addon:RecordPlayerSpellSucceeded(246097),
    "the instant Radiance override must confirm its configured input")
local radianceState = addon:GetChargeState(radianceIndex, addon:GetSlot(radianceIndex), now)
assert(radianceState.baseCharges == 1,
    "the first instant Radiance must spend exactly one of two charges")
now = 2
addon:ReleaseInputKey("R")
addon:ObserveInputKey("R")
assert(addon:RecordPlayerSpellSucceeded(194509),
    "normal Radiance must confirm through the same configured slot")
radianceState = addon:GetChargeState(radianceIndex, addon:GetSlot(radianceIndex), now)
assert(radianceState.baseCharges == 0 and radianceState.nextRechargeAt,
    "the recommendation must leave the ready queue after both Radiance charges are spent")

addon:ObserveInputKey("S")
assert(addon:RecordPlayerSpellSucceeded(1253593),
    "a successful Void Shield override must confirm Power Word: Shield")
local shieldState = addon:GetTrackedState(addon:GetSlot(shieldIndex), now)
assert(shieldState.count == 1,
    "Power Word: Shield must leave the ready queue after either shield variant succeeds")

addon:SetRotationPreset("disc_voidweaver_mythicplus")
addon.talentSnapshot.priestOracle = false
addon.talentSnapshot.discVoidweaver = true
penanceIndex = addon:GetSlotIndexByAbilityKey("disc_penance")
assert(addon:GetSlot(penanceIndex).maxCharges == 1,
    "Voidweaver must not receive Oracle's additional Penance charge")
local ranks = addon:GetActivePriorityRanks()
assert(ranks.disc_mind_blast < ranks.disc_penance,
    "Voidweaver must prioritize Mind Blast before Penance")

addon:SetRotationPreset("priest_archon_mythicplus")
assert(addon.db.profile.rotationPreset == "disc_voidweaver_mythicplus",
    "Discipline must reject Holy Priest presets")

addon.db.profile.rotationPreset = "priest_archon_mythicplus"
addon:EnsureRotationProfile()
assert(addon.db.profile.rotationPreset == "disc_oracle_mythicplus",
    "Discipline must recover from a stored Holy preset with its default Oracle preset")

addon.specializationID = 257
addon:EnsureRotationProfile()
assert(addon.db.profile.rotationPreset == "priest_archon_mythicplus",
    "Holy must recover from a stored Discipline preset with its own default")

addon.specializationID = 256
addon.db.profile.rotationPreset = "priest_oracle_raid"
addon:EnsureRotationProfile()
assert(addon.db.profile.rotationPreset == "disc_oracle_raid",
    "switching from Holy Raid to Discipline must preserve the selected content type")
addon.specializationID = 257
addon:EnsureRotationProfile()
assert(addon.db.profile.rotationPreset == "priest_archon_raid",
    "switching back to Holy must continue preserving Raid content")

print("discipline_rotation.lua: OK")
