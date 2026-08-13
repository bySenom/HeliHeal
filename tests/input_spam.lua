local addon = {}
local namespace = { addon = addon }

local now = 0
local gcdDuration = 1.2
GetTime = function() return now end
IsControlKeyDown = function() return false end
IsAltKeyDown = function() return false end
IsShiftKeyDown = function() return false end
C_Spell = {
    GetSpellCooldown = function(spellID)
        assert(spellID == 61304)
        return { startTime = now, duration = gcdDuration, isEnabled = true, modRate = 1 }
    end,
}

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
                castSpellIDs = { 5394, 1267068, 1267089 },
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
assert(scheduled[1].delay == 5, "an unmatched observation must use the safe event timeout")

addon:ReleaseInputKey("BUTTON5")
now = 0.1
addon:ObserveInputKey("BUTTON5")
assert(#scheduled == 1, "repeat click inside queue plus GCD lockout must be ignored")

now = 2.0
assert(not acknowledgements[1], "queued input must not advance before a successful cast event")
assert(addon:CommitObservedSpell(1267068), "the Stormstream player-cast ID must confirm the input")
assert(acknowledgements[1] == 1, "the successful player spell must acknowledge exactly once")
assert(scheduled[1].cancelled, "successful confirmation must cancel the timeout")

addon:ReleaseInputKey("BUTTON5")
now = 3.19
addon:ObserveInputKey("BUTTON5")
assert(#scheduled == 1, "the live 1.2-second GCD must keep the input locked")

now = 3.21
addon:ObserveInputKey("BUTTON5")
assert(#scheduled == 2, "a genuinely later press must remain observable")
assert(scheduled[2].delay == 5, "later inputs must use the same event timeout")
now = 8.21
scheduled[2].callback()
assert(acknowledgements[1] == 1, "timeout must never simulate a successful cast")
assert(not addon.pendingAcknowledgements[1], "timeout must release the stale pending input")

now = 10
addon:ObserveInputKey("1")
assert(#scheduled == 3 and scheduled[3].delay == 5,
    "a standard keyboard action binding must wait for cast confirmation")
now = 10.4
assert(not acknowledgements[2], "keyboard recommendation must remain after the queue component")
assert(addon:CommitObservedSpell(1064), "matching keyboard spell success must be accepted")
assert(acknowledgements[2] == 1, "keyboard action may advance only on successful cast confirmation")

now = 20
addon:ReleaseInputKey("1")
addon:ObserveInputKey("1")
assert(addon:RejectObservedSpell(1064), "matching failed cast must reject the pending observation")
assert(acknowledgements[2] == 1 and not addon.pendingAcknowledgements[2],
    "failed casts must keep the recommendation and clear only the pending input")

now = 30
addon:ReleaseInputKey("1")
assert(not addon:RecordPlayerSpellSucceeded(1064),
    "instant success arriving before the secure post-hook must be cached")
now = 30.05
addon:ObserveInputKey("1")
assert(acknowledgements[2] == 2 and not addon.pendingAcknowledgements[2],
    "the post-hook must consume a matching recent instant-cast success immediately")

now = 40
addon:ReleaseInputKey("1")
addon.inputLockedUntil[2] = nil
addon:RecordPlayerSpellSucceeded(1064)
now = 40.3
addon:ObserveInputKey("1")
assert(acknowledgements[2] == 2 and addon.pendingAcknowledgements[2],
    "an expired success cache entry must never confirm a later input")

addon:RejectObservedSpell(1064)
now = 50
gcdDuration = 0
addon:ReleaseInputKey("1")
addon.inputLockedUntil[2] = nil
addon:ObserveInputKey("1")
assert(addon:CommitObservedSpell(1064), "inactive readable GCD must still confirm the cast")
assert(addon.inputLockedUntil[2] == now,
    "a readable inactive GCD must not fall back to a stale 1.5-second lock")

local nextFrameCallback
C_Timer.After = function(_, callback) nextFrameCallback = callback end
gcdDuration = 1.2
now = 60
addon:ReleaseInputKey("1")
addon:ObserveInputKey("1")
assert(addon:CommitObservedSpell(1064) and nextFrameCallback,
    "successful cast must schedule a next-frame GCD sample")
addon.inputGeneration = (addon.inputGeneration or 0) + 1
addon.inputLockedUntil = {}
nextFrameCallback()
assert(not addon.inputLockedUntil[2],
    "a stale next-frame callback must not mutate a newer runtime generation")

print("Input guard OK: hard/instant success commits, exact GCD locks, stale callbacks and failures never advance")
