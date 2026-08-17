local _, ns = ...
local library = ns.AbilityLibrary

-- Holy Priest priority data for Midnight 12.1.
-- Guide snapshot: Wowhead, updated 2026-08-12.
-- https://www.wowhead.com/guide/classes/priest/holy/rotation-cooldowns-pve-healer
local abilities = {
    priest_apotheosis = {
        spellID = 200183, name = "Apotheosis", cooldown = 120,
        requiresTalent = "priestApotheosis", confirmOnPlayerSuccess = true,
        roleLabel = "BURST", inputLockout = 1.5,
    },
    priest_divine_hymn = {
        spellID = 64843, name = "Divine Hymn", cooldown = 180,
        requiresTalent = "priestDivineHymn", confirmOnPlayerSuccess = true,
        roleLabel = "BURST", inputLockout = 1.5,
    },
    priest_halo = {
        spellID = 120517, name = "Halo", cooldown = 60,
        requiresTalent = "priestArchon", roleLabel = "AOE", inputLockout = 1.5,
    },
    priest_guardian_spirit = {
        spellID = 47788, name = "Guardian Spirit", cooldown = 180,
        requiresTalent = "priestGuardianSpirit", confirmOnPlayerSuccess = true,
        roleLabel = "SAVE", inputLockout = 1.5,
    },
    priest_holy_word_serenity = {
        spellID = 2050, name = "Holy Word: Serenity", cooldown = 60,
        castSpellIDs = { 2050, 1250581 }, bonusChargeTalent = "priestMiracleWorker",
        cooldownTalent = "priestHolyCelerity", cooldownReduction = 15,
        roleLabel = "SINGLE", inputLockout = 1.5,
    },
    priest_holy_word_sanctify = {
        spellID = 34861, name = "Holy Word: Sanctify", cooldown = 60,
        requiresTalent = "priestSanctify", excludesTalent = "priestUltimateSerenity",
        bonusChargeTalent = "priestMiracleWorker", cooldownTalent = "priestHolyCelerity",
        cooldownReduction = 15, roleLabel = "AOE", inputLockout = 1.5,
    },
    priest_prayer_of_mending = {
        spellID = 33076, name = "Prayer of Mending", cooldown = 12,
        bonusChargeTalent = "priestOracle", roleLabel = "AOE", inputLockout = 1.5,
    },
    priest_prayer_of_healing = {
        spellID = 596, name = "Prayer of Healing", cooldown = 0,
        requiresTalent = "priestPrayerOfHealing", roleLabel = "AOE", inputLockout = 1.5,
    },
    priest_flash_heal = {
        spellID = 2061, name = "Flash Heal", cooldown = 0,
        castSpellIDs = { 2061, 1262763 }, roleLabel = "SAVE", inputLockout = 1.5,
    },
    priest_holy_word_chastise = {
        spellID = 88625, name = "Holy Word: Chastise", cooldown = 60,
        requiresTalent = "priestChastise", cooldownTalent = "priestHolyCelerity", cooldownReduction = 15,
        roleLabel = "SINGLE", inputLockout = 1.5,
    },
    priest_smite = {
        spellID = 585, name = "Smite", cooldown = 0,
        roleLabel = "SINGLE", inputLockout = 1.5,
    },
}

for key, ability in pairs(abilities) do
    ability.class = "PRIEST"
    ability.specialization = "Holy"
    library:RegisterAbility(key, ability)
end

local function modeSlots(hero, raid)
    local halo = hero == "archon" and { "priest_halo" } or {}
    local sanctify = { "priest_holy_word_sanctify" }
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
        standard = list("priest_holy_word_serenity", sanctify, halo, "priest_apotheosis",
            "priest_prayer_of_mending", "priest_flash_heal", "priest_prayer_of_healing",
            "priest_divine_hymn", "priest_guardian_spirit", "priest_holy_word_chastise", "priest_smite"),
        aoe = list("priest_divine_hymn", "priest_apotheosis", halo, sanctify,
            "priest_prayer_of_mending", "priest_prayer_of_healing", "priest_holy_word_serenity",
            "priest_flash_heal", "priest_holy_word_chastise", "priest_smite", "priest_guardian_spirit"),
        single = list("priest_holy_word_serenity", "priest_guardian_spirit", "priest_apotheosis",
            "priest_prayer_of_mending", "priest_flash_heal", halo, sanctify,
            "priest_prayer_of_healing", "priest_holy_word_chastise", "priest_smite", "priest_divine_hymn"),
        mana = list("priest_prayer_of_mending", "priest_holy_word_serenity", sanctify, halo,
            "priest_apotheosis", "priest_flash_heal", "priest_holy_word_chastise", "priest_smite",
            "priest_prayer_of_healing", "priest_guardian_spirit", "priest_divine_hymn"),
    }
end

local function registerPreset(key, name, heroTalent, hero, content)
    local modes = modeSlots(hero, content == "Raid")
    library:RegisterPreset(key, {
        name = name,
        class = "PRIEST",
        specialization = "Holy",
        specializationID = 257,
        heroTalent = heroTalent,
        content = content,
        guideVersion = "12.1",
        guideUpdated = "2026-08-12",
        slots = modes.standard,
        modeSlots = modes,
    })
end

registerPreset("priest_archon_mythicplus", "Archon • Mythic+", "Archon", "archon", "Mythic+")
registerPreset("priest_archon_raid", "Archon • Raid", "Archon", "archon", "Raid")
registerPreset("priest_oracle_mythicplus", "Oracle • Mythic+", "Oracle", "oracle", "Mythic+")
registerPreset("priest_oracle_raid", "Oracle • Raid", "Oracle", "oracle", "Raid")
