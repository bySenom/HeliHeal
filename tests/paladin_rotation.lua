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
assert(loadfile("Snapshots.lua"))("HeliHeal", namespace)
assert(loadfile("Input.lua"))("HeliHeal", namespace)
assert(loadfile("Display.lua"))("HeliHeal", namespace)

addon.classToken = "PALADIN"
addon.specializationID = 65
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
    paladinDivineResonance = false,
    paladinLightsConviction = true,
    paladinCrusadersMight = true,
    paladinImbuedInfusions = true,
    paladinInflorescenceSunwell = false,
    paladinSanctifiedWrath = false,
    paladinHandOfDivinity = false,
    paladinAvengingWrath = false,
    paladinAvengingCrusader = false,
    paladinAuraMastery = true,
    paladinRingingHeavens = false,
    paladinWalkIntoLight = false,
    paladinDivineFavor = false,
    paladinDivineOverload = false,
    paladinRisingSunlight = false,
    paladinBeaconVirtue = true,
    paladinTier4 = true,
    paladinBlessingSacrifice = true,
    paladinSacrificeOfTheJust = true,
    paladinBlessingProtection = true,
    paladinImprovedBlessingProtection = true,
    paladinLayOnHands = true,
    paladinTirionsDevotion = true,
    paladinDivineSteed = true,
    paladinCavalier = true,
    paladinDivineSpurs = true,
    paladinUnbreakableSpirit = true,
    paladinForewarning = false,
    paladinValiance = false,
    paladinLayingDownArms = false,
    paladinSolidarity = false,
}
addon.IsTalentActive = function(self, key)
    return self.talentSnapshot.available and self.talentSnapshot[key] == true
end
addon.RefreshDisplay = function() end
addon.RefreshOptionsUI = function() end
addon.Print = function() end

UnitSpellHaste = function() return 20 end
InCombatLockdown = function() return false end
assert(addon:RefreshSpellHasteSnapshot(true), "out-of-combat spell haste must be readable")

local tollIndex = addon:GetSlotIndexByAbilityKey("paladin_divine_toll")
local shockIndex = addon:GetSlotIndexByAbilityKey("paladin_holy_shock")
local flameIndex = addon:GetSlotIndexByAbilityKey("paladin_eternal_flame")
local dawnIndex = addon:GetSlotIndexByAbilityKey("paladin_light_of_dawn")
local holyLightIndex = addon:GetSlotIndexByAbilityKey("paladin_holy_light")
local flashIndex = addon:GetSlotIndexByAbilityKey("paladin_flash_of_light")
local virtueIndex = addon:GetSlotIndexByAbilityKey("paladin_beacon_of_virtue")
local hammerIndex = addon:GetSlotIndexByAbilityKey("paladin_hammer_of_wrath")
local shieldIndex = addon:GetSlotIndexByAbilityKey("paladin_shield_of_the_righteous")
local crusaderStrikeIndex = addon:GetSlotIndexByAbilityKey("paladin_crusader_strike")
local protectionIndex = addon:GetSlotIndexByAbilityKey("paladin_divine_protection")
local shieldDefensiveIndex = addon:GetSlotIndexByAbilityKey("paladin_divine_shield")
local sacrificeIndex = addon:GetSlotIndexByAbilityKey("paladin_blessing_of_sacrifice")
local layOnHandsIndex = addon:GetSlotIndexByAbilityKey("paladin_lay_on_hands")
local blessingProtectionIndex = addon:GetSlotIndexByAbilityKey("paladin_blessing_of_protection")
local steedIndex = addon:GetSlotIndexByAbilityKey("paladin_divine_steed")
local auraMasteryIndex = addon:GetSlotIndexByAbilityKey("paladin_aura_mastery")

local sharedJudgmentIndex = addon:GetSlotIndexByAbilityKey("paladin_judgment")
addon:SetAbilityBinding(sharedJudgmentIndex, "1")
assert(addon.db.profile.slots[hammerIndex].derivedBindingFrom == "paladin_judgment"
        and addon.db.profile.slots[sharedJudgmentIndex].inputKey == "1"
        and addon.db.profile.slots[hammerIndex].inputKey == "1",
    "Judgment and its Hammer of Wrath replacement must share one editable binding")
assert(#addon:GetBindingConflicts() == 0,
    "the intentional Judgment and Hammer shared binding must not be reported as a conflict")
addon:ObserveInputKey("1")
assert(addon.pendingAcknowledgements[sharedJudgmentIndex]
        and not addon.pendingAcknowledgements[hammerIndex],
    "the shared key must observe only the editable Judgment source slot")
addon:ResetInputState()

assert(addon:GetSlot(tollIndex).cooldown == 30,
    "Quickened Invocation must reduce Divine Toll to 30 seconds")
assert(addon:GetSlot(shockIndex).maxCharges == 2,
    "Light's Conviction must keep two Holy Shock charges")
assert(addon:GetSlot(virtueIndex).enabled and addon:GetSlot(virtueIndex).cooldown == 15
    and addon:GetSlot(virtueIndex).roleLabel == "BURST",
    "selected Beacon of Virtue must be a tracked 15-second Mythic+ burst setup")
assert(addon:GetSlot(auraMasteryIndex).enabled,
    "Aura Mastery must remain available without Ringing of the Heavens")
addon:SetHolyPowerEstimate(0, true)
addon.talentSnapshot.paladinAurora = true
addon:AcknowledgeSlot(auraMasteryIndex)
assert(addon.sessionHolyPower == 0 and addon.pendingFreeHolyPowerSpenders == 0,
    "Aura Mastery without Ringing must not imitate a Divine Toll or grant Aurora")
addon:ResetRuntimeState()
addon.talentSnapshot.paladinRingingHeavens = true
addon:AcknowledgeSlot(auraMasteryIndex)
assert(addon.sessionHolyPower == 3 and addon.pendingFreeHolyPowerSpenders == 1,
    "Ringing Aura Mastery must inherit Divine Toll's Holy Power and Aurora effects")
