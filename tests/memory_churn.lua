local addon = {}
local namespace = { media = { fallbackIcon = 134400 } }

LibStub = function()
    return { NewAddon = function() return addon end }
end

GetTime = function() return 0 end

assert(loadfile("AbilityLibrary.lua"))("HeliHeal", namespace)
assert(loadfile("Classes/Paladin.lua"))("HeliHeal", namespace)
assert(loadfile("Core.lua"))("HeliHeal", namespace)
assert(loadfile("Display.lua"))("HeliHeal", namespace)

addon.classToken = "PALADIN"
addon.db = {
    profile = {
        rotationPreset = "paladin_herald_mythicplus",
        healingMode = "standard",
        bindings = {},
    },
}
addon.db.profile.slots = namespace.AbilityLibrary:BuildPresetSlots(addon.db.profile.rotationPreset, {})
addon:ResetRuntimeState()
addon.talentSnapshot = {
    available = true,
    paladinHerald = true,
    paladinDivineToll = true,
}
addon.IsTalentActive = function(self, key)
    return self.talentSnapshot.available and self.talentSnapshot[key] == true
end

local resolveCalls = 0
local originalResolve = namespace.AbilityLibrary.Resolve
namespace.AbilityLibrary.Resolve = function(library, slot)
    resolveCalls = resolveCalls + 1
    return originalResolve(library, slot)
end

local firstOrder = addon:GetDisplayOrder(0)
local firstItems = {}
for _, item in ipairs(firstOrder) do firstItems[item.slotIndex] = item end
local resolvedAfterWarmup = resolveCalls

for _ = 1, 1000 do
    local order = addon:GetDisplayOrder(0)
    assert(order == firstOrder, "HUD refreshes must reuse the display-order table")
    for _, item in ipairs(order) do
        assert(firstItems[item.slotIndex] == item, "HUD refreshes must reuse per-slot display items")
    end
end

assert(resolveCalls == resolvedAfterWarmup,
    "stable HUD refreshes must not repeatedly resolve spell metadata")
assert(addon:GetActivePriorityRanks() == addon:GetActivePriorityRanks(),
    "priority-rank maps must be cached while preset and mode remain unchanged")

print(("memory churn model: ok (%d resolved slots, 1000 cached refreshes)"):format(resolveCalls))
