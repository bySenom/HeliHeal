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
    bindings = {},
} }
addon.db.profile.slots = namespace.AbilityLibrary:BuildPresetSlots(addon.db.profile.rotationPreset, {})
assert(#addon.db.profile.slots == 11,
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
local voidShieldIndex = addon:GetSlotIndexByAbilityKey("disc_void_shield")
local evangelismIndex = addon:GetSlotIndexByAbilityKey("disc_evangelism")
local ultimateIndex = addon:GetSlotIndexByAbilityKey("disc_ultimate_penitence")
local barrierIndex = addon:GetSlotIndexByAbilityKey("disc_power_word_barrier")
local painSuppressionIndex = addon:GetSlotIndexByAbilityKey("disc_pain_suppression")
local shadowWordDeathIndex = addon:GetSlotIndexByAbilityKey("disc_shadow_word_death")
local smiteIndex = addon:GetSlotIndexByAbilityKey("disc_smite")

assert(addon:GetSlot(radianceIndex).cooldown == 12.5 and addon:GetSlot(radianceIndex).maxCharges == 2,
    "Bright Pupil, Light's Promise and 20% haste must produce two 12.5-second Radiance charges")
assert(addon:GetSlot(penanceIndex).cooldown == 7.5 and addon:GetSlot(penanceIndex).maxCharges == 2,
    "Oracle and 20% haste must produce two 7.5-second Penance charges")
assert(addon:GetSlot(mindBlastIndex).cooldown == 7.5,
    "Mind Blast's 9-second base cooldown must scale with cached haste")
assert(addon:GetSlot(voidShieldIndex).cooldown == 7.5,
    "Void Shield must retain its fixed 7.5-second Midnight cooldown")
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

local order = addon:GetDisplayOrder(now)
assert(order[1].ability.abilityKey == "disc_void_shield",
    "the standard Discipline priority must lead with ready Void Shield")
addon:AcknowledgeSlot(voidShieldIndex)
order = addon:GetDisplayOrder(now)
assert(order[1].ability.abilityKey == "disc_evangelism",
    "Evangelism must follow Void Shield in the static ramp priority")

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
