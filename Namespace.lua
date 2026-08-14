local addonName, ns = ...

ns.addonName = addonName
ns.media = {
    fallbackIcon = 134400,
    font = "Fonts\\FRIZQT__.TTF",
    fontOrder = { "friz", "arial", "morpheus", "skurri" },
    fonts = {
        friz = { name = "Friz Quadrata", path = "Fonts\\FRIZQT__.TTF" },
        arial = { name = "Arial Narrow", path = "Fonts\\ARIALN.TTF" },
        morpheus = { name = "Morpheus", path = "Fonts\\MORPHEUS.TTF" },
        skurri = { name = "Skurri", path = "Fonts\\SKURRI.TTF" },
    },
}

-- Public, deliberately small extension surface for future class-data packs.
_G.HeliHealAPI = ns
