local _, ns = ...
local L = ns.L or function(value, ...) return select("#", ...) > 0 and value:format(...) or value end

local HeliHeal = LibStub("AceAddon-3.0"):NewAddon("HeliHeal", "AceConsole-3.0")
ns.addon = HeliHeal

local HEALING_MODES = { "standard", "aoe", "single", "mana" }
local HEALING_MODE_LABELS = {
    standard = "Standard",
    aoe = "AoE",
    single = "Einzelziel",
    mana = "Mana sparen",
}
local HEALING_MODE_ALIASES = {
    standard = "standard", normal = "standard",
    aoe = "aoe", gruppe = "aoe",
    single = "single", einzel = "single", einzelziel = "single",
    mana = "mana", sparen = "mana",
}

local HEALER_SPECIALIZATIONS = {
    SHAMAN = 264,
    DRUID = 105,
    PALADIN = 65,
    PRIEST = { [256] = true, [257] = true },
    MONK = 270,
}

local HEALER_DISPELS = {
    SHAMAN = { spellID = 77130, name = "Purify Spirit", cooldown = 8 },
    DRUID = { spellID = 88423, name = "Nature's Cure", cooldown = 8 },
    PALADIN = { spellID = 4987, name = "Cleanse", cooldown = 8 },
    PRIEST = { spellID = 527, name = "Purify", cooldown = 8 },
    MONK = { spellID = 115450, name = "Detox", cooldown = 8 },
}

-- Nature's Swiftness does not begin its cooldown when the buff is armed.
-- UNIT_SPELLCAST_SUCCEEDED for one of these consumers is the first safe,
-- target-independent signal that the local cooldown may start.
local SWIFTNESS_CONSUMER_SPELL_IDS = {
    DRUID = {
        [8936] = true,  -- Regrowth
        [20484] = true, -- Rebirth
        [339] = true,   -- Entangling Roots
    },
    SHAMAN = {
        [8004] = true,   -- Healing Surge
        [1064] = true,   -- Chain Heal
        [73920] = true,  -- Healing Rain
        [77472] = true,  -- Healing Wave
        [197995] = true, -- Wellspring
        [188196] = true, -- Lightning Bolt
        [188443] = true, -- Chain Lightning
        [117014] = true, -- Elemental Blast
    },
}

local CURRENT_SCHEMA_VERSION = 6
local ROTATION_DATA_VERSION = 12122
local STORMSTREAM_CAST_SPELL_IDS = {
    [1267068] = true,
    [1267089] = true,
}
local PALADIN_WINGS_DURATION = 20
local PALADIN_CRUSADER_DURATION = 15
local PALADIN_HAND_OF_DIVINITY_DURATION = 20
local PALADIN_INFUSION_DURATION = 15
local PALADIN_ARMAMENT_DURATION = 20
local PALADIN_VIRTUE_DURATION = 9
local PALADIN_DIVINE_RESONANCE_TICK = 5
local PALADIN_DIVINE_RESONANCE_TICKS = 3

local function copyTable(source)
    local result = {}
    for key, value in pairs(source or {}) do
        if type(value) == "table" then
            result[key] = copyTable(value)
        else
            result[key] = value
        end
    end
    return result
end

local PERSISTENT_RUNTIME_FIELDS = {
    "sessionUses", "sessionCharges", "sessionSpendHistory", "sessionTimedEffects",
    "sessionAtonements", "holyPowerBaseline", "holyPowerFreeSpenderBaseline",
    "sessionHolyPower", "holyPowerEvents", "nextHolyPowerEventID",
    "pendingFreeHolyPowerSpenders", "pendingPaladinInfusion", "paladinWingsUntil",
    "paladinCrusaderUntil", "paladinVirtueUntil", "pendingPaladinHandOfDivinity",
    "paladinDivineResonance",
    "paladinArmamentExpirations", "paladinNextArmamentType",
    "pendingSwiftness", "pendingDownpour",
    "pendingUnleash", "pendingArchdruid", "pendingDruidSoul",
    "unleashConsumptionHistory", "riptideRechargeRateUntil", "priestApotheosisUntil",
    "pendingMonkTea", "monkJadeSerpentUntil", "monkConduitHeartAt",
    "sessionMonkRenewingMists", "monkSheilunClouds", "monkSheilunCombatStartedAt",
    "monkSheilunLeftCombatAt", "monkTeachingsStacks", "dispelUsedAt",
}

function HeliHeal:ResetInputState()
    if self.CancelPendingAcknowledgements then self:CancelPendingAcknowledgements() end
    self.inputGeneration = (self.inputGeneration or 0) + 1
    self.holyPowerSyncToken = (self.holyPowerSyncToken or 0) + 1
    self.pendingAcknowledgements = {}
    self.recentSuccessfulSpells = {}
    self.processedPlayerCastGUIDs = {}
    self.recentDirectConfirmations = {}
    self.recentExternalHolyPowerSuccess = {}
    self.recentPaladinArmamentSuccess = nil
    self.heldInputKeys = {}
    self.mouseHeldInputs = {}
    self.inputLockedUntil = {}
    self.lastObservedInputs = {}
    self.recentAssistedSwiftnessConsumer = nil
    self.rotationStuckCandidate = nil
end

function HeliHeal:ResetRuntimeState()
    self:ResetInputState()
    self.sessionUses = {}
    self.sessionCharges = {}
    self.armamentDiagnosticEvents = {}
    self.sessionSpendHistory = {}
    self.sessionTimedEffects = {}
    self.rotationRejectionBackoff = {}
    self.sessionAtonements = {}
    self.holyPowerBaseline = 0
    self.holyPowerFreeSpenderBaseline = 0
    self.sessionHolyPower = 0
    self.holyPowerEvents = {}
    self.nextHolyPowerEventID = 0
    self.pendingFreeHolyPowerSpenders = 0
    self.pendingPaladinInfusion = nil
    self.paladinInfusionCDMRecheckAt = nil
    self.paladinInfusionConsumptionEvidence = nil
    self.paladinWingsUntil = nil
    self.paladinCrusaderUntil = nil
    self.paladinVirtueUntil = nil
    self.pendingPaladinHandOfDivinity = nil
    self.paladinDivineResonance = nil
    self.paladinArmamentExpirations = {}
    self.paladinNextArmamentType = "bulwark"
    self.pendingSwiftness = nil
    self.pendingDownpour = nil
    self.pendingUnleash = nil
    self.pendingArchdruid = nil
    self.pendingDruidSoul = nil
    self.unleashConsumptionHistory = {}
    self.riptideRechargeRateUntil = nil
    self.priestApotheosisUntil = nil
    self.pendingMonkTea = nil
    self.monkJadeSerpentUntil = nil
    self.monkConduitHeartAt = nil
    self.sessionMonkRenewingMists = {}
    self.monkSheilunClouds = 0
    self.monkSheilunCombatStartedAt = nil
    self.monkSheilunLeftCombatAt = nil
    self.monkTeachingsStacks = 0
    self.dispelUsedAt = nil
end

function HeliHeal:GetDispelInfo()
    local configured = HEALER_DISPELS[self.classToken]
    if not configured or not self.supportedClass then return nil end
    local name, icon = configured.name, ns.media and ns.media.fallbackIcon
    if C_Spell and type(C_Spell.GetSpellInfo) == "function" then
        local ok, info = pcall(C_Spell.GetSpellInfo, configured.spellID)
        if ok and type(info) == "table" then
            name = info.name or name
            icon = info.iconID or icon
        end
    end
    return {
        spellID = configured.spellID,
        name = name,
        icon = icon,
        cooldown = configured.cooldown,
    }
end

function HeliHeal:RecordDispelSpellSucceeded(spellID, now)
    local dispel = self:GetDispelInfo()
    if not dispel or tonumber(spellID) ~= dispel.spellID then return false end
    self.dispelUsedAt = now or GetTime()
    if self.frame then self:RefreshDisplay() end
    return true
end

function HeliHeal:GetDispelCooldownState(now)
    local dispel = self:GetDispelInfo()
    if not dispel then return nil end
    now = now or GetTime()
    local usedAt = tonumber(self.dispelUsedAt)
    local remaining = usedAt and math.max(0, usedAt + dispel.cooldown - now) or 0
    if remaining <= 0 then self.dispelUsedAt = nil end
    return dispel, remaining, usedAt
end

function HeliHeal:CaptureZoneRuntimeState()
    if not self.supportedClass then return false end
    local runtime = {}
    for _, field in ipairs(PERSISTENT_RUNTIME_FIELDS) do
        local value = self[field]
        if value ~= nil then
            runtime[field] = type(value) == "table" and copyTable(value) or value
        end
    end
    self.zoneRuntimeSnapshot = {
        classToken = self.classToken,
        specializationID = self.specializationID,
        rotationPreset = self.db and self.db.profile and self.db.profile.rotationPreset,
        runtime = runtime,
    }
    return true
end

function HeliHeal:RestoreZoneRuntimeState()
    local snapshot = self.zoneRuntimeSnapshot
    self.zoneRuntimeSnapshot = nil
    if not snapshot or not self.supportedClass
        or snapshot.classToken ~= self.classToken
        or snapshot.specializationID ~= self.specializationID
        or snapshot.rotationPreset ~= (self.db and self.db.profile and self.db.profile.rotationPreset) then
        return false
    end
    self:ResetRuntimeState()
    for _, field in ipairs(PERSISTENT_RUNTIME_FIELDS) do
        local value = snapshot.runtime[field]
        if value ~= nil then
            self[field] = type(value) == "table" and copyTable(value) or value
        end
    end
    if self.frame then self:RefreshDisplay() end
    return true
end

function HeliHeal:MigrateProfile(profile)
    profile = profile or (self.db and self.db.profile)
    if not profile then return false end
    local originalVersion = tonumber(rawget(profile, "schemaVersion")) or 0
    if originalVersion >= CURRENT_SCHEMA_VERSION then return false end

    profile.bindings = profile.bindings or {}
    if originalVersion < 1 then
        for _, oldSlot in ipairs(profile.slots or {}) do
            if oldSlot.inputKey and oldSlot.inputKey ~= "" then
                for abilityKey, ability in pairs(ns.AbilityLibrary.abilities) do
                    if tonumber(oldSlot.spellID) == ability.spellID then
                        profile.bindings[abilityKey] = oldSlot.inputKey
                    end
                end
            end
        end
    end
    if originalVersion < 2 then
        for abilityKey, inputKey in pairs(profile.bindings) do
            if type(inputKey) ~= "string" then
                profile.bindings[abilityKey] = nil
            else
                profile.bindings[abilityKey] = inputKey:match("^%s*(.-)%s*$"):upper()
            end
        end
        profile.healingMode = HEALING_MODE_ALIASES[(profile.healingMode or "standard"):lower()] or "standard"
    end
    if originalVersion < 3 then
        local oldPrimarySize = tonumber(rawget(profile, "primaryIconSize")) or 62
        local oldSecondarySize = tonumber(rawget(profile, "secondaryIconSize")) or 46
        profile.primaryIconWidth = tonumber(rawget(profile, "primaryIconWidth")) or oldPrimarySize
        profile.primaryIconHeight = tonumber(rawget(profile, "primaryIconHeight")) or oldPrimarySize
        profile.secondaryIconWidth = tonumber(rawget(profile, "secondaryIconWidth")) or oldSecondarySize
        profile.secondaryIconHeight = tonumber(rawget(profile, "secondaryIconHeight")) or oldSecondarySize
        profile.primaryIconZoom = tonumber(rawget(profile, "primaryIconZoom")) or 1
        profile.secondaryIconZoom = tonumber(rawget(profile, "secondaryIconZoom")) or 1
    end
    if originalVersion < 4 then
        local oldDispelOffset = tonumber(rawget(profile, "dispelCursorOffsetX"))
        if oldDispelOffset == nil or oldDispelOffset == 24 then
            profile.dispelCursorOffsetX = 42
        end
    end
    if originalVersion < 5 then
        local supportCopies = {
            supportWindowSpacing = "spacing",
            supportWindowIconWidth = "secondaryIconWidth",
            supportWindowIconHeight = "secondaryIconHeight",
            supportWindowIconZoom = "secondaryIconZoom",
            supportWindowIconOffsetX = "secondaryIconOffsetX",
            supportWindowIconOffsetY = "secondaryIconOffsetY",
            supportWindowIconInset = "iconInset",
            supportWindowPaddingX = "panelPaddingX",
            supportWindowPaddingY = "panelPaddingY",
            supportWindowPanelBackgroundAlpha = "panelBackgroundAlpha",
            supportWindowShowPanelBackground = "showPanelBackground",
            supportWindowShowHeader = "showHeader",
            supportWindowShowAbilityName = "showAbilityName",
            supportWindowShowIconBorder = "showIconBorder",
            supportWindowShowHotkey = "showHotkey",
            supportWindowShowCooldown = "showCooldown",
        }
        for supportKey, sharedKey in pairs(supportCopies) do
            local value = rawget(profile, sharedKey)
            if value ~= nil then profile[supportKey] = value end
        end
        profile.supportWindowOrientation = "HORIZONTAL"
    end
    if originalVersion < 6 then
        -- Move only the previous shipped defaults closer together. Any
        -- distinct user-selected spacing remains untouched.
        local mainSpacing = tonumber(rawget(profile, "spacing"))
        local supportSpacing = tonumber(rawget(profile, "supportWindowSpacing"))
        if mainSpacing == nil or mainSpacing == 7 then profile.spacing = 3 end
        if supportSpacing == nil or supportSpacing == 7 then profile.supportWindowSpacing = 3 end
    end
    profile.schemaVersion = CURRENT_SCHEMA_VERSION
    profile.rotationDataVersion = ROTATION_DATA_VERSION
    return true
end

function HeliHeal:GetPlayerSpecializationID()
    if type(GetSpecialization) ~= "function" or type(GetSpecializationInfo) ~= "function" then return nil end
    local ok, specializationID = pcall(function()
        local specializationIndex = GetSpecialization()
        if not specializationIndex then return nil end
        return GetSpecializationInfo(specializationIndex)
    end)
    return ok and tonumber(specializationID) or nil
end

