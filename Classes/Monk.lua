local _, ns = ...
local library = ns.AbilityLibrary

-- Mistweaver Monk priority data for Midnight 12.1.
-- Guide snapshot: Wowhead, updated 2026-08-15.
-- https://www.wowhead.com/guide/classes/monk/mistweaver/rotation-cooldowns-pve-healer
local abilities = {
    monk_renewing_mist = {
        spellID = 115151, name = "Renewing Mist", cooldown = 9, maxCharges = 2,
        bonusChargeTalent = "monkPoolOfMists", hastedCooldown = true,
        confirmOnPlayerSuccess = true, roleLabel = "AOE", inputLockout = 1.0,
    },
    monk_thunder_focus_tea = {
        spellID = 116680, name = "Thunder Focus Tea", cooldown = 30, maxCharges = 1,
        bonusChargeTalent = "monkEndlessDraught", requiresTalent = "monkThunderFocusTea",
        confirmOnPlayerSuccess = true, roleLabel = "BURST", inputLockout = 0.5,
    },
    monk_rising_sun_kick = {
        spellID = 107428, name = "Rising Sun Kick", cooldown = 10,
        excludesTalent = "monkRushingWindKick", hastedCooldown = true,
        confirmOnPlayerSuccess = true, roleLabel = "SINGLE", inputLockout = 1.0,
    },
    monk_rushing_wind_kick = {
        spellID = 467307, name = "Rushing Wind Kick", cooldown = 10,
        requiresTalent = "monkRushingWindKick", hastedCooldown = true,
        derivedBindingFrom = "monk_rising_sun_kick",
        confirmOnPlayerSuccess = true, roleLabel = "AOE", inputLockout = 1.0,
    },
    monk_blackout_kick = {
        spellID = 100784, name = "Blackout Kick", cooldown = 3,
        hastedCooldown = true, confirmOnPlayerSuccess = true,
        roleLabel = "SINGLE", inputLockout = 1.0,
    },
    monk_tiger_palm = {
        spellID = 100780, name = "Tiger Palm", cooldown = 0,
        confirmOnPlayerSuccess = true, roleLabel = "SINGLE", inputLockout = 1.0,
    },
    monk_spinning_crane_kick = {
        spellID = 101546, name = "Spinning Crane Kick", cooldown = 0,
        confirmOnPlayerSuccess = true, roleLabel = "AOE", inputLockout = 1.5,
    },
    monk_vivify = {
        spellID = 116670, name = "Vivify", cooldown = 0,
        excludesTalent = "monkSheilunsGift", roleLabel = "SINGLE", inputLockout = 1.5,
    },
    monk_sheiluns_gift = {
        spellID = 399491, name = "Sheilun's Gift", cooldown = 0,
        recommendationLockout = 8, requiresTalent = "monkSheilunsGift",
        confirmOnPlayerSuccess = true, roleLabel = "BURST", inputLockout = 2.0,
        derivedBindingFrom = "monk_vivify",
    },
    monk_enveloping_mist = {
        spellID = 124682, name = "Enveloping Mist", cooldown = 0,
        requiresTalent = "monkEnvelopingMist", roleLabel = "BURST", inputLockout = 2.0,
    },
    monk_soothing_mist = {
        spellID = 115175, name = "Soothing Mist", cooldown = 0,
        roleLabel = "SAVE", inputLockout = 1.0,
    },
    monk_life_cocoon = {
        spellID = 116849, name = "Life Cocoon", cooldown = 120,
        requiresTalent = "monkLifeCocoon", cooldownTalent = "monkChrysalis",
        cooldownReduction = 45, confirmOnPlayerSuccess = true,
        roleLabel = "SAVE", inputLockout = 0.75,
    },
    monk_revival = {
        spellID = 115310, name = "Revival", cooldown = 180,
        requiresTalent = "monkRevival", cooldownTalent = "monkUpliftedSpirits",
        cooldownReduction = 30, confirmOnPlayerSuccess = true,
        roleLabel = "BURST", inputLockout = 1.0,
    },
    monk_restoral = {
        spellID = 388615, name = "Restoral", cooldown = 180,
        requiresTalent = "monkRestoral", cooldownTalent = "monkUpliftedSpirits",
        cooldownReduction = 30, confirmOnPlayerSuccess = true,
        roleLabel = "BURST", inputLockout = 1.0,
        derivedBindingFrom = "monk_revival",
    },
    monk_yulon = {
        spellID = 322118, name = "Invoke Yu'lon, the Jade Serpent", cooldown = 120,
        requiresTalent = "monkYulon", cooldownTalent = "monkGiftCelestials",
        cooldownReduction = 60, confirmOnPlayerSuccess = true,
        roleLabel = "BURST", inputLockout = 1.5,
    },
    monk_chiji = {
        spellID = 325197, name = "Invoke Chi-Ji, the Red Crane", cooldown = 120,
        requiresTalent = "monkChiji", cooldownTalent = "monkGiftCelestials",
        cooldownReduction = 60, confirmOnPlayerSuccess = true,
        roleLabel = "BURST", inputLockout = 1.5,
        derivedBindingFrom = "monk_yulon",
    },
    monk_celestial_conduit = {
        spellID = 443028, name = "Celestial Conduit", cooldown = 90,
        requiresTalent = "monkConduit", confirmOnPlayerSuccess = true,
        roleLabel = "BURST", inputLockout = 4.0,
    },
}

