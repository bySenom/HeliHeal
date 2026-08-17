local addon = {}
local namespace = { media = { fallbackIcon = 134400 } }

LibStub = function()
    return { NewAddon = function() return addon end }
end
GetTime = function() return 0 end
InCombatLockdown = function() return false end
IsPlayerSpell = function() return false end

local selectedSpellIDs = {
    1248423, -- Oracle
    472433,  -- Evangelism
    1253593, -- Void Shield
    322115,  -- Light's Promise
    390684,  -- Bright Pupil
    421453,  -- Ultimate Penitence
    33206,   -- Pain Suppression
}

C_ClassTalents = { GetActiveConfigID = function() return 25601 end }
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
assert(loadfile("Classes/Priest.lua"))("HeliHeal", namespace)
assert(loadfile("Classes/DisciplinePriest.lua"))("HeliHeal", namespace)
assert(loadfile("Core.lua"))("HeliHeal", namespace)
assert(loadfile("TalentSnapshot.lua"))("HeliHeal", namespace)

addon.classToken = "PRIEST"
addon.specializationID = 256
addon.db = { profile = {
    rotationPreset = "disc_voidweaver_raid", healingMode = "standard", bindings = {},
} }
addon.db.profile.slots = namespace.AbilityLibrary:BuildPresetSlots(addon.db.profile.rotationPreset, {})
addon.RefreshDisplay = function() end
addon.RefreshOptionsUI = function() end
addon.Print = function() end
addon:ResetRuntimeState()

assert(addon:RefreshTalentSnapshot(true), "Discipline talent snapshot must be readable")
assert(addon.talentSnapshot.priestOracle and addon.talentSnapshot.discEvangelism
    and addon.talentSnapshot.discVoidShield and addon.talentSnapshot.discLightsPromise
    and addon.talentSnapshot.discBrightPupil and addon.talentSnapshot.discUltimatePenitence
    and addon.talentSnapshot.discPainSuppression,
    "Oracle and selected Discipline talents must be detected from committed entries")
assert(addon.db.profile.rotationPreset == "disc_oracle_raid",
    "Discipline hero detection must switch to Oracle without changing Raid content")

selectedSpellIDs[1] = 450405 -- Voidweaver / Void Blast
assert(addon:RefreshTalentSnapshot(true), "changed Discipline talent snapshot must be readable")
assert(addon.talentSnapshot.discVoidweaver and not addon.talentSnapshot.priestOracle,
    "Voidweaver must replace Oracle when the active hero tree changes")
assert(addon.db.profile.rotationPreset == "disc_voidweaver_raid",
    "Discipline hero detection must preserve Raid when switching to Voidweaver")

print("discipline_talents.lua: OK")
