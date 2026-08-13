local addon = {}
local namespace = { media = { fallbackIcon = 134400 } }

LibStub = function()
    return { NewAddon = function() return addon end }
end

local now = 0
GetTime = function() return now end

assert(loadfile("AbilityLibrary.lua"))("HeliHeal", namespace)
assert(loadfile("Classes/Paladin.lua"))("HeliHeal", namespace)
assert(loadfile("Core.lua"))("HeliHeal", namespace)
assert(loadfile("Display.lua"))("HeliHeal", namespace)

addon.classToken = "PALADIN"
addon.db = {
    profile = {
        rotationPreset = "paladin_herald_mythicplus",
        healingMode = "standard",
        bindings = {},
    },
}
addon.db.profile.slots = namespace.AbilityLibrary:BuildPresetSlots(addon.db.profile.rotationPreset, {})
addon:ResetRuntimeState()
addon.talentSnapshot = {
    available = true,
    paladinHerald = true,
    paladinLightsmith = false,
    paladinDivineToll = true,
    paladinHolyPrism = false,
    paladinQuickenedInvocation = true,
    paladinLightsConviction = true,
}
addon.IsTalentActive = function(self, key)
    return self.talentSnapshot.available and self.talentSnapshot[key] == true
end
addon.RefreshDisplay = function() end
addon.RefreshOptionsUI = function() end
addon.Print = function() end

local tollIndex = addon:GetSlotIndexByAbilityKey("paladin_divine_toll")
local shockIndex = addon:GetSlotIndexByAbilityKey("paladin_holy_shock")
local flameIndex = addon:GetSlotIndexByAbilityKey("paladin_eternal_flame")
local dawnIndex = addon:GetSlotIndexByAbilityKey("paladin_light_of_dawn")
local flashIndex = addon:GetSlotIndexByAbilityKey("paladin_flash_of_light")

assert(addon:GetSlot(tollIndex).cooldown == 45,
    "Quickened Invocation must reduce Divine Toll to 45 seconds")
assert(addon:GetSlot(shockIndex).maxCharges == 2,
    "Light's Conviction must keep two Holy Shock charges")

local order = addon:GetDisplayOrder(now)
assert(order[1].ability.abilityKey == "paladin_divine_toll",
    "Herald Mythic+ must open with its available low-Holy-Power cooldown")
for _, item in ipairs(order) do
    assert((item.ability.holyPowerCost or 0) == 0,
        "Holy Power spenders must stay hidden below three Holy Power")
end

addon:AcknowledgeSlot(tollIndex)
assert(addon.sessionHolyPower == 3, "Divine Toll must add three locally estimated Holy Power")
order = addon:GetDisplayOrder(now)
assert(order[1].ability.abilityKey == "paladin_holy_shock",
    "Holy Shock must precede the normal spender below the five-point cap")

addon:AcknowledgeSlot(shockIndex)
assert(addon.sessionHolyPower == 4, "Holy Shock must add one locally estimated Holy Power")
order = addon:GetDisplayOrder(now)
assert(order[1].ability.abilityKey == "paladin_holy_shock",
    "the second Holy Shock charge must remain ahead of the spender below cap")

addon:AcknowledgeSlot(shockIndex)
assert(addon.sessionHolyPower == 5, "the second Holy Shock must cap the local estimate")
order = addon:GetDisplayOrder(now)
assert(order[1].ability.abilityKey == "paladin_eternal_flame",
    "Herald Mythic+ must force Eternal Flame first at five Holy Power")

addon:AcknowledgeSlot(flameIndex)
assert(addon.sessionHolyPower == 2, "Eternal Flame must spend three local Holy Power")
addon:AcknowledgeSlot(flashIndex)
assert(addon.sessionHolyPower == 3, "Flash of Light must generate one local Holy Power")
addon:AcknowledgeSlot(flameIndex)
assert(addon.sessionHolyPower == 0, "a spender at three Holy Power must return the estimate to zero")
order = addon:GetDisplayOrder(now)
for _, item in ipairs(order) do
    assert(item.ability.abilityKey ~= "paladin_eternal_flame"
        and item.ability.abilityKey ~= "paladin_light_of_dawn",
        "spenders must hide again after falling below three Holy Power")
end

addon:SetRotationPreset("paladin_lightsmith_raid")
addon.talentSnapshot.paladinHerald = false
addon.talentSnapshot.paladinLightsmith = true
addon.talentSnapshot.paladinDivineToll = false
local armamentIndex = addon:GetSlotIndexByAbilityKey("paladin_holy_armament")
local wordIndex = addon:GetSlotIndexByAbilityKey("paladin_word_of_glory")
assert(addon:GetSlot(armamentIndex).enabled and addon:GetSlot(armamentIndex).cooldown == 45,
    "Lightsmith must expose its two-charge Holy Armament with Quickened Invocation")
assert(addon:GetSlot(wordIndex).enabled and not addon:GetSlotIndexByAbilityKey("paladin_eternal_flame"),
    "Lightsmith must use Word of Glory instead of Eternal Flame")
assert(namespace.AbilityLibrary:GetPresetPriorityKeys("paladin_lightsmith_raid", "standard")[3]
        == "paladin_light_of_dawn",
    "Raid standard mode must prioritize Light of Dawn as its spender")

print("paladin_rotation.lua: OK")
