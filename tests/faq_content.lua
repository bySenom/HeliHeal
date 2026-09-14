local namespace = {}

assert(loadfile("FAQ.lua"))("HeliHeal", namespace)

local general = namespace.FAQ:GetEntries("SHAMAN", 264)
assert(#general == 3,
    "every supported healer must receive the general HeliHeal usage FAQ")

local paladin = namespace.FAQ:GetEntries("PALADIN", 65)
assert(#paladin == 16,
    "Holy Paladin must receive general and specialization-specific FAQ entries")

for index, entry in ipairs(paladin) do
    assert(entry.group and entry.tag and (entry.icon or (entry.spellIDs and #entry.spellIDs > 0)),
        ("FAQ entry %d must provide accordion grouping, a tag and an icon source"):format(index))
end

local paladinSpellTopics = 0
for _, entry in ipairs(paladin) do
    if entry.spellIDs and #entry.spellIDs > 0 then paladinSpellTopics = paladinSpellTopics + 1 end
end
assert(paladinSpellTopics == 13,
    "every Holy Paladin guide topic must expose related spell icons")

local combined = {}
for _, entry in ipairs(paladin) do
    combined[#combined + 1] = entry.question .. " " .. entry.answer
end
local content = table.concat(combined, "\n")
assert(content:find("Holy Bulwark", 1, true)
        and content:find("Sacred Weapon", 1, true)
        and content:find("Solidarity", 1, true)
        and content:find("Hand of Divinity", 1, true)
        and content:find("Divine Overload", 1, true)
        and content:find("Rising Sunlight", 1, true)
        and content:find("Divine Resonance", 1, true)
        and content:find("Beacon of Virtue", 1, true)
        and content:find("Mana", 1, true)
        and content:find("Cleanse", 1, true)
        and content:find("Bewegung", 1, true)
        and content:find("DEF", 1, true),
    "Holy Paladin FAQ must explain targets, contexts, mana, utility, movement and the DEF window")

print("FAQ content OK: general guidance and Holy Paladin targeting help")
