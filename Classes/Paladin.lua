local _, ns = ...
local library = ns.AbilityLibrary

-- Holy Paladin priority data for Midnight 12.1.
-- Guide snapshot: Wowhead, updated 2026-07-10.
-- https://www.wowhead.com/guide/classes/paladin/holy/rotation-cooldowns-pve-healer
local abilities = {
    paladin_holy_shock = {
        spellID = 20473, name = "Holy Shock", cooldown = 6, maxCharges = 2,
        holyPowerGain = 1, inputLockout = 1.5,
    },
    paladin_divine_toll = {
        spellID = 375576, name = "Divine Toll", cooldown = 60,
        castSpellIDs = { 375576, 304971 }, holyPowerGain = 3,
        maxHolyPower = 2, inputLockout = 1.5,
    },
    paladin_holy_prism = {
        spellID = 114165, name = "Holy Prism", cooldown = 45,
        holyPowerGain = 3, maxHolyPower = 2, inputLockout = 1.5,
    },
    paladin_holy_armament = {
        spellID = 432459, name = "Holy Armament", cooldown = 60, maxCharges = 2,
        castSpellIDs = { 432459, 432472 }, holyPowerGain = 3, maxHolyPower = 2,
        inputLockout = 1.5,
    },
    paladin_word_of_glory = {
        spellID = 85673, name = "Word of Glory", cooldown = 0,
        holyPowerCost = 3, inputLockout = 1.5,
    },
    paladin_eternal_flame = {
        spellID = 156322, name = "Eternal Flame", cooldown = 0,
        holyPowerCost = 3, inputLockout = 1.5,
    },
    paladin_light_of_dawn = {
        spellID = 85222, name = "Light of Dawn", cooldown = 0,
        holyPowerCost = 3, inputLockout = 1.5,
    },
    paladin_holy_light = {
        spellID = 82326, name = "Holy Light", cooldown = 0,
        holyPowerGain = 1, inputLockout = 1.5,
    },
    paladin_flash_of_light = {
        spellID = 19750, name = "Flash of Light", cooldown = 0,
        holyPowerGain = 1, inputLockout = 1.5,
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
    local primarySpender = raid and "paladin_light_of_dawn" or spender
    local secondarySpender = raid and spender or "paladin_light_of_dawn"
    return {
        standard = list(generator, prism, "paladin_holy_shock", primarySpender,
            secondarySpender, "paladin_holy_light", "paladin_flash_of_light"),
        aoe = list(generator, prism, "paladin_holy_shock", "paladin_light_of_dawn",
            spender, "paladin_holy_light", "paladin_flash_of_light"),
        single = list(generator, prism, "paladin_holy_shock", spender,
            "paladin_holy_light", "paladin_flash_of_light", "paladin_light_of_dawn"),
        mana = list(generator, prism, "paladin_holy_shock", primarySpender,
            secondarySpender, "paladin_flash_of_light", "paladin_holy_light"),
    }
end

local function registerPreset(key, name, heroTalent, hero, content)
    local modes = modeSlots(hero, content == "Raid")
    library:RegisterPreset(key, {
        name = name,
        class = "PALADIN",
        specialization = "Holy",
        heroTalent = heroTalent,
        content = content,
        guideVersion = "12.1",
        guideUpdated = "2026-07-10",
        slots = modes.standard,
        modeSlots = modes,
    })
end

registerPreset("paladin_herald_mythicplus", "Herald of the Sun • Mythic+", "Herald of the Sun", "herald", "Mythic+")
registerPreset("paladin_herald_raid", "Herald of the Sun • Raid", "Herald of the Sun", "herald", "Raid")
registerPreset("paladin_lightsmith_mythicplus", "Lightsmith • Mythic+", "Lightsmith", "lightsmith", "Mythic+")
registerPreset("paladin_lightsmith_raid", "Lightsmith • Raid", "Lightsmith", "lightsmith", "Raid")