for key, ability in pairs(abilities) do
    ability.class = "MONK"
    ability.specialization = "Mistweaver"
    library:RegisterAbility(key, ability)
end

local BINDABLE_SLOTS = {
    "monk_renewing_mist", "monk_thunder_focus_tea",
    "monk_rising_sun_kick", "monk_rushing_wind_kick",
    "monk_tiger_palm", "monk_blackout_kick", "monk_spinning_crane_kick",
    "monk_vivify", "monk_sheiluns_gift", "monk_enveloping_mist",
    "monk_soothing_mist", "monk_life_cocoon", "monk_revival",
    "monk_restoral", "monk_yulon", "monk_chiji", "monk_celestial_conduit",
}

local function appendPriority(first, second)
    local result = {}
    for _, abilityKey in ipairs(first or {}) do result[#result + 1] = abilityKey end
    for _, abilityKey in ipairs(second or {}) do result[#result + 1] = abilityKey end
    return result
end

local function modes(content, heroKey)
    local raid = content == "Raid"
    local aoeCooldowns = {
        "monk_revival", "monk_restoral",
    }
    if heroKey == "conduit" then
        aoeCooldowns[#aoeCooldowns + 1] = "monk_celestial_conduit"
    end
    aoeCooldowns[#aoeCooldowns + 1] = "monk_yulon"
    aoeCooldowns[#aoeCooldowns + 1] = "monk_chiji"

    if raid then
        return {
            standard = {
                "monk_rushing_wind_kick", "monk_rising_sun_kick",
                "monk_thunder_focus_tea", "monk_renewing_mist",
                "monk_sheiluns_gift", "monk_tiger_palm", "monk_blackout_kick",
                "monk_spinning_crane_kick",
            },
            aoe = appendPriority(aoeCooldowns, {
                "monk_renewing_mist", "monk_rushing_wind_kick", "monk_rising_sun_kick",
                "monk_sheiluns_gift", "monk_spinning_crane_kick", "monk_thunder_focus_tea",
            }),
            single = {
                "monk_life_cocoon", "monk_thunder_focus_tea", "monk_enveloping_mist",
                "monk_soothing_mist", "monk_vivify", "monk_sheiluns_gift",
                "monk_renewing_mist", "monk_rushing_wind_kick", "monk_rising_sun_kick",
            },
            mana = {
                "monk_renewing_mist", "monk_rushing_wind_kick", "monk_rising_sun_kick",
                "monk_thunder_focus_tea", "monk_tiger_palm", "monk_blackout_kick",
            },
        }
    end
    return {
        standard = {
            "monk_rushing_wind_kick", "monk_rising_sun_kick", "monk_thunder_focus_tea",
            "monk_renewing_mist", "monk_sheiluns_gift", "monk_tiger_palm",
            "monk_blackout_kick", "monk_spinning_crane_kick",
        },
        aoe = appendPriority(aoeCooldowns, {
            "monk_sheiluns_gift", "monk_renewing_mist",
            "monk_rushing_wind_kick", "monk_rising_sun_kick", "monk_spinning_crane_kick",
            "monk_thunder_focus_tea",
        }),
        single = {
            "monk_life_cocoon", "monk_thunder_focus_tea", "monk_enveloping_mist",
            "monk_soothing_mist", "monk_vivify", "monk_sheiluns_gift",
            "monk_renewing_mist", "monk_rushing_wind_kick", "monk_rising_sun_kick",
            "monk_tiger_palm", "monk_blackout_kick",
        },
        mana = {
            "monk_thunder_focus_tea", "monk_renewing_mist", "monk_rushing_wind_kick",
            "monk_rising_sun_kick", "monk_tiger_palm", "monk_blackout_kick",
        },
    }
end

local function registerPreset(key, name, heroTalent, heroKey, content)
    local modeSlots = modes(content, heroKey)
    library:RegisterPreset(key, {
        name = name,
        class = "MONK",
        specialization = "Mistweaver",
        heroTalent = heroTalent,
        content = content,
        guideVersion = "12.1",
        guideUpdated = "2026-08-15",
        -- Keep the complete talent union bindable while each healing mode gets
        -- a deliberately small, context-safe priority list.
        slots = BINDABLE_SLOTS,
        modeSlots = modeSlots,
        renewingMistGoals = content == "Raid" and {
            standard = 8, aoe = 10, single = 2, mana = 5,
        } or {
            standard = 4, aoe = 5, single = 2, mana = 3,
        },
    })
end

registerPreset("monk_conduit_mythicplus", "Conduit of the Celestials • Mythic+", "Conduit of the Celestials", "conduit", "Mythic+")
registerPreset("monk_conduit_raid", "Conduit of the Celestials • Raid", "Conduit of the Celestials", "conduit", "Raid")
registerPreset("monk_harmony_mythicplus", "Master of Harmony • Mythic+", "Master of Harmony", "harmony", "Mythic+")
registerPreset("monk_harmony_raid", "Master of Harmony • Raid", "Master of Harmony", "harmony", "Raid")
