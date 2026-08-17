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
}
addon.IsTalentActive = function(self, key)
    return self.talentSnapshot.available and self.talentSnapshot[key] == true
end
addon.RefreshDisplay = function() end
addon.Print = function() end

local rejuvIndex = addon:GetSlotIndexByAbilityKey("druid_rejuvenation")
local rejuv = addon:GetSlot(rejuvIndex)
assert(rejuv.trackedDuration == 12, "Rejuvenation must use its base twelve-second estimate")
assert(addon:GetTrackedGoal(rejuv) == 3, "standard Mythic+ must target three estimated Rejuvenations")

addon:AcknowledgeSlot(rejuvIndex)
local state = addon:GetTrackedState(rejuv, now)
assert(state.count == 1 and state.nextExpiresAt == 12, "one input must add one timed Rejuvenation")

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
assert(found and found.trackedText == "4/3" and found.remaining == 10,
    "the HUD model must expose count/goal and wait for the oldest estimate")

now = 12.1
state = addon:GetTrackedState(rejuv, now)
assert(state.count == 3, "only expired estimates may leave the counter")
now = 14.1
assert(addon:GetTrackedState(rejuv, now).count == 0, "all estimates must expire independently")

addon.talentSnapshot.druidGermination = true
rejuv = addon:GetSlot(rejuvIndex)
assert(rejuv.trackedDuration == 14, "Germination must extend the local estimate to fourteen seconds")
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

print("druid_rotation.lua: OK")
