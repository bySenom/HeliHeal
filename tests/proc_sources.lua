local addon = { db = { char = {} }, classToken = "PALADIN", specializationID = 65 }
assert(loadfile("InfusionTracker.lua"))("HeliHeal", { addon = addon })
local tracker = addon.ProcTracker
local frames = {}
local hide = true
BuffBarCooldownViewer = {
    GetHideWhenInactive = function() return hide end,
    itemFramePool = { EnumerateActive = function()
        local index = 0
        return function() index = index + 1; return frames[index] end
    end },
}
local function frame(id, spell, shown)
    return { cooldownID = id, GetBaseSpellID = function(self) return self.spell end,
        spell = spell, IsShown = function(self) return self.shown end, shown = shown }
end
local infusion = frame(77, 53576, true)
local other = frame(88, 12345, false)
frames = { infusion, other }
assert(tracker:AddProc("12345"))
assert(not tracker:AddProc("12345"))
assert(not tracker:AddProc("-3"))
assert(not tracker:AddProc("3.5"))
assert(tracker:GetProcState("infusion_of_light") == "ACTIVE")
assert(tracker:GetProcState("spell_12345") == "INACTIVE")
local active, reliable = tracker:GetInfusionOfLightState()
assert(active and reliable)
infusion.spell = nil -- known definition, redacted identity
assert(tracker:GetProcState("infusion_of_light") == "ACTIVE")
infusion.spell = 999 -- recycled to a different identity
assert(tracker:GetProcState("infusion_of_light") == "UNKNOWN")
infusion.spell = 53576
hide = false
assert(tracker:GetProcState("infusion_of_light") == "UNKNOWN")
hide = true
infusion.shown = nil
assert(tracker:GetProcState("infusion_of_light") == "UNKNOWN")
infusion.shown = true
frames[3] = frame(90, 53576, true)
assert(tracker:GetProcState("infusion_of_light") == "UNKNOWN")
frames = { frame(40, nil, true) }
assert(tracker:GetProcState("infusion_of_light") == "UNKNOWN")
assert(not tracker:RemoveProc("infusion_of_light"))
assert(tracker:RemoveProc("spell_12345"))
addon:DisableProcTracker()
assert(tracker:GetProcState("infusion_of_light") == "UNKNOWN")
print("proc_sources: OK")
