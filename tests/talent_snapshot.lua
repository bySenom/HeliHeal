local addon = {}
local namespace = { media = { fallbackIcon = 134400 } }

LibStub = function()
    return { NewAddon = function() return addon end }
end

local now = 0
GetTime = function() return now end
InCombatLockdown = function() return false end
C_SpellBook = {
    IsSpellKnown = function(spellID) return spellID == 1264866 or spellID == 1264867 end,
}

local selectedSpellIDs = { 333919, 462488, 1252882, 1270453, 443418, 73685 }
C_ClassTalents = { GetActiveConfigID = function() return 77 end }
C_Traits = {
    GetConfigInfo = function() return { treeIDs = { 10 } } end,
    GetTreeNodes = function() return { 101, 102, 103, 104, 105, 106 } end,
    GetNodeInfo = function(_, nodeID)
        if nodeID == 105 then
            return { subTreeID = 900, subTreeActive = false, entryIDsWithCommittedRanks = { { entryID = 1105, rank = 1 } } }
        end
        return { entryIDsWithCommittedRanks = { { entryID = nodeID + 1000, rank = 1 } } }
    end,
    GetEntryInfo = function(_, entryID) return { definitionID = entryID + 1000 } end,
    GetDefinitionInfo = function(definitionID)
        local nodeIndex = definitionID - 2101 + 1
        return { spellID = selectedSpellIDs[nodeIndex] }
    end,
}

assert(loadfile("AbilityLibrary.lua"))("HeliHeal", namespace)
assert(loadfile("Classes/Shaman.lua"))("HeliHeal", namespace)
assert(loadfile("Core.lua"))("HeliHeal", namespace)
assert(loadfile("TalentSnapshot.lua"))("HeliHeal", namespace)
assert(loadfile("Display.lua"))("HeliHeal", namespace)

addon.db = {
    profile = {
        rotationPreset = "shaman_totemic_mythicplus",
        healingMode = "aoe",
        bindings = {},
    },
}
addon.db.profile.slots = namespace.AbilityLibrary:BuildPresetSlots(addon.db.profile.rotationPreset, {})
addon.classToken = "SHAMAN"
addon.sessionUses = {}
addon.sessionCharges = {}
addon.sessionSpendHistory = {}
addon.pendingSwiftness = nil
addon.pendingDownpour = nil
addon.RefreshDisplay = function() end
addon.RefreshOptionsUI = function() end
addon.Print = function() end

assert(addon:RefreshTalentSnapshot(true), "active talent config must be readable outside combat")
assert(addon:IsTalentActive("echoOfTheElements"), "Echo of the Elements must be detected")
assert(addon:IsTalentActive("downpour"), "Downpour must be detected")
assert(addon:IsTalentActive("doubleDip"), "Double Dip must be detected")
assert(addon:IsTalentActive("mysticKnowledge"), "Mystic Knowledge must be detected")
assert(addon:IsTalentActive("unleashLife"), "Unleash Life must be detected")
assert(not addon:IsTalentActive("elementalReverb"), "unselected talents must remain inactive")
assert(addon:IsTalentActive("restorationTier2") and addon:IsTalentActive("restorationTier4"),
    "equipped Restoration set bonuses must be cached with the build")
assert(addon.db.profile.rotationPreset == "shaman_farseer_mythicplus",
    "detected Farseer talents must switch only the hero part of the selected content preset")

local riptideIndex = addon:GetSlotIndexByAbilityKey("riptide")
local riptide = addon:GetSlot(riptideIndex)
assert(riptide.maxCharges == 2, "base charge plus Echo must produce two Riptide charges")
assert(addon:SpendCharge(riptideIndex, riptide, now), "Riptide charge must be spendable")
local riptideState = addon:GetChargeState(riptideIndex, riptide, now)
assert(riptideState.nextRechargeAt == 6, "Riptide starts with the six-second base recharge")

now = 1
addon:ApplyMysticKnowledge(now)
assert(math.abs(riptideState.nextRechargeAt - (1 + (5 / 1.1))) < 0.001,
    "Mystic Knowledge must accelerate remaining Riptide recharge by ten percent")

addon:ArmDownpour(now)
assert(addon.pendingDownpour.uses == 2, "Double Dip must grant two local Downpour uses")
addon:ConsumeDownpour(now)
assert(addon.pendingDownpour and addon.pendingDownpour.uses == 1, "first Downpour must leave the second use")

local unleashIndex = addon:GetSlotIndexByAbilityKey("unleash_life")
local chainIndex = addon:GetSlotIndexByAbilityKey("chain_heal")
local waveIndex = addon:GetSlotIndexByAbilityKey("healing_wave")
assert(addon:GetSlot(unleashIndex).cooldown == 17, "Restoration 2pc must reduce Unleash Life to 17 seconds")
addon:AcknowledgeSlot(unleashIndex)
assert(addon.pendingUnleash and addon.pendingUnleash.remaining == 2,
    "Restoration 4pc must arm two Unleash Life consumers")
assert(addon:GetDisplayOrder(now)[1].ability.abilityKey == "chain_heal",
    "AoE mode must prioritize Chain Heal while Unleash Life is armed")
addon:AcknowledgeSlot(chainIndex)
assert(addon.pendingUnleash and addon.pendingUnleash.remaining == 1,
    "first empowered heal must leave the 4pc's second use")
addon:AcknowledgeSlot(waveIndex)
assert(not addon.pendingUnleash, "second empowered heal must consume the remaining use")
addon.pendingAcknowledgements = {}
addon.inputLockedUntil = {}
assert(addon:RefundAbility("wave"), "failed consumer must be refundable")
assert(addon.pendingUnleash and addon.pendingUnleash.remaining == 1,
    "refunding a failed consumer must restore its Unleash Life use")

print("Talent snapshot OK: talents, tier set, Unleash Life and contextual consumers drive local state")
