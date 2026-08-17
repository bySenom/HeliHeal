local addon = {}
local namespace = { media = { fallbackIcon = 134400 } }

LibStub = function()
    return { NewAddon = function() return addon end }
end
GetTime = function() return 0 end
InCombatLockdown = function() return false end
IsPlayerSpell = function() return false end

local selectedSpellIDs = {
    1248423, -- Oracle / Guiding Light
    34861,   -- Holy Word: Sanctify
    596,     -- Prayer of Healing
    88625,   -- Holy Word: Chastise
    235587,  -- Miracle Worker
    1215245, -- Eternal Sanctity
    1215275, -- Holy Celerity
    390994,  -- Voice of Harmony
    196985,  -- Light of the Naaru (rank 2)
    1272359, -- Prophet's Insight
    200183,  -- Apotheosis
    64843,   -- Divine Hymn
    47788,   -- Guardian Spirit
}

C_ClassTalents = { GetActiveConfigID = function() return 25701 end }
C_Traits = {
    GetConfigInfo = function() return { treeIDs = { 1 } } end,
    GetTreeNodes = function()
        local result = {}
        for index = 1, #selectedSpellIDs do result[index] = index end
        return result
    end,
    GetNodeInfo = function(_, nodeID)
        return { entryIDsWithCommittedRanks = { {
            entryID = 100 + nodeID,
            rank = selectedSpellIDs[nodeID] == 196985 and 2 or 1,
        } } }
    end,
    GetEntryInfo = function(_, entryID) return { definitionID = entryID + 1000 } end,
    GetDefinitionInfo = function(definitionID)
        return { spellID = selectedSpellIDs[definitionID - 1100] }
    end,
}

assert(loadfile("AbilityLibrary.lua"))("HeliHeal", namespace)
assert(loadfile("Classes/Priest.lua"))("HeliHeal", namespace)
assert(loadfile("Core.lua"))("HeliHeal", namespace)
assert(loadfile("TalentSnapshot.lua"))("HeliHeal", namespace)

addon.classToken = "PRIEST"
addon.specializationID = 257
addon.db = { profile = {
    rotationPreset = "priest_archon_raid", healingMode = "standard", bindings = {},
} }
addon.db.profile.slots = namespace.AbilityLibrary:BuildPresetSlots(addon.db.profile.rotationPreset, {})
addon.RefreshDisplay = function() end
addon.RefreshOptionsUI = function() end
addon.Print = function() end
addon:ResetRuntimeState()

assert(addon:RefreshTalentSnapshot(true), "Priest talent snapshot must be readable")
assert(addon.talentSnapshot.priestOracle and addon.talentSnapshot.priestMiracleWorker
    and addon.talentSnapshot.priestEternalSanctity and addon.talentSnapshot.priestHolyCelerity
    and addon.talentSnapshot.priestVoiceHarmony,
    "Oracle and Holy Word support talents must be detected from committed entries")
assert(addon.talentSnapshot.priestLightNaaruRank == 2,
    "both Light of the Naaru ranks must be retained")
assert(addon.db.profile.rotationPreset == "priest_oracle_raid",
    "hero detection must switch to Oracle without changing Raid content")

selectedSpellIDs[1] = 120517 -- Archon / Halo
assert(addon:RefreshTalentSnapshot(true), "changed Priest talent snapshot must be readable")
assert(addon.talentSnapshot.priestArchon and not addon.talentSnapshot.priestOracle,
    "Archon must replace Oracle when the active hero tree changes")
assert(addon.db.profile.rotationPreset == "priest_archon_raid",
    "hero detection must preserve Raid when switching to Archon")

print("priest_talents.lua: OK")