addon:ResetRuntimeState()
addon.talentSnapshot.paladinRingingHeavens = false
addon.talentSnapshot.paladinAurora = false
assert(not dawnIndex, "Mythic+ must not expose Light of Dawn as a priority or binding")
local function containsAbility(keys, expected)
    for _, key in ipairs(keys) do
        if key == expected then return true end
    end
    return false
end
local function abilityPosition(keys, expected)
    for index, key in ipairs(keys) do
        if key == expected then return index end
    end
end
local function displayContains(items, expected)
    for _, item in ipairs(items) do
        if item.ability.abilityKey == expected then return true end
    end
    return false
end

local initialOrder = addon:GetDisplayOrder(now)
assert(not displayContains(initialOrder, "paladin_flash_of_light"),
    "Flash of Light must stay hidden without a locally known Infusion")

assert(protectionIndex and shieldDefensiveIndex and sacrificeIndex and layOnHandsIndex
    and blessingProtectionIndex and steedIndex,
    "Paladin presets must register every defensive, external and movement support binding")
assert(addon:GetSlot(protectionIndex).cooldown == 42
    and addon:GetSlot(shieldDefensiveIndex).cooldown == 210,
    "Unbreakable Spirit must reduce the local Divine Protection and Divine Shield timers by 30 percent")
assert(addon:GetSlot(sacrificeIndex).cooldown == 105
    and addon:GetSlot(blessingProtectionIndex).cooldown == 240,
    "selected blessing talents must reduce the local Sacrifice and Protection timers")
assert(math.abs(addon:GetSlot(layOnHandsIndex).cooldown - 180) < 0.001,
    "Tirion's Devotion and Unbreakable Spirit must both contribute to Lay on Hands' local timer")
assert(addon:GetSlot(steedIndex).maxCharges == 2 and addon:GetSlot(steedIndex).cooldown == 36,
    "Cavalier and Divine Spurs must grant the second charge and reduce Divine Steed to 36 seconds")
local supportOrder = addon:GetSupportDisplayOrder(now)
assert(#supportOrder == 6 and displayContains(supportOrder, "paladin_divine_protection")
    and displayContains(supportOrder, "paladin_divine_steed"),
    "the separate support strip must expose ready Paladin tools")
assert(not displayContains(addon:GetDisplayOrder(now), "paladin_divine_protection")
    and not displayContains(addon:GetDisplayOrder(now), "paladin_divine_steed"),
    "support tools must never enter the five healing recommendations")
addon:AcknowledgeSlot(protectionIndex)
supportOrder = addon:GetSupportDisplayOrder(now)
for _, item in ipairs(supportOrder) do
    if item.ability.abilityKey == "paladin_divine_protection" then
        assert(item.remaining == 42,
            "a confirmed defensive cast must start its talent-adjusted local cooldown")
    end
end
addon:ResetRuntimeState()
for _, presetKey in ipairs({
        "paladin_herald_mythicplus", "paladin_lightsmith_mythicplus",
        "paladin_herald_raid", "paladin_lightsmith_raid",
    }) do
    for _, mode in ipairs({ "standard", "aoe", "single", "mana" }) do
        local keys = namespace.AbilityLibrary:GetPresetPriorityKeys(presetKey, mode)
        assert(abilityPosition(keys, "paladin_shield_of_the_righteous"),
            "every Holy Paladin mode must expose Shield of the Righteous for confirmed damage spending")
        assert(abilityPosition(keys, "paladin_judgment")
            and abilityPosition(keys, "paladin_hammer_of_wrath")
            and abilityPosition(keys, "paladin_flash_of_light")
            and abilityPosition(keys, "paladin_holy_light"),
            "every Holy Paladin mode must retain both healing and damage fillers")
        if mode == "aoe" or mode == "single" then
            assert(abilityPosition(keys, "paladin_flash_of_light") < abilityPosition(keys, "paladin_judgment")
                and abilityPosition(keys, "paladin_holy_light") < abilityPosition(keys, "paladin_judgment"),
                "explicit healing contexts must prefer direct healing over damage fillers")
        end
    end
end
assert(addon:GetSlot(hammerIndex).cooldown == 6.25 and addon:GetSlot(hammerIndex).holyPowerGain == 1,
    "cached haste must scale Hammer of Wrath and its confirmed cast must generate Holy Power")
assert(addon:GetSlot(shieldIndex).holyPowerCost == 3,
    "Shield of the Righteous must remain a bindable three-Holy-Power spender")
assert(not addon:GetSlot(crusaderStrikeIndex).enabled,
    "Crusader Strike must stay disabled without Avenging Crusader")
assert(containsAbility(namespace.AbilityLibrary:GetPresetPriorityKeys(
        "paladin_herald_mythicplus", "standard"), "paladin_beacon_of_virtue")
    and containsAbility(namespace.AbilityLibrary:GetPresetPriorityKeys(
        "paladin_herald_mythicplus", "aoe"), "paladin_beacon_of_virtue"),
    "Virtue must be available in Mythic+ Standard and AoE modes")
assert(containsAbility(namespace.AbilityLibrary:GetPresetPriorityKeys(
        "paladin_herald_raid", "standard"), "paladin_beacon_of_virtue")
    and containsAbility(namespace.AbilityLibrary:GetPresetPriorityKeys(
        "paladin_herald_raid", "aoe"), "paladin_beacon_of_virtue"),
    "selected Beacon of Virtue must also remain available in Raid priorities")
assert(not containsAbility(namespace.AbilityLibrary:GetPresetPriorityKeys(
        "paladin_herald_mythicplus", "single"), "paladin_beacon_of_virtue")
    and not containsAbility(namespace.AbilityLibrary:GetPresetPriorityKeys(
        "paladin_herald_mythicplus", "mana"), "paladin_beacon_of_virtue"),
    "Virtue must not be forced by Single Target or Mana Saving modes")

