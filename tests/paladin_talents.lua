local addon = {}
local namespace = { media = { fallbackIcon = 134400 } }

LibStub = function()
    return { NewAddon = function() return addon end }
end

GetTime = function() return 0 end
InCombatLockdown = function() return false end
IsPlayerSpell = function() return false end

local selectedSpellIDs = {
    432459, -- Lightsmith / Holy Armament
    379391, -- Quickened Invocation
    414073, -- Light's Conviction
    216331, -- Avenging Crusader
    1241511, -- Call of the Righteous (rank 2)
}

C_ClassTalents = { GetActiveConfigID = function() return 9001 end }
C_Traits = {
    GetConfigInfo = function() return { treeIDs = { 1 } } end,
    GetTreeNodes = function() return { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 } end,
    GetNodeInfo = function(_, nodeID)
        if not selectedSpellIDs[nodeID] then return { entryIDsWithCommittedRanks = {} } end
        return { entryIDsWithCommittedRanks = { {
            entryID = 100 + nodeID,
            rank = selectedSpellIDs[nodeID] == 1241511 and 2 or 1,
        } } }
    end,
    GetEntryInfo = function(_, entryID) return { definitionID = entryID + 1000 } end,
    GetDefinitionInfo = function(definitionID)
        return { spellID = selectedSpellIDs[definitionID - 1100] }
    end,
}

assert(loadfile("AbilityLibrary.lua"))("HeliHeal", namespace)
assert(loadfile("Classes/Paladin.lua"))("HeliHeal", namespace)
assert(loadfile("Core.lua"))("HeliHeal", namespace)
assert(loadfile("TalentSnapshot.lua"))("HeliHeal", namespace)

addon.classToken = "PALADIN"
addon.db = {
    profile = {
        rotationPreset = "paladin_herald_raid",
        healingMode = "standard",
        bindings = {},
    },
}
addon.db.profile.slots = namespace.AbilityLibrary:BuildPresetSlots(addon.db.profile.rotationPreset, {})
addon.RefreshDisplay = function() end
addon.RefreshOptionsUI = function() end
addon.Print = function() end
addon:ResetRuntimeState()

assert(addon:RefreshTalentSnapshot(true), "Paladin talent snapshot must be readable")
assert(addon.talentSnapshot.paladinLightsmith and addon.talentSnapshot.paladinQuickenedInvocation,
    "Lightsmith and Quickened Invocation must be detected from committed entries")
assert(addon.db.profile.rotationPreset == "paladin_lightsmith_raid",
    "hero detection must preserve the selected Raid content type")
local armamentIndex = addon:GetSlotIndexByAbilityKey("paladin_holy_armament")
local crusaderIndex = addon:GetSlotIndexByAbilityKey("paladin_avenging_crusader")
assert(addon:GetSlot(armamentIndex).enabled and addon:GetSlot(armamentIndex).cooldown == 45,
    "Lightsmith must enable Holy Armament and apply Quickened Invocation")
assert(addon:GetSlot(crusaderIndex).enabled and addon:GetSlot(crusaderIndex).cooldown == 45,
    "Avenging Crusader must apply both ranks of Call of the Righteous")

selectedSpellIDs = {
    431377, -- Herald of the Sun
    439760, -- Aurora
    375576, -- Divine Toll
    379391, -- Quickened Invocation
    414073, -- Light's Conviction
    31884,  -- Avenging Wrath
    1241542, -- Ringing of the Heavens
    392911,  -- Unwavering Spirit
    1241511, -- Call of the Righteous (rank 2)
}

assert(addon:RefreshTalentSnapshot(true), "changed Paladin talent snapshot must be readable")
assert(addon.db.profile.rotationPreset == "paladin_herald_raid",
    "switching hero trees must preserve Raid")
local tollIndex = addon:GetSlotIndexByAbilityKey("paladin_divine_toll")
local prismIndex = addon:GetSlotIndexByAbilityKey("paladin_holy_prism")
local wingsIndex = addon:GetSlotIndexByAbilityKey("paladin_avenging_wrath")
assert(addon:GetSlot(tollIndex).enabled and addon:GetSlot(tollIndex).cooldown == 30,
    "Herald Divine Toll must use its 30-second talented cooldown")
assert(not addon:GetSlot(prismIndex).enabled, "the unselected Holy Prism choice must stay hidden")
assert(addon:GetSlot(wingsIndex).enabled,
    "Avenging Wrath must replace the unselected Avenging Crusader")
assert(addon:GetSlot(wingsIndex).cooldown == 90,
    "two Call of the Righteous ranks must reduce Avenging Wrath to 90 seconds")
local auraIndex = addon:GetSlotIndexByAbilityKey("paladin_aura_mastery")
assert(addon:GetSlot(auraIndex).enabled and addon:GetSlot(auraIndex).cooldown == 150,
    "Ringing and Unwavering Spirit must enable a 150-second Aura Mastery")

print("paladin_talents.lua: OK")
