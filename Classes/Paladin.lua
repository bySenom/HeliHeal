local _, ns = ...
local library = ns.AbilityLibrary

-- Holy Paladin priority data for Midnight 12.1.
-- Guide snapshot: Wowhead/Icy Veins/Method, reviewed 2026-09-14.
-- https://www.wowhead.com/guide/classes/paladin/holy/rotation-cooldowns-pve-healer
local abilities = {
    paladin_holy_shock = {
        spellID = 20473, name = "Holy Shock", cooldown = 6, maxCharges = 1,
        bonusChargeTalent = "paladinLightsConviction",
        holyPowerGain = 1, hastedCooldown = true, inputLockout = 1.5,
    },
    paladin_divine_toll = {
        spellID = 375576, name = "Divine Toll", cooldown = 45,
        castSpellIDs = { 375576, 304971 }, holyPowerGain = 3,
        maxHolyPower = 2, requiresTalent = "paladinDivineToll",
        excludesTalent = "paladinLightsmith", cooldownTalent = "paladinQuickenedInvocation",
        cooldownReduction = 15, grantsFreeSpenderTalent = "paladinAurora", inputLockout = 1.5,
    },
    paladin_holy_prism = {
        spellID = 114165, name = "Holy Prism", cooldown = 45,
        holyPowerGain = 3, maxHolyPower = 2, requiresTalent = "paladinHolyPrism",
        excludesTalent = "paladinLightsmith", cooldownTalent = "paladinQuickenedInvocation",
        cooldownReduction = 15, grantsFreeSpenderTalent = "paladinAurora", inputLockout = 1.5,
    },
    paladin_holy_armament = {
        spellID = 432459, name = "Holy Bulwark", cooldown = 60, maxCharges = 2,
        castSpellIDs = { 432459, 432472 }, holyPowerGain = 3, maxHolyPower = 2,
        requiresTalent = "paladinLightsmith", cooldownTalent = "paladinQuickenedInvocation",
        cooldownReduction = 15, cooldownPercentTalents = { paladinForewarning = 20 },
        confirmOnPlayerSuccess = true, inputLockout = 1.5,
    },
    paladin_avenging_wrath = {
        spellID = 31884, name = "Avenging Wrath", cooldown = 120,
        requiresTalent = "paladinAvengingWrath", cooldownRankTalent = "paladinCallOfRighteous",
        cooldownReductionPerRank = 15, confirmOnPlayerSuccess = true, inputLockout = 1.0,
    },
    paladin_avenging_crusader = {
        spellID = 216331, name = "Avenging Crusader", cooldown = 60,
        requiresTalent = "paladinAvengingCrusader", cooldownRankTalent = "paladinCallOfRighteous",
        cooldownReductionPerRank = 7.5, confirmOnPlayerSuccess = true, inputLockout = 1.0,
    },
    paladin_aura_mastery = {
        spellID = 31821, name = "Aura Mastery", cooldown = 180,
        requiresTalent = "paladinAuraMastery", holyPowerGain = 0,
        holyPowerGainTalent = "paladinRingingHeavens", holyPowerTalentGain = 3,
        grantsFreeSpenderTalent = "paladinAurora",
        grantsFreeSpenderRequiredTalent = "paladinRingingHeavens",
        cooldownTalent = "paladinUnwaveringSpirit",
        cooldownReduction = 30, confirmOnPlayerSuccess = true, inputLockout = 1.5,
    },
    paladin_beacon_of_virtue = {
        spellID = 200025, name = "Beacon of Virtue", cooldown = 15,
        requiresTalent = "paladinBeaconVirtue", roleLabel = "BURST",
        confirmOnPlayerSuccess = true, inputLockout = 1.5,
    },
    paladin_judgment = {
        spellID = 275773, name = "Judgment", cooldown = 11,
        castSpellIDs = { 24275 }, holyPowerGain = 1, hastedCooldown = true,
        confirmOnPlayerSuccess = true, inputLockout = 1.5,
    },
    paladin_hammer_of_wrath = {
        spellID = 24275, name = "Hammer of Wrath", cooldown = 7.5,
        holyPowerGain = 1, hastedCooldown = true,
        confirmOnPlayerSuccess = true, inputLockout = 1.5,
        derivedBindingFrom = "paladin_judgment",
    },
    -- Observed for One Button Assistant resource reconciliation. These do not
    -- appear in HeliHeal's healing priority or binding options.
    paladin_crusader_strike = {
        spellID = 35395, name = "Crusader Strike", cooldown = 6,
        holyPowerGain = 1, hastedCooldown = true,
        requiresTalent = "paladinAvengingCrusader",
        confirmOnPlayerSuccess = true, inputLockout = 1.5,
    },
    paladin_shield_of_the_righteous = {
        spellID = 53600, name = "Shield of the Righteous", cooldown = 0,
        holyPowerCost = 3, confirmOnPlayerSuccess = true, inputLockout = 1.0,
    },
    paladin_word_of_glory = {
        spellID = 85673, name = "Word of Glory", cooldown = 0,
        holyPowerCost = 3, excludesTalent = "paladinHerald", inputLockout = 1.5,
    },
    paladin_eternal_flame = {
        spellID = 156322, name = "Eternal Flame", cooldown = 0,
        holyPowerCost = 3, requiresTalent = "paladinHerald", inputLockout = 1.5,
    },
    paladin_light_of_dawn = {
        spellID = 85222, name = "Light of Dawn", cooldown = 0,
        holyPowerCost = 3, roleLabel = "AOE", inputLockout = 1.5,
    },
    paladin_holy_light = {
        spellID = 82326, name = "Holy Light", cooldown = 0,
        holyPowerGain = 1, roleLabel = "SAVE", inputLockout = 1.5,
    },
    paladin_flash_of_light = {
        spellID = 19750, name = "Flash of Light", cooldown = 0,
        holyPowerGain = 1, roleLabel = "BURST", inputLockout = 1.5,
    },
    -- These tools use the same confirmed-cast and local cooldown ledger as the
    -- healing rotation, but are rendered in a separate readiness strip. Their
    -- correct use depends on incoming damage, target state and encounter
    -- mechanics that Midnight intentionally keeps out of recommendation logic.
    paladin_divine_protection = {
        spellID = 498, name = "Divine Protection", cooldown = 60,
        cooldownPercentTalents = { paladinUnbreakableSpirit = 30 },
        confirmOnPlayerSuccess = true, inputLockout = 0.5,
    },
    paladin_divine_shield = {
        spellID = 642, name = "Divine Shield", cooldown = 300,
        cooldownPercentTalents = { paladinUnbreakableSpirit = 30 },
        confirmOnPlayerSuccess = true, inputLockout = 1.5,
    },
    paladin_blessing_of_sacrifice = {
        spellID = 6940, name = "Blessing of Sacrifice", cooldown = 120,
        requiresTalent = "paladinBlessingSacrifice",
        cooldownTalent = "paladinSacrificeOfTheJust", cooldownReduction = 15,
        confirmOnPlayerSuccess = true, inputLockout = 0.5,
    },
    paladin_lay_on_hands = {
        spellID = 633, name = "Lay on Hands", cooldown = 600,
        requiresTalent = "paladinLayOnHands",
        cooldownPercentTalents = {
            paladinUnbreakableSpirit = 30,
            paladinTirionsDevotion = 40,
        },
        confirmOnPlayerSuccess = true, inputLockout = 0.5,
    },
    paladin_blessing_of_protection = {
        spellID = 1022, name = "Blessing of Protection", cooldown = 300,
        requiresTalent = "paladinBlessingProtection",
        cooldownTalent = "paladinImprovedBlessingProtection", cooldownReduction = 60,
        confirmOnPlayerSuccess = true, inputLockout = 1.5,
    },
    paladin_divine_steed = {
        spellID = 190784, name = "Divine Steed", cooldown = 45, maxCharges = 1,
        requiresTalent = "paladinDivineSteed", bonusChargeTalent = "paladinCavalier",
        cooldownPercentTalents = { paladinDivineSpurs = 20 },
        confirmOnPlayerSuccess = true, inputLockout = 0.5,
    },
}