addon.talentSnapshot.paladinDivineResonance = true
addon:ResetRuntimeState()
addon:SetHolyPowerEstimate(0, true)
now = 0
addon:AcknowledgeSlot(tollIndex)
local resonance = addon:GetPaladinDivineResonanceState(now)
assert(resonance and resonance.nextTickAt == 5 and resonance.ticksRemaining == 3,
    "a confirmed Divine Toll must arm the three deterministic Divine Resonance timings")
addon:SetHolyPowerEstimate(4, true)
now = 3.6
local resonanceOrder = addon:GetDisplayOrder(now)
assert(resonanceOrder[1].ability.abilityKey == "paladin_eternal_flame",
    "four Holy Power shortly before a Divine Resonance tick must promote the healing spender")
now = 5
resonance = addon:GetPaladinDivineResonanceState(now)
assert(resonance and resonance.nextTickAt == 10 and resonance.ticksRemaining == 2,
    "the first fixed Divine Resonance timing must advance without reading a combat aura")
now = 15
assert(not addon:GetPaladinDivineResonanceState(now),
    "Divine Resonance must end after its third fixed Holy Shock timing")
addon.talentSnapshot.paladinDivineResonance = false
addon:ResetRuntimeState()
now = 0

addon:SetRotationPreset("paladin_herald_raid")
addon:SetHealingMode("aoe", true)
addon.talentSnapshot.paladinRingingHeavens = true
local raidVirtueIndex = addon:GetSlotIndexByAbilityKey("paladin_beacon_of_virtue")
local raidTollIndex = addon:GetSlotIndexByAbilityKey("paladin_divine_toll")
addon:SetHolyPowerEstimate(0, true)
now = 0
local raidVirtueOrder = addon:GetDisplayOrder(now)
assert(raidVirtueOrder[1].ability.abilityKey == "paladin_beacon_of_virtue",
    "Raid AoE must establish Beacon of Virtue before ready paired burst cooldowns")
addon:AcknowledgeSlot(raidVirtueIndex)
assert(addon:IsPaladinVirtueActive(now) and addon.paladinVirtueUntil == 9,
    "a confirmed Beacon of Virtue cast must start its nine-second local window")
raidVirtueOrder = addon:GetDisplayOrder(now)
assert(raidVirtueOrder[1].ability.abilityKey == "paladin_divine_toll"
        and raidVirtueOrder[2].ability.abilityKey == "paladin_aura_mastery",
    "the active Raid Virtue window must pair Divine Toll and Ringing Aura Mastery")
addon:AcknowledgeSlot(raidTollIndex)
now = 9
assert(not addon:IsPaladinVirtueActive(now),
    "the locally reconstructed Beacon of Virtue window must expire after nine seconds")
addon:SetRotationPreset("paladin_herald_mythicplus")
addon:SetHealingMode("standard", true)
addon.talentSnapshot.paladinRingingHeavens = false
now = 0

for _, presetKey in ipairs({ "paladin_herald_mythicplus", "paladin_lightsmith_mythicplus" }) do
    for _, mode in ipairs({ "standard", "aoe", "single", "mana" }) do
        assert(not containsAbility(namespace.AbilityLibrary:GetPresetPriorityKeys(presetKey, mode),
                "paladin_light_of_dawn"),
            "every Holy Paladin Mythic+ mode must omit Light of Dawn")
    end
end
assert(addon:GetSlot(holyLightIndex).roleLabel == "SAVE"
    and addon:GetSlot(flashIndex).roleLabel == "BURST",
    "Paladin contextual heal labels must survive preset resolution")
addon.talentSnapshot.paladinDivineFavor = true
addon.talentSnapshot.paladinDivineOverload = true
local holyLightSummary = addon:GetPaladinHolyLightTalentSummary()
assert(holyLightSummary and holyLightSummary:find("-10%% Mana")
        and holyLightSummary:find("-15%% Cast")
        and holyLightSummary:find("+30%% Heilung")
        and holyLightSummary:find("+20%% Mana"),
    "selected passive Holy Light talents must expose their reliable modifiers")
addon.talentSnapshot.paladinDivineFavor = false
addon.talentSnapshot.paladinDivineOverload = false
assert(addon:GetSlot(shockIndex).cooldown == 5,
    "20 percent cached spell haste must reduce Holy Shock recharge from six to five seconds")
local judgmentIndex = addon:GetSlotIndexByAbilityKey("paladin_judgment")
assert(addon:GetSlot(judgmentIndex).cooldown == 5,
    "cached spell haste must reduce Judgment's six-second cooldown")
addon:AcknowledgeSlot(judgmentIndex)
now = 1
addon:AcknowledgeSlot(shockIndex)
assert(addon.sessionUses[judgmentIndex] == -1.5,
    "Crusader's Might must reduce the running Judgment cooldown by 1.5 seconds per Holy Shock")
local judgment = addon:GetSlot(judgmentIndex)
assert(math.abs(math.max(0, addon.sessionUses[judgmentIndex] + judgment.cooldown - now) - 2.5) < 0.001,
    "Judgment must have 2.5 seconds remaining after one second and one Crusader's Might reduction")
addon:AcknowledgeSlot(shieldIndex)
local shockState = addon.sessionCharges[shockIndex]
assert(shockState and math.abs(shockState.nextRechargeAt - 4) < 0.001,
    "Shield of the Righteous must reduce Holy Shock's running five-second recharge by two seconds")
addon:ResetRuntimeState()
now = 0
InCombatLockdown = function() return true end
UnitSpellHaste = function() return 100 end
assert(not addon:RefreshSpellHasteSnapshot(true) and addon:GetSlot(shockIndex).cooldown == 5,
    "combat must retain the last safe haste snapshot instead of evaluating restricted stats")
InCombatLockdown = function() return false end

local order = addon:GetDisplayOrder(now)
assert(order[1].ability.abilityKey == "paladin_divine_toll",
    "Herald Mythic+ must open with its available low-Holy-Power cooldown")
