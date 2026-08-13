local _, ns = ...
local L = ns.L or function(value, ...) return select("#", ...) > 0 and value:format(...) or value end

local AbilityLibrary = {
    abilities = {},
    presets = {},
}
ns.AbilityLibrary = AbilityLibrary

local function shallowCopy(source)
    local result = {}
    for key, value in pairs(source or {}) do
        result[key] = value
    end
    return result
end

function AbilityLibrary:RegisterAbility(key, data)
    assert(type(key) == "string" and key ~= "", "HeliHeal ability key must be a non-empty string")
    assert(type(data) == "table", "HeliHeal ability data must be a table")

    local record = shallowCopy(data)
    record.key = key
    record.spellID = math.max(0, math.floor(tonumber(record.spellID) or 0))
    record.cooldown = math.max(0, tonumber(record.cooldown) or 0)
    record.maxCharges = math.max(1, math.floor(tonumber(record.maxCharges) or 1))
    record.maxBonusCharges = math.max(0, math.floor(tonumber(record.maxBonusCharges) or 0))
    record.inputLockout = math.max(0, tonumber(record.inputLockout) or 1.0)
    record.trackedDuration = math.max(0, tonumber(record.trackedDuration) or 0)
    record.trackedGoal = math.max(0, math.floor(tonumber(record.trackedGoal) or 0))
    record.holyPowerGain = math.max(0, math.floor(tonumber(record.holyPowerGain) or 0))
    record.holyPowerCost = math.max(0, math.floor(tonumber(record.holyPowerCost) or 0))
    record.maxHolyPower = record.maxHolyPower and math.max(0, math.floor(tonumber(record.maxHolyPower) or 0)) or nil
    self.abilities[key] = record
    return record
end

function AbilityLibrary:GetAbility(key)
    return self.abilities[key]
end

function AbilityLibrary:RegisterPreset(key, data)
    assert(type(key) == "string" and key ~= "", "HeliHeal preset key must be a non-empty string")
    assert(type(data) == "table" and type(data.slots) == "table", "HeliHeal preset requires slots")
    self.presets[key] = shallowCopy(data)
end

function AbilityLibrary:GetPresetPriorityKeys(key, healingMode)
    local preset = assert(self:GetPreset(key), "Unknown HeliHeal rotation preset: " .. tostring(key))
    local modeSlots = preset.modeSlots and preset.modeSlots[healingMode or "standard"]
    return modeSlots or preset.slots
end

function AbilityLibrary:GetPreset(key)
    return self.presets[key]
end

function AbilityLibrary:BuildPresetSlots(key, bindings)
    local preset = assert(self:GetPreset(key), "Unknown HeliHeal rotation preset: " .. tostring(key))
    local abilityKeys = {}
    local seen = {}
    local function appendKeys(source)
        for _, abilityKey in ipairs(source or {}) do
            if not seen[abilityKey] then
                seen[abilityKey] = true
                abilityKeys[#abilityKeys + 1] = abilityKey
            end
        end
    end
    appendKeys(preset.slots)
    for _, modeSlots in pairs(preset.modeSlots or {}) do
        appendKeys(modeSlots)
    end

    local slots = {}
    for priority, abilityKey in ipairs(abilityKeys) do
        local ability = assert(self:GetAbility(abilityKey), "Unknown HeliHeal ability: " .. tostring(abilityKey))
        local bindingKey = ability.derivedBindingFrom or abilityKey
        slots[priority] = {
            abilityKey = abilityKey,
            enabled = true,
            spellID = ability.spellID,
            name = ability.name,
            icon = ability.icon,
            cooldown = ability.cooldown,
            maxCharges = ability.maxCharges,
            maxBonusCharges = ability.maxBonusCharges,
            grantsBonusChargeTo = ability.grantsBonusChargeTo,
            armsSwiftness = ability.armsSwiftness,
            preferredSwiftnessConsumer = ability.preferredSwiftnessConsumer,
            consumesSwiftness = ability.consumesSwiftness,
            inputLockout = ability.inputLockout,
            castSpellIDs = ability.castSpellIDs,
            trackedDuration = ability.trackedDuration,
            trackedGoal = ability.trackedGoal,
            holyPowerGain = ability.holyPowerGain,
            holyPowerCost = ability.holyPowerCost,
            maxHolyPower = ability.maxHolyPower,
            derivedBindingFrom = ability.derivedBindingFrom,
            inputKey = bindings and bindings[bindingKey] or "",
        }
    end
    return slots
end

function AbilityLibrary:Resolve(slot)
    local spellID = math.max(0, math.floor(tonumber(slot.spellID) or 0))
    local name = slot.name
    local icon = slot.icon

    -- Spell metadata is resolved for presentation only. It is never used to
    -- choose an action and no cooldown, aura, target, health or power API is read.
    if spellID > 0 and C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(spellID)
        if info then
            -- Blizzard spell metadata is already localized for every client.
            name = info.name or name
            icon = info.iconID or icon
        end
    end

    return {
        spellID = spellID,
        name = (name and name ~= "") and name or (spellID > 0 and ("Spell " .. spellID) or L("Nicht belegt")),
        icon = tonumber(icon) or ns.media.fallbackIcon,
        cooldown = math.max(0, tonumber(slot.cooldown) or 0),
        abilityKey = slot.abilityKey,
        maxCharges = math.max(1, math.floor(tonumber(slot.maxCharges) or 1)),
        maxBonusCharges = math.max(0, math.floor(tonumber(slot.maxBonusCharges) or 0)),
        grantsBonusChargeTo = slot.grantsBonusChargeTo,
        armsSwiftness = slot.armsSwiftness == true,
        preferredSwiftnessConsumer = slot.preferredSwiftnessConsumer,
        consumesSwiftness = slot.consumesSwiftness == true,
        inputLockout = math.max(0, tonumber(slot.inputLockout) or 1.0),
        castSpellIDs = slot.castSpellIDs,
        trackedDuration = math.max(0, tonumber(slot.trackedDuration) or 0),
        trackedGoal = math.max(0, math.floor(tonumber(slot.trackedGoal) or 0)),
        holyPowerGain = math.max(0, math.floor(tonumber(slot.holyPowerGain) or 0)),
        holyPowerCost = math.max(0, math.floor(tonumber(slot.holyPowerCost) or 0)),
        maxHolyPower = slot.maxHolyPower and math.max(0, math.floor(tonumber(slot.maxHolyPower) or 0)) or nil,
        derivedBindingFrom = slot.derivedBindingFrom,
        enabled = slot.enabled ~= false and spellID > 0,
    }
end
