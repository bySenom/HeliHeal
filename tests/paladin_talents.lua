local addon = {}
local namespace = { media = { fallbackIcon = 134400 } }

LibStub = function()
    return { NewAddon = function() return addon end }
end

GetTime = function() return 0 end
InCombatLockdown = function() return false end
IsPlayerSpell = function() return false end
C_SpellBook = {
    IsSpellKnown = function(spellID) return spellID == 1296657 end,
}

local selectedSpellIDs = {
    1289728, -- Lightsmith / Holy Armaments talent definition
    379391, -- Quickened Invocation
    414073, -- Light's Conviction
    196926, -- Crusader's Might
    392961, -- Imbued Infusions
    392907, -- Inflorescence of the Sunwell
    53376, -- Sanctified Wrath
    414273, -- Hand of Divinity
    394088, -- Avenging Crusader talent definition
    31821, -- Aura Mastery
    1270916, -- Divine Favor
    1271077, -- Divine Overload
    461250, -- Rising Sunlight (Midnight redesign)
    1241511, -- Call of the Righteous (rank 2)
    200025, -- Beacon of Virtue
    6940, -- Blessing of Sacrifice
    384820, -- Sacrifice of the Just
    1022, -- Blessing of Protection
    384909, -- Improved Blessing of Protection
    633, -- Lay on Hands
    414720, -- Tirion's Devotion (Holy)
    190784, -- Divine Steed
    230332, -- Cavalier
    469409, -- Divine Spurs
    114154, -- Unbreakable Spirit
    378425, -- Uther's Counsel
    432804, -- Forewarning
    432919, -- Valiance
    432866, -- Laying Down Arms
    432802, -- Solidarity
}

