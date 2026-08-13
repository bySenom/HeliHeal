local _, ns = ...

ns.defaults = {
    global = {
        lastSeenChangelogVersion = "",
        language = "auto",
    },
    profile = {
        schemaVersion = 2,
        enabled = true,
        locked = false,
        scale = 1,
        spacing = 7,
        showPanelBackground = false,
        showHeader = false,
        showAbilityName = false,
        showPriorityBadge = false,
        showIconBorder = true,
        showHotkey = true,
        showCooldown = true,
        rotationPreset = "shaman_totemic_mythicplus",
        healingMode = "standard",
        rotationDataVersion = 12105,
        bindings = {},
        point = "CENTER",
        relativePoint = "CENTER",
        x = 0,
        y = -165,
        slots = ns.AbilityLibrary:BuildPresetSlots("shaman_totemic_mythicplus", {}),
    },
}