function HeliHeal:RefreshPlayerSupport(resetOnChange)
    local previousClass = self.classToken
    local previousSpecialization = self.specializationID
    local previousSupport = self.supportedClass
    local _, classToken = UnitClass("player")
    if not classToken then classToken = previousClass end
    self.classToken = classToken
    local specializationID = self:GetPlayerSpecializationID()
    if not specializationID and classToken == previousClass then specializationID = previousSpecialization end
    self.specializationID = specializationID
    local supportedSpecs = HEALER_SPECIALIZATIONS[classToken]
    self.supportedClass = type(supportedSpecs) == "table"
        and supportedSpecs[self.specializationID] == true
        or supportedSpecs == self.specializationID

    local changed = previousClass ~= self.classToken
        or previousSpecialization ~= self.specializationID
        or previousSupport ~= self.supportedClass
    if changed and resetOnChange then
        self:ResetRuntimeState()
        if self.Mana and self.Mana.Initialize then self.Mana:Initialize(self) end
        if self.db then self:EnsureRotationProfile() end
        if self.frame then
            self:ApplyDisplaySettings()
            self:RefreshDisplay()
        end
        if self.RefreshOptionsUI then self:RefreshOptionsUI() end
    end
    return changed
end

function HeliHeal:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("HeliHealDB", ns.defaults, true)
    ns.SetLocale(self.db.global.language)
    self:MigrateProfile(self.db.profile)
    self:ResetRuntimeState()
    self:RefreshPlayerSupport(false)
    self:EnsureRotationProfile()

    self:RegisterChatCommand("heliheal", "HandleSlashCommand")
    self:RegisterChatCommand("hh", "HandleSlashCommand")

    self.db.RegisterCallback(self, "OnProfileChanged", "RefreshFromProfile")
    self.db.RegisterCallback(self, "OnProfileCopied", "RefreshFromProfile")
    self.db.RegisterCallback(self, "OnProfileReset", "RefreshFromProfile")
end

function HeliHeal:OnEnable()
    self.inputListenerEnabled = true
    self:CreateManaTracker()
    self:CreateInputListener()
    self:InitializeProcTracker()
    self:CreateDisplay()
    self:SetupOptions()
    self:CreateTalentListener()
    self:RefreshFromProfile()
end

function HeliHeal:OnDisable()
    self.inputListenerEnabled = false
    if self.mouseInputListener then self.mouseInputListener:UnregisterAllEvents() end
    if self.castInputListener then self.castInputListener:UnregisterAllEvents() end
    if self.talentListener then self.talentListener:UnregisterAllEvents() end
    if self.DisableProcTracker then self:DisableProcTracker() end
    if self.Mana then self.Mana:Disable() end
    self:ResetRuntimeState()
    if self.frame then self.frame:Hide() end
    if self.supportFrame then self.supportFrame:Hide() end
    if self.dispelCursorFrame then self.dispelCursorFrame:Hide() end
end

function HeliHeal:RefreshFromProfile()
    self:ResetRuntimeState()
    self:MigrateProfile(self.db.profile)
    self:EnsureRotationProfile()
    if self.Mana and self.Mana.ResetAutoModeState then self.Mana:ResetAutoModeState() end
    if self.frame then
        self:ApplyDisplaySettings()
        self:RefreshDisplay()
    end
    if self.RefreshOptionsUI then
        self:RefreshOptionsUI()
    end
end

function HeliHeal:EnsureRotationProfile()
    local profile = self.db.profile
    profile.bindings = profile.bindings or {}

    -- Preserve matching keys from older freeform slots before replacing them
    -- with the authoritative class data pack.
    if rawget(profile, "rotationDataVersion") ~= ROTATION_DATA_VERSION then
        for _, oldSlot in ipairs(profile.slots or {}) do
            if oldSlot.inputKey and oldSlot.inputKey ~= "" then
                for abilityKey, ability in pairs(ns.AbilityLibrary.abilities) do
                    if tonumber(oldSlot.spellID) == ability.spellID then
                        profile.bindings[abilityKey] = oldSlot.inputKey
                    end
                end
            end
        end
        profile.rotationDataVersion = ROTATION_DATA_VERSION
    end

    profile.healingMode = HEALING_MODE_LABELS[profile.healingMode] and profile.healingMode or "standard"

    local defaults = {
        SHAMAN = "shaman_totemic_mythicplus",
        DRUID = "druid_wildstalker_mythicplus",
        PALADIN = "paladin_herald_mythicplus",
        PRIEST = "priest_archon_mythicplus",
        MONK = "monk_conduit_mythicplus",
    }
    local storedPreset = profile.rotationPreset and ns.AbilityLibrary:GetPreset(profile.rotationPreset)
    local priestContent = storedPreset and storedPreset.content == "Raid" and "raid" or "mythicplus"
    local defaultPreset = self.classToken == "PRIEST" and self.specializationID == 256
        and ("disc_oracle_" .. priestContent)
        or (self.classToken == "PRIEST" and ("priest_archon_" .. priestContent)
        or (defaults[self.classToken] or "shaman_totemic_mythicplus"))
    local presetKey = profile.rotationPreset or defaultPreset
    local preset = ns.AbilityLibrary:GetPreset(presetKey)
    if not preset or preset.class ~= self.classToken
        or (preset.specializationID and preset.specializationID ~= self.specializationID) then
        presetKey = defaultPreset
    end
    profile.rotationPreset = presetKey
    profile.slots = ns.AbilityLibrary:BuildPresetSlots(presetKey, profile.bindings)
end

function HeliHeal:SetRotationPreset(presetKey)
    local preset = ns.AbilityLibrary:GetPreset(presetKey)
    if not preset or preset.class ~= self.classToken
        or (preset.specializationID and preset.specializationID ~= self.specializationID) then
        return
    end
    self.db.profile.rotationPreset = presetKey
    self.db.profile.rotationDataVersion = ROTATION_DATA_VERSION
    self.db.profile.slots = ns.AbilityLibrary:BuildPresetSlots(presetKey, self.db.profile.bindings)
    self:ResetSession()
    self:RefreshOptionsUI()
end

local function talentBuildBindingKey(configID)
    configID = tonumber(configID)
    return configID and tostring(math.floor(configID)) or nil
end

function HeliHeal:GetActiveTalentBuildInfo()
    local snapshot = self.talentSnapshot
    local configID = snapshot and tonumber(snapshot.configID)
    if not configID then return nil end
    return configID, snapshot.configName or L("Talent-Build %s", configID)
end