assert(not order[1].paladinResourceBlocked,
    "a Holy Power spender must never replace an actionable primary recommendation")

addon:AcknowledgeSlot(tollIndex)
assert(addon.sessionHolyPower == 3, "Divine Toll must add three locally estimated Holy Power")
order = addon:GetDisplayOrder(now)
assert(order[1].ability.abilityKey == "paladin_beacon_of_virtue",
    "Beacon of Virtue must prepare the Mythic+ burst window before direct healing")
addon:AcknowledgeSlot(virtueIndex)
order = addon:GetDisplayOrder(now)
assert(order[1].ability.abilityKey == "paladin_holy_shock",
    "Holy Shock must follow the active Virtue setup below the five-point cap")

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
assert(#order >= 5 and containsAbility({
        order[2].ability.abilityKey,
        order[3].ability.abilityKey,
        order[4].ability.abilityKey,
        order[5].ability.abilityKey,
    }, "paladin_judgment"),
    "capped Holy Power must retain five recommendations with Judgment behind the spender")

addon:AcknowledgeSlot(flameIndex)
assert(addon.sessionHolyPower == 2, "Eternal Flame must spend three local Holy Power")
addon:AcknowledgeSlot(flashIndex)
assert(addon.sessionHolyPower == 3, "Flash of Light must generate one local Holy Power")
addon:AcknowledgeSlot(flameIndex)
assert(addon.sessionHolyPower == 0, "a spender at three Holy Power must return the estimate to zero")
order = addon:GetDisplayOrder(now)
assert((order[1].ability.holyPowerCost or 0) == 0 and not order[1].paladinResourceBlocked,
    "an unavailable spender must not become primary after Holy Power falls below three")
for _, item in ipairs(order) do
    if (item.ability.holyPowerCost or 0) > 0 then
        assert(item.paladinResourceBlocked,
            "spenders below three Holy Power must be marked as future steps")
    end
end

addon:SetRotationPreset("paladin_lightsmith_raid")
addon.talentSnapshot.paladinHerald = false
addon.talentSnapshot.paladinLightsmith = true
addon.talentSnapshot.paladinDivineToll = false
addon.talentSnapshot.paladinForewarning = false
addon.talentSnapshot.paladinValiance = true
addon.talentSnapshot.paladinLayingDownArms = true
addon.talentSnapshot.paladinSolidarity = true
addon.talentSnapshot.paladinBeaconVirtue = false
local armamentIndex = addon:GetSlotIndexByAbilityKey("paladin_holy_armament")
local wordIndex = addon:GetSlotIndexByAbilityKey("paladin_word_of_glory")
local raidDawnIndex = addon:GetSlotIndexByAbilityKey("paladin_light_of_dawn")
assert(addon:GetSlot(armamentIndex).enabled and addon:GetSlot(armamentIndex).cooldown == 60,
    "Quickened Invocation must not reduce Holy Armament's current 60-second recharge")
addon.talentSnapshot.paladinForewarning = true
order = addon:GetDisplayOrder(now)
assert(#order >= 5 and order[5].paladinResourceBlocked
        and (order[5].ability.holyPowerCost or 0) == 3,
    "Lightsmith without Beacon or Infusion must backfill a fifth future Holy Power spender")
addon.talentSnapshot.paladinBeaconVirtue = true
assert(addon:GetSlot(armamentIndex).enabled and addon:GetSlot(armamentIndex).cooldown == 48,
    "Forewarning must reduce Holy Armament to 48 seconds without the obsolete Quickened Invocation reduction")
assert(addon:GetSlot(armamentIndex).confirmOnPlayerSuccess,
    "both transformed Holy Armament casts must support direct Blizzard success confirmation")
addon:AcknowledgeSlot(armamentIndex)
local armamentRechargeBeforeValiance = addon.sessionCharges[armamentIndex].nextRechargeAt
local bulwarkExpirationBeforeValiance = addon.paladinArmamentExpirations.bulwark
assert(addon.paladinNextArmamentType == "sacred"
        and addon:GetSlot(armamentIndex).spellID == 432472
        and addon:GetSlot(armamentIndex).name == "Sacred Weapon",
    "Holy Bulwark must transform the shared Armament slot into Sacred Weapon")
local cdmValianceActive = true
addon.ProcTracker = {
    GetInfusionOfLightState = function() return cdmValianceActive, true end,
}
assert(addon:GetPaladinInfusionCharges(now) == 1,
    "the dedicated CDM proc must arm Valiance before the consumer succeeds")
local lightsmithFlashIndex = addon:GetSlotIndexByAbilityKey("paladin_flash_of_light")
addon:AcknowledgeSlot(lightsmithFlashIndex)
assert(addon.sessionCharges[armamentIndex].nextRechargeAt == armamentRechargeBeforeValiance - 3
        and addon.paladinArmamentExpirations.bulwark == bulwarkExpirationBeforeValiance,
    "a CDM-confirmed Infusion consumption must advance the shared Armaments recharge without changing active effect durations")
cdmValianceActive = false
addon.ProcTracker = nil
addon.paladinArmamentExpirations = {}
addon.pendingPaladinInfusion = true
addon:AcknowledgeSlot(lightsmithFlashIndex)
assert(addon.sessionCharges[armamentIndex].nextRechargeAt == armamentRechargeBeforeValiance - 6,
    "each confirmed Infusion consumption must advance Holy Armaments by another three seconds")
addon.paladinArmamentExpirations.bulwark = now + 20
local lightsmithLayOnHandsIndex = addon:GetSlotIndexByAbilityKey("paladin_lay_on_hands")
addon:AcknowledgeSlot(lightsmithLayOnHandsIndex)
local layOnHandsUsedAt = addon.sessionUses[lightsmithLayOnHandsIndex]
assert(addon.paladinArmamentExpirations.bulwark == now + 20,
    "Solidarity must arm the locally guaranteed Holy Bulwark expiration")