C_ClassTalents = { GetActiveConfigID = function() return 9001 end }
C_Traits = {
    GetConfigInfo = function() return { treeIDs = { 1 } } end,
    GetTreeNodes = function()
        local nodes = {}
        for index = 1, #selectedSpellIDs do nodes[index] = index end
        return nodes
    end,
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
assert(addon.talentSnapshot.paladinCrusadersMight,
    "Crusader's Might must be detected for Judgment cooldown reduction")
assert(addon.talentSnapshot.paladinImbuedInfusions,
    "Imbued Infusions must be detected for the Holy Shock cooldown reduction")
assert(addon.talentSnapshot.paladinInflorescenceSunwell,
    "Inflorescence of the Sunwell must be detected for the second Infusion charge")
assert(addon.talentSnapshot.paladinSanctifiedWrath and addon.talentSnapshot.paladinHandOfDivinity,
    "Wings duration and Hand of Divinity must be detected from the committed loadout")
assert(addon.talentSnapshot.paladinBeaconVirtue,
    "Beacon of Virtue must be detected from the committed Holy talent loadout")
assert(addon.talentSnapshot.paladinAuraMastery and not addon.talentSnapshot.paladinRingingHeavens,
    "Aura Mastery must be detected independently from its optional Ringing improvement")
assert(addon.talentSnapshot.paladinDivineFavor
        and addon.talentSnapshot.paladinDivineOverload
        and addon.talentSnapshot.paladinRisingSunlight,
    "Holy Light modifiers and redesigned Rising Sunlight must be detected from committed entries")
addon:PrintTalentSnapshot()
assert(addon.talentSnapshot.paladinBlessingSacrifice
    and addon.talentSnapshot.paladinSacrificeOfTheJust
    and addon.talentSnapshot.paladinBlessingProtection
    and addon.talentSnapshot.paladinImprovedBlessingProtection
    and addon.talentSnapshot.paladinLayOnHands
    and addon.talentSnapshot.paladinTirionsDevotion
    and addon.talentSnapshot.paladinDivineSteed
    and addon.talentSnapshot.paladinCavalier
    and addon.talentSnapshot.paladinDivineSpurs
    and addon.talentSnapshot.paladinUnbreakableSpirit
    and addon.talentSnapshot.paladinUthersCounsel,
    "Paladin defensive, external and movement talents must be detected from committed entries")
assert(addon.talentSnapshot.paladinTier4,
    "the Midnight 12.1 Holy Paladin four-set must be detected out of combat")
assert(addon.talentSnapshot.paladinForewarning and addon.talentSnapshot.paladinValiance,
    "Lightsmith cooldown talents must be detected from committed entries")
assert(addon.talentSnapshot.paladinLayingDownArms and addon.talentSnapshot.paladinSolidarity,
    "Lightsmith Armament expiration talents must be detected from committed entries")
assert(addon.db.profile.rotationPreset == "paladin_lightsmith_raid",
    "hero detection must preserve the selected Raid content type")
local armamentIndex = addon:GetSlotIndexByAbilityKey("paladin_holy_armament")
local crusaderIndex = addon:GetSlotIndexByAbilityKey("paladin_avenging_crusader")
assert(addon:GetSlot(armamentIndex).enabled and addon:GetSlot(armamentIndex).cooldown == 36,
    "Lightsmith must apply Quickened Invocation and Forewarning to Holy Armament in order")
assert(addon:GetSlot(crusaderIndex).enabled and addon:GetSlot(crusaderIndex).cooldown == 45,
    "Avenging Crusader must apply both ranks of Call of the Righteous")
local steedIndex = addon:GetSlotIndexByAbilityKey("paladin_divine_steed")
assert(addon:GetSlot(steedIndex).cooldown == 36 and addon:GetSlot(steedIndex).maxCharges == 2,
    "Divine Spurs and Cavalier must alter Divine Steed's recharge and charges independently")
local shieldIndex = addon:GetSlotIndexByAbilityKey("paladin_divine_shield")
local protectionIndex = addon:GetSlotIndexByAbilityKey("paladin_blessing_of_protection")
local layOnHandsIndex = addon:GetSlotIndexByAbilityKey("paladin_lay_on_hands")
assert(addon:GetSlot(shieldIndex).cooldown == 165,
    "Unbreakable Spirit and Uther's Counsel must reduce Divine Shield by a combined 45 percent")
assert(addon:GetSlot(protectionIndex).cooldown == 204,
    "Improved Blessing of Protection must apply before Uther's Counsel's 15-percent reduction")
assert(math.abs(addon:GetSlot(layOnHandsIndex).cooldown - 90) < 0.01,
    "Unbreakable Spirit, Tirion's Devotion and Uther's Counsel must combine on Lay on Hands")

selectedSpellIDs = {
    431377, -- Herald of the Sun
    439760, -- Aurora
    1270916, -- Divine Favor
    1271077, -- Divine Overload
    461250, -- Rising Sunlight (Midnight redesign)
    375576, -- Divine Toll
    379391, -- Quickened Invocation
    414073, -- Light's Conviction
    31884,  -- Avenging Wrath
    31821,  -- Aura Mastery
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
assert(addon:GetSlot(wingsIndex).confirmOnPlayerSuccess,
    "Avenging Wrath must survive profile rebuilding with direct success confirmation enabled")
assert(addon:GetSlot(wingsIndex).cooldown == 90,
    "two Call of the Righteous ranks must reduce Avenging Wrath to 90 seconds")
local auraIndex = addon:GetSlotIndexByAbilityKey("paladin_aura_mastery")
assert(addon:GetSlot(auraIndex).enabled and addon:GetSlot(auraIndex).cooldown == 150,
    "Ringing and Unwavering Spirit must enable a 150-second Aura Mastery")

selectedSpellIDs = {
    431377, -- Herald of the Sun
    375576, -- Divine Toll
    384027, -- Divine Resonance
}
assert(addon:RefreshTalentSnapshot(true), "Divine Resonance loadout must remain readable")
assert(addon.talentSnapshot.paladinDivineResonance
        and not addon.talentSnapshot.paladinQuickenedInvocation,
    "Divine Resonance must be detected independently from its Quickened Invocation choice")
local resonanceTollIndex = addon:GetSlotIndexByAbilityKey("paladin_divine_toll")
assert(addon:GetSlot(resonanceTollIndex).cooldown == 45,
    "Divine Resonance must retain Divine Toll's base local cooldown")

print("paladin_talents.lua: OK")
