local _, ns = ...
local library = ns.AbilityLibrary

-- Discipline Priest priority data for Midnight 12.1.
-- Rotation snapshot reviewed 2026-08-17 against the current Wowhead Midnight
-- guide and 12.1 spell database. HeliHeal models only confirmed player casts;
-- Atonement, health, targets and combat auras remain deliberately unread.
local abilities = {
    disc_evangelism = {
        spellID = 472433, name = "Evangelism", cooldown = 90,
        requiresTalent = "discEvangelism", confirmOnPlayerSuccess = true,
        roleLabel = "BURST", inputLockout = 1.5,
    },
    disc_power_word_radiance = {
        spellID = 194509, castSpellIDs = { 194509, 246097 },
        name = "Power Word: Radiance", cooldown = 18,
        bonusChargeTalent = "discLightsPromise",
        cooldownTalent = "discBrightPupil", cooldownReduction = 3,
        hastedCooldown = true, roleLabel = "AOE", inputLockout = 2.0,
    },
    disc_penance = {
        spellID = 47540, name = "Penance", cooldown = 9,
        bonusChargeTalent = "priestOracle", hastedCooldown = true,
        roleLabel = "BURST", inputLockout = 2.0,
    },
    disc_ultimate_penitence = {
        spellID = 421453, name = "Ultimate Penitence", cooldown = 240,
        requiresTalent = "discUltimatePenitence", confirmOnPlayerSuccess = true,
        roleLabel = "BURST", inputLockout = 7.5,
    },
    disc_power_word_barrier = {
        spellID = 62618, name = "Power Word: Barrier", cooldown = 180,
        requiresTalent = "discPowerWordBarrier", confirmOnPlayerSuccess = true,
        roleLabel = "AOE", inputLockout = 1.5,
    },
    disc_pain_suppression = {
        spellID = 33206, name = "Pain Suppression", cooldown = 180,
        requiresTalent = "discPainSuppression", confirmOnPlayerSuccess = true,
        roleLabel = "SAVE", inputLockout = 1.0,
    },
    disc_mind_blast = {
        spellID = 8092, name = "Mind Blast", cooldown = 9,
        hastedCooldown = true, roleLabel = "SINGLE", inputLockout = 1.5,
    },
    disc_shadow_word_death = {
        spellID = 32379, castSpellIDs = { 32379, 1240008 },
        name = "Shadow Word: Death", cooldown = 20,
        roleLabel = "SINGLE", inputLockout = 1.5,
    },
    disc_power_word_shield = {
        spellID = 17, castSpellIDs = { 17, 1253593 },
        name = "Power Word: Shield / Void Shield", cooldown = 0,
        confirmOnPlayerSuccess = true,
        trackedDuration = 15, trackedGoal = 1, roleLabel = "SAVE", inputLockout = 1.5,
    },
    disc_smite = {
        spellID = 585, castSpellIDs = { 585, 450215 }, name = "Smite / Void Blast", cooldown = 0,
        roleLabel = "SINGLE", inputLockout = 1.5,
    },
}

for key, ability in pairs(abilities) do
    ability.class = "PRIEST"
    ability.specialization = "Discipline"
    ability.specializationID = 256
    library:RegisterAbility(key, ability)
end

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

local function modeSlots(hero, raid)
    local damageCore = hero == "voidweaver"
        and { "disc_mind_blast", "disc_penance", "disc_shadow_word_death" }
        or { "disc_penance", "disc_mind_blast", "disc_shadow_word_death" }
    local ramp = raid
        and { "disc_power_word_shield", "disc_evangelism", "disc_power_word_radiance" }
        or { "disc_evangelism", "disc_power_word_radiance", "disc_power_word_shield" }

    return {
        -- Shadow Word: Pain maintenance and Shadow Mend/Flash Heal procs require
        -- target or aura context that this static input tracker intentionally lacks.
        -- Master the Darkness overrides Power Word: Shield with Void Shield on
        -- the same action-bar button; disc_power_word_shield accepts both casts.
        standard = list(ramp, damageCore,
            "disc_ultimate_penitence", "disc_power_word_barrier", "disc_pain_suppression", "disc_smite"),
        aoe = list("disc_evangelism",
            "disc_power_word_radiance", "disc_ultimate_penitence", "disc_power_word_barrier",
            damageCore, "disc_power_word_shield", "disc_smite", "disc_pain_suppression"),
        single = list("disc_pain_suppression", "disc_penance",
            "disc_power_word_shield", "disc_evangelism", "disc_power_word_radiance",
            "disc_mind_blast", "disc_shadow_word_death",
            "disc_ultimate_penitence", "disc_power_word_barrier", "disc_smite"),
        mana = list("disc_evangelism",
            "disc_power_word_radiance", damageCore, "disc_smite", "disc_power_word_shield",
            "disc_ultimate_penitence", "disc_power_word_barrier", "disc_pain_suppression"),
    }
end

local function registerPreset(key, name, heroTalent, hero, content)
    local modes = modeSlots(hero, content == "Raid")
    library:RegisterPreset(key, {
        name = name,
        class = "PRIEST",
        specialization = "Discipline",
        specializationID = 256,
        heroTalent = heroTalent,
        content = content,
        guideVersion = "12.1",
        guideUpdated = "2026-08-17",
        slots = modes.standard,
        modeSlots = modes,
    })
end

registerPreset("disc_oracle_mythicplus", "Oracle • Mythic+", "Oracle", "oracle", "Mythic+")
registerPreset("disc_oracle_raid", "Oracle • Raid", "Oracle", "oracle", "Raid")
registerPreset("disc_voidweaver_mythicplus", "Voidweaver • Mythic+", "Voidweaver", "voidweaver", "Mythic+")
registerPreset("disc_voidweaver_raid", "Voidweaver • Raid", "Voidweaver", "voidweaver", "Raid")
