local addon = {}
local namespace = {
    AbilityLibrary = {
        Resolve = function(_, slot) return slot end,
        GetPresetPriorityKeys = function()
            return { "healing_stream_combo", "natures_swiftness", "chain_heal", "riptide" }
        end,
    },
}

LibStub = function()
    return {
        NewAddon = function() return addon end,
    }
end

local now = 0
GetTime = function() return now end

assert(loadfile("Core.lua"))("HeliHeal", namespace)
assert(loadfile("Display.lua"))("HeliHeal", namespace)

local healingStream = {
    abilityKey = "healing_stream_combo",
    spellID = 5394,
    enabled = true,
    cooldown = 17,
    maxCharges = 2,
    maxBonusCharges = 2,
}

local swiftness = {
    abilityKey = "natures_swiftness",
    spellID = 378081,
    enabled = true,
    cooldown = 60,
    maxCharges = 1,
    maxBonusCharges = 0,
    grantsBonusChargeTo = "healing_stream_combo",
    armsSwiftness = true,
    preferredSwiftnessConsumer = "chain_heal",
}

local chainHeal = {
    abilityKey = "chain_heal",
    spellID = 1064,
    enabled = true,
    cooldown = 0,
    maxCharges = 1,
    maxBonusCharges = 0,
    consumesSwiftness = true,
}

local riptide = {
    abilityKey = "riptide",
    spellID = 61295,
    enabled = true,
    cooldown = 6,
    maxCharges = 2,
    maxBonusCharges = 0,
    consumesSwiftness = true,
}

addon.db = { profile = { rotationPreset = "test", healingMode = "standard", slots = { healingStream, swiftness, chainHeal, riptide } } }
addon.sessionCharges = {}
addon.sessionSpendHistory = {}
addon.sessionUses = {}
addon.pendingSwiftness = nil
addon.RefreshDisplay = function() end

local function expect(base, bonus, recharge, label)
    local state = addon:GetChargeState(1, healingStream, now)
    assert(state.baseCharges == base, label .. ": base charges")
    assert(state.bonusCharges == bonus, label .. ": bonus charges")
    assert(state.nextRechargeAt == recharge, label .. ": recharge timestamp")
end

expect(2, 0, nil, "initial 2/2")
addon:GrantBonusCharge("healing_stream_combo", now)
expect(2, 1, nil, "swiftness creates effective 3/2")

assert(addon:SpendCharge(1, healingStream, now))
expect(2, 0, nil, "stormstream leaves normal charges untouched")
assert(addon:SpendCharge(1, healingStream, now))
expect(1, 0, 17, "first normal charge spent")
assert(addon:SpendCharge(1, healingStream, now))
expect(0, 0, 17, "second normal charge spent")

now = 17
expect(1, 0, 34, "first sequential recharge")
now = 34
expect(2, 0, nil, "second sequential recharge")

now = 100
addon:AcknowledgeSlot(2)
assert(addon.pendingSwiftness and addon.pendingSwiftness.slotIndex == 2, "swiftness must remain armed")
assert(addon.sessionUses[2] == nil, "swiftness cooldown must not start on key press")
expect(2, 1, nil, "swiftness grants one stormstream use")

local order = addon:GetDisplayOrder(now)
assert(order[1].ability.abilityKey == "chain_heal", "chain heal must move ahead of stormstream while swiftness is armed")

addon:AcknowledgeSlot(3)
assert(addon.pendingSwiftness == nil, "chain heal must consume pending swiftness")
assert(addon.sessionUses[2] == now, "swiftness cooldown starts on consumer input")
expect(2, 1, nil, "consuming swiftness leaves stormstream available")

local riptideState = addon:GetChargeState(4, riptide, now)
assert(riptideState.baseCharges == 2, "riptide starts at two charges")
assert(addon:SpendCharge(4, riptide, now))
assert(addon:SpendCharge(4, riptide, now))
assert(riptideState.baseCharges == 0 and riptideState.nextRechargeAt == 106, "riptide spends both charges")
now = 106
addon:GetChargeState(4, riptide, now)
assert(riptideState.baseCharges == 1 and riptideState.nextRechargeAt == 112, "riptide first sequential recharge")
now = 112
addon:GetChargeState(4, riptide, now)
assert(riptideState.baseCharges == 2 and riptideState.nextRechargeAt == nil, "riptide second sequential recharge")

now = 120
assert(addon:SpendCharge(4, riptide, now), "riptide can be spent for refund test")
addon.pendingAcknowledgements = {}
addon.inputLockedUntil = {}
addon.Print = function() end
assert(addon:RefundAbility("riptide"), "manual refund must restore the most recent charge")
assert(riptideState.baseCharges == 2 and riptideState.nextRechargeAt == nil, "refund restores charge and cancels recharge at cap")

print("State model OK: HST 3/2, Swiftness sequencing, Riptide recharge and manual refund")
