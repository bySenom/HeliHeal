local addon = { db = { char = {} }, classToken = "PALADIN", specializationID = 65 }
assert(loadfile("InfusionTracker.lua"))("HeliHeal", { addon = addon })
local tracker = addon.ProcTracker
local function item(id, spell, active)
    return { cooldownID = id, spell = spell, active = active,
        GetBaseSpellID = function(self) return self.spell end,
        IsActive = function(self) return self.active end,
        IsShown = function() return true end }
end
local infusion, purpose, unrelated = item(77, 53576, false), item(88, 223819, true), item(99, 999, true)
local frames = { infusion, purpose, unrelated }
BuffIconCooldownViewer = { GetHideWhenInactive = function() return false end,
    itemFramePool = { EnumerateActive = function()
        local index = 0
        return function() index = index + 1; return frames[index] end
    end } }
tracker:AddProc(223819)
assert(tracker:GetProcState("infusion_of_light") == "INACTIVE")
assert(tracker:GetDivinePurposeState() == "ACTIVE")
infusion.active, purpose.active = true, false
assert(tracker:GetProcState("infusion_of_light") == "ACTIVE")
assert(tracker:GetDivinePurposeState() == "INACTIVE")
infusion.active = nil
assert(tracker:GetProcState("infusion_of_light") == "UNKNOWN")
infusion.active = true; infusion.spell = 999
assert(tracker:GetProcState("infusion_of_light") == "UNKNOWN")
infusion.spell = 53576
frames[4] = item(101, 53576, false)
assert(tracker:GetProcState("infusion_of_light") == "UNKNOWN")
print("proc_icons: OK")
