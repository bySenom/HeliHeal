local addon = {}
local namespace = { media = { fallbackIcon = 134400 } }

LibStub = function() return { NewAddon = function() return addon end } end
local now = 0
GetTime = function() return now end

assert(loadfile("AbilityLibrary.lua"))("HeliHeal", namespace)
assert(loadfile("Classes/Monk.lua"))("HeliHeal", namespace)
assert(loadfile("Core.lua"))("HeliHeal", namespace)
assert(loadfile("Input.lua"))("HeliHeal", namespace)
assert(loadfile("Display.lua"))("HeliHeal", namespace)

addon.classToken = "MONK"
addon.specializationID = 270
addon.cachedSpellHaste = 20
addon.db = { profile = {
    rotationPreset = "monk_conduit_mythicplus", healingMode = "standard", bindings = {},
} }
addon.db.profile.slots = namespace.AbilityLibrary:BuildPresetSlots(addon.db.profile.rotationPreset, {})
addon.RefreshDisplay = function() end
addon.RefreshOptionsUI = function() end
addon.Print = function() end
assert(addon:GetSlot(addon:GetSlotIndexByAbilityKey("monk_rising_sun_kick")).enabled
    and not addon:GetSlot(addon:GetSlotIndexByAbilityKey("monk_rushing_wind_kick")).enabled,
    "an unavailable talent snapshot must keep the base kick and hide its replacement")
assert(addon:GetSlot(addon:GetSlotIndexByAbilityKey("monk_vivify")).enabled
    and not addon:GetSlot(addon:GetSlotIndexByAbilityKey("monk_sheiluns_gift")).enabled,
    "an unavailable talent snapshot must not expose both mutually exclusive heals")
addon.talentSnapshot = {
    available = true,
    monkConduit = true, monkHarmony = false, monkEndlessDraught = true,
    monkPoolOfMists = true, monkGiftCelestials = true, monkFocusedThunder = true,
    monkSheilunsGift = true, monkJadefireTeachings = false, monkRushingWindKick = true,
    monkUpliftedSpirits = true, monkChrysalis = true, monkMistWrap = true,
    monkRapidDiffusion = true, monkRisingMist = true, monkLotusInfusion = true,
    monkMorningBreeze = true, monkEmperorsElixir = true, monkMistsOfLife = true,
    monkThunderFocusTea = true, monkEnvelopingMist = true, monkLifeCocoon = true,
    monkRevival = true, monkRestoral = false, monkYulon = true, monkChiji = false,
    monkVeilOfPride = true, monkTranquilTea = false,
}
addon.IsTalentActive = function(self, key)
    return self.talentSnapshot.available and self.talentSnapshot[key] == true
end
addon:ResetRuntimeState()

local rushingBindingIndex = addon:GetSlotIndexByAbilityKey("monk_rushing_wind_kick")
addon:SetAbilityBinding(rushingBindingIndex, "SHIFT-BUTTON4")
assert(addon.db.profile.bindings.monk_rising_sun_kick == "SHIFT-BUTTON4"
    and addon.db.profile.slots[rushingBindingIndex].inputKey == "SHIFT-BUTTON4",
    "Rushing Wind Kick must share and update its replaced Rising Sun Kick binding")
assert(#addon:GetBindingConflicts() == 0,
    "mutually exclusive Mistweaver replacement spells must not create false conflicts")

assert(#addon.db.profile.slots == 17,
    "Mistweaver presets must expose every bindable talent variant")
local conduitAoe = namespace.AbilityLibrary:GetPresetPriorityKeys("monk_conduit_mythicplus", "aoe")
local harmonyAoe = namespace.AbilityLibrary:GetPresetPriorityKeys("monk_harmony_mythicplus", "aoe")
local function containsKey(list, expected)
    for _, key in ipairs(list) do if key == expected then return true end end
    return false
end
assert(containsKey(conduitAoe, "monk_celestial_conduit")
    and not containsKey(harmonyAoe, "monk_celestial_conduit"),
    "Conduit and Harmony must retain separate hero-specific AoE priority paths")
local renewingIndex = addon:GetSlotIndexByAbilityKey("monk_renewing_mist")
local renewing = addon:GetSlot(renewingIndex)
assert(renewing.maxCharges == 3 and math.abs(renewing.cooldown - 7.5) < 0.001,
    "Pool of Mists and cached haste must produce three 7.5-second Renewing Mist charges")
assert(math.abs(addon:GetSlot(addon:GetSlotIndexByAbilityKey("monk_rushing_wind_kick")).cooldown - 8.33) < 0.001,
    "Rushing Wind Kick must scale its ten-second base cooldown with cached haste")
assert(not addon:GetSlot(addon:GetSlotIndexByAbilityKey("monk_rising_sun_kick")).enabled
    and addon:GetSlot(addon:GetSlotIndexByAbilityKey("monk_rushing_wind_kick")).enabled,
    "Rushing Wind Kick must replace Rising Sun Kick")
assert(not addon:GetSlot(addon:GetSlotIndexByAbilityKey("monk_vivify")).enabled
    and addon:GetSlot(addon:GetSlotIndexByAbilityKey("monk_sheiluns_gift")).enabled,
    "Sheilun's Gift must replace Vivify")
assert(addon:GetSlot(addon:GetSlotIndexByAbilityKey("monk_life_cocoon")).cooldown == 75,
    "Chrysalis must reduce Life Cocoon from 120 to 75 seconds")
