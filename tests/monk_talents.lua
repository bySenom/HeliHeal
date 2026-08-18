local addon = {}
local namespace = { media = { fallbackIcon = 134400 } }

LibStub = function() return { NewAddon = function() return addon end } end
GetTime = function() return 0 end
InCombatLockdown = function() return false end
IsPlayerSpell = function() return false end

local selectedSpellIDs = {
    450769, 450892, 173841, 388212, 197895, 399491, 467307, 388551,
    202424, 197900, 388847, 274909, 458431, 1277302, 1268807,
    388548, 116680, 124682, 116849, 115310, 322118, 400053,
    1260511, 325202, 115294,
}
C_ClassTalents = { GetActiveConfigID = function() return 27001 end }
C_Traits = {
    GetConfigInfo = function() return { treeIDs = { 1 } } end,
    GetTreeNodes = function()
        local result = {}
        for index = 1, #selectedSpellIDs do result[index] = index end
        return result
    end,
    GetNodeInfo = function(_, nodeID)
        return { entryIDsWithCommittedRanks = { { entryID = 100 + nodeID, rank = 1 } } }
    end,
    GetEntryInfo = function(_, entryID) return { definitionID = entryID + 1000 } end,
    GetDefinitionInfo = function(definitionID)
        return { spellID = selectedSpellIDs[definitionID - 1100] }
    end,
}

assert(loadfile("AbilityLibrary.lua"))("HeliHeal", namespace)
assert(loadfile("Classes/Monk.lua"))("HeliHeal", namespace)
assert(loadfile("Core.lua"))("HeliHeal", namespace)
assert(loadfile("TalentSnapshot.lua"))("HeliHeal", namespace)

addon.classToken = "MONK"
addon.specializationID = 270
addon.db = { profile = {
    rotationPreset = "monk_conduit_raid", healingMode = "standard", bindings = {},
} }
addon.db.profile.slots = namespace.AbilityLibrary:BuildPresetSlots(addon.db.profile.rotationPreset, {})
addon.RefreshDisplay = function() end
addon.RefreshOptionsUI = function() end
addon.Print = function() end
addon:ResetRuntimeState()

assert(addon:RefreshTalentSnapshot(true), "Mistweaver talent snapshot must be readable")
assert(addon.talentSnapshot.monkHarmony and addon.talentSnapshot.monkEndlessDraught
    and addon.talentSnapshot.monkPoolOfMists and addon.talentSnapshot.monkRushingWindKick
    and addon.talentSnapshot.monkRisingMist and addon.talentSnapshot.monkMistsOfLife
    and addon.talentSnapshot.monkVeilOfPride and addon.talentSnapshot.monkSpiritfont
    and addon.talentSnapshot.monkDanceOfChiji and addon.talentSnapshot.monkManaTea
    and not addon.talentSnapshot.monkTranquilTea,
    "high-impact Mistweaver and Master of Harmony talents must be detected")
assert(addon.db.profile.rotationPreset == "monk_harmony_raid",
    "hero detection must switch to Master of Harmony without changing Raid content")

local readTreeNodes = C_Traits.GetTreeNodes
C_Traits.GetTreeNodes = function() return {} end
assert(not addon:RefreshTalentSnapshot(true),
    "a temporarily empty trait tree must not be accepted as a new snapshot")
assert(addon.talentSnapshot.available and addon.talentSnapshot.monkHarmony,
    "the last valid Mistweaver snapshot must survive a transient trait API failure")
C_Traits.GetTreeNodes = readTreeNodes

selectedSpellIDs[1] = 443028
assert(addon:RefreshTalentSnapshot(true), "changed Mistweaver talent snapshot must be readable")
assert(addon.talentSnapshot.monkConduit and not addon.talentSnapshot.monkHarmony,
    "Conduit of the Celestials must replace Master of Harmony")
assert(addon.db.profile.rotationPreset == "monk_conduit_raid",
    "hero switching must continue to preserve Raid content")

print("monk_talents.lua: OK")
