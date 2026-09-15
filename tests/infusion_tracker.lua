local addon = {
    classToken = "PALADIN",
    specializationID = 65,
    messages = {},
}
local namespace = { addon = addon }
local now = 100
GetTime = function() return now end
issecretvalue = function(value) return type(value) == "table" and value.secret == true end
C_Spell = {
    GetSpellName = function(spellID)
        return (spellID == 53576 or spellID == 54149) and "Infusion of Light" or "Other Buff"
    end,
}
C_Timer = { After = function(_, callback) callback() end }
addon.Print = function(self, message) self.messages[#self.messages + 1] = message end

local registrations = {}
CreateFrame = function()
    return {
        RegisterEvent = function(_, event) registrations[event] = true end,
        UnregisterAllEvents = function() end,
        SetScript = function(self, _, callback) self.callback = callback end,
    }
end

local infusionActive = false
local infusionShown = false
local infusionCooldownID = 77
local infusionFrame = {
    cooldownID = infusionCooldownID,
    GetCooldownID = function(self) return self.cooldownID end,
    GetBaseSpellID = function() return 53576 end,
    GetAuraSpellID = function() return infusionActive and 54149 or nil end,
    GetSpellID = function() return 53576 end,
    GetNameText = function() return "Infusion of Light" end,
    IsActive = function() return infusionActive end,
    IsShown = function() return infusionShown end,
}
local otherFrame = {
    cooldownID = 88,
    GetBaseSpellID = function() return 12345 end,
    IsActive = function() return true end,
    IsShown = function() return true end,
}
local frames = { otherFrame, infusionFrame }
local scans = 0
BuffBarCooldownViewer = {
    GetHideWhenInactive = function() return true end,
    itemFramePool = {
        EnumerateActive = function()
            scans = scans + 1
            local index = 0
            return function()
                index = index + 1
                return frames[index]
            end
        end,
    },
}

assert(loadfile("InfusionTracker.lua"))("HeliHeal", namespace)
addon:InitializeProcTracker()
assert(registrations.PLAYER_ENTERING_WORLD and registrations.PLAYER_SPECIALIZATION_CHANGED
        and registrations.TRAIT_CONFIG_UPDATED and registrations.SPELLS_CHANGED
        and registrations.UNIT_AURA,
    "the tracker must listen for structural CDM changes and player aura update signals")
assert(addon.ProcTracker.registered and addon.ProcTracker.cooldownID == 77
        and addon.ProcTracker.spellID == 53576,
    "the tracker must identify and cache the Infusion frame by its base spell ID")
local stateActive, stateReliable = addon.ProcTracker:GetInfusionOfLightState()
assert(not stateActive and stateReliable,
    "the tracker API must distinguish a reliable inactive state from unavailable tracking")
local scansAfterCache = scans
assert(not addon.ProcTracker:HasInfusionOfLight() and scans == scansAfterCache,
    "an inactive hidden Blizzard frame must stay cached without another pool scan")
infusionActive = true
infusionShown = true
addon.ProcTracker.listener.callback(nil, "UNIT_AURA", "player")
assert(addon.ProcTracker.active and addon.ProcTracker:HasInfusionOfLight()
        and scans == scansAfterCache,
    "a player aura event must refresh the dedicated item's visibility without rescanning")
assert(addon.ProcTracker:GetInfusionOfLightState() == true,
    "the tracker API must expose the active proc")
infusionActive = false
infusionShown = false
addon.ProcTracker.listener.callback(nil, "UNIT_AURA", "player")
assert(not addon.ProcTracker.active and not addon.ProcTracker:HasInfusionOfLight(),
    "the player aura signal must detect the active-to-inactive transition")

local replacementFrame = {
    cooldownID = 99,
    GetBaseSpellID = function() return 53576 end,
    IsActive = function() return true end,
    IsShown = function() return true end,
}
infusionFrame.cooldownID = 1000
frames = { replacementFrame }
assert(addon.ProcTracker:Refresh(true) and addon.ProcTracker.infusionFrame == replacementFrame
        and addon.ProcTracker.cooldownID == 99,
    "a recycled pool frame must invalidate the cache and bind the replacement")

local emptyShell = {
    IsShown = function() return false end,
}
local dedicatedShown = false
local dedicatedFrame = {
    cooldownID = 123,
    IsShown = function() return dedicatedShown end,
}
frames = { emptyShell, dedicatedFrame }
replacementFrame.cooldownID = 1001
assert(not addon.ProcTracker:Refresh(true)
        and addon.ProcTracker.infusionFrame == dedicatedFrame
        and addon.ProcTracker.dedicated,
    "one identity-redacted configured item must bind as the dedicated Infusion frame while edit-mode shells are ignored")
dedicatedShown = true
assert(addon.ProcTracker:HasInfusionOfLight(),
    "the dedicated Infusion item must report active from its shown state")
BuffBarCooldownViewer.GetHideWhenInactive = function() return false end
assert(not addon.ProcTracker:HasInfusionOfLight(),
    "visibility detection must refuse an always-visible viewer when Hide When Inactive is disabled")
BuffBarCooldownViewer.GetHideWhenInactive = function() return true end

addon.ProcTracker:PrintStatus()
addon.ProcTracker:PrintRegisteredBuffs()
assert(#addon.messages > 0, "debug commands must produce one-time diagnostic output")

print("Infusion tracker OK: CDM identity, dedicated visibility state, shells and recycling")