now = now + 19
addon:GetDisplayOrder(now)
assert(not addon.pendingPaladinInfusion
        and addon.sessionUses[lightsmithLayOnHandsIndex] == layOnHandsUsedAt,
    "Laying Down Arms must not trigger before the Armament expires")
now = now + 1
addon:GetDisplayOrder(now)
assert(addon:GetPaladinInfusionCharges(now) == 1,
    "Laying Down Arms must grant a local Infusion when Holy Bulwark expires")
assert(addon.sessionUses[lightsmithLayOnHandsIndex] == layOnHandsUsedAt - 15,
    "Laying Down Arms must advance the running Lay on Hands cooldown by 15 seconds")
addon:AcknowledgeSlot(armamentIndex, 432472)
assert(addon.paladinArmamentExpirations.sacred == now + 20,
    "the observed Sacred Weapon spell ID must track its separate expiration")
assert(addon.paladinNextArmamentType == "bulwark"
        and addon:GetSlot(armamentIndex).spellID == 432459
        and addon:GetSlot(armamentIndex).name == "Holy Bulwark",
    "Sacred Weapon must transform the shared Armament slot back into Holy Bulwark")
assert(addon:TrackPaladinArmament(432472, now + 5)
        and addon.paladinArmamentExpirations.sacred == now + 40,
    "same-caster Armament reapplication must extend the existing duration")
addon.talentSnapshot.paladinSolidarity = false
addon.paladinArmamentExpirations = {}
assert(addon:TrackPaladinArmament(432459, now)
        and addon.paladinNextArmamentType == "sacred"
        and not next(addon.paladinArmamentExpirations),
    "the Armament must still transform without inferring expiration when Solidarity is absent")
addon.talentSnapshot.paladinSolidarity = true
addon:ResetRuntimeState()
now = now + 1
assert(addon:RecordPlayerSpellSucceeded(432459, "Direct-Bulwark"),
    "Holy Bulwark must confirm without a pending key observation")
local firstArmamentState = addon.sessionCharges[armamentIndex]
assert(firstArmamentState and firstArmamentState.baseCharges == 1
        and addon.paladinNextArmamentType == "sacred",
    "one Holy Bulwark cast must spend exactly one shared Armament charge")
now = now + 0.6
assert(addon:RecordPlayerSpellSucceeded(432459, "Solidarity-Bulwark")
        and addon.sessionCharges[armamentIndex].baseCharges == 1
        and addon.paladinNextArmamentType == "sacred",
    "the delayed Solidarity copy must not spend another charge or flip the Armament again")
now = now + 1.4
assert(addon:RecordPlayerSpellSucceeded(432472, "Direct-Sacred"),
    "Sacred Weapon must confirm without a pending key observation")
local directArmamentState = addon.sessionCharges[armamentIndex]
assert(directArmamentState and directArmamentState.baseCharges == 0
        and directArmamentState.nextRechargeAt > now,
    "two directly confirmed Armament casts must consume both shared charges")
addon:SetHolyPowerEstimate(0, true)
order = addon:GetDisplayOrder(now)
local armamentDisplay
for _, item in ipairs(order) do
    if item.ability.abilityKey == "paladin_holy_armament" then armamentDisplay = item break end
end
assert(armamentDisplay and armamentDisplay.remaining > 0,
    "Holy Armament must remain on its local recharge after both charges are consumed")
addon:ResetRuntimeState()
addon:BackoffRejectedRotationSlot(armamentIndex, now)
order = addon:GetDisplayOrder(now)
local backedOffArmament
for _, item in ipairs(order) do
    if item.ability.abilityKey == "paladin_holy_armament" then backedOffArmament = item break end
end
assert(backedOffArmament and backedOffArmament.remaining == 5
        and order[1].ability.abilityKey ~= "paladin_holy_armament",
    "a Blizzard-rejected ready Armament must leave primary position during its retry backoff")
addon:ClearRotationRejectionBackoff(armamentIndex)
assert(addon:GetSlot(wordIndex).enabled and not addon:GetSlotIndexByAbilityKey("paladin_eternal_flame"),
    "Lightsmith must use Word of Glory instead of Eternal Flame")
assert(addon:GetSlotIndexByAbilityKey("paladin_beacon_of_virtue"),
    "Beacon of Virtue must remain bindable in Raid when the talent is selected")
assert(addon:GetSlot(raidDawnIndex).roleLabel == "AOE",
    "Raid must retain Light of Dawn as its labelled AoE spender")
assert(namespace.AbilityLibrary:GetPresetPriorityKeys("paladin_lightsmith_raid", "standard")[1]
        == "paladin_holy_armament",
    "Lightsmith Raid must open with Holy Armament instead of a situational major cooldown")
assert(namespace.AbilityLibrary:GetPresetPriorityKeys("paladin_lightsmith_raid", "standard")[5]
        == "paladin_light_of_dawn",
    "Raid standard mode must keep Word of Glory ahead of the situational Light of Dawn")
for _, abilityKey in ipairs(namespace.AbilityLibrary:GetPresetPriorityKeys(
        "paladin_lightsmith_raid", "standard")) do
    assert(abilityKey ~= "paladin_avenging_wrath" and abilityKey ~= "paladin_avenging_crusader"
        and abilityKey ~= "paladin_aura_mastery",
        "Standard mode must not force situational major cooldowns")
end
assert(namespace.AbilityLibrary:GetPresetPriorityKeys("paladin_lightsmith_raid", "aoe")[1]
        == "paladin_aura_mastery",
    "explicit AoE mode must retain the optional major-cooldown path")

