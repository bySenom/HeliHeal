local addon = {}
local namespace = { media = { fallbackIcon = 134400 } }

LibStub = function()
    return { NewAddon = function() return addon end }
end

local now = 0
GetTime = function() return now end

assert(loadfile("AbilityLibrary.lua"))("HeliHeal", namespace)
assert(loadfile("Classes/Druid.lua"))("HeliHeal", namespace)
assert(loadfile("Core.lua"))("HeliHeal", namespace)
assert(loadfile("Input.lua"))("HeliHeal", namespace)
assert(loadfile("Display.lua"))("HeliHeal", namespace)

addon.classToken = "DRUID"
addon.db = {
    profile = {
        rotationPreset = "druid_wildstalker_mythicplus",
        healingMode = "standard",
        bindings = {},
    },
}
addon.db.profile.slots = namespace.AbilityLibrary:BuildPresetSlots(addon.db.profile.rotationPreset, {})
addon:ResetRuntimeState()
addon.talentSnapshot = {
    available = true,
    druidGermination = false,
    druidLingeringHealing = false,
    druidVerdantInfusion = false,
    druidProsperity = false,
    druidPassingSeasons = false,
    druidEarlySpring = false,
    druidPowerArchdruid = true,
    druidSoulOfTheForest = true,
    druidConvoke = true,
    druidCenariusGuidance = true,
    druidIncarnationTree = false,
    druidTranquility = true,
    druidInnerPeace = false,
    druidFlourish = false,
}
addon.IsTalentActive = function(self, key)
    return self.talentSnapshot.available and self.talentSnapshot[key] == true
end
addon.RefreshDisplay = function() end
addon.Print = function() end

local rejuvIndex = addon:GetSlotIndexByAbilityKey("druid_rejuvenation")
local rejuv = addon:GetSlot(rejuvIndex)
assert(rejuv.trackedDuration == 12, "Rejuvenation must use its twelve-second base duration")
assert(addon:GetTrackedGoal(rejuv) == 3, "standard Mythic+ must target three estimated Rejuvenations")

local swiftmendIndex = addon:GetSlotIndexByAbilityKey("druid_swiftmend")
local freshOrder = addon:GetDisplayOrder(now)
for _, item in ipairs(freshOrder) do
    assert(item.ability.abilityKey ~= "druid_swiftmend",
        "Swiftmend must be withheld until a locally known HoT exists")
end

addon:AcknowledgeSlot(rejuvIndex)
local state = addon:GetTrackedState(rejuv, now)
assert(state.count == 1 and state.nextExpiresAt == 12, "one input must add one timed Rejuvenation")
local swiftmendVisible = false
for _, item in ipairs(addon:GetDisplayOrder(now)) do
    if item.ability.abilityKey == "druid_swiftmend" then swiftmendVisible = true end
end
assert(swiftmendVisible, "a locally known Rejuvenation must unlock Swiftmend")

now = 1
addon:AcknowledgeSlot(swiftmendIndex)
assert(addon.pendingArchdruid and addon.pendingArchdruid.expiresAt == 16,
    "Swiftmend must arm Power of the Archdruid for fifteen seconds")
assert(addon:GetDisplayOrder(now)[1].ability.abilityKey == "druid_rejuvenation",
    "Soul of the Forest must prioritize a valid Rejuvenation or Regrowth consumer")

now = 2
addon:AcknowledgeSlot(rejuvIndex)
state = addon:GetTrackedState(rejuv, now)
assert(state.count == 4, "Power of the Archdruid Rejuvenation must add one cast plus two copies")
assert(not addon.pendingArchdruid, "Rejuvenation must consume Power of the Archdruid")

local order = addon:GetDisplayOrder(now)
local found
for _, item in ipairs(order) do
    if item.ability.abilityKey == "druid_rejuvenation" then found = item end
end
assert(found and found.trackedText == "4/3" and found.remaining == 10,
    "the HUD model must expose count/goal and wait for the oldest estimate")

now = 12.1
state = addon:GetTrackedState(rejuv, now)
assert(state.count == 3, "only expired estimates may leave the counter")
now = 14.1
assert(addon:GetTrackedState(rejuv, now).count == 0, "all estimates must expire independently")

addon.talentSnapshot.druidGermination = true
rejuv = addon:GetSlot(rejuvIndex)
assert(rejuv.trackedDuration == 14, "Germination must use the fourteen-second Rejuvenation variant")
assert(addon:GetTrackedCapacity(rejuv) == 10, "Germination must permit two Mythic+ applications per target")
addon.talentSnapshot.druidLingeringHealing = true
assert(addon:GetSlot(rejuvIndex).trackedDuration == 17,
    "Germination and Lingering Healing must combine to seventeen seconds")
addon.talentSnapshot.druidGermination = false
assert(addon:GetSlot(rejuvIndex).trackedDuration == 15,
    "Lingering Healing alone must extend Rejuvenation to fifteen seconds")
addon.talentSnapshot.druidLingeringHealing = false

local lifebloomIndex = addon:GetSlotIndexByAbilityKey("druid_lifebloom")
local lifebloom = addon:GetSlot(lifebloomIndex)
addon:AcknowledgeSlot(lifebloomIndex)
state = addon:GetTrackedState(lifebloom, now)
assert(state.count == 1 and state.goal == 1 and state.nextExpiresAt == now + 15,
    "Lifebloom must use one fifteen-second maintenance estimate")
now = now + 10
addon:AcknowledgeSlot(lifebloomIndex)
state = addon:GetTrackedState(lifebloom, now)
assert(state.count == 1 and state.nextExpiresAt == now + 15,
    "a repeated Lifebloom input must refresh its single local duration")

