local namespace = { addon = {} }

assert(loadfile("Input.lua"))("HeliHeal", namespace)

local observedSlot
C_ActionBar = {
    IsAssistedCombatAction = function(slot)
        observedSlot = slot
        return false
    end,
}

local addon = namespace.addon
local cases = {
    MULTIACTIONBAR1BUTTON1 = 61,
    MULTIACTIONBAR1BUTTON10 = 70,
    MULTIACTIONBAR1BUTTON11 = 71,
    MULTIACTIONBAR1BUTTON12 = 72,
    MULTIACTIONBAR2BUTTON12 = 60,
}

for bindingAction, expectedSlot in pairs(cases) do
    observedSlot = nil
    assert(addon:ObserveAssistedCombatBinding(bindingAction) == false)
    assert(observedSlot == expectedSlot,
        bindingAction .. " should resolve to action slot " .. expectedSlot)
end

observedSlot = nil
assert(addon:ObserveAssistedCombatBinding("MULTIACTIONBAR1BUTTON") == false)
assert(observedSlot == nil, "malformed multi-action bindings must be ignored")

print("action slot tests passed")
