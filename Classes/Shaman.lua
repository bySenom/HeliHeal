local _, ns = ...
local library = ns.AbilityLibrary

-- Restoration Shaman priority data for Midnight 12.1.
-- Guide snapshot: Wowhead, updated 2026-08-10.
-- https://www.wowhead.com/guide/classes/shaman/restoration/rotation-cooldowns-pve-healer
local abilities = {
    healing_stream_combo = {
        spellID = 5394,
        name = "Healing Stream / Stormstream Totem",
        -- Midnight 12.1 recharge time per normal Healing Stream Totem charge.
        cooldown = 17,
        inputLockout = 1.0,
        maxCharges = 2,
        maxBonusCharges = 2,
        -- 1267068 is the player cast; 1267089 is the visible proc aura seen
        -- in the UI and retained as a compatibility alias.
        castSpellIDs = { 5394, 1267068, 1267089 },
        note = "Stormstream uses the Healing Stream action without consuming a normal charge. Random Riptide procs remain untracked.",
    },
    riptide = {
        spellID = 61295,
        name = "Riptide",
        cooldown = 6,
        maxCharges = 2,
        inputLockout = 1.5,
        consumesSwiftness = true,
    },
    natures_swiftness = {
        spellID = 378081,
        name = "Nature's Swiftness",
        cooldown = 60,
        grantsBonusChargeTo = "healing_stream_combo",
        armsSwiftness = true,
        preferredSwiftnessConsumer = "chain_heal",
        confirmOnPlayerSuccess = true,
    },
    ancestral_swiftness = {
        spellID = 443454,
        name = "Ancestral Swiftness",
        cooldown = 30,
        grantsBonusChargeTo = "healing_stream_combo",
        armsSwiftness = true,
        preferredSwiftnessConsumer = "chain_heal",
        confirmOnPlayerSuccess = true,
    },
    surging_totem = { spellID = 444995, name = "Surging Totem", cooldown = 25 },
    unleash_life = { spellID = 73685, name = "Unleash Life", cooldown = 20, inputLockout = 1.5 },
    healing_rain = {
        spellID = 73920,
        name = "Healing Rain",
        cooldown = 18,
        consumesSwiftness = true,
        castSpellIDs = { 73920, 207778 },
    },
    downpour = {
        spellID = 207778,
        name = "Downpour",
        cooldown = 0,
        inputLockout = 1.5,
        derivedBindingFrom = "healing_rain",
    },
    chain_heal = { spellID = 1064, name = "Chain Heal", cooldown = 0, roleLabel = "AOE", inputLockout = 1.5, consumesSwiftness = true },
    healing_wave = { spellID = 77472, name = "Healing Wave", cooldown = 0, roleLabel = "SINGLE", inputLockout = 1.5, consumesSwiftness = true },
}

for key, ability in pairs(abilities) do
    ability.class = "SHAMAN"
    ability.specialization = "Restoration"
    library:RegisterAbility(key, ability)
end

local function registerPreset(key, name, heroTalent, content, slots, modeSlots)
    library:RegisterPreset(key, {
        name = name,
        class = "SHAMAN",
        specialization = "Restoration",
        heroTalent = heroTalent,
        content = content,
        guideVersion = "12.1",
        guideUpdated = "2026-08-10",
        slots = slots,
        modeSlots = modeSlots,
    })
end

local function modes(swiftness, includeSurging)
    local aoe = { "healing_stream_combo", "riptide", swiftness }
    if includeSurging then aoe[#aoe + 1] = "surging_totem" end
    aoe[#aoe + 1] = "downpour"
    aoe[#aoe + 1] = "healing_rain"
    aoe[#aoe + 1] = "unleash_life"
    aoe[#aoe + 1] = "chain_heal"
    aoe[#aoe + 1] = "healing_wave"

    local single = { "riptide", "healing_stream_combo", swiftness, "unleash_life" }
    if includeSurging then single[#single + 1] = "surging_totem" end
    single[#single + 1] = "healing_wave"
    single[#single + 1] = "chain_heal"

    local mana = { "healing_stream_combo", "riptide", "unleash_life", swiftness, "healing_wave", "chain_heal" }
    if includeSurging then mana[#mana + 1] = "surging_totem" end
    return { aoe = aoe, single = single, mana = mana }
end

registerPreset("shaman_totemic_mythicplus", "Totemic • Mythic+", "Totemic", "Mythic+", {
    "healing_stream_combo",
    "riptide",
    "natures_swiftness",
    "surging_totem",
    "unleash_life",
    "chain_heal",
    "healing_wave",
}, modes("natures_swiftness", true))

registerPreset("shaman_totemic_raid", "Totemic • Raid", "Totemic", "Raid", {
    "healing_stream_combo",
    "riptide",
    "natures_swiftness",
    "surging_totem",
    "chain_heal",
    "healing_wave",
}, modes("natures_swiftness", true))

registerPreset("shaman_farseer_mythicplus", "Farseer • Mythic+", "Farseer", "Mythic+", {
    "healing_stream_combo",
    "riptide",
    "ancestral_swiftness",
    "unleash_life",
    "healing_rain",
    "chain_heal",
    "healing_wave",
}, modes("ancestral_swiftness", false))

registerPreset("shaman_farseer_raid", "Farseer • Raid", "Farseer", "Raid", {
    "healing_stream_combo",
    "riptide",
    "ancestral_swiftness",
    "unleash_life",
    "healing_rain",
    "chain_heal",
    "healing_wave",
}, modes("ancestral_swiftness", false))