function HeliHeal:GetTalentBuildsForCurrentSpec()
    local builds = {}
    local seen = {}
    if C_ClassTalents and type(C_ClassTalents.GetConfigIDsBySpecID) == "function"
        and C_Traits and type(C_Traits.GetConfigInfo) == "function" then
        local ok, configIDs = pcall(C_ClassTalents.GetConfigIDsBySpecID, self.specializationID)
        if ok and type(configIDs) == "table" then
            for _, configID in ipairs(configIDs) do
                configID = tonumber(configID)
                if configID and not seen[configID] then
                    local infoOK, info = pcall(C_Traits.GetConfigInfo, configID)
                    if infoOK and info then
                        seen[configID] = true
                        builds[#builds + 1] = {
                            configID = configID,
                            name = info.name or L("Talent-Build %s", configID),
                        }
                    end
                end
            end
        end
    end
    local activeID, activeName = self:GetActiveTalentBuildInfo()
    if activeID and not seen[activeID] then
        builds[#builds + 1] = { configID = activeID, name = activeName }
    end
    table.sort(builds, function(a, b)
        return tostring(a.name):lower() < tostring(b.name):lower()
    end)
    for _, build in ipairs(builds) do build.active = build.configID == activeID end
    return builds
end

function HeliHeal:GetTalentBuildBinding(configID)
    local key = talentBuildBindingKey(configID)
    local bindings = self.db and self.db.char and self.db.char.talentBuildBindings
    local binding = key and bindings and bindings[key]
    if type(binding) ~= "table" then return nil end
    local preset = ns.AbilityLibrary:GetPreset(binding.rotationPreset)
    if not preset or preset.class ~= self.classToken
        or (preset.specializationID and preset.specializationID ~= self.specializationID)
        or (binding.classToken and binding.classToken ~= self.classToken)
        or (binding.specializationID and binding.specializationID ~= self.specializationID)
        or not HEALING_MODE_LABELS[binding.healingMode] then
        return nil
    end
    return binding
end

function HeliHeal:SetTalentBuildBinding(configID, presetKey, healingMode)
    configID = tonumber(configID)
    local preset = ns.AbilityLibrary:GetPreset(presetKey)
    if not configID or not preset or preset.class ~= self.classToken
        or (preset.specializationID and preset.specializationID ~= self.specializationID)
        or not HEALING_MODE_LABELS[healingMode] then
        self:Print(L("Talent-Build-Zuordnung konnte nicht gespeichert werden."))
        return false
    end
    local configName = L("Talent-Build %s", configID)
    if C_Traits and type(C_Traits.GetConfigInfo) == "function" then
        local ok, info = pcall(C_Traits.GetConfigInfo, configID)
        if ok and info and info.name then configName = info.name end
    end
    self.db.char.talentBuildBindings = self.db.char.talentBuildBindings or {}
    self.db.char.talentBuildBindings[talentBuildBindingKey(configID)] = {
        rotationPreset = presetKey,
        healingMode = healingMode,
        classToken = self.classToken,
        specializationID = self.specializationID,
        configName = configName,
    }
    local activeConfigID = self:GetActiveTalentBuildInfo()
    if activeConfigID == configID then
        local _, changed = self:ApplyTalentBuildBinding(configID)
        if changed then
            self:ResetRuntimeState()
            if self.frame then self:RefreshDisplay() end
        end
    end
    if self.RefreshOptionsUI then self:RefreshOptionsUI() end
    self:Print(L("Talent-Build %s wurde mit %s und %s verknüpft.",
        configName, preset.name or presetKey, L(HEALING_MODE_LABELS[healingMode])))
    return true
end

function HeliHeal:LinkActiveTalentBuild()
    local configID = self:GetActiveTalentBuildInfo()
    if not configID then
        self:Print(L("Aktiver Talent-Build ist noch nicht lesbar."))
        return false
    end
    return self:SetTalentBuildBinding(configID, self.db.profile.rotationPreset, self:GetHealingMode())
end

function HeliHeal:UnlinkTalentBuild(configID)
    configID = tonumber(configID)
    local key = talentBuildBindingKey(configID)
    local bindings = self.db and self.db.char and self.db.char.talentBuildBindings
    if not key or not bindings or not bindings[key] then return false end
    local configName = bindings[key].configName or L("Talent-Build %s", configID)
    bindings[key] = nil
    if self.RefreshOptionsUI then self:RefreshOptionsUI() end
    self:Print(L("Verknüpfung für Talent-Build %s entfernt.", configName))
    return true
end

function HeliHeal:UnlinkActiveTalentBuild()
    return self:UnlinkTalentBuild(self:GetActiveTalentBuildInfo())
end

function HeliHeal:ApplyTalentBuildBinding(configID)
    local binding = self:GetTalentBuildBinding(configID)
    if not binding then return false, false end
    local profile = self.db.profile
    local changed = profile.rotationPreset ~= binding.rotationPreset
        or self:GetHealingMode() ~= binding.healingMode
    profile.rotationPreset = binding.rotationPreset
    profile.healingMode = binding.healingMode
    profile.rotationDataVersion = ROTATION_DATA_VERSION
    profile.slots = ns.AbilityLibrary:BuildPresetSlots(binding.rotationPreset, profile.bindings)
    return true, changed
end

function HeliHeal:SetAbilityBinding(slotIndex, inputKey)
    local slot = self.db.profile.slots[slotIndex]
    if not slot or not slot.abilityKey then
        return
    end
    inputKey = inputKey or ""
    local bindingKey = slot.derivedBindingFrom or slot.abilityKey
    self.db.profile.bindings[bindingKey] = inputKey
    for _, configured in ipairs(self.db.profile.slots) do
        if configured.abilityKey == bindingKey or configured.derivedBindingFrom == bindingKey then
            configured.inputKey = inputKey
        end
    end
    self:RefreshDisplay()
    if self.RefreshOptionsUI then self:RefreshOptionsUI() end
    local conflict = self:GetBindingConflictForAbility(bindingKey)
    if conflict then
        self:Print(L("Hotkey %s ist mehrfach belegt: %s", conflict.inputKey, table.concat(conflict.names, ", ")))
    end
end

function HeliHeal:GetBindingConflicts()
    local grouped = {}
    for slotIndex, slot in ipairs(self.db.profile.slots or {}) do
        local ability = self:GetSlot(slotIndex)
        if ability and ability.enabled and slot.inputKey and slot.inputKey ~= "" then
            local group = grouped[slot.inputKey]
            if not group then
                group = { inputKey = slot.inputKey, abilityKeys = {}, names = {} }
                grouped[slot.inputKey] = group
            end
            local bindingKey = slot.derivedBindingFrom or slot.abilityKey
            if not group.abilityKeys[bindingKey] then
                group.abilityKeys[bindingKey] = true
                group.names[#group.names + 1] = ability.name or bindingKey
            end
        end
    end
    local conflicts = {}
    for _, group in pairs(grouped) do
        local count = 0
        for _ in pairs(group.abilityKeys) do count = count + 1 end
        if count > 1 then conflicts[#conflicts + 1] = group end
    end
    table.sort(conflicts, function(a, b) return a.inputKey < b.inputKey end)
    return conflicts
end

function HeliHeal:GetBindingConflictForAbility(abilityKey)
    for _, conflict in ipairs(self:GetBindingConflicts()) do
        if conflict.abilityKeys[abilityKey] then return conflict end
    end
end

function HeliHeal:ReconcileOutOfCombatState(silent)
    if InCombatLockdown and InCombatLockdown() then
        self.outOfCombatSyncPending = true
        return false
    end

    local now = GetTime()
    self.outOfCombatSyncPending = false
    self:ResetInputState()
    for slotIndex, _ in ipairs(self.db.profile.slots or {}) do
        local ability = self:GetSlot(slotIndex)
        if ability then
            local usedAt = self.sessionUses[slotIndex]
            if usedAt and (ability.cooldown <= 0 or now >= usedAt + ability.cooldown) then
                self.sessionUses[slotIndex] = nil
            end
            if ability.maxCharges > 1 then self:GetChargeState(slotIndex, ability, now) end
            if ability.trackedDuration > 0 then self:GetTrackedState(ability, now) end
        end
    end
    self:GetAtonementState(now)
    if self.riptideRechargeRateUntil and now >= self.riptideRechargeRateUntil then
        self.riptideRechargeRateUntil = nil
    end
    if self.pendingSwiftness and self.pendingSwiftness.expiresAt and now >= self.pendingSwiftness.expiresAt then
        self.pendingSwiftness = nil
    end
    self:IsDownpourReady(now)
    if not self:IsUnleashReady(now) then self.unleashConsumptionHistory = {} end
    self:IsArchdruidReady(now)
    if self.Mana then self.Mana:RefreshOutOfCombatSnapshot(true) end
    self:RefreshDisplay()
    if not silent then self:Print(L("Lokalen Zustand außerhalb des Kampfes abgeglichen.")) end
    return true
end

local function countEntries(value)
    local count = 0
    for _ in pairs(value or {}) do count = count + 1 end
    return count
end

function HeliHeal:BuildDiagnosticReport(currentRotationOnly)
    local version = "?"
    if C_AddOns and type(C_AddOns.GetAddOnMetadata) == "function" then
        version = C_AddOns.GetAddOnMetadata("HeliHeal", "Version") or version
    elseif type(GetAddOnMetadata) == "function" then
        version = GetAddOnMetadata("HeliHeal", "Version") or version
    end
    local build = type(GetBuildInfo) == "function" and select(2, GetBuildInfo()) or "?"
    local talent = self.talentSnapshot or {}
    local activeBindingKeys
    if currentRotationOnly then
        activeBindingKeys = {}
        for slotIndex, configuredSlot in ipairs(self.db.profile.slots or {}) do
            local ability = self.GetSlot and self:GetSlot(slotIndex) or configuredSlot
            if ability and ability.enabled then
                activeBindingKeys[configuredSlot.abilityKey] = true
                if configuredSlot.derivedBindingFrom then activeBindingKeys[configuredSlot.derivedBindingFrom] = true end
            end
        end
    end
    local conflictKeys = {}
    for _, conflict in ipairs(self:GetBindingConflicts()) do
        local relevant = not currentRotationOnly
        for abilityKey in pairs(conflict.abilityKeys or {}) do
            if activeBindingKeys and activeBindingKeys[abilityKey] then relevant = true break end
        end
        if relevant then conflictKeys[#conflictKeys + 1] = conflict.inputKey end
    end
    local bindings = {}
    for abilityKey, inputKey in pairs(self.db.profile.bindings or {}) do
        if inputKey ~= "" and (not activeBindingKeys or activeBindingKeys[abilityKey]) then
            bindings[#bindings + 1] = abilityKey .. "=" .. inputKey
        end
    end
    table.sort(bindings)
    return table.concat({
        "version=" .. tostring(version),
        "client=" .. tostring(build),
        "locale=" .. tostring(ns.locale or "?"),
        "clientLocale=" .. tostring(ns.clientLocale or "?"),
        "localeMode=" .. tostring(ns.localeMode or "auto"),
        "localeFallback=" .. tostring(ns.localeFallback == true),
        "class=" .. tostring(self.classToken or "?"),
        "spec=" .. tostring(self.specializationID or "?"),
        "supported=" .. tostring(self.supportedClass == true),
        "schema=" .. tostring(rawget(self.db.profile, "schemaVersion") or 0),
        "preset=" .. tostring(self.db.profile.rotationPreset or "?"),
        "mode=" .. tostring(self:GetHealingMode()),
        "talentConfig=" .. tostring(talent.configID or "unavailable"),
        "talentsReadable=" .. tostring(talent.available == true),
        "bindings=" .. (#bindings > 0 and table.concat(bindings, ",") or "none"),
        "conflicts=" .. (#conflictKeys > 0 and table.concat(conflictKeys, ",") or "none"),
        "uses=" .. countEntries(self.sessionUses),
        "charges=" .. countEntries(self.sessionCharges),
        "tracked=" .. countEntries(self.sessionTimedEffects),
        "atonementGroup=" .. tostring(self.sessionAtonements and self.sessionAtonements.groupUntil or 0),
        "atonementSingle=" .. tostring(self.sessionAtonements and self.sessionAtonements.singleUntil or 0),
        "spellHaste=" .. tostring(self.cachedSpellHaste or "unavailable"),
        "holyPower=" .. tostring(self.sessionHolyPower or 0),
        "mana=" .. tostring(self.Mana and self.Mana.current or "unavailable"),
        "manaReliability=" .. tostring(self.Mana and self.Mana.reliability or "UNKNOWN"),
        "freeSpenders=" .. tostring(self.pendingFreeHolyPowerSpenders or 0),
        "paladinInfusions=" .. tostring(self:GetPaladinInfusionCharges()),
        "paladinWingsUntil=" .. tostring(self.paladinWingsUntil or 0),
        "paladinCrusaderUntil=" .. tostring(self.paladinCrusaderUntil or 0),
        "paladinVirtueUntil=" .. tostring(self.paladinVirtueUntil or 0),
        "paladinHandUses=" .. tostring(self.pendingPaladinHandOfDivinity
            and self.pendingPaladinHandOfDivinity.uses or 0),
        "paladinResonanceTicks=" .. tostring(self.paladinDivineResonance
            and self.paladinDivineResonance.ticksRemaining or 0),
        "paladinArmaments=" .. tostring(countEntries(self.paladinArmamentExpirations)),
        "pendingInputs=" .. countEntries(self.pendingAcknowledgements),
    }, "; ")
end

function HeliHeal:PrintDiagnostics()
    self:Print("DIAG: " .. self:BuildDiagnosticReport())
end

function HeliHeal:GetAddonVersion()
    if C_AddOns and type(C_AddOns.GetAddOnMetadata) == "function" then
        return C_AddOns.GetAddOnMetadata("HeliHeal", "Version") or ns.changelog.currentVersion
    elseif type(GetAddOnMetadata) == "function" then
        return GetAddOnMetadata("HeliHeal", "Version") or ns.changelog.currentVersion
    end
    return ns.changelog.currentVersion
end

function HeliHeal:ShouldShowWhatsNew()
    local global = self.db and self.db.global
    return global and global.lastSeenChangelogVersion ~= self:GetAddonVersion()
end

function HeliHeal:MarkChangelogSeen(version)
    if self.db and self.db.global then
        self.db.global.lastSeenChangelogVersion = version or self:GetAddonVersion()
    end
end

function HeliHeal:GetLanguageMode()
    return self.db and self.db.global and self.db.global.language or "auto"
end

function HeliHeal:SetLanguageMode(mode, reloadUI)
    if mode ~= "auto" and mode ~= "deDE" and mode ~= "enUS" then return false end
    if self:GetLanguageMode() == mode then return true end
    self.db.global.language = mode
    ns.SetLocale(mode)
    if reloadUI ~= false then
        if C_UI and C_UI.Reload then C_UI.Reload() else ReloadUI() end
    end
    return true
end

function HeliHeal:GetHealingMode()
    return self.db.profile.healingMode or "standard"
end

function HeliHeal:GetHealingModeLabel()
    return L(HEALING_MODE_LABELS[self:GetHealingMode()] or HEALING_MODE_LABELS.standard)
end

function HeliHeal:SetHealingMode(mode, silent, automatic)
    mode = HEALING_MODE_ALIASES[(mode or ""):lower()] or mode
    if not HEALING_MODE_LABELS[mode] then
        return false
    end
    if self.Mana and not automatic then self.Mana:OnManualModeChanged() end
    self.db.profile.healingMode = mode
    self:RefreshDisplay()
    if self.RefreshOptionsUI then self:RefreshOptionsUI() end
    if not silent then self:Print(L("Heilmodus: %s", self:GetHealingModeLabel())) end
    return true
end

function HeliHeal:CycleHealingMode()
    local current = self:GetHealingMode()
    for index, mode in ipairs(HEALING_MODES) do
        if mode == current then
            return self:SetHealingMode(HEALING_MODES[(index % #HEALING_MODES) + 1])
        end
    end
    return self:SetHealingMode("standard")
end

function HeliHeal:GetActivePriorityRanks()
    local presetKey = self.db.profile.rotationPreset
    local mode = self:GetHealingMode()
    local cached = self.activePriorityRanksCache
    if cached and cached.presetKey == presetKey and cached.mode == mode then
        return cached.ranks
    end
    local keys = ns.AbilityLibrary:GetPresetPriorityKeys(presetKey, mode)
    local ranks = {}
    for rank, abilityKey in ipairs(keys) do ranks[abilityKey] = rank end
    self.activePriorityRanksCache = { presetKey = presetKey, mode = mode, ranks = ranks }
    return ranks
end

function HeliHeal:ApplyPaladinArmamentPresentation(ability)
    if not ability or ability.abilityKey ~= "paladin_holy_armament" then return end
    local sacred = self.paladinNextArmamentType == "sacred"
    local spellID = sacred and 432472 or 432459
    local fallbackName = sacred and "Sacred Weapon" or "Holy Bulwark"
    self.paladinArmamentPresentation = self.paladinArmamentPresentation or {}
    local presentation = self.paladinArmamentPresentation[spellID]
    if not presentation then
        presentation = { name = fallbackName }
        if C_Spell and type(C_Spell.GetSpellInfo) == "function" then
            local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
            if ok and type(info) == "table" then
                presentation.name = info.name or presentation.name
                presentation.icon = info.iconID
            end
        end
        self.paladinArmamentPresentation[spellID] = presentation
    end
    ability.spellID = spellID
    ability.name = presentation.name
    if presentation.icon then ability.icon = presentation.icon end
end

function HeliHeal:GetSlot(slotIndex)
    slotIndex = tonumber(slotIndex) or 0
    local slot = self.db.profile.slots[slotIndex]
    if not slot then
        return nil
    end
    self.resolvedSlotCache = self.resolvedSlotCache or {}
    local cached = self.resolvedSlotCache[slotIndex]
    if not cached or cached.slot ~= slot then
        local resolved = ns.AbilityLibrary:Resolve(slot)
        cached = {
            slot = slot,
            ability = resolved,
            baseEnabled = resolved.enabled,
            baseCooldown = resolved.cooldown,
            baseMaxCharges = resolved.maxCharges,
            baseTrackedDuration = resolved.trackedDuration,
            baseSpellID = resolved.spellID,
            baseName = resolved.name,
            baseIcon = resolved.icon,
        }
        self.resolvedSlotCache[slotIndex] = cached
    end
    local ability = cached.ability
    ability.enabled = cached.baseEnabled
    ability.cooldown = cached.baseCooldown
    ability.maxCharges = cached.baseMaxCharges
    ability.trackedDuration = cached.baseTrackedDuration
    ability.spellID = cached.baseSpellID
    ability.name = cached.baseName
    ability.icon = cached.baseIcon
    self:ApplyPaladinArmamentPresentation(ability)
    if ability.abilityKey == "riptide" and self.GetRiptideMaxCharges then
        ability.maxCharges = self:GetRiptideMaxCharges(ability.maxCharges)
    elseif ability.abilityKey == "downpour" and self.talentSnapshot and self.talentSnapshot.available then
        ability.enabled = ability.enabled and self:IsTalentActive("downpour")
    elseif ability.abilityKey == "unleash_life" and self.talentSnapshot and self.talentSnapshot.available then
        ability.enabled = ability.enabled and self:IsTalentActive("unleashLife")
        if self:IsTalentActive("restorationTier2") then ability.cooldown = 17 end
    end
    local talentSnapshotAvailable = self.talentSnapshot and self.talentSnapshot.available
    if ability.requiresTalent then
        -- A reload can occur while the trait API is unavailable in combat. In
        -- that state, hiding optional/replacement abilities is safer than
        -- exposing every mutually exclusive talent from the union slot list.
        ability.enabled = ability.enabled and talentSnapshotAvailable
            and self:IsTalentActive(ability.requiresTalent)
    end
    if talentSnapshotAvailable then
        if ability.excludesTalent and self:IsTalentActive(ability.excludesTalent) then
            ability.enabled = false
        end
        if ability.cooldownTalent and self:IsTalentActive(ability.cooldownTalent) then
            ability.cooldown = math.max(0, ability.cooldown - ability.cooldownReduction)
        end
        if ability.cooldownRankTalent then
            local rank = self.GetTalentRank and self:GetTalentRank(ability.cooldownRankTalent) or 0
            ability.cooldown = math.max(0, ability.cooldown - (rank * ability.cooldownReductionPerRank))
        end
        if ability.cooldownMultiplierTalent and self:IsTalentActive(ability.cooldownMultiplierTalent) then
            ability.cooldown = math.max(0, ability.cooldown * ability.cooldownMultiplier)
        end
        if ability.cooldownPercentTalents then
            local reductionPercent = 0
            for talentKey, percent in pairs(ability.cooldownPercentTalents) do
                if self:IsTalentActive(talentKey) then
                    reductionPercent = reductionPercent + math.max(0, tonumber(percent) or 0)
                end
            end
            ability.cooldown = math.max(0, ability.cooldown * (1 - math.min(100, reductionPercent) / 100))
        end
        if ability.bonusChargeTalent and self:IsTalentActive(ability.bonusChargeTalent) then
            ability.maxCharges = ability.maxCharges + 1
        end
        if ability.abilityKey == "druid_rejuvenation" then
            -- Rejuvenation is 12 sec baseline. Germination's second copy uses
            -- the 14-sec variant, while Lingering Healing adds another 3 sec.
            if self:IsTalentActive("druidGermination") then
                ability.trackedDuration = ability.trackedDuration + 2
            end
            if self:IsTalentActive("druidLingeringHealing") then
                ability.trackedDuration = ability.trackedDuration + 3
            end
        end
        if self.classToken == "PRIEST" and self:IsTalentActive("priestProphetInsight")
            and (ability.abilityKey == "priest_holy_word_serenity"
                or ability.abilityKey == "priest_holy_word_sanctify"
                or ability.abilityKey == "priest_holy_word_chastise") then
            ability.cooldown = math.max(0, ability.cooldown - 5)
        end
    end
    if ability.hastedCooldown and ability.cooldown > 0 then
        local haste = math.max(0, tonumber(self.cachedSpellHaste) or 0)
        ability.cooldown = math.floor(((ability.cooldown / (1 + haste / 100)) * 100) + 0.5) / 100
    end
    return ability
end

function HeliHeal:RefreshSpellHasteSnapshot(silent)
    if type(UnitSpellHaste) ~= "function" then return false end
    if InCombatLockdown and InCombatLockdown() then return false end
    local ok, haste = pcall(function()
        local value = tonumber(UnitSpellHaste("player"))
        if not value or value < 0 or value > 500 then return nil end
        return value
    end)
    if not ok or haste == nil then return false end
    local changed = math.abs((self.cachedSpellHaste or -1) - haste) > 0.001
    self.cachedSpellHaste = haste
    if changed then
        self:RefreshDisplay()
        if self.RefreshOptionsUI then self:RefreshOptionsUI() end
    end
    if not silent then self:Print(L("Gespeichertes Zaubertempo: %.1f%%", haste)) end
    return true
end

function HeliHeal:GetHolyPowerDelta(ability)
    if not ability then return 0, 0 end
    local gain = math.max(0, tonumber(ability.holyPowerGain) or 0)
    if ability.holyPowerGainTalent and self:IsTalentActive(ability.holyPowerGainTalent) then
        gain = gain + math.max(0, tonumber(ability.holyPowerTalentGain) or 0)
    end
    if (ability.abilityKey == "paladin_judgment" or ability.abilityKey == "paladin_hammer_of_wrath")
        and self:GetPaladinInfusionConsumerState() then
        gain = gain + 1
    end
    if ability.abilityKey == "paladin_hammer_of_wrath" and self:IsPaladinWingsActive() then
        -- Hammer replaces Judgment during Avenging Wrath and inherits its
        -- additional Holy Power generation.
        gain = gain + 1
    end
    return gain, math.max(0, tonumber(ability.holyPowerCost) or 0)
end

function HeliHeal:GetPaladinInfusionState(now)
    now = now or GetTime()
    local state = self.pendingPaladinInfusion
    if state == true or type(state) == "number" then
        state = {
            charges = state == true and 1 or math.max(0, math.floor(state)),
            expiresAt = now + PALADIN_INFUSION_DURATION,
        }
        self.pendingPaladinInfusion = state
    end
    if type(state) == "table"
        and ((tonumber(state.charges) or 0) <= 0 or now >= (tonumber(state.expiresAt) or 0)) then
        self.pendingPaladinInfusion = nil
        state = nil
    end

    local tracker = self.ProcTracker
    if self.classToken == "PALADIN" and tracker
        and type(tracker.GetInfusionOfLightState) == "function" then
        local active, reliable = tracker:GetInfusionOfLightState()
        if reliable then
            if active then
                if now >= (tonumber(self.paladinInfusionCDMRecheckAt) or 0) then
                    if not state then
                        state = {
                            charges = 1,
                            expiresAt = now + PALADIN_INFUSION_DURATION,
                            source = "cdm",
                        }
                        self.pendingPaladinInfusion = state
                    else
                        state.cdmObserved = true
                        state.expiresAt = math.max(tonumber(state.expiresAt) or 0,
                            now + PALADIN_INFUSION_DURATION)
                    end
                    self.paladinInfusionCDMRecheckAt = nil
                    state.lastVisibleAt = now
                    self.paladinInfusionConsumptionEvidence = nil
                end
            elseif now >= (tonumber(state and state.localEvidenceUntil) or 0) then
                -- Retain a single recent observation for success-event ordering
                -- only. It must not keep the proc eligible in the HUD.
                if state and state.lastVisibleAt and now - state.lastVisibleAt <= 0.3 then
                    self.paladinInfusionConsumptionEvidence = {
                        charges = 1, expiresAt = state.lastVisibleAt + 0.3,
                    }
                end
                self.pendingPaladinInfusion = nil
                self.paladinInfusionCDMRecheckAt = nil
                state = nil
            end
        end
    end
    return state
end

function HeliHeal:GetPaladinInfusionCharges(now)
    local state = self:GetPaladinInfusionState(now)
    return state and math.max(0, math.floor(tonumber(state.charges) or 0)) or 0
end

function HeliHeal:GetPaladinInfusionConsumerState(now)
    now = now or GetTime()
    local state = self:GetPaladinInfusionState(now)
    if state then return state end
    local evidence = self.paladinInfusionConsumptionEvidence
    if evidence and now <= evidence.expiresAt then return evidence end
    self.paladinInfusionConsumptionEvidence = nil
end

function HeliHeal:ArmPaladinInfusion(now)
    now = now or GetTime()
    local state = self:GetPaladinInfusionState(now)
    local maximum = self:IsTalentActive("paladinInflorescenceSunwell") and 2 or 1
    self.pendingPaladinInfusion = {
        charges = math.min(maximum, (state and state.charges or 0) + 1),
        expiresAt = now + PALADIN_INFUSION_DURATION,
        localEvidenceUntil = now + 0.5,
    }
    return true
end

function HeliHeal:GetPaladinInfusionConsumerPriority(abilityKey, now)
    if self.classToken ~= "PALADIN" or self:GetPaladinInfusionCharges(now) <= 0 then return nil end
    -- Healing contexts spend Infusion on Flash of Light. Mana Saving is the
    -- explicit low-pressure/damage context and may convert it through the
    -- active Judgment replacement for the extra Holy Power instead.
    if self:GetHealingMode() == "mana" then
        if abilityKey == "paladin_judgment" or abilityKey == "paladin_hammer_of_wrath" then return 1 end
        if abilityKey == "paladin_flash_of_light" then return 2 end
    else
        if abilityKey == "paladin_flash_of_light" then return 1 end
        if abilityKey == "paladin_judgment" or abilityKey == "paladin_hammer_of_wrath" then return 2 end
    end
end

function HeliHeal:ApplyPaladinInfusionEffects(abilityKey, now)
    if self.classToken ~= "PALADIN" then return false end
    if abilityKey == "paladin_holy_light" and self:IsTalentActive("paladinTier4") then
        return self:ArmPaladinInfusion(now)
    end
    local state = self:GetPaladinInfusionConsumerState(now)
    if abilityKey == "paladin_flash_of_light" or abilityKey == "paladin_judgment"
        or abilityKey == "paladin_hammer_of_wrath" then
        self:RecordArmamentDiagnostic("infusion-consumer", nil, now,
            abilityKey .. " infusion=" .. tostring(state and state.charges or 0))
    end
    if state
        and (abilityKey == "paladin_flash_of_light" or abilityKey == "paladin_judgment"
            or abilityKey == "paladin_hammer_of_wrath") then
        self.paladinInfusionConsumptionEvidence = nil
        state.charges = state.charges - 1
        if state.charges <= 0 then
            self.pendingPaladinInfusion = nil
            -- CDM exposes presence, not stacks. Give Blizzard one short aura
            -- update window before treating continued visibility as another
            -- Infusion charge.
            self.paladinInfusionCDMRecheckAt = (now or GetTime()) + 0.2
        end
        if self:IsTalentActive("paladinImbuedInfusions") then
            self:ReduceLocalAbilityCooldown("paladin_holy_shock", 1, now)
        end
        if self:IsTalentActive("paladinValiance") then
            -- Valiance advances the shared Holy Armaments recharge whenever
            -- an Infusion charge is consumed. Active Bulwark/Sacred Weapon
            -- effect durations are unrelated and must never absorb this CDR.
            self:ReduceLocalAbilityCooldown("paladin_holy_armament", 3, now)
        end
        return true
    end
    return false
end

function HeliHeal:IsPaladinWingsActive(now)
    if self.classToken ~= "PALADIN" then return false end
    now = now or GetTime()
    if self.paladinWingsUntil and now >= self.paladinWingsUntil then
        self.paladinWingsUntil = nil
    end
    return self.paladinWingsUntil ~= nil
end

function HeliHeal:IsPaladinCrusaderActive(now)
    if self.classToken ~= "PALADIN" then return false end
    now = now or GetTime()
    if self.paladinCrusaderUntil and now >= self.paladinCrusaderUntil then
        self.paladinCrusaderUntil = nil
    end
    return self.paladinCrusaderUntil ~= nil
end

function HeliHeal:IsPaladinVirtueActive(now)
    if self.classToken ~= "PALADIN" then return false end
    now = now or GetTime()
    if self.paladinVirtueUntil and now >= self.paladinVirtueUntil then
        self.paladinVirtueUntil = nil
    end
    return self.paladinVirtueUntil ~= nil
end

function HeliHeal:IsPaladinRaidVirtueContext()
    if self.classToken ~= "PALADIN" or self:GetHealingMode() ~= "aoe"
        or not self:IsTalentActive("paladinBeaconVirtue") then
        return false
    end
    local preset = ns.AbilityLibrary:GetPreset(self.db.profile.rotationPreset)
    return preset and preset.content == "Raid" or false
end

function HeliHeal:GetPaladinVirtueSetupPriority(abilityKey, now)
    if not self:IsPaladinRaidVirtueContext() or self:IsPaladinVirtueActive(now) then return nil end
    return abilityKey == "paladin_beacon_of_virtue" and 1 or nil
end

function HeliHeal:GetPaladinVirtueWindowPriority(abilityKey, now)
    if not self:IsPaladinRaidVirtueContext() or not self:IsPaladinVirtueActive(now) then return nil end
    if abilityKey == "paladin_divine_toll" then return 1 end
    if abilityKey == "paladin_aura_mastery" and self:IsTalentActive("paladinRingingHeavens") then return 2 end
end

function HeliHeal:GetPaladinHolyLightTalentSummary()
    if self.classToken ~= "PALADIN" then return nil end
    local parts = {}
    if self:IsTalentActive("paladinDivineFavor") then
        parts[#parts + 1] = L("Favor: -10% Mana/-15% Cast")
    end
    if self:IsTalentActive("paladinDivineOverload") then
        parts[#parts + 1] = L("Overload: +30% Heilung/+20% Mana")
    end
    return #parts > 0 and table.concat(parts, " • ") or nil
end

function HeliHeal:ArmPaladinDivineResonance(now)
    if self.classToken ~= "PALADIN" or not self:IsTalentActive("paladinDivineResonance") then
        return false
    end
    now = now or GetTime()
    self.paladinDivineResonance = {
        nextTickAt = now + PALADIN_DIVINE_RESONANCE_TICK,
        ticksRemaining = PALADIN_DIVINE_RESONANCE_TICKS,
    }
    return true
end

function HeliHeal:GetPaladinDivineResonanceState(now)
    local state = self.paladinDivineResonance
    if type(state) ~= "table" then return nil end
    now = now or GetTime()
    while state.ticksRemaining > 0 and now >= state.nextTickAt do
        state.ticksRemaining = state.ticksRemaining - 1
        state.nextTickAt = state.nextTickAt + PALADIN_DIVINE_RESONANCE_TICK
    end
    if state.ticksRemaining <= 0 then
        self.paladinDivineResonance = nil
        return nil
    end
    return state
end

function HeliHeal:IsPaladinDivineResonanceOvercapImminent(now)
    if (self.sessionHolyPower or 0) < 4 then return false end
    local state = self:GetPaladinDivineResonanceState(now)
    return state and state.nextTickAt - (now or GetTime()) <= 1.5 or false
end

function HeliHeal:GetPaladinMajorCooldownDuration(abilityKey)
    local base = abilityKey == "paladin_avenging_crusader"
        and PALADIN_CRUSADER_DURATION or PALADIN_WINGS_DURATION
    local rank = self.GetTalentRank and self:GetTalentRank("paladinCallOfRighteous") or 0
    local reduction = abilityKey == "paladin_avenging_crusader" and 2 or 3
    local duration = math.max(1, base - (math.max(0, rank) * reduction))
    if self:IsTalentActive("paladinSanctifiedWrath") then duration = duration * 1.5 end
    return duration
end

function HeliHeal:GetPaladinHandOfDivinityState(now)
    local state = self.pendingPaladinHandOfDivinity
    if not state then return nil end
    now = now or GetTime()
    if state.uses <= 0 or now >= state.expiresAt then
        self.pendingPaladinHandOfDivinity = nil
        return nil
    end
    return state
end

function HeliHeal:GetPaladinHandOfDivinityPriority(abilityKey, now)
    if abilityKey ~= "paladin_holy_light" or not self:GetPaladinHandOfDivinityState(now) then return nil end
    return 1
end

function HeliHeal:ReducePaladinJudgmentCooldown(seconds, now)
    if self.classToken ~= "PALADIN" then return false end
    local slotIndex = self:GetSlotIndexByAbilityKey("paladin_judgment")
    local ability = slotIndex and self:GetSlot(slotIndex)
    local usedAt = slotIndex and self.sessionUses[slotIndex]
    if not ability or not usedAt then return false end
    now = now or GetTime()
    self.sessionUses[slotIndex] = usedAt - math.max(0, tonumber(seconds) or 0)
    if now >= self.sessionUses[slotIndex] + ability.cooldown then
        self.sessionUses[slotIndex] = nil
    end
    return true
end

function HeliHeal:ApplyPaladinCooldownEffects(abilityKey, now)
    if self.classToken ~= "PALADIN" then return false end
    local changed = false
    if abilityKey == "paladin_shield_of_the_righteous" then
        changed = self:ReduceLocalAbilityCooldown("paladin_holy_shock", 2, now) or changed
    end
    if self:IsTalentActive("paladinCrusadersMight")
        and (abilityKey == "paladin_holy_shock" or abilityKey == "paladin_crusader_strike") then
        changed = self:ReducePaladinJudgmentCooldown(1.5, now) or changed
    end
    return changed
end

function HeliHeal:TrackPaladinArmament(observedSpellID, now)
    if self.classToken ~= "PALADIN" then return false end
    now = now or GetTime()
    local armamentType
    if tonumber(observedSpellID) == 432459 then
        armamentType = "bulwark"
    elseif tonumber(observedSpellID) == 432472 then
        armamentType = "sacred"
    else
        armamentType = self.paladinNextArmamentType or "bulwark"
    end
    self.paladinNextArmamentType = armamentType == "bulwark" and "sacred" or "bulwark"
    if not self:IsTalentActive("paladinLayingDownArms")
        or not self:IsTalentActive("paladinSolidarity") then
        return true
    end
    self.paladinArmamentExpirations = self.paladinArmamentExpirations or {}
    local previousExpiration = tonumber(self.paladinArmamentExpirations[armamentType]) or now
    -- Midnight 12.1 extends a same-caster Armament when it is reapplied.
    self.paladinArmamentExpirations[armamentType] = math.max(now, previousExpiration)
        + PALADIN_ARMAMENT_DURATION
    return true
end

function HeliHeal:ProcessPaladinArmamentExpirations(now)
    if self.classToken ~= "PALADIN" then return false end
    now = now or GetTime()
    local expirations = self.paladinArmamentExpirations
    if not expirations then return false end
    local changed = false
    for armamentType, expiresAt in pairs(expirations) do
        if now >= expiresAt then
            expirations[armamentType] = nil
            if self:IsTalentActive("paladinLayingDownArms") then
                self:ReduceLocalAbilityCooldown("paladin_lay_on_hands", 15, now)
                self:ArmPaladinInfusion(now)
            end
            changed = true
        end
    end
    return changed
end

function HeliHeal:ApplyPaladinCastEffects(abilityKey, now, observedSpellID)
    local changed = self:ApplyPaladinInfusionEffects(abilityKey, now)
    changed = self:ApplyPaladinCooldownEffects(abilityKey, now) or changed
    if self.classToken ~= "PALADIN" then return changed end
    now = now or GetTime()
    if abilityKey == "paladin_holy_light" then
        local hand = self:GetPaladinHandOfDivinityState(now)
        if hand then
            hand.uses = hand.uses - 1
            if hand.uses <= 0 then self.pendingPaladinHandOfDivinity = nil end
            changed = true
        end
    elseif abilityKey == "paladin_divine_toll" or abilityKey == "paladin_holy_prism" then
        changed = self:ArmPaladinDivineResonance(now) or changed
    elseif abilityKey == "paladin_avenging_wrath" then
        self.paladinWingsUntil = now + self:GetPaladinMajorCooldownDuration(abilityKey)
        self.paladinCrusaderUntil = nil
        if self:IsTalentActive("paladinHandOfDivinity") then
            self.pendingPaladinHandOfDivinity = {
                uses = 2,
                expiresAt = now + PALADIN_HAND_OF_DIVINITY_DURATION,
            }
        end
        changed = true
    elseif abilityKey == "paladin_avenging_crusader" then
        self.paladinCrusaderUntil = now + self:GetPaladinMajorCooldownDuration(abilityKey)
        self.paladinWingsUntil = nil
        if self:IsTalentActive("paladinHandOfDivinity") then
            self.pendingPaladinHandOfDivinity = {
                uses = 1,
                expiresAt = now + PALADIN_HAND_OF_DIVINITY_DURATION,
            }
        end
        changed = true
    elseif abilityKey == "paladin_beacon_of_virtue" then
        self.paladinVirtueUntil = now + PALADIN_VIRTUE_DURATION
        changed = true
    elseif abilityKey == "paladin_holy_armament" then
        changed = self:ArmPaladinDivineResonance(now) or changed
        changed = self:TrackPaladinArmament(observedSpellID, now) or changed
    elseif abilityKey == "paladin_aura_mastery" and self:IsTalentActive("paladinRingingHeavens") then
        changed = self:ArmPaladinDivineResonance(now) or changed
    end
    return changed
end

function HeliHeal:RecalculateHolyPower()
    local value = math.max(0, math.min(5, tonumber(self.holyPowerBaseline) or 0))
    local freeSpenders = math.max(0, math.min(1, tonumber(self.holyPowerFreeSpenderBaseline) or 0))
    for _, event in ipairs(self.holyPowerEvents or {}) do
        local cost = event.cost
        if cost > 0 and (freeSpenders > 0 or event.forcedFree) then
            cost = 0
            if freeSpenders > 0 then freeSpenders = freeSpenders - 1 end
        end
        value = math.max(0, math.min(5, value - cost + event.gain))
        if event.grantsFreeSpender then freeSpenders = math.min(1, freeSpenders + 1) end
    end
    self.sessionHolyPower = value
    self.pendingFreeHolyPowerSpenders = freeSpenders
    return value
end

function HeliHeal:ApplyAuthoritativeHolyPower(value)
    value = tonumber(value)
    if not value or value < 0 or value > 5 then return false end
    value = math.floor(value)
    local changed = value ~= (self.sessionHolyPower or 0)
    self.holyPowerBaseline = value
    self.holyPowerFreeSpenderBaseline = self.pendingFreeHolyPowerSpenders or 0
    self.holyPowerEvents = {}
    self.nextHolyPowerEventID = 0
    self:RecalculateHolyPower()
    if changed then self:RefreshDisplay() end
    return true
end

function HeliHeal:RecordHolyPowerEvent(slotIndex, ability)
    local gain, cost = self:GetHolyPowerDelta(ability)
    if gain <= 0 and cost <= 0 then return false end
    local grantsFreeSpender = ability.grantsFreeSpenderTalent
        and self:IsTalentActive(ability.grantsFreeSpenderTalent) or false
    if grantsFreeSpender and ability.grantsFreeSpenderRequiredTalent then
        grantsFreeSpender = self:IsTalentActive(ability.grantsFreeSpenderRequiredTalent)
    end
    self.nextHolyPowerEventID = (self.nextHolyPowerEventID or 0) + 1
    self.holyPowerEvents = self.holyPowerEvents or {}
    self.holyPowerEvents[#self.holyPowerEvents + 1] = {
        id = self.nextHolyPowerEventID,
        slotIndex = slotIndex,
        abilityKey = ability.abilityKey,
        gain = gain,
        cost = cost,
        forcedFree = cost > (self.sessionHolyPower or 0)
            and (self.pendingFreeHolyPowerSpenders or 0) <= 0,
        grantsFreeSpender = grantsFreeSpender,
    }
    self:RecalculateHolyPower()
    return true
end

function HeliHeal:RemoveLatestHolyPowerEvent(slotIndex)
    for index = #(self.holyPowerEvents or {}), 1, -1 do
        if self.holyPowerEvents[index].slotIndex == slotIndex then
            table.remove(self.holyPowerEvents, index)
            self:RecalculateHolyPower()
            return true
        end
    end
    return false
end

function HeliHeal:SetHolyPowerEstimate(value, silent)
    value = tonumber(value)
    if not value or value < 0 or value > 5 or value % 1 ~= 0 then return false end
    self.holyPowerBaseline = value
    self.holyPowerFreeSpenderBaseline = 0
    self.holyPowerEvents = {}
    self.nextHolyPowerEventID = 0
    self:RecalculateHolyPower()
    self:RefreshDisplay()
    if not silent then self:Print(L("Lokale Holy-Power-Schätzung: %d/5", value)) end
    return true
end

function HeliHeal:GetTrackedGoal(ability)
    if not ability then return 0 end
    if ability.abilityKey == "druid_rejuvenation" then
        local preset = ns.AbilityLibrary:GetPreset(self.db.profile.rotationPreset)
        local goals = preset and preset.rejuvenationGoals
        return math.max(1, tonumber(goals and goals[self:GetHealingMode()]) or 1)
    end
    return math.max(0, tonumber(ability.trackedGoal) or 0)
end

function HeliHeal:GetMonkRenewingMistGoal()
    local preset = ns.AbilityLibrary:GetPreset(self.db.profile.rotationPreset)
    local goals = preset and preset.renewingMistGoals
    return math.max(1, tonumber(goals and goals[self:GetHealingMode()]) or 1)
end

function HeliHeal:GetMonkSheilunCloudInterval()
    return self:IsTalentActive("monkVeilOfPride") and 4 or 8
end

function HeliHeal:GetMonkSheilunCloudGoal()
    local mode = self:GetHealingMode()
    -- Sheilun is an emergency/ramp heal, not a maintenance button. Lower
    -- thresholds belong to the explicit damage-response modes; the neutral
    -- list banks a meaningful cast instead of pushing Sheilun every 16-32 sec.
    if mode == "aoe" then return 5 end
    if mode == "single" then return 3 end
    if mode == "mana" then return 10 end
    return 6
end

function HeliHeal:GetMonkSheilunCloudState(now)
    now = now or GetTime()
    local clouds = math.max(0, math.min(10, tonumber(self.monkSheilunClouds) or 0))
    if self.monkSheilunCombatStartedAt then
        local generated = math.floor(math.max(0, now - self.monkSheilunCombatStartedAt)
            / self:GetMonkSheilunCloudInterval())
        clouds = math.min(10, clouds + generated)
    elseif self.monkSheilunLeftCombatAt and now - self.monkSheilunLeftCombatAt >= 60 then
        clouds = 0
    end
    self.monkSheilunCloudStateCache = self.monkSheilunCloudStateCache or {}
    local state = self.monkSheilunCloudStateCache
    state.count = clouds
    state.goal = self:GetMonkSheilunCloudGoal()
    return state
end

function HeliHeal:BeginMonkCombat(now)
    if self.classToken ~= "MONK" or self.monkSheilunCombatStartedAt then return false end
    now = now or GetTime()
    local state = self:GetMonkSheilunCloudState(now)
    self.monkSheilunClouds = state.count
    self.monkSheilunCombatStartedAt = now
    self.monkSheilunLeftCombatAt = nil
    return true
end

function HeliHeal:EndMonkCombat(now)
    if self.classToken ~= "MONK" then return false end
    now = now or GetTime()
    local state = self:GetMonkSheilunCloudState(now)
    self.monkSheilunClouds = state.count
    self.monkSheilunCombatStartedAt = nil
    self.monkSheilunLeftCombatAt = now
    return true
end

function HeliHeal:ConsumeMonkSheilunClouds(now)
    now = now or GetTime()
    self.monkSheilunClouds = 0
    if self.monkSheilunCombatStartedAt then self.monkSheilunCombatStartedAt = now end
    return true
end

function HeliHeal:GetMonkRenewingMistState(now)
    now = now or GetTime()
    local entries = self.sessionMonkRenewingMists or {}
    self.sessionMonkRenewingMists = entries
    local writeIndex = 1
    for readIndex = 1, #entries do
        local entry = entries[readIndex]
        if entry.expiresAt > now then
            entries[writeIndex] = entry
            writeIndex = writeIndex + 1
        end
    end
    for index = #entries, writeIndex, -1 do entries[index] = nil end
    table.sort(entries, function(a, b) return a.expiresAt < b.expiresAt end)
    self.monkRenewingMistStateCache = self.monkRenewingMistStateCache or {}
    local state = self.monkRenewingMistStateCache
    state.count = #entries
    state.goal = self:GetMonkRenewingMistGoal()
    state.nextExpiresAt = entries[1] and entries[1].expiresAt or nil
    state.nextStartedAt = entries[1] and entries[1].startedAt or nil
    return state
end

function HeliHeal:AddMonkRenewingMist(duration, now)
    now = now or GetTime()
    duration = math.max(1, tonumber(duration) or 20)
    self:GetMonkRenewingMistState(now)
    local capacity = ns.AbilityLibrary:GetPreset(self.db.profile.rotationPreset)
    capacity = capacity and capacity.content == "Raid" and 20 or 5
    if #self.sessionMonkRenewingMists >= capacity then return false end
    self.sessionMonkRenewingMists[#self.sessionMonkRenewingMists + 1] = {
        startedAt = now,
        expiresAt = now + duration,
        maxExpiresAt = now + (duration * 2),
    }
    table.sort(self.sessionMonkRenewingMists, function(a, b) return a.expiresAt < b.expiresAt end)
    return true
end

function HeliHeal:ExtendMonkRenewingMists(seconds, now)
    now = now or GetTime()
    self:GetMonkRenewingMistState(now)
    local changed = false
    for _, entry in ipairs(self.sessionMonkRenewingMists) do
        local extended = math.min(entry.maxExpiresAt, entry.expiresAt + seconds)
        if extended > entry.expiresAt then
            entry.expiresAt = extended
            changed = true
        end
    end
    table.sort(self.sessionMonkRenewingMists, function(a, b) return a.expiresAt < b.expiresAt end)
    return changed
end

function HeliHeal:GetAtonementState(now)
    now = now or GetTime()
    self.sessionAtonements = self.sessionAtonements or {}
    local state = self.sessionAtonements
    if (state.groupUntil or 0) <= now then
        state.groupStartedAt, state.groupUntil = nil, nil
    end
    if (state.singleUntil or 0) <= now then
        state.singleStartedAt, state.singleUntil = nil, nil
    end
    return state
end

function HeliHeal:RecordAtonement(scope, duration, now)
    if scope ~= "group" and scope ~= "single" then return false end
    duration = math.max(0, tonumber(duration) or 0)
    if duration <= 0 then return false end
    now = now or GetTime()
    local state = self:GetAtonementState(now)
    state[scope .. "StartedAt"] = now
    state[scope .. "Until"] = now + duration
    return true
end

function HeliHeal:GetAtonementWindow(ability, now)
    if not ability or not ability.atonementScope then return nil end
    now = now or GetTime()
    local state = self:GetAtonementState(now)
    if ability.atonementScope == "group" then
        if not state.groupUntil then return nil end
        return state.groupUntil, state.groupStartedAt, state.groupUntil - state.groupStartedAt
    end
    if self:GetHealingMode() ~= "single" then return nil end
    local useGroup = (state.groupUntil or 0) >= (state.singleUntil or 0)
    local prefix = useGroup and "group" or "single"
    local untilAt = state[prefix .. "Until"]
    local startedAt = state[prefix .. "StartedAt"]
    if not untilAt or not startedAt then return nil end
    return untilAt, startedAt, untilAt - startedAt
end

function HeliHeal:GetTrackedCapacity(ability)
    if ability.abilityKey ~= "druid_rejuvenation" then
        return math.max(1, self:GetTrackedGoal(ability))
    end
    local preset = ns.AbilityLibrary:GetPreset(self.db.profile.rotationPreset)
    local groupSize = preset and preset.content == "Raid" and 20 or 5
    return groupSize * (self:IsTalentActive("druidGermination") and 2 or 1)
end

function HeliHeal:HasLocalDruidHot(now)
    now = now or GetTime()
    -- Swiftmend accepts only Rejuvenation, Regrowth or Wild Growth. Lifebloom
    -- is deliberately excluded even though HeliHeal tracks its maintenance.
    local rejuvenationIndex = self:GetSlotIndexByAbilityKey("druid_rejuvenation")
    local rejuvenation = rejuvenationIndex and self:GetSlot(rejuvenationIndex)
    local rejuvenationState = rejuvenation and self:GetTrackedState(rejuvenation, now)
    if rejuvenationState and rejuvenationState.count > 0 then return true end

    local regrowthIndex = self:GetSlotIndexByAbilityKey("druid_regrowth")
    local regrowthUsedAt = regrowthIndex and self.sessionUses[regrowthIndex]
    if regrowthUsedAt and now < regrowthUsedAt + 12 then return true end

    local wildGrowthIndex = self:GetSlotIndexByAbilityKey("druid_wild_growth")
    local wildGrowthUsedAt = wildGrowthIndex and self.sessionUses[wildGrowthIndex]
    if wildGrowthUsedAt and now < wildGrowthUsedAt + 7 then return true end
    return false
end

function HeliHeal:ExtendLocalDruidHots(seconds, now)
    seconds = math.max(0, tonumber(seconds) or 0)
    if seconds <= 0 then return false end
    now = now or GetTime()
    local changed = false
    for _, abilityKey in ipairs({ "druid_rejuvenation", "druid_lifebloom" }) do
        local slotIndex = self:GetSlotIndexByAbilityKey(abilityKey)
        local ability = slotIndex and self:GetSlot(slotIndex)
        if ability then self:GetTrackedState(ability, now) end
        local entries = self.sessionTimedEffects and self.sessionTimedEffects[abilityKey]
        for index = 1, #(entries or {}) do
            entries[index] = entries[index] + seconds
            changed = true
        end
    end
    return changed
end

function HeliHeal:GetTrackedState(ability, now)
    if not ability or ability.trackedDuration <= 0 then return nil end
    now = now or GetTime()
    self.sessionTimedEffects = self.sessionTimedEffects or {}
    local entries = self.sessionTimedEffects[ability.abilityKey]
    if not entries then
        entries = {}
        self.sessionTimedEffects[ability.abilityKey] = entries
    end
    local writeIndex = 1
    for readIndex = 1, #entries do
        local expiresAt = entries[readIndex]
        if expiresAt > now then
            entries[writeIndex] = expiresAt
            writeIndex = writeIndex + 1
        end
    end
    for index = #entries, writeIndex, -1 do entries[index] = nil end

    self.trackedStateCache = self.trackedStateCache or {}
    local state = self.trackedStateCache[ability.abilityKey]
    if not state then
        state = {}
        self.trackedStateCache[ability.abilityKey] = state
    end
    state.count = #entries
    state.nextExpiresAt = entries[1]
    state.goal = self:GetTrackedGoal(ability)
    return state
end

function HeliHeal:AddTrackedApplications(ability, amount, now)
    if not ability or ability.trackedDuration <= 0 then return end
    now = now or GetTime()
    local state = self:GetTrackedState(ability, now)
    local entries = self.sessionTimedEffects[ability.abilityKey]
    -- Lifebloom is maintained as one known logical slot. A repeated input is
    -- therefore a refresh. Rejuvenation cannot do this because its target is
    -- deliberately unknown and each input may represent another ally.
    if ability.abilityKey == "druid_lifebloom" then
        entries = {}
        self.sessionTimedEffects[ability.abilityKey] = entries
        state.count = 0
    end
    local capacity = self:GetTrackedCapacity(ability)
    for _ = 1, math.min(math.max(1, amount or 1), math.max(0, capacity - state.count)) do
        entries[#entries + 1] = now + ability.trackedDuration
    end
    table.sort(entries)
end

function HeliHeal:IsArchdruidReady(now)
    now = now or GetTime()
    if self.pendingArchdruid and now >= self.pendingArchdruid.expiresAt then
        self.pendingArchdruid = nil
    end
    return self.pendingArchdruid ~= nil
end

function HeliHeal:IsDruidSoulReady(now)
    now = now or GetTime()
    if self.pendingDruidSoul and now >= self.pendingDruidSoul.expiresAt then
        self.pendingDruidSoul = nil
    end
    return self.pendingDruidSoul ~= nil
end

function HeliHeal:GetSlotIndexByAbilityKey(abilityKey)
    for slotIndex, slot in ipairs(self.db.profile.slots) do
        if slot.abilityKey == abilityKey then
            return slotIndex
        end
    end
end

function HeliHeal:GetChargeState(slotIndex, ability, now)
    if not ability or ability.maxCharges <= 1 then
        return nil
    end

    now = now or GetTime()
    local state = self.sessionCharges[slotIndex]
    if not state then
        state = {
            baseCharges = ability.maxCharges,
            bonusCharges = 0,
            nextRechargeAt = nil,
        }
        self.sessionCharges[slotIndex] = state
    end

    state.baseCharges = math.min(state.baseCharges, ability.maxCharges)

    while state.nextRechargeAt and now >= state.nextRechargeAt and state.baseCharges < ability.maxCharges do
        state.baseCharges = state.baseCharges + 1
        if state.baseCharges < ability.maxCharges then
            state.nextRechargeAt = self:GetRechargeFinish(ability, state.nextRechargeAt)
        else
            state.nextRechargeAt = nil
        end
    end
    return state
end

function HeliHeal:GetRechargeFinish(ability, startedAt)
    local duration = ability.cooldown
    if self.classToken == "MONK" and self.monkJadeSerpentUntil
        and startedAt < self.monkJadeSerpentUntil
        and (ability.abilityKey == "monk_renewing_mist"
            or ability.abilityKey == "monk_thunder_focus_tea") then
        local acceleratedWindow = math.max(0, self.monkJadeSerpentUntil - startedAt)
        local acceleratedWork = acceleratedWindow * 1.75
        if acceleratedWork >= duration then return startedAt + (duration / 1.75) end
        return startedAt + acceleratedWindow + (duration - acceleratedWork)
    end
    if ability.abilityKey ~= "riptide" or not self.riptideRechargeRateUntil
        or startedAt >= self.riptideRechargeRateUntil then
        return startedAt + duration
    end

    local rate = 1.1
    local acceleratedWindow = math.max(0, self.riptideRechargeRateUntil - startedAt)
    if acceleratedWindow * rate >= duration then
        return startedAt + (duration / rate)
    end
    return startedAt + acceleratedWindow + (duration - (acceleratedWindow * rate))
end

function HeliHeal:RecordArmamentDiagnostic(kind, spellID, now, detail)
    if self.classToken ~= "PALADIN" then return end
    local index = self:GetSlotIndexByAbilityKey("paladin_holy_armament")
    local state = index and self.sessionCharges[index]
    local events = self.armamentDiagnosticEvents or {}
    self.armamentDiagnosticEvents = events
    now = now or GetTime()
    events[#events + 1] = ("t=%.3f %s spell=%s charges=%s next=%.3f %s"):format(
        now, kind, tostring(spellID or "-"), tostring(state and state.baseCharges or "uninitialized"),
        state and state.nextRechargeAt and math.max(0, state.nextRechargeAt - now) or 0,
        detail or "")
    if #events > 40 then table.remove(events, 1) end
end

function HeliHeal:ReduceLocalAbilityCooldown(abilityKey, seconds, now)
    local slotIndex = self:GetSlotIndexByAbilityKey(abilityKey)
    local ability = slotIndex and self:GetSlot(slotIndex)
    if not ability or not ability.enabled then return false end
    now = now or GetTime()
    seconds = math.max(0, tonumber(seconds) or 0)
    if ability.maxCharges > 1 then
        local state = self.sessionCharges[slotIndex]
        -- Settle completed recharges before modifying the running one. A cast
        -- event can arrive after the deadline but before the next HUD update.
        if state then state = self:GetChargeState(slotIndex, ability, now) end
        if not state or not state.nextRechargeAt then return false end
        local applied = math.min(seconds, math.max(0, state.nextRechargeAt - now))
        state.nextRechargeAt = state.nextRechargeAt - applied
        state.cooldownReductionTotal = (state.cooldownReductionTotal or 0) + applied
        state.cooldownReductionCount = (state.cooldownReductionCount or 0) + (applied > 0 and 1 or 0)
        state.lastCooldownReductionAt = now
        self:GetChargeState(slotIndex, ability, now)
        if abilityKey == "paladin_holy_armament" then
            self:RecordArmamentDiagnostic("reduction", nil, now, ("requested=%.3f applied=%.3f"):format(seconds, applied))
        end
        return true
    end
    local usedAt = self.sessionUses[slotIndex]
    if not usedAt then return false end
    self.sessionUses[slotIndex] = usedAt - seconds
    if now >= self.sessionUses[slotIndex] + ability.cooldown then self.sessionUses[slotIndex] = nil end
    return true
end

function HeliHeal:ApplyMonkJadeSerpentRecovery(now)
    if not self:IsTalentActive("monkConduit") then return false end
    now = now or GetTime()
    local previousUntil = self.monkJadeSerpentUntil or now
    local startsAt = math.max(now, previousUntil)
    local newUntil = now + 8
    local addedWindow = math.max(0, newUntil - startsAt)
    self.monkJadeSerpentUntil = math.max(previousUntil, newUntil)
    if addedWindow <= 0 then return true end
    local function accelerate(abilityKey)
        local slotIndex = self:GetSlotIndexByAbilityKey(abilityKey)
        local ability = slotIndex and self:GetSlot(slotIndex)
        if not ability or not ability.enabled then return end
        if ability.maxCharges > 1 then
            local state = self.sessionCharges[slotIndex]
            if state and state.nextRechargeAt and state.nextRechargeAt > startsAt then
                local remaining = state.nextRechargeAt - startsAt
                local acceleratedWork = addedWindow * 1.75
                state.nextRechargeAt = startsAt + (remaining <= acceleratedWork
                    and (remaining / 1.75) or (addedWindow + remaining - acceleratedWork))
            end
        else
            local usedAt = self.sessionUses[slotIndex]
            if usedAt then
                local readyAt = usedAt + ability.cooldown
                if readyAt <= startsAt then return end
                local remaining = readyAt - startsAt
                local acceleratedWork = addedWindow * 1.75
                local adjusted = remaining <= acceleratedWork and (remaining / 1.75)
                    or (addedWindow + remaining - acceleratedWork)
                self.sessionUses[slotIndex] = startsAt + adjusted - ability.cooldown
            end
        end
    end
    for _, abilityKey in ipairs({
        "monk_renewing_mist", "monk_rising_sun_kick", "monk_rushing_wind_kick",
        "monk_life_cocoon", "monk_thunder_focus_tea",
    }) do accelerate(abilityKey) end
    return true
end

function HeliHeal:IsMonkTeaReady(now)
    now = now or GetTime()
    if self.pendingMonkTea and now >= self.pendingMonkTea.expiresAt then self.pendingMonkTea = nil end
    return self.pendingMonkTea and self.pendingMonkTea.uses > 0 or false
end

function HeliHeal:GetMonkTeaConsumerPriority(abilityKey, now)
    if not self:IsMonkTeaReady(now) then return nil end
    local mode = self:GetHealingMode()
    local orders
    if mode == "single" then
        orders = {
            monk_enveloping_mist = 1,
            monk_rising_sun_kick = 2,
            monk_rushing_wind_kick = 2,
            monk_renewing_mist = 3,
        }
    else
        -- Current 12.1 raid and Mythic+ priorities use Thunder Focus Tea to
        -- empower the active Rising/Rushing Wind Kick. Enveloping Mist is a
        -- damage-response cast and must not jump into the neutral rotation.
        orders = {
            monk_rising_sun_kick = 1,
            monk_rushing_wind_kick = 1,
            monk_renewing_mist = 2,
        }
    end
    return orders[abilityKey]
end

function HeliHeal:ApplyActiveMonkRecovery(abilityKey, now)
    if not self.monkJadeSerpentUntil or now >= self.monkJadeSerpentUntil then return false end
    if abilityKey ~= "monk_rising_sun_kick" and abilityKey ~= "monk_rushing_wind_kick"
        and abilityKey ~= "monk_life_cocoon" then return false end
    local slotIndex = self:GetSlotIndexByAbilityKey(abilityKey)
    local ability = slotIndex and self:GetSlot(slotIndex)
    local usedAt = slotIndex and self.sessionUses[slotIndex]
    if not ability or not usedAt then return false end
    local remaining = math.max(0, usedAt + ability.cooldown - now)
    local window = math.max(0, self.monkJadeSerpentUntil - now)
    local acceleratedWork = window * 1.75
    local adjusted = acceleratedWork >= remaining and (remaining / 1.75)
        or (window + remaining - acceleratedWork)
    self.sessionUses[slotIndex] = now + adjusted - ability.cooldown
    return true
end

function HeliHeal:ApplyMistweaverCastEffects(abilityKey, now)
    if self.classToken ~= "MONK" then return end
    local isKick = abilityKey == "monk_rising_sun_kick" or abilityKey == "monk_rushing_wind_kick"
    if abilityKey == "monk_sheiluns_gift" then
        self:ConsumeMonkSheilunClouds(now)
    elseif abilityKey == "monk_tiger_palm" then
        self.monkTeachingsStacks = math.min(4, (self.monkTeachingsStacks or 0) + 1)
    elseif abilityKey == "monk_blackout_kick" then
        self.monkTeachingsStacks = 0
    end
    if abilityKey == "monk_thunder_focus_tea" then
        self.pendingMonkTea = {
            uses = self:IsTalentActive("monkFocusedThunder") and 2 or 1,
            expiresAt = now + 30,
        }
        if self:IsTalentActive("monkMorningBreeze") then
            self:ReduceLocalAbilityCooldown("monk_rising_sun_kick", 999, now)
            self:ReduceLocalAbilityCooldown("monk_rushing_wind_kick", 999, now)
        end
        self:ApplyMonkJadeSerpentRecovery(now)
        return
    end

    local teaReady = self:IsMonkTeaReady(now)
    local consumesTea = abilityKey == "monk_renewing_mist" or abilityKey == "monk_enveloping_mist" or isKick
    local renewingDuration = 20 + (self:IsTalentActive("monkLotusInfusion") and 2 or 0)
    if abilityKey == "monk_renewing_mist" then
        self:AddMonkRenewingMist(renewingDuration + (teaReady and 10 or 0), now)
        if self:IsTalentActive("monkPoolOfMists") then
            self:ReduceLocalAbilityCooldown("monk_rising_sun_kick", 1, now)
            self:ReduceLocalAbilityCooldown("monk_rushing_wind_kick", 1, now)
        end
    elseif (isKick or abilityKey == "monk_enveloping_mist")
        and self:IsTalentActive("monkRapidDiffusion") then
        self:AddMonkRenewingMist(6, now)
    elseif abilityKey == "monk_life_cocoon" and self:IsTalentActive("monkMistsOfLife") then
        self:AddMonkRenewingMist(renewingDuration, now)
    end

    if isKick then
        if teaReady then self:ReduceLocalAbilityCooldown(abilityKey, 9, now) end
        if self:IsTalentActive("monkPoolOfMists") then
            self:ReduceLocalAbilityCooldown("monk_renewing_mist", 1, now)
        end
        if self:IsTalentActive("monkRisingMist") then self:ExtendMonkRenewingMists(4, now) end
    end
    self:ApplyActiveMonkRecovery(abilityKey, now)
    if abilityKey == "monk_celestial_conduit" and self:IsTalentActive("monkConduit") then
        self.monkConduitHeartAt = now + 4
    end
    if consumesTea and teaReady then
        self.pendingMonkTea.uses = self.pendingMonkTea.uses - 1
        if self.pendingMonkTea.uses <= 0 then self.pendingMonkTea = nil end
    end
end

function HeliHeal:ApplyMysticKnowledge(now)
    if not self.IsTalentActive or not self:IsTalentActive("mysticKnowledge") then return end
    local slotIndex = self:GetSlotIndexByAbilityKey("riptide")
    local ability = slotIndex and self:GetSlot(slotIndex)
    if not ability then return end

    local state = self.sessionCharges[slotIndex]
    self.riptideRechargeRateUntil = now + 8
    if state and state.nextRechargeAt and state.nextRechargeAt > now then
        local remainingWork = state.nextRechargeAt - now
        state.nextRechargeAt = now + (remainingWork / 1.1)
    end
end

function HeliHeal:GrantBonusCharge(abilityKey, now)
    local slotIndex = self:GetSlotIndexByAbilityKey(abilityKey)
    local ability = slotIndex and self:GetSlot(slotIndex)
    if not ability or ability.maxBonusCharges <= 0 then
        return
    end

    local state = self:GetChargeState(slotIndex, ability, now)
    state.bonusCharges = math.min(ability.maxBonusCharges, state.bonusCharges + 1)
end

function HeliHeal:SpendCharge(slotIndex, ability, now, observedSpellID)
    local state = self:GetChargeState(slotIndex, ability, now)
    if not state then
        return false
    end

    self.sessionSpendHistory = self.sessionSpendHistory or {}
    self.sessionSpendHistory[slotIndex] = self.sessionSpendHistory[slotIndex] or {}

    -- The transformed Stormstream player cast has its own success spell ID.
    -- If the granting random proc was unreadable, consume that observed proc
    -- without touching either normal Healing Stream charge.
    local observedStormstream = ability.abilityKey == "healing_stream_combo"
        and STORMSTREAM_CAST_SPELL_IDS[tonumber(observedSpellID)] == true
    if observedStormstream then
        if state.bonusCharges > 0 then
            state.bonusCharges = state.bonusCharges - 1
            table.insert(self.sessionSpendHistory[slotIndex], "bonus")
        else
            table.insert(self.sessionSpendHistory[slotIndex], "observed_bonus")
        end
        return true
    end

    -- Without an authoritative cast ID, retain the local guaranteed-proc
    -- fallback and spend its synthetic bonus before a normal charge.
    local observedNormalHealingStream = ability.abilityKey == "healing_stream_combo"
        and observedSpellID ~= nil
    if not observedNormalHealingStream and state.bonusCharges > 0 then
        state.bonusCharges = state.bonusCharges - 1
        table.insert(self.sessionSpendHistory[slotIndex], "bonus")
        return true
    end
    if state.baseCharges <= 0 then
        if observedSpellID then
            -- Blizzard confirmed a cast our estimate considered unavailable.
            -- Its post-cast count is conservatively zero, but its effects must
            -- still run. Preserve any running recharge rather than restart it.
            if not state.nextRechargeAt and ability.cooldown > 0 then
                state.nextRechargeAt = self:GetRechargeFinish(ability, now)
            end
            table.insert(self.sessionSpendHistory[slotIndex], "confirmed_unestimated")
            return true
        end
        return false
    end

    state.baseCharges = state.baseCharges - 1
    table.insert(self.sessionSpendHistory[slotIndex], "base")
    if not state.nextRechargeAt and ability.cooldown > 0 then
        state.nextRechargeAt = self:GetRechargeFinish(ability, now)
    end
    return true
end

function HeliHeal:IsDownpourReady(now)
    local state = self.pendingDownpour
    now = now or GetTime()
    if state and now >= state.expiresAt then
        self.pendingDownpour = nil
        return false
    end
    return state and state.uses > 0 or false
end

function HeliHeal:ArmDownpour(now)
    if self.talentSnapshot and self.talentSnapshot.available and not self:IsTalentActive("downpour") then
        self.pendingDownpour = nil
        return false
    end
    local uses = self.IsTalentActive and self:IsTalentActive("doubleDip") and 2 or 1
    self.pendingDownpour = { uses = uses, maxUses = uses, expiresAt = now + 16 }
    return true
end

function HeliHeal:ConsumeDownpour(now)
    if not self:IsDownpourReady(now) then return false end
    self.pendingDownpour.uses = self.pendingDownpour.uses - 1
    if self.pendingDownpour.uses <= 0 then self.pendingDownpour = nil end
    return true
end

function HeliHeal:IsUnleashReady(now)
    local state = self.pendingUnleash
    now = now or GetTime()
    if state and now >= state.expiresAt then
        self.pendingUnleash = nil
        return false
    end
    return state and state.remaining > 0 or false
end

function HeliHeal:ArmUnleash(now)
    local uses = self.IsTalentActive and self:IsTalentActive("restorationTier4") and 2 or 1
    self.pendingUnleash = { remaining = uses, maxUses = uses, expiresAt = now + 10 }
end

function HeliHeal:ConsumeUnleash(abilityKey, now)
    if abilityKey ~= "riptide" and abilityKey ~= "chain_heal" and abilityKey ~= "healing_wave" then
        return false
    end
    if not self:IsUnleashReady(now) then return false end
    self.pendingUnleash.remaining = self.pendingUnleash.remaining - 1
    self.unleashConsumptionHistory = self.unleashConsumptionHistory or {}
    self.unleashConsumptionHistory[abilityKey] = (self.unleashConsumptionHistory[abilityKey] or 0) + 1
    if self.pendingUnleash.remaining <= 0 then self.pendingUnleash = nil end
    return true
end

function HeliHeal:GetUnleashConsumerPriority(abilityKey)
    if not self:IsUnleashReady(GetTime()) then return nil end
    local mode = self:GetHealingMode()
    local orders = {
        standard = { riptide = 1, chain_heal = 2, healing_wave = 3 },
        aoe = { chain_heal = 1, riptide = 2, healing_wave = 3 },
        single = { riptide = 1, healing_wave = 2, chain_heal = 3 },
        mana = { healing_wave = 1, riptide = 2, chain_heal = 3 },
    }
    return (orders[mode] or orders.standard)[abilityKey]
end

function HeliHeal:RestoreUnleashConsumption(abilityKey, now)
    local history = self.unleashConsumptionHistory and self.unleashConsumptionHistory[abilityKey] or 0
    if history <= 0 then return false end
    self.unleashConsumptionHistory[abilityKey] = history - 1
    local maxUses = self.IsTalentActive and self:IsTalentActive("restorationTier4") and 2 or 1
    if self:IsUnleashReady(now) then
        self.pendingUnleash.maxUses = maxUses
        self.pendingUnleash.remaining = math.min(maxUses, self.pendingUnleash.remaining + 1)
    else
        self.pendingUnleash = { remaining = 1, maxUses = maxUses, expiresAt = now + 10 }
    end
    return true
end

function HeliHeal:ArmSwiftness(slotIndex, ability, now)
    if self.pendingSwiftness then
        return false
    end

    self.pendingSwiftness = {
        slotIndex = slotIndex,
        armedAt = now,
        consumerAbilityKey = ability.preferredSwiftnessConsumer or "chain_heal",
        bonusGrantedTo = ability.grantsBonusChargeTo,
    }
    -- The One Button Assistant may report the instant consumer immediately
    -- before the off-GCD Swiftness success from the same physical action. In
    -- that narrow, explicitly correlated case the buff was already consumed
    -- in game, so begin the local cooldown at the consumer's success time.
    local recent = self.recentAssistedSwiftnessConsumer
    self.recentAssistedSwiftnessConsumer = nil
    if recent and recent.generation == (self.inputGeneration or 0)
        and now >= recent.succeededAt and now - recent.succeededAt <= 0.75 then
        self:ConsumeSwiftness(recent.succeededAt)
    end
    return true
end

function HeliHeal:IsSwiftnessConsumerSpell(spellID)
    local consumers = SWIFTNESS_CONSUMER_SPELL_IDS[self.classToken]
    return consumers and consumers[tonumber(spellID)] == true or false
end

function HeliHeal:ConsumeSwiftnessForSpell(spellID, now)
    if not self.pendingSwiftness then return false end
    if not self:IsSwiftnessConsumerSpell(spellID) then return false end
    return self:ConsumeSwiftness(now)
end

function HeliHeal:ConsumeSwiftness(now)
    local pending = self.pendingSwiftness
    if not pending then
        return false
    end

    self.sessionUses[pending.slotIndex] = now
    self.pendingSwiftness = nil
    return true
end

function HeliHeal:IsPriestApotheosisActive(now)
    now = now or GetTime()
    if self.priestApotheosisUntil and now >= self.priestApotheosisUntil then
        self.priestApotheosisUntil = nil
    end
    return self.priestApotheosisUntil ~= nil
end

function HeliHeal:GetPriestHolyWordReductionMultiplier(now)
    local multiplier = self:IsPriestApotheosisActive(now) and 3 or 1
    local naaruRank = self.GetTalentRank and self:GetTalentRank("priestLightNaaru") or 0
    return multiplier * (1 + (math.max(0, math.min(2, naaruRank)) * 0.1))
end

function HeliHeal:ReducePriestHolyWordCooldown(abilityKey, baseReduction, now)
    local slotIndex = self:GetSlotIndexByAbilityKey(abilityKey)
    local ability = slotIndex and self:GetSlot(slotIndex)
    if not ability or not ability.enabled then return false end
    now = now or GetTime()
    local reduction = math.max(0, tonumber(baseReduction) or 0)
        * self:GetPriestHolyWordReductionMultiplier(now)
    if reduction <= 0 then return false end

    if ability.maxCharges > 1 then
        local state = self:GetChargeState(slotIndex, ability, now)
        if not state.nextRechargeAt then return false end
        state.nextRechargeAt = math.max(now, state.nextRechargeAt - reduction)
        self:GetChargeState(slotIndex, ability, now)
    else
        local usedAt = self.sessionUses[slotIndex]
        if not usedAt then return false end
        self.sessionUses[slotIndex] = usedAt - reduction
        if now >= self.sessionUses[slotIndex] + ability.cooldown then
            self.sessionUses[slotIndex] = nil
        end
    end
    return true
end

function HeliHeal:ActivatePriestApotheosis(now)
    now = now or GetTime()
    local duration = self:IsTalentActive("priestEternalSanctity") and 32 or 20
    self.priestApotheosisUntil = now + duration
    for _, abilityKey in ipairs({
        "priest_holy_word_serenity", "priest_holy_word_sanctify", "priest_holy_word_chastise",
    }) do
        local slotIndex = self:GetSlotIndexByAbilityKey(abilityKey)
        local ability = slotIndex and self:GetSlot(slotIndex)
        if ability and ability.enabled then
            if ability.maxCharges > 1 then
                local state = self:GetChargeState(slotIndex, ability, now)
                state.baseCharges = math.min(ability.maxCharges, state.baseCharges + 1)
                if state.baseCharges >= ability.maxCharges then state.nextRechargeAt = nil end
            else
                self.sessionUses[slotIndex] = nil
            end
        end
    end
end

function HeliHeal:ApplyPriestHolyWordEffects(abilityKey, now)
    if self.classToken ~= "PRIEST" then return end
    if abilityKey == "priest_apotheosis" then
        self:ActivatePriestApotheosis(now)
        return
    end

    if abilityKey == "priest_flash_heal" then
        self:ReducePriestHolyWordCooldown("priest_holy_word_serenity", 6, now)
    elseif abilityKey == "priest_prayer_of_healing" then
        local target = self:IsTalentActive("priestUltimateSerenity")
            and "priest_holy_word_serenity" or "priest_holy_word_sanctify"
        self:ReducePriestHolyWordCooldown(target, 6, now)
    elseif abilityKey == "priest_prayer_of_mending" and self:IsTalentActive("priestVoiceHarmony") then
        self:ReducePriestHolyWordCooldown("priest_holy_word_serenity", 4, now)
    elseif abilityKey == "priest_halo" and self:IsTalentActive("priestVoiceHarmony") then
        local target = self:IsTalentActive("priestUltimateSerenity")
            and "priest_holy_word_serenity" or "priest_holy_word_sanctify"
        self:ReducePriestHolyWordCooldown(target, 4, now)
    elseif abilityKey == "priest_smite" then
        self:ReducePriestHolyWordCooldown("priest_holy_word_chastise", 4, now)
    end
end

function HeliHeal:AcknowledgeSlot(slotIndex, observedSpellID)
    slotIndex = tonumber(slotIndex)
    local slot = slotIndex and self:GetSlot(slotIndex)
    if not slot or not slot.enabled then
        self:Print(L("Prioritätsplatz %s ist nicht belegt.", tostring(slotIndex or "?")))
        return
    end
    if self.ResetRotationStuckCandidate then self:ResetRotationStuckCandidate() end
    if self.ClearRotationRejectionBackoff then self:ClearRotationRejectionBackoff(slotIndex) end

    local now = GetTime()
    -- Avenging Wrath replaces Judgment with Hammer of Wrath on the same
    -- action-bar binding. The shared Judgment observer accepts either cast,
    -- then commits the transformed spell to Hammer's own cooldown and Holy
    -- Power model.
    if slot.abilityKey == "paladin_judgment" and tonumber(observedSpellID) == 24275 then
        local hammerIndex = self:GetSlotIndexByAbilityKey("paladin_hammer_of_wrath")
        local hammer = hammerIndex and self:GetSlot(hammerIndex)
        if hammer and hammer.enabled then
            slotIndex, slot = hammerIndex, hammer
        end
    end
    if slot.abilityKey == "druid_swiftmend" and self:IsTalentActive("druidSoulOfTheForest") then
        self.pendingDruidSoul = { expiresAt = now + 15 }
        if self:IsTalentActive("druidPowerArchdruid") then
            self.pendingArchdruid = { expiresAt = now + 15 }
        end
    end
    if slot.abilityKey == "healing_rain" and self:IsDownpourReady(now) then
        self:ConsumeDownpour(now)
        self:RefreshDisplay()
        return
    elseif slot.abilityKey == "downpour" then
        if self:ConsumeDownpour(now) then self:RefreshDisplay() end
        return
    end
    if slot.armsSwiftness then
        if not self:ArmSwiftness(slotIndex, slot, now) then
            return
        end
        if slot.grantsBonusChargeTo then
            self:GrantBonusCharge(slot.grantsBonusChargeTo, now)
        end
        self:ApplyMysticKnowledge(now)
        self:RefreshDisplay()
        return
    end

    if slot.consumesSwiftness then
        self:ConsumeSwiftness(now)
    end

    self:RecordAtonement(slot.atonementScope, slot.atonementDuration, now)

    if (slot.trackedDuration or 0) > 0 then
        local applications = 1
        if slot.abilityKey == "druid_rejuvenation" and self:IsArchdruidReady(now) then
            applications = 3
            self.pendingArchdruid = nil
        end
        self:AddTrackedApplications(slot, applications, now)
    elseif slot.maxCharges > 1 then
        if not self:SpendCharge(slotIndex, slot, now, observedSpellID) then
            return
        end
    else
        self.sessionUses[slotIndex] = now
    end

    self:RecordHolyPowerEvent(slotIndex, slot)
    self:ApplyPaladinCastEffects(slot.abilityKey, now, observedSpellID)
    self:ApplyPriestHolyWordEffects(slot.abilityKey, now)
    self:ApplyMistweaverCastEffects(slot.abilityKey, now)

    if slot.abilityKey == "druid_tranquility" and self:IsTalentActive("druidFlourish") then
        self:ExtendLocalDruidHots(10, now)
    end
    if slot.abilityKey == "druid_rejuvenation" or slot.abilityKey == "druid_regrowth" then
        if slot.abilityKey == "druid_regrowth" and self:IsArchdruidReady(now) then
            self.pendingArchdruid = nil
        end
        self.pendingDruidSoul = nil
    end

    self:ConsumeUnleash(slot.abilityKey, now)

    if slot.abilityKey == "unleash_life" then
        self:ArmUnleash(now)
    end


    if slot.abilityKey == "healing_rain" then
        self:ArmDownpour(now)
    end

    if slot.grantsBonusChargeTo then
        self:GrantBonusCharge(slot.grantsBonusChargeTo, now)
    end
    self:RefreshDisplay()
end


function HeliHeal:RefundAbility(abilityName)
    local aliases = {
        hst = "healing_stream_combo", healingstream = "healing_stream_combo", stormstream = "healing_stream_combo",
        riptide = "riptide", springflut = "riptide",
        downpour = "downpour", regenguss = "downpour",
        rain = "healing_rain", healingrain = "healing_rain", heilregen = "healing_rain",
        swift = "natures_swiftness", swiftness = "natures_swiftness",
        healingstreamcombo = "healing_stream_combo", healingrain = "healing_rain",
        ancestral = "ancestral_swiftness", ancestralswiftness = "ancestral_swiftness",
        unleash = "unleash_life", unleashlife = "unleash_life", lebenentfesseln = "unleash_life",
        chain = "chain_heal", chainheal = "chain_heal", kettenheilung = "chain_heal",
        wave = "healing_wave", healingwave = "healing_wave", wellederheilung = "healing_wave",
        holyshock = "paladin_holy_shock", shock = "paladin_holy_shock",
        divinetoll = "paladin_divine_toll", toll = "paladin_divine_toll",
        holyprism = "paladin_holy_prism", prism = "paladin_holy_prism",
        holyarmament = "paladin_holy_armament", armament = "paladin_holy_armament",
        wordofglory = "paladin_word_of_glory", wog = "paladin_word_of_glory",
        eternalflame = "paladin_eternal_flame", flame = "paladin_eternal_flame",
        lightofdawn = "paladin_light_of_dawn", lod = "paladin_light_of_dawn",
        judgment = "paladin_judgment", hammerofwrath = "paladin_hammer_of_wrath", how = "paladin_hammer_of_wrath",
        shieldoftherighteous = "paladin_shield_of_the_righteous", sotr = "paladin_shield_of_the_righteous",
        holylight = "paladin_holy_light", flashoflight = "paladin_flash_of_light", fol = "paladin_flash_of_light",
    }
    local key = (abilityName or ""):lower():gsub("[%s_%-]", "")
    key = aliases[key] or key
    if key == "natures_swiftness" and not self:GetSlotIndexByAbilityKey(key) then
        if self:GetSlotIndexByAbilityKey("druid_natures_swiftness") then
            key = "druid_natures_swiftness"
        else
            key = "ancestral_swiftness"
        end
    end
    if key == "downpour" then
        if self.talentSnapshot and self.talentSnapshot.available and not self:IsTalentActive("downpour") then
            return false
        end
        local now = GetTime()
        local maxUses = self.IsTalentActive and self:IsTalentActive("doubleDip") and 2 or 1
        if self:IsDownpourReady(now) then
            self.pendingDownpour.maxUses = maxUses
            self.pendingDownpour.uses = math.min(maxUses, self.pendingDownpour.uses + 1)
        else
            self.pendingDownpour = { uses = 1, maxUses = maxUses, expiresAt = now + 16 }
        end
        self:RefreshDisplay()
        self:Print(L("Downpour lokal wiederhergestellt."))
        return true
    end

    local slotIndex = self:GetSlotIndexByAbilityKey(key)
    local ability = slotIndex and self:GetSlot(slotIndex)
    if not ability then return false end

    self:RemoveLatestHolyPowerEvent(slotIndex)

    local pendingTimer = self.pendingAcknowledgements and self.pendingAcknowledgements[slotIndex]
    pendingTimer = pendingTimer and (pendingTimer.timer or pendingTimer)
    if pendingTimer and type(pendingTimer.Cancel) == "function" then pendingTimer:Cancel() end
    if self.pendingAcknowledgements then self.pendingAcknowledgements[slotIndex] = nil end
    if self.inputLockedUntil then self.inputLockedUntil[slotIndex] = nil end

    if ability.maxCharges > 1 then
        local state = self:GetChargeState(slotIndex, ability, GetTime())
        self.sessionSpendHistory = self.sessionSpendHistory or {}
        local history = self.sessionSpendHistory[slotIndex] or {}
        local kind = table.remove(history)
        if kind == "bonus" then
            if state.bonusCharges >= ability.maxBonusCharges then return false end
            state.bonusCharges = math.min(ability.maxBonusCharges, state.bonusCharges + 1)
        elseif kind == "base" then
            if state.baseCharges >= ability.maxCharges then return false end
            state.baseCharges = state.baseCharges + 1
            if state.baseCharges >= ability.maxCharges then state.nextRechargeAt = nil end
        elseif kind == "observed_bonus" then
            return false
        elseif state.baseCharges < ability.maxCharges then
            state.baseCharges = math.min(ability.maxCharges, state.baseCharges + 1)
            if state.baseCharges >= ability.maxCharges then state.nextRechargeAt = nil end
        else
            return false
        end
    else
        self.sessionUses[slotIndex] = nil
        if self.pendingSwiftness and self.pendingSwiftness.slotIndex == slotIndex then
            local bonusKey = self.pendingSwiftness.bonusGrantedTo
            local bonusIndex = bonusKey and self:GetSlotIndexByAbilityKey(bonusKey)
            local bonusAbility = bonusIndex and self:GetSlot(bonusIndex)
            local bonusState = bonusAbility and self:GetChargeState(bonusIndex, bonusAbility, GetTime())
            if bonusState and bonusState.bonusCharges > 0 then
                bonusState.bonusCharges = bonusState.bonusCharges - 1
            end
            self.pendingSwiftness = nil
        end
        if key == "healing_rain" then self.pendingDownpour = nil end
        if key == "unleash_life" then self.pendingUnleash = nil end
    end
    self:RestoreUnleashConsumption(key, GetTime())
    self:RefreshDisplay()
    self:Print(L("%s lokal zurückerstattet.", ability.name or key))
    return true
end

function HeliHeal:ResetSession()
    self:ResetRuntimeState()
    self:RefreshDisplay()
    self:Print(L("Lokale Cooldown-Simulation zurückgesetzt."))
end

function HeliHeal:ResetSlots()
    self.db.profile.bindings = {}
    self.db.profile.slots = ns.AbilityLibrary:BuildPresetSlots(self.db.profile.rotationPreset, {})
    self:ResetSession()
    self:RefreshOptionsUI()
end

function HeliHeal:OpenOptions()
    self:ShowOptions()
end

function HeliHeal:HandleSlashCommand(input)
    local command, argument = (input or ""):match("^%s*(%S*)%s*(.-)%s*$")
    command = command:lower()

    if command == "used" or command == "benutzt" then
        self:AcknowledgeSlot(tonumber(argument))
    elseif command == "reset" then
        self:ResetSession()
    elseif command == "sync" then
        self:ReconcileOutOfCombatState(false)
    elseif command == "debug" or command == "diag" then
        self:PrintDiagnostics()
    elseif command == "iol" then
        self.ProcTracker:PrintStatus()
    elseif command == "cdmbuffs" then
        self.ProcTracker:PrintRegisteredBuffs()
    elseif command == "changelog" or command == "updates" then
        self:ShowChangelogHistory()
    elseif command == "refund" or command == "zurueck" then
        if not self:RefundAbility(argument) then
            self:Print(L("Unbekannte Fähigkeit. Beispiele: /hh refund hst, riptide, downpour, rain"))
        end
    elseif command == "mode" or command == "modus" then
        if argument:lower() == "next" or argument:lower() == "weiter" then
            self:CycleHealingMode()
        elseif not self:SetHealingMode(argument) then
            self:Print(L("Modi: standard, aoe, single, mana, next"))
        end
    elseif command == "hp" or command == "holypower" then
        if not self:SetHolyPowerEstimate(argument) then
            self:Print(L("Verwendung: /hh hp 0-5"))
        end
    elseif command == "mana" then
        local manaCommand, manaArgument = argument:lower():match("^(%S*)%s*(.-)%s*$")
        if manaCommand == "probe" or manaCommand == "api" then
            self:Print("[Mana Probe] " .. self.Mana:GetAPIProbeText())
        elseif manaCommand == "full" or manaCommand == "voll" then
            if self.Mana:SetManualPercent(100) then
                self:Print("[Mana] Manual baseline set to 100%.")
            else
                self:Print("[Mana] Manual calibration is only available outside combat.")
            end
        elseif manaCommand == "set" then
            if self.Mana:SetManualPercent(manaArgument) then
                self:Print(("[Mana] Manual baseline set to %s%%."):format(manaArgument))
            else
                self:Print("[Mana] Usage: /hh mana set 0-100 (outside combat)")
            end
        elseif manaCommand == "debug" then
            if manaArgument == "on" or manaArgument == "an" then
                self.db.profile.manaDebug = true
            elseif manaArgument == "off" or manaArgument == "aus" then
                self.db.profile.manaDebug = false
            else
                self.db.profile.manaDebug = not self.db.profile.manaDebug
            end
            self:Print("[Mana] Debug " .. (self.db.profile.manaDebug and "ON" or "OFF"))
        elseif manaCommand == "sync" then
            if not self.Mana:RefreshOutOfCombatSnapshot(true) then
                self:Print("[Mana] Sync is only available outside combat for Restoration Shaman.")
            else
                self:Print("[Mana] " .. self.Mana:GetStatusText())
            end
        else
            self:Print("[Mana] " .. self.Mana:GetStatusText())
        end
    elseif command == "talents" or command == "talente" then
        if argument:lower() == "refresh" or argument:lower() == "neu" then
            self:RefreshTalentSnapshot(false)
        else
            self:PrintTalentSnapshot()
        end
    elseif command == "show" then
        self.db.profile.enabled = true
        self:ApplyDisplaySettings()
    elseif command == "hide" then
        self.db.profile.enabled = false
        self:ApplyDisplaySettings()
    elseif command == "lock" then
        self.db.profile.locked = not self.db.profile.locked
        self:ApplyDisplaySettings()
        self:Print(L(self.db.profile.locked and "Anzeige gesperrt." or "Anzeige entsperrt."))
    else
        self:OpenOptions()
    end
end

function _G.HeliHeal_AcknowledgeSlot(slotIndex)
    if ns.addon then
        ns.addon:AcknowledgeSlot(slotIndex)
    end
end
