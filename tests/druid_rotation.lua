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
    druidPowerArchdruid = true,
    druidConvoke = true,
    druidCenariusGuidance = true,
}
addon.IsTalentActive = function(self, key)
    return self.talentSnapshot.available and self.talentSnapshot[key] == true
end
addon.RefreshDisplay = function() end
addon.Print = function() end

local rejuvIndex = addon:GetSlotIndexByAbilityKey("druid_rejuvenation")
local rejuv = addon:GetSlot(rejuvIndex)
assert(rejuv.trackedDuration == 17, "Rejuvenation must use its Midnight seventeen-second estimate")
assert(addon:GetTrackedGoal(rejuv) == 3, "standard Mythic+ must target three estimated Rejuvenations")

addon:AcknowledgeSlot(rejuvIndex)
local state = addon:GetTrackedState(rejuv, now)
assert(state.count == 1 and state.nextExpiresAt == 17, "one input must add one timed Rejuvenation")

now = 1
local swiftmendIndex = addon:GetSlotIndexByAbilityKey("druid_swiftmend")
addon:AcknowledgeSlot(swiftmendIndex)
assert(addon.pendingArchdruid and addon.pendingArchdruid.expiresAt == 16,
    "Swiftmend must arm Power of the Archdruid for fifteen seconds")

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
assert(found and found.trackedText == "4/3" and found.remaining == 15,
    "the HUD model must expose count/goal and wait for the oldest estimate")

now = 17.1
state = addon:GetTrackedState(rejuv, now)
assert(state.count == 3, "only expired estimates may leave the counter")
now = 19.1
assert(addon:GetTrackedState(rejuv, now).count == 0, "all estimates must expire independently")

addon.talentSnapshot.druidGermination = true
rejuv = addon:GetSlot(rejuvIndex)
assert(rejuv.trackedDuration == 17, "Germination must not change Rejuvenation duration in Midnight 12.1")
assert(addon:GetTrackedCapacity(rejuv) == 10, "Germination must permit two Mythic+ applications per target")

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
