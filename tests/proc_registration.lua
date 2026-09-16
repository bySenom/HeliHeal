local addon = { db = { char = {} } }
assert(loadfile("InfusionTracker.lua"))("HeliHeal", { addon = addon })
local tracker = addon.ProcTracker
Enum = { CooldownViewerCategory = { TrackedBuff = 2, TrackedBar = 3, HiddenPassive = -2 },
    CooldownLayoutStatus = { Success = 0 } }
local combat, pending, rejected = false, false, false
InCombatLockdown = function() return combat end
local changes, saves = 0, 0
local catalog = { [77] = { spellID = 53576, category = 2 },
    [88] = { spellID = 223819, category = -2 },
    [99] = { spellID = 999, category = 2 } }
local manager = { HasPendingChanges = function() return pending end,
    SaveLayouts = function() saves = saves + 1 end }
local provider = {
    GetLayoutManager = function() return manager end,
    GetDisplayData = function() return { cooldownInfoByID = catalog } end,
    MarkDirty = function() end,
    SetCooldownToCategory = function(_, id, category)
        changes = changes + 1
        if rejected then return 1 end
        catalog[id].category = category
        return 0
    end,
}
CooldownViewerSettings = { GetDataProvider = function() return provider end }
local added, tracked = tracker:AddProc(223819)
assert(added and tracked and changes == 1 and saves == 1)
assert(catalog[88].category == 3 and catalog[99].category == 2)
assert(tracker:RegisterProcWithBlizzard("spell_223819"))
assert(changes == 1 and saves == 1) -- idempotent
combat = true
assert(not tracker:RegisterProcWithBlizzard("infusion_of_light"))
combat = false; pending = true
assert(not tracker:RegisterProcWithBlizzard("infusion_of_light"))
pending = false
assert(changes == 1 and saves == 1)
catalog[78] = { spellID = 54149, category = 2 }
assert(not tracker:RegisterProcWithBlizzard("infusion_of_light"))
catalog[78] = nil
assert(tracker:RegisterProcWithBlizzard("infusion_of_light"))
assert(catalog[77].category == 2 and changes == 1 and saves == 1)
catalog[77].category = -2
rejected = true
assert(not tracker:RegisterProcWithBlizzard("infusion_of_light"))
assert(saves == 1)
rejected = false
assert(tracker:RegisterProcWithBlizzard("infusion_of_light"))
assert(catalog[77].category == 3 and saves == 2)
assert(tracker:RemoveProc("spell_223819"))
assert(catalog[88].category == 3) -- removal preserves Blizzard settings
CooldownViewerSettings = nil
local ok, registered = tracker:AddProc(45678)
assert(ok and not registered) -- source remains usable for manual setup
print("proc_registration: OK")
