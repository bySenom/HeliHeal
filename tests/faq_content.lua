local namespace = {}

assert(loadfile("FAQ.lua"))("HeliHeal", namespace)

local general = namespace.FAQ:GetEntries("SHAMAN", 264)
assert(#general == 3,
    "every supported healer must receive the general HeliHeal usage FAQ")

local paladin = namespace.FAQ:GetEntries("PALADIN", 65)
assert(#paladin == 9,
    "Holy Paladin must receive general and specialization-specific FAQ entries")

local combined = {}
for _, entry in ipairs(paladin) do
    combined[#combined + 1] = entry.question .. " " .. entry.answer
end
local content = table.concat(combined, "\n")
assert(content:find("Holy Bulwark", 1, true)
        and content:find("Sacred Weapon", 1, true)
        and content:find("Solidarity", 1, true)
        and content:find("Hand of Divinity", 1, true)
        and content:find("DEF", 1, true),
    "Holy Paladin FAQ must explain Armament targets, proc healing and the DEF window")

print("FAQ content OK: general guidance and Holy Paladin targeting help")
