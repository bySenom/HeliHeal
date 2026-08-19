local addon = {}
local namespace = { media = { fallbackIcon = 134400 } }

LibStub = function(name)
    assert(name == "AceAddon-3.0")
    return {
        NewAddon = function()
            return addon
        end,
    }
end

local now = 100
GetTime = function()
    return now
end

C_Spell = {
    GetSpellInfo = function(spellID)
        return { name = "Localized " .. spellID, iconID = spellID + 1 }
    end,
}

assert(loadfile("Core.lua"))("HeliHeal", namespace)

local expected = {
    SHAMAN = 77130,
    DRUID = 88423,
    PALADIN = 4987,
    PRIEST = 527,
    MONK = 115450,
}

for classToken, spellID in pairs(expected) do
    addon.classToken = classToken
    addon.supportedClass = true
    addon.dispelUsedAt = nil

    local dispel = addon:GetDispelInfo()
    assert(dispel and dispel.spellID == spellID and dispel.cooldown == 8,
        classToken .. " must expose its eight-second healer dispel")
    assert(not addon:RecordDispelSpellSucceeded(spellID + 1, now),
        "an unrelated spell must not start the dispel timer")
    assert(addon:RecordDispelSpellSucceeded(spellID, now),
        "the confirmed dispel must start the local timer")

    local _, remaining, usedAt = addon:GetDispelCooldownState(now + 3)
    assert(remaining == 5 and usedAt == now,
        "the local dispel timer must count down from eight seconds")

    local _, expired = addon:GetDispelCooldownState(now + 8)
    assert(expired == 0 and addon.dispelUsedAt == nil,
        "the expired dispel timer must clear itself")
end

print("dispel_tracker.lua: OK")