for key, ability in pairs(abilities) do
    ability.class = "PALADIN"
    ability.specialization = "Holy"
    library:RegisterAbility(key, ability)
end

local function modeSlots(hero, raid)
    local spender = hero == "herald" and "paladin_eternal_flame" or "paladin_word_of_glory"
    local generator = hero == "lightsmith" and "paladin_holy_armament" or "paladin_divine_toll"
    local prism = hero == "herald" and { "paladin_holy_prism" } or {}
    -- Beacon of Virtue is a normal talent choice in both content types. Its
    -- requiresTalent flag keeps it hidden when the active loadout omits it.
    local virtue = { "paladin_beacon_of_virtue" }
    -- Light of Dawn is a raid-only Holy Power spender. In Mythic+ the local
    -- model should reserve Holy Power for Eternal Flame or Word of Glory.
    local dawn = raid and { "paladin_light_of_dawn" } or {}
    local function list(...)
        local result = {}
        for _, value in ipairs({ ... }) do
            if type(value) == "table" then
                for _, nested in ipairs(value) do result[#result + 1] = nested end
            else
                result[#result + 1] = value
            end
        end
        return result
    end
    return {
        -- Major cooldowns are intentionally reserved for the explicit AoE
        -- context because the static tracker cannot see incoming damage.
        standard = list(generator, prism, virtue, "paladin_holy_shock", spender,
            dawn, "paladin_judgment", "paladin_hammer_of_wrath",
            "paladin_crusader_strike", "paladin_flash_of_light", "paladin_holy_light",
            "paladin_shield_of_the_righteous"),
        aoe = list("paladin_aura_mastery", "paladin_avenging_wrath", "paladin_avenging_crusader",
            generator, prism, virtue, "paladin_holy_shock", dawn, spender,
            "paladin_flash_of_light", "paladin_holy_light", "paladin_judgment",
            "paladin_hammer_of_wrath", "paladin_crusader_strike", "paladin_shield_of_the_righteous"),
        single = list(generator, prism, "paladin_holy_shock", spender,
            "paladin_flash_of_light", "paladin_holy_light", "paladin_judgment",
            "paladin_hammer_of_wrath", "paladin_crusader_strike",
            "paladin_shield_of_the_righteous", dawn),
        mana = list(generator, prism, "paladin_holy_shock", spender,
            dawn, "paladin_judgment", "paladin_hammer_of_wrath",
            "paladin_crusader_strike", "paladin_shield_of_the_righteous",
            "paladin_flash_of_light", "paladin_holy_light"),
    }
end

local SUPPORT_SLOTS = {
    "paladin_divine_protection",
    "paladin_divine_shield",
    "paladin_blessing_of_sacrifice",
    "paladin_lay_on_hands",
    "paladin_blessing_of_protection",
    "paladin_divine_steed",
}

local function registerPreset(key, name, heroTalent, hero, content)
    local modes = modeSlots(hero, content == "Raid")
    library:RegisterPreset(key, {
        name = name,
        class = "PALADIN",
        specialization = "Holy",
        heroTalent = heroTalent,
        content = content,
        guideVersion = "12.1",
        guideUpdated = "2026-09-13",
        slots = modes.standard,
        modeSlots = modes,
        supportSlots = SUPPORT_SLOTS,
    })
end

registerPreset("paladin_herald_mythicplus", "Herald of the Sun • Mythic+", "Herald of the Sun", "herald", "Mythic+")
registerPreset("paladin_herald_raid", "Herald of the Sun • Raid", "Herald of the Sun", "herald", "Raid")
registerPreset("paladin_lightsmith_mythicplus", "Lightsmith • Mythic+", "Lightsmith", "lightsmith", "Mythic+")
registerPreset("paladin_lightsmith_raid", "Lightsmith • Raid", "Lightsmith", "lightsmith", "Raid")
