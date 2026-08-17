local _, ns = ...
local library = ns.AbilityLibrary

-- Restoration Druid priority data for Midnight 12.1.
-- Guide snapshot: Wowhead, updated 2026-06-12.
-- https://www.wowhead.com/guide/classes/druid/restoration/rotation-cooldowns-pve-healer
local abilities = {
    druid_lifebloom = {
        spellID = 33763,
        name = "Lifebloom",
        cooldown = 0,
        trackedDuration = 15,
        trackedGoal = 1,
        inputLockout = 1.5,
    },
    druid_swiftmend = {
        spellID = 18562,
        name = "Swiftmend",
        cooldown = 15,
        inputLockout = 1.5,
    },
    druid_wild_growth = {
        spellID = 48438,
        name = "Wild Growth",
        cooldown = 10,
        confirmOnPlayerSuccess = true,
        inputLockout = 1.5,
    },
    druid_rejuvenation = {
        spellID = 774,
        name = "Rejuvenation",
        cooldown = 0,
        trackedDuration = 12,
        inputLockout = 1.5,
    },
    druid_natures_swiftness = {
        spellID = 132158,
        name = "Nature's Swiftness",
        cooldown = 60,
        inputLockout = 1.0,
    },
    druid_regrowth = {
        spellID = 8936,
        name = "Regrowth",
        cooldown = 0,
        inputLockout = 1.5,
    },
}

for key, ability in pairs(abilities) do
    ability.class = "DRUID"
    ability.specialization = "Restoration"
    library:RegisterAbility(key, ability)
end

local function modes(raid)
    return {
        aoe = {
            "druid_lifebloom", "druid_swiftmend", "druid_wild_growth",
            "druid_rejuvenation", "druid_regrowth", "druid_natures_swiftness",
        },
        single = {
            "druid_lifebloom", "druid_rejuvenation", "druid_swiftmend",
            "druid_natures_swiftness", "druid_regrowth", "druid_wild_growth",
        },
        mana = {
            "druid_lifebloom", "druid_swiftmend", "druid_wild_growth",
            "druid_rejuvenation", "druid_regrowth", "druid_natures_swiftness",
        },
    }
end

local function registerPreset(key, name, heroTalent, content)
    local raid = content == "Raid"
    library:RegisterPreset(key, {
        name = name,
        class = "DRUID",
        specialization = "Restoration",
        heroTalent = heroTalent,
        content = content,
        guideVersion = "12.1",
        guideUpdated = "2026-06-12",
        slots = {
            "druid_lifebloom", "druid_swiftmend", "druid_wild_growth",
            "druid_rejuvenation", "druid_natures_swiftness", "druid_regrowth",
        },
        modeSlots = modes(raid),
        rejuvenationGoals = raid and {
            standard = 8, aoe = 12, single = 2, mana = 5,
        } or {
            standard = 3, aoe = 5, single = 2, mana = 2,
        },
    })
end

registerPreset("druid_wildstalker_mythicplus", "Wildstalker • Mythic+", "Wildstalker", "Mythic+")
registerPreset("druid_wildstalker_raid", "Wildstalker • Raid", "Wildstalker", "Raid")
registerPreset("druid_keeper_mythicplus", "Keeper of the Grove • Mythic+", "Keeper of the Grove", "Mythic+")
registerPreset("druid_keeper_raid", "Keeper of the Grove • Raid", "Keeper of the Grove", "Raid")