addon:ResetRuntimeState()
addon.talentSnapshot.druidVerdantInfusion = true
local verdantSwiftmendVisible = false
for _, item in ipairs(addon:GetDisplayOrder(now)) do
    if item.ability.abilityKey == "druid_swiftmend" then verdantSwiftmendVisible = true end
end
assert(verdantSwiftmendVisible,
    "Verdant Infusion must permit Swiftmend without a locally known HoT")
addon.talentSnapshot.druidVerdantInfusion = false

addon.talentSnapshot.druidProsperity = true
assert(addon:GetSlot(swiftmendIndex).maxCharges == 2,
    "Prosperity must grant Swiftmend a second charge")
addon.talentSnapshot.druidProsperity = false
addon.talentSnapshot.druidEarlySpring = true
assert(addon:GetSlot(swiftmendIndex).cooldown == 14,
    "Early Spring must reduce Swiftmend to fourteen seconds")
assert(addon:GetSlot(addon:GetSlotIndexByAbilityKey("druid_wild_growth")).cooldown == 9,
    "Early Spring must reduce Wild Growth to nine seconds")
addon.talentSnapshot.druidEarlySpring = false

now = now + 1
local wildGrowthIndex = addon:GetSlotIndexByAbilityKey("druid_wild_growth")
assert(addon:GetSlot(wildGrowthIndex).confirmOnPlayerSuccess,
    "Wild Growth must use direct successful-cast confirmation")
assert(addon:RecordPlayerSpellSucceeded(48438),
    "Wild Growth must confirm without a correlated action-bar input")
assert(addon.sessionUses[wildGrowthIndex] == now,
    "a successful Wild Growth cast must start its local cooldown")
local wildGrowthItem
for _, item in ipairs(addon:GetDisplayOrder(now)) do
    if item.ability.abilityKey == "druid_wild_growth" then wildGrowthItem = item end
end
assert(wildGrowthItem and wildGrowthItem.remaining == 10,
    "the HUD must move Wild Growth into its ten-second waiting state")

now = now + 1
local swiftnessIndex = addon:GetSlotIndexByAbilityKey("druid_natures_swiftness")
assert(addon:GetSlot(swiftnessIndex).confirmOnPlayerSuccess,
    "Nature's Swiftness must use direct successful-cast confirmation")
assert(addon:RecordPlayerSpellSucceeded(132158),
    "Nature's Swiftness must confirm without a correlated action-bar input")
assert(addon.sessionUses[swiftnessIndex] == now,
    "a successful Nature's Swiftness cast must start its local cooldown")
local swiftnessItem
for _, item in ipairs(addon:GetDisplayOrder(now)) do
    if item.ability.abilityKey == "druid_natures_swiftness" then swiftnessItem = item end
end
assert(swiftnessItem and math.abs(swiftnessItem.remaining - 60) < 0.001,
    ("the HUD must move Nature's Swiftness into its sixty-second waiting state (got %s)")
        :format(swiftnessItem and tostring(swiftnessItem.remaining) or "missing"))
addon.talentSnapshot.druidPassingSeasons = true
assert(addon:GetSlot(swiftnessIndex).cooldown == 45,
    "Passing Seasons must reduce Nature's Swiftness by fifteen seconds")
addon.talentSnapshot.druidPassingSeasons = false

local tranquilityIndex = addon:GetSlotIndexByAbilityKey("druid_tranquility")
local tranquility = addon:GetSlot(tranquilityIndex)
assert(tranquility.enabled and tranquility.cooldown == 180,
    "talented Tranquility must use its three-minute cooldown")
addon.talentSnapshot.druidInnerPeace = true
assert(addon:GetSlot(tranquilityIndex).cooldown == 150,
    "Inner Peace must reduce Tranquility by thirty seconds")
addon.talentSnapshot.druidInnerPeace = false
addon.talentSnapshot.druidFlourish = true
addon:AcknowledgeSlot(rejuvIndex)
local beforeFlourish = addon:GetTrackedState(addon:GetSlot(rejuvIndex), now).nextExpiresAt
addon:AcknowledgeSlot(tranquilityIndex)
assert(addon:GetTrackedState(addon:GetSlot(rejuvIndex), now).nextExpiresAt == beforeFlourish + 10,
    "Flourish must extend locally tracked HoTs through Tranquility by ten seconds")
addon.talentSnapshot.druidFlourish = false

local treeIndex = addon:GetSlotIndexByAbilityKey("druid_incarnation_tree")
assert(not addon:GetSlot(treeIndex).enabled,
    "Incarnation: Tree of Life must stay hidden when not selected")
addon.talentSnapshot.druidIncarnationTree = true
assert(addon:GetSlot(treeIndex).enabled and addon:GetSlot(treeIndex).cooldown == 180,
    "talented Incarnation: Tree of Life must use its three-minute cooldown")
addon.talentSnapshot.druidIncarnationTree = false

now = now + 1
local convokeIndex = addon:GetSlotIndexByAbilityKey("druid_convoke")
local convoke = addon:GetSlot(convokeIndex)
assert(convoke.enabled and convoke.cooldown == 60,
    "Cenarius' Guidance must halve Convoke's 120-second base cooldown")
assert(addon:RecordPlayerSpellSucceeded(391528),
    "Convoke must confirm directly without a correlated action-bar input")
assert(addon.sessionUses[convokeIndex] == now,
    "a successful Convoke must start its local cooldown")
addon.talentSnapshot.druidCenariusGuidance = false
assert(addon:GetSlot(convokeIndex).cooldown == 120,
    "Convoke must retain its 120-second cooldown without Cenarius' Guidance")
addon.talentSnapshot.druidConvoke = false
assert(not addon:GetSlot(convokeIndex).enabled,
    "Convoke must be hidden when its talent is not selected")

print("druid_rotation.lua: OK")
