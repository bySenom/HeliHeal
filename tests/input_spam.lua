local addon = {}
local namespace = { addon = addon }

local now = 0
GetTime = function() return now end
IsControlKeyDown = function() return false end
IsAltKeyDown = function() return false end
IsShiftKeyDown = function() return false end
GetCVar = function() return "400" end
C_Spell = { GetSpellQueueWindow = function() return 400 end }

local scheduled = {}
C_Timer = {
    NewTimer = function(delay, callback)
        local timer = { delay = delay, callback = callback }
        function timer:Cancel() self.cancelled = true end
        scheduled[#scheduled + 1] = timer
        return timer
    end,
}

assert(loadfile("Input.lua"))("HeliHeal", namespace)

addon.db = {
    profile = {
        slots = {
            {
                spellID = 5394,
                enabled = true,
                inputKey = "BUTTON5",
                inputLockout = 1.0,
            },
        },
    },
}
addon.pendingAcknowledgements = {}
addon.heldInputKeys = {}
addon.inputLockedUntil = {}

local acknowledgements = 0
addon.AcknowledgeSlot = function(_, slotIndex)
    assert(slotIndex == 1)
    acknowledgements = acknowledgements + 1
end

addon:ObserveInputKey("BUTTON5")
addon:ObserveInputKey("BUTTON5")
assert(#scheduled == 1, "holding/spamming down must queue only once")

addon:ReleaseInputKey("BUTTON5")
now = 0.1
addon:ObserveInputKey("BUTTON5")
assert(#scheduled == 1, "repeat click inside queue plus GCD lockout must be ignored")

now = 0.4
scheduled[1].callback()
assert(acknowledgements == 1, "first physical press must acknowledge once")

addon:ReleaseInputKey("BUTTON5")
now = 1.39
addon:ObserveInputKey("BUTTON5")
assert(#scheduled == 1, "lockout must include 400 ms queue plus 1.0 s GCD")

now = 1.41
addon:ObserveInputKey("BUTTON5")
assert(#scheduled == 2, "a genuinely later press must remain observable")
now = 1.81
scheduled[2].callback()
assert(acknowledgements == 2, "later valid press must acknowledge exactly once")

print("Input spam guard OK: hold once, rapid repeats ignored, later press accepted")