assert(addon:GetSlot(addon:GetSlotIndexByAbilityKey("monk_revival")).cooldown == 150,
    "Uplifted Spirits must reduce Revival from 180 to 150 seconds")
assert(addon:GetSlot(addon:GetSlotIndexByAbilityKey("monk_yulon")).cooldown == 60,
    "Gift of the Celestials must reduce Yu'lon from 120 to 60 seconds")

local sheilunIndex = addon:GetSlotIndexByAbilityKey("monk_sheiluns_gift")
local sheilun = addon:GetSlot(sheilunIndex)
assert(sheilun.cooldown == 0 and sheilun.recommendationLockout == 8
    and sheilun.confirmOnPlayerSuccess,
    "Sheilun's Gift must retain its zero spell cooldown but use direct confirmation and a local recommendation delay")
addon.monkSheilunClouds = 4
addon:AcknowledgeSlot(sheilunIndex)
local orderAfterSheilun = addon:GetDisplayOrder(now)
local sawSheilun = false
for _, item in ipairs(orderAfterSheilun) do
    if item.ability.abilityKey == "monk_sheiluns_gift" then sawSheilun = true break end
end
assert(not sawSheilun and addon:GetMonkSheilunCloudState(now).count == 0,
    "a confirmed Sheilun's Gift cast must consume local clouds and leave the active recommendation")

local kickIndex = addon:GetSlotIndexByAbilityKey("monk_rushing_wind_kick")
addon:AcknowledgeSlot(kickIndex)
assert(addon.sessionUses[kickIndex] == now, "a kick must start its local cooldown")

now = 1
local teaIndex = addon:GetSlotIndexByAbilityKey("monk_thunder_focus_tea")
addon:AcknowledgeSlot(teaIndex)
assert(addon.pendingMonkTea and addon.pendingMonkTea.uses == 2,
    "Focused Thunder must arm two deterministic empower uses")
assert(addon.sessionUses[kickIndex] == nil,
    "Morning Breeze must reset the active kick cooldown")
local teaState = addon:GetChargeState(teaIndex, addon:GetSlot(teaIndex), now)
assert(teaState.baseCharges == 1 and teaState.nextRechargeAt
    and math.abs(teaState.nextRechargeAt - 25) < 0.001,
    "Endless Draught and Heart of the Jade Serpent must retain one TFT charge and accelerate recharge")

now = 2
addon:AcknowledgeSlot(renewingIndex)
local coverage = addon:GetMonkRenewingMistState(now)
assert(coverage.count == 2 and addon.sessionMonkRenewingMists[2].expiresAt == 34,
    "TFT plus Lotus Infusion must create a 32-second Renewing Mist estimate")
assert(addon.sessionMonkRenewingMists[2].startedAt == 2,
    "Renewing Mist coverage entries must retain their actual start for duration visualization")
assert(addon.pendingMonkTea and addon.pendingMonkTea.uses == 1,
    "the first Focused Thunder consumer must leave one use")

now = 3
addon:AcknowledgeSlot(kickIndex)
coverage = addon:GetMonkRenewingMistState(now)
assert(coverage.count == 3,
    "Rapid Diffusion must add a six-second Renewing Mist estimate after a kick")
assert(coverage.nextExpiresAt == 12 and addon.sessionMonkRenewingMists[2].expiresAt == 13,
    "Rising Mist must extend each short mist by four seconds without exceeding double duration")
assert(not addon.pendingMonkTea,
    "the second valid Focused Thunder consumer must consume the remaining use")
local kick = addon:GetSlot(kickIndex)
assert(not addon.sessionUses[kickIndex]
    or addon.sessionUses[kickIndex] + kick.cooldown <= now + 1.1,
    "TFT-empowered kick must reduce its incoming cooldown by nine seconds")

now = 4
local cocoonIndex = addon:GetSlotIndexByAbilityKey("monk_life_cocoon")
addon:AcknowledgeSlot(cocoonIndex)
assert(addon:GetMonkRenewingMistState(now).count == 4,
    "Mists of Life must add a Renewing Mist estimate after Life Cocoon")

addon:ResetRuntimeState()
addon:BeginMonkCombat(now)
now = 20
assert(addon:GetMonkSheilunCloudState(now).count == 4,
    "Veil of Pride must generate one local Sheilun cloud every four combat seconds")
local function orderContains(abilityKey)
    for _, item in ipairs(addon:GetDisplayOrder(now)) do
        if item.ability.abilityKey == abilityKey then return true end
    end
    return false
end
assert(orderContains("monk_tiger_palm") and not orderContains("monk_blackout_kick")
    and orderContains("monk_spinning_crane_kick") and not orderContains("monk_life_cocoon")
    and not orderContains("monk_sheiluns_gift") and not orderContains("monk_enveloping_mist"),
    "standard mode must expose both melee branches while hiding contextual healing cooldowns")
now = 28
assert(orderContains("monk_sheiluns_gift"),
    "standard mode must offer Sheilun's Gift once six locally generated clouds are banked")
addon:AcknowledgeSlot(addon:GetSlotIndexByAbilityKey("monk_tiger_palm"))
assert(not orderContains("monk_tiger_palm") and orderContains("monk_blackout_kick"),
    "a confirmed Tiger Palm must advance the standard damage filler to Blackout Kick")
addon:AcknowledgeSlot(addon:GetSlotIndexByAbilityKey("monk_blackout_kick"))
assert(orderContains("monk_tiger_palm"),
    "a confirmed Blackout Kick must return the standard damage filler to Tiger Palm")

print("monk_rotation.lua: OK")