addon:SetRotationPreset("paladin_herald_mythicplus")
addon.talentSnapshot.paladinHerald = true
addon.talentSnapshot.paladinLightsmith = false
addon.talentSnapshot.paladinDivineToll = true
addon.talentSnapshot.paladinForewarning = false
addon.talentSnapshot.paladinValiance = false
addon.talentSnapshot.paladinLayingDownArms = false
addon.talentSnapshot.paladinSolidarity = false
addon.talentSnapshot.paladinAvengingWrath = true
addon.talentSnapshot.paladinHandOfDivinity = true
addon.talentSnapshot.paladinWalkIntoLight = true
addon.talentSnapshot.paladinAurora = false
local wingsIndex = addon:GetSlotIndexByAbilityKey("paladin_avenging_wrath")
assert(addon:GetSlot(wingsIndex).enabled, "Avenging Wrath must replace the unselected Avenging Crusader")
order = addon:GetDisplayOrder(now)
assert(displayContains(order, "paladin_judgment")
    and not displayContains(order, "paladin_hammer_of_wrath"),
    "Judgment alone must occupy the damage-generator branch outside Wings")
addon:SetHolyPowerEstimate(0, true)
addon:AcknowledgeSlot(tollIndex)
addon:AcknowledgeSlot(shockIndex)
assert(addon.sessionHolyPower == 4, "confirmed generators must be applied in cast order")
assert(addon:RefundAbility("toll"), "Divine Toll must be refundable for local recovery")
assert(addon.sessionHolyPower == 1,
    "refunding an older generator must replay later Holy Power events instead of rolling them back")
addon:AcknowledgeSlot(wingsIndex)
assert(addon.sessionHolyPower == 1,
    "Walk Into Light must not generate Holy Power after its 12.0.5 redesign")
order = addon:GetDisplayOrder(now)
assert(addon:IsPaladinWingsActive(now)
    and displayContains(order, "paladin_hammer_of_wrath")
    and not displayContains(order, "paladin_judgment"),
    "Hammer of Wrath alone must replace Judgment during confirmed Wings")
assert(addon.pendingPaladinHandOfDivinity and addon.pendingPaladinHandOfDivinity.uses == 2,
    "Hand of Divinity must arm two Holy Lights after Avenging Wrath")
assert(order[1].ability.abilityKey == "paladin_holy_light",
    "Hand of Divinity must immediately prioritize Holy Light in Standard mode")
addon:SetHolyPowerEstimate(0, true)
assert(addon:RecordPlayerSpellSucceeded(24275, "Wings-Hammer"),
    "Hammer of Wrath must be directly confirmable during Wings")
assert(addon.sessionHolyPower == 2,
    "Hammer of Wrath must inherit Judgment's additional Holy Power during Wings")
assert(addon.sessionUses[hammerIndex] == now and addon.sessionUses[sharedJudgmentIndex] == nil,
    "the shared Judgment input must commit Hammer of Wrath to its own cooldown state")
now = now + 1
addon.pendingPaladinInfusion = true
addon:SetHolyPowerEstimate(0, true)
assert(addon:RecordPlayerSpellSucceeded(24275, "Infused-Wings-Hammer"),
    "the Wings replacement must remain a valid Infusion consumer")
assert(addon.sessionHolyPower == 3 and not addon.pendingPaladinInfusion,
    "infused Hammer of Wrath must inherit both Judgment bonuses and consume Infusion")
addon:SetHealingMode("single", true)
order = addon:GetDisplayOrder(now)
assert(order[1].ability.abilityKey == "paladin_holy_light",
    "Hand of Divinity must surface its instant Holy Light in an explicit healing context")
addon:AcknowledgeSlot(holyLightIndex)
assert(addon.pendingPaladinHandOfDivinity.uses == 1,
    "the first Hand of Divinity Holy Light must leave one use")
assert(addon:GetPaladinInfusionCharges(now) == 1,
    "the Season 2 four-set must grant Infusion after the first Hand of Divinity Holy Light")
