local addon = {}
local namespace = { media = { fallbackIcon = 134400 } }

LibStub = function()
    return { NewAddon = function() return addon end }
end

local now = 0
GetTime = function() return now end

assert(loadfile("AbilityLibrary.lua"))("HeliHeal", namespace)
assert(loadfile("Classes/Shaman.lua"))("HeliHeal", namespace)
assert(loadfile("Core.lua"))("HeliHeal", namespace)
assert(loadfile("Display.lua"))("HeliHeal", namespace)

addon.db = {
    profile = {
        rotationPreset = "shaman_totemic_mythicplus",
        healingMode = "standard",
        bindings = { healing_rain = "SHIFT-5" },
    },
}
addon.db.profile.slots = namespace.AbilityLibrary:BuildPresetSlots(addon.db.profile.rotationPreset, addon.db.profile.bindings)
addon.sessionUses = {}
addon.sessionCharges = {}
addon.sessionSpendHistory = {}
addon.pendingSwiftness = nil
addon.pendingDownpour = nil
addon.talentSnapshot = {
    available = true,
    surgingTotem = true,
    downpour = true,
    unleashLife = false,
}
addon.IsTalentActive = function(self, key)
    return self.talentSnapshot.available and self.talentSnapshot[key] == true
end
addon.RefreshDisplay = function() end
addon.RefreshOptionsUI = function() end
addon.Print = function() end

local riptideIndex = addon:GetSlotIndexByAbilityKey("riptide")
assert(addon:GetSlot(riptideIndex).cooldown == 6, "Totemic Riptide must use the six-second base recharge")
addon.talentSnapshot.ripCurrent = true
assert(addon:GetSlot(riptideIndex).cooldown == 5,
    "Rip Current must reduce Totemic Riptide recharge to five seconds")
addon.talentSnapshot.ripCurrent = false
local chainIndex = addon:GetSlotIndexByAbilityKey("chain_heal")
local waveIndex = addon:GetSlotIndexByAbilityKey("healing_wave")
assert(addon:GetSlot(chainIndex).choiceGroup == "shaman_healing_filler"
    and addon:GetSlot(waveIndex).choiceGroup == "shaman_healing_filler",
    "Chain Heal and Healing Wave must resolve as one situational filler choice")

local function firstKey()
    return addon:GetDisplayOrder(now)[1].ability.abilityKey
end

assert(firstKey() == "healing_stream_combo", "standard must retain the existing preset as default")
addon:SetHealingMode("single", true)
assert(firstKey() == "riptide", "single-target mode must be an optional reordered view")
addon:SetHealingMode("mana", true)
assert(firstKey() == "healing_stream_combo", "mana mode must remain selectable")
local manaKeys = namespace.AbilityLibrary:GetPresetPriorityKeys("shaman_totemic_mythicplus", "mana")
assert(table.concat(manaKeys, ",") == table.concat({
    "healing_stream_combo", "riptide", "unleash_life", "natures_swiftness", "healing_wave",
}, ","), "mana mode must expose only the conservative five-ability priority")
for _, abilityKey in ipairs(manaKeys) do
    assert(abilityKey ~= "chain_heal" and abilityKey ~= "surging_totem"
        and abilityKey ~= "healing_rain" and abilityKey ~= "downpour",
        "mana mode must not leak expensive group spenders or setup spells")
end

addon:SetHealingMode("aoe", true)
local rainIndex = addon:GetSlotIndexByAbilityKey("healing_rain")
local downpourIndex = addon:GetSlotIndexByAbilityKey("downpour")
assert(rainIndex and downpourIndex, "context pack must contain Healing Rain and derived Downpour")
assert(not addon:GetSlot(rainIndex).enabled,
    "Totemic must hide Healing Rain when Surging Totem replaces it")

-- Farseer retains the regular Healing Rain -> Downpour interaction.
addon.db.profile.rotationPreset = "shaman_farseer_mythicplus"
addon.db.profile.slots = namespace.AbilityLibrary:BuildPresetSlots(
    addon.db.profile.rotationPreset, addon.db.profile.bindings)
addon.resolvedSlotCache = {}
addon.activePriorityRanksCache = nil
addon.talentSnapshot.surgingTotem = false
rainIndex = addon:GetSlotIndexByAbilityKey("healing_rain")
downpourIndex = addon:GetSlotIndexByAbilityKey("downpour")
assert(addon:GetSlot(rainIndex).enabled, "Farseer must retain Healing Rain")
assert(addon.db.profile.slots[downpourIndex].inputKey == "SHIFT-5", "Downpour must inherit Healing Rain's binding")

addon:AcknowledgeSlot(rainIndex)
assert(addon:IsDownpourReady(now), "Healing Rain input must arm one Downpour use")
local sawDownpour, sawRain = false, false
for _, item in ipairs(addon:GetDisplayOrder(now)) do
    sawDownpour = sawDownpour or item.ability.abilityKey == "downpour"
    sawRain = sawRain or item.ability.abilityKey == "healing_rain"
end
assert(sawDownpour and not sawRain, "AoE mode must replace Healing Rain with ready Downpour")

addon:AcknowledgeSlot(rainIndex)
assert(not addon:IsDownpourReady(now), "same Healing Rain input must consume derived Downpour")
assert(addon.sessionUses[rainIndex] == now, "Downpour must not restart Healing Rain's local cooldown")

addon:SetHealingMode("standard", true)
assert(firstKey() == "healing_stream_combo", "returning to standard must restore the untouched guide order")

-- Talent abilities must belong to the neutral Raid priority even when they
-- were not selected when the preset was first opened. GetSlot then controls
-- visibility from the current out-of-combat talent snapshot.
addon.db.profile.rotationPreset = "shaman_totemic_raid"
addon.db.profile.slots = namespace.AbilityLibrary:BuildPresetSlots(
    addon.db.profile.rotationPreset, addon.db.profile.bindings)
addon.resolvedSlotCache = {}
addon.activePriorityRanksCache = nil
local function raidShowsUnleash()
    for _, item in ipairs(addon:GetDisplayOrder(now)) do
        if item.ability.abilityKey == "unleash_life" then return true end
    end
    return false
end
addon.talentSnapshot.unleashLife = false
assert(not raidShowsUnleash(), "unselected Unleash Life must stay hidden in Totemic Raid")
addon.talentSnapshot.unleashLife = true
assert(raidShowsUnleash(), "selected Unleash Life must appear dynamically in Totemic Raid")

print("Healing modes OK: Standard preserved, optional AoE/Single/Mana, derived Downpour state")
