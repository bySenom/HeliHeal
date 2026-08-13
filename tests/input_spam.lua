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
            {
                spellID = 1064,
                enabled = true,
                inputKey = "1",
                inputLockout = 1.5,
            },
        },
    },
}
addon.pendingAcknowledgements = {}
addon.heldInputKeys = {}
addon.inputLockedUntil = {}

local acknowledgements = {}
addon.AcknowledgeSlot = function(_, slotIndex)
    acknowledgements[slotIndex] = (acknowledgements[slotIndex] or 0) + 1
end

addon:ObserveInputKey("BUTTON5")
addon:ObserveInputKey("BUTTON5")
assert(#scheduled == 1, "holding/spamming down must queue only once")
assert(math.abs(scheduled[1].delay - 1.9) < 0.001,
    "acknowledgement must wait for 400 ms SpellQueueWindow plus a 1.5 s base GCD")

addon:ReleaseInputKey("BUTTON5")
now = 0.1
addon:ObserveInputKey("BUTTON5")
assert(#scheduled == 1, "repeat click inside queue plus GCD lockout must be ignored")

now = 0.4
assert(not acknowledgements[1], "SpellQueueWindow alone must not remove the recommendation")
now = 1.9
scheduled[1].callback()
assert(acknowledgements[1] == 1, "first physical press must acknowledge once after the local action window")

addon:ReleaseInputKey("BUTTON5")
now = 1.89
addon:ObserveInputKey("BUTTON5")
assert(#scheduled == 1, "lockout must include SpellQueueWindow plus the full base GCD")

now = 1.91
addon:ObserveInputKey("BUTTON5")
assert(#scheduled == 2, "a genuinely later press must remain observable")
assert(math.abs(scheduled[2].delay - 1.9) < 0.001, "later inputs must use the same safe commit delay")
now = 3.81
scheduled[2].callback()
assert(acknowledgements[1] == 2, "later valid press must acknowledge exactly once")

now = 10
addon:ObserveInputKey("1")
assert(#scheduled == 3 and math.abs(scheduled[3].delay - 1.9) < 0.001,
    "a standard keyboard action binding must use queue plus GCD delay")
now = 10.4
assert(not acknowledgements[2], "keyboard recommendation must remain after the queue component")
now = 11.9
scheduled[3].callback()
assert(acknowledgements[2] == 1, "keyboard action may advance only after the complete local action window")

print("Input guard OK: queue plus GCD commit delay, spam ignored, later press accepted")