order = addon:GetDisplayOrder(now)
assert(order[1].ability.abilityKey == "paladin_flash_of_light"
        and abilityPosition((function()
            local keys = {}
            for _, item in ipairs(order) do keys[#keys + 1] = item.ability.abilityKey end
            return keys
        end)(), "paladin_holy_light") > 1,
    "the known Infusion must be consumed before the second Hand of Divinity Holy Light")
addon:AcknowledgeSlot(flashIndex)
assert(addon:GetPaladinInfusionCharges(now) == 0,
    "the interleaved Flash of Light must consume the known Infusion")
order = addon:GetDisplayOrder(now)
assert(order[1].ability.abilityKey == "paladin_eternal_flame"
        and displayContains(order, "paladin_holy_light"),
    "five Holy Power must be spent before the remaining Hand of Divinity Holy Light")
addon:AcknowledgeSlot(flameIndex)
order = addon:GetDisplayOrder(now)
assert(order[1].ability.abilityKey == "paladin_holy_light",
    "the remaining Hand of Divinity Holy Light must return after Infusion and capped Holy Power are spent")
addon:AcknowledgeSlot(holyLightIndex)
assert(not addon.pendingPaladinHandOfDivinity,
    "the second Hand of Divinity Holy Light must consume the local state")
addon:SetHealingMode("standard", true)
now = now + 20
addon:SetHolyPowerEstimate(0, true)
order = addon:GetDisplayOrder(now)
assert(not addon:IsPaladinWingsActive(now)
    and displayContains(order, "paladin_judgment")
    and not displayContains(order, "paladin_hammer_of_wrath"),
    "Judgment must return when the local Wings window expires")
assert(addon:SetHolyPowerEstimate(5, true) and addon.sessionHolyPower == 5,
    "manual Holy Power synchronization must accept exact values from zero to five")

addon.talentSnapshot.paladinAurora = true
addon:SetHolyPowerEstimate(0, true)
addon:AcknowledgeSlot(tollIndex)
assert(addon.sessionHolyPower == 3 and addon.pendingFreeHolyPowerSpenders == 1,
    "Aurora must arm one guaranteed free spender after Divine Toll")
addon:AcknowledgeSlot(flameIndex)
assert(addon.sessionHolyPower == 3 and addon.pendingFreeHolyPowerSpenders == 0,
    "the guaranteed Aurora spender must not subtract Holy Power")

addon.talentSnapshot.paladinAurora = false
addon:SetHolyPowerEstimate(2, true)
addon:AcknowledgeSlot(flameIndex)
assert(addon.sessionHolyPower == 2,
    "a confirmed spender below three Holy Power must be inferred as a free random proc")

addon.pendingFreeHolyPowerSpenders = 1
addon.holyPowerFreeSpenderBaseline = 1
assert(addon:ApplyAuthoritativeHolyPower(4) and addon.sessionHolyPower == 4,
    "readable player Holy Power must become the authoritative local baseline")
assert(addon.pendingFreeHolyPowerSpenders == 1,
    "resource synchronization must preserve a separately tracked guaranteed free spender")
local shield = namespace.AbilityLibrary:FindAbilityBySpellID(53600, "PALADIN")
assert(shield and shield.abilityKey == "paladin_shield_of_the_righteous",
    "the OBA observer must resolve Shield of the Righteous outside the healing priority")
addon:RecordHolyPowerEvent(0, shield)
assert(addon.sessionHolyPower == 4 and addon.pendingFreeHolyPowerSpenders == 0,
    "an OBA damage spender must consume a guaranteed free-spender state without losing Holy Power")

local activeShockIndex = addon:GetSlotIndexByAbilityKey("paladin_holy_shock")
addon.sessionCharges[activeShockIndex] = nil
addon:AcknowledgeSlot(activeShockIndex)
local shockRechargeBeforeShield = addon.sessionCharges[activeShockIndex].nextRechargeAt
addon:SetHolyPowerEstimate(3, true)
now = now + 1
assert(addon:RecordPlayerSpellSucceeded(53600, "Direct-Shield"),
    "a directly confirmed Shield of the Righteous must be observed from the configured priority")
assert(addon.sessionHolyPower == 0,
    "Shield of the Righteous must spend three Holy Power before Word of Glory is evaluated")
assert(addon.sessionCharges[activeShockIndex].nextRechargeAt == shockRechargeBeforeShield - 2,
    "Shield of the Righteous must reduce the running Holy Shock recharge by two seconds")
assert(not addon:RecordExternalHolyPowerSpell(53600, now),
    "a configured Shield must not also enter the external-spell fallback")
assert(addon.sessionHolyPower == 0,
    "the same Shield success must not spend Holy Power twice")

addon:SetHolyPowerEstimate(3, true)
addon.pendingAssistedCombat = { generation = addon.inputGeneration or 0, expectedSpellID = 53600 }
assert(addon:RecordPlayerSpellSucceeded(53600, "OBA-Shield"),
    "One Button Assistant must correlate Shield of the Righteous through its configured slot")
assert(addon.sessionHolyPower == 0,
    "One Button Assistant Shield must spend exactly three local Holy Power")
assert(addon.sessionCharges[activeShockIndex].nextRechargeAt == nil
        and addon.sessionCharges[activeShockIndex].baseCharges == 2,
    "One Button Assistant Shield must apply the same reduction and finish a ready Holy Shock charge")

addon.pendingPaladinInfusion = nil
assert(addon:RecordPlayerSpellSucceeded(24275, "Direct-Hammer"),
    "a confirmed Hammer of Wrath must be recognized directly")
assert(addon.sessionHolyPower == 1,
    "Hammer of Wrath must add one Holy Power only after its successful cast")

-- Only the deterministic 12.1 four-set Infusion is modeled. Random Holy
-- Shock and Judgment procs remain intentionally unreadable in combat.
addon:SetRotationPreset("paladin_herald_raid")
addon.talentSnapshot.paladinHerald = true
addon.talentSnapshot.paladinLightsmith = false
addon.talentSnapshot.paladinDivineToll = true
addon.talentSnapshot.paladinBeaconVirtue = false
addon.talentSnapshot.paladinTier4 = true
addon:SetHealingMode("standard", true)
addon:SetHolyPowerEstimate(0, true)
local raidHolyLightIndex = addon:GetSlotIndexByAbilityKey("paladin_holy_light")
local raidFlashIndex = addon:GetSlotIndexByAbilityKey("paladin_flash_of_light")
local raidJudgmentIndex = addon:GetSlotIndexByAbilityKey("paladin_judgment")
addon:AcknowledgeSlot(raidHolyLightIndex)
assert(addon.pendingPaladinInfusion, "four-set Holy Light must arm one guaranteed Infusion")
local raidShockIndex = addon:GetSlotIndexByAbilityKey("paladin_holy_shock")
addon:AcknowledgeSlot(raidShockIndex)
local shockRechargeBeforeInfusion = addon.sessionCharges[raidShockIndex].nextRechargeAt
order = addon:GetDisplayOrder(now)
assert(order[1].ability.abilityKey == "paladin_flash_of_light"
    and order[2].ability.abilityKey == "paladin_judgment"
    and not displayContains(order, "paladin_hammer_of_wrath"),
    "healing modes must spend Infusion on Flash of Light before the damage consumer")
addon:AcknowledgeSlot(raidJudgmentIndex)
assert(not addon.pendingPaladinInfusion, "Judgment must consume the local guaranteed Infusion")
order = addon:GetDisplayOrder(now)
assert(not displayContains(order, "paladin_flash_of_light"),
    "Flash of Light must disappear as soon as the locally known Infusion is consumed")
assert(addon.sessionCharges[raidShockIndex].nextRechargeAt == shockRechargeBeforeInfusion - 1,
    "Imbued Infusions must reduce the locally tracked Holy Shock recharge by one second")

addon.pendingPaladinInfusion = true
addon:AcknowledgeSlot(raidFlashIndex)
assert(not addon.pendingPaladinInfusion, "Flash of Light must remain a valid Infusion consumer")

addon:ResetRuntimeState()
addon.talentSnapshot.paladinTier4 = true
addon:SetHealingMode("mana", true)
addon:AcknowledgeSlot(raidHolyLightIndex)
assert(addon.pendingPaladinInfusion, "Holy Light must re-arm Infusion after a runtime reset")
order = addon:GetDisplayOrder(now)
assert(order[1].ability.abilityKey == "paladin_judgment",
    "Mana Saving must prefer the damage Infusion consumer")
addon:AcknowledgeSlot(raidJudgmentIndex)
assert(addon.sessionHolyPower == 3,
    "Holy Light plus infused Judgment must generate one plus two Holy Power")
assert(not addon.pendingPaladinInfusion, "Judgment must consume the local guaranteed Infusion")

addon:ResetRuntimeState()
addon.talentSnapshot.paladinTier4 = false
addon:AcknowledgeSlot(raidHolyLightIndex)
assert(not addon.pendingPaladinInfusion,
    "Holy Light must not invent an Infusion without the detected four-set")

addon:ResetRuntimeState()
addon.talentSnapshot.paladinTier4 = true
addon.talentSnapshot.paladinInflorescenceSunwell = true
now = 100
addon:AcknowledgeSlot(raidHolyLightIndex)
addon:AcknowledgeSlot(raidHolyLightIndex)
assert(addon:GetPaladinInfusionCharges(now) == 2,
    "Inflorescence of the Sunwell must retain two guaranteed Infusion charges")
addon:AcknowledgeSlot(raidFlashIndex)
assert(addon:GetPaladinInfusionCharges(now) == 1,
    "an Infusion consumer must spend only one of two locally tracked charges")
now = 116
assert(addon:GetPaladinInfusionCharges(now) == 0 and not addon.pendingPaladinInfusion,
    "locally tracked Infusion must expire after its 15-second duration")
addon.talentSnapshot.paladinInflorescenceSunwell = false

-- A configured dedicated Blizzard CDM item makes random Infusion procs
-- available to the same local priority/consumer model.
addon:ResetRuntimeState()
addon.talentSnapshot.paladinTier4 = false
local cdmInfusionActive = true
addon.ProcTracker = {
    GetInfusionOfLightState = function()
        return cdmInfusionActive, true
    end,
}
assert(addon:GetPaladinInfusionCharges(now) == 1
        and addon.pendingPaladinInfusion.source == "cdm",
    "a reliable active CDM item must import a random Infusion proc")
order = addon:GetDisplayOrder(now)
assert(displayContains(order, "paladin_flash_of_light"),
    "a CDM-observed Infusion must make its healing consumer eligible")
addon:AcknowledgeSlot(raidFlashIndex)
assert(addon:GetPaladinInfusionCharges(now) == 0,
    "a confirmed consumer must suppress immediate re-import of the same CDM visibility state")
now = now + 0.25
assert(addon:GetPaladinInfusionCharges(now) == 1,
    "continued CDM visibility after the recheck window must represent another possible charge")
cdmInfusionActive = false
assert(addon:GetPaladinInfusionCharges(now) == 0,
    "a reliable hidden CDM item must clear the imported Infusion state")
addon.ProcTracker = nil
now = 0

-- Avenging Crusader is a separate replacement window: it adds Crusader Strike
-- without removing Judgment or enabling Hammer of Wrath.
addon:SetRotationPreset("paladin_lightsmith_raid")
addon.talentSnapshot.paladinHerald = false
addon.talentSnapshot.paladinLightsmith = true
addon.talentSnapshot.paladinAvengingWrath = false
addon.talentSnapshot.paladinAvengingCrusader = true
addon.talentSnapshot.paladinHandOfDivinity = true
addon.talentSnapshot.paladinSanctifiedWrath = false
addon.talentSnapshot.paladinCallOfRighteous = true
addon.talentSnapshot.paladinCallOfRighteousRank = 2
addon.GetTalentRank = function(self, key)
    return key == "paladinCallOfRighteous" and self.talentSnapshot.paladinCallOfRighteousRank or 0
end
addon:SetHealingMode("aoe", true)
local crusaderIndex = addon:GetSlotIndexByAbilityKey("paladin_avenging_crusader")
local activeCrusaderStrikeIndex = addon:GetSlotIndexByAbilityKey("paladin_crusader_strike")
assert(addon:GetPaladinMajorCooldownDuration("paladin_avenging_crusader") == 11,
    "Call of the Righteous must remove two seconds per rank from Avenging Crusader")
addon:AcknowledgeSlot(crusaderIndex)
assert(addon:IsPaladinCrusaderActive(now) and addon.pendingPaladinHandOfDivinity.uses == 1,
    "Avenging Crusader must open its own window and arm one Hand of Divinity cast")
order = addon:GetDisplayOrder(now)
assert(displayContains(order, "paladin_judgment")
    and displayContains(order, "paladin_crusader_strike")
    and not displayContains(order, "paladin_hammer_of_wrath"),
    "Avenging Crusader must show Judgment plus Crusader Strike, never Hammer of Wrath")
local activeJudgmentIndex = addon:GetSlotIndexByAbilityKey("paladin_judgment")
addon:AcknowledgeSlot(activeJudgmentIndex)
local judgmentUsedAt = addon.sessionUses[activeJudgmentIndex]
now = now + 1
addon:SetHolyPowerEstimate(0, true)
addon:AcknowledgeSlot(activeCrusaderStrikeIndex)
assert(addon.sessionHolyPower == 1,
    "confirmed Crusader Strike must generate one Holy Power in its active window")
assert(addon.sessionUses[activeJudgmentIndex] == judgmentUsedAt - 1.5,
    "Crusader's Might must reduce Judgment after confirmed Crusader Strike")
addon.talentSnapshot.paladinSanctifiedWrath = true
assert(addon:GetPaladinMajorCooldownDuration("paladin_avenging_wrath") == 21,
    "Sanctified Wrath must extend the Call-adjusted Avenging Wrath duration by 50 percent")

print("paladin_rotation.lua: OK")
