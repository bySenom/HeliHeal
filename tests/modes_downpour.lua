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
addon.RefreshDisplay = function() end
addon.RefreshOptionsUI = function() end
addon.Print = function() end

local riptideIndex = addon:GetSlotIndexByAbilityKey("riptide")
assert(addon:GetSlot(riptideIndex).cooldown == 6, "Totemic Riptide must use the six-second base recharge")

local function firstKey()
    return addon:GetDisplayOrder(now)[1].ability.abilityKey
end

assert(firstKey() == "healing_stream_combo", "standard must retain the existing preset as default")
addon:SetHealingMode("single", true)
assert(firstKey() == "riptide", "single-target mode must be an optional reordered view")
addon:SetHealingMode("mana", true)
assert(firstKey() == "healing_stream_combo", "mana mode must remain selectable")

addon:SetHealingMode("aoe", true)
local rainIndex = addon:GetSlotIndexByAbilityKey("healing_rain")
local downpourIndex = addon:GetSlotIndexByAbilityKey("downpour")
assert(rainIndex and downpourIndex, "context pack must contain Healing Rain and derived Downpour")
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

print("Healing modes OK: Standard preserved, optional AoE/Single/Mana, derived Downpour state")
