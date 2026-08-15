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

local RESTORATION_SPECIALIZATIONS = {
    SHAMAN = 264,
    DRUID = 105,
    PALADIN = 65,
}

local CURRENT_SCHEMA_VERSION = 3
local ROTATION_DATA_VERSION = 12108
local STORMSTREAM_CAST_SPELL_IDS = {
    [1267068] = true,
    [1267089] = true,
}

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

function HeliHeal:ResetInputState()
    if self.CancelPendingAcknowledgements then self:CancelPendingAcknowledgements() end
    self.inputGeneration = (self.inputGeneration or 0) + 1
    self.pendingAcknowledgements = {}
    self.recentSuccessfulSpells = {}
    self.recentDirectConfirmations = {}
    self.heldInputKeys = {}
    self.mouseHeldInputs = {}
    self.inputLockedUntil = {}
    self.lastObservedInputs = {}
end

function HeliHeal:ResetRuntimeState()
    self:ResetInputState()
    self.sessionUses = {}
    self.sessionCharges = {}
    self.sessionSpendHistory = {}
    self.sessionTimedEffects = {}
    self.holyPowerBaseline = 0
    self.holyPowerFreeSpenderBaseline = 0
    self.sessionHolyPower = 0
    self.holyPowerEvents = {}
    self.nextHolyPowerEventID = 0
    self.pendingFreeHolyPowerSpenders = 0
    self.pendingSwiftness = nil
    self.pendingDownpour = nil
    self.pendingUnleash = nil
    self.pendingArchdruid = nil
    self.unleashConsumptionHistory = {}
    self.riptideRechargeRateUntil = nil
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
    self.classToken = classToken
    self.specializationID = self:GetPlayerSpecializationID()
    self.supportedClass = RESTORATION_SPECIALIZATIONS[classToken] == self.specializationID

    local changed = previousClass ~= self.classToken
        or previousSpecialization ~= self.specializationID
        or previousSupport ~= self.supportedClass
    if changed and resetOnChange then
        self:ResetRuntimeState()
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
    self:CreateInputListener()
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
    self:ResetRuntimeState()
    if self.frame then self.frame:Hide() end
end

function HeliHeal:RefreshFromProfile()
    self:ResetRuntimeState()
    self:MigrateProfile(self.db.profile)
    self:EnsureRotationProfile()
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
    }
    local defaultPreset = defaults[self.classToken] or "shaman_totemic_mythicplus"
    local presetKey = profile.rotationPreset or defaultPreset
    local preset = ns.AbilityLibrary:GetPreset(presetKey)
    if not preset or preset.class ~= self.classToken then
        presetKey = defaultPreset
    end
    profile.rotationPreset = presetKey
    profile.slots = ns.AbilityLibrary:BuildPresetSlots(presetKey, profile.bindings)
end

function HeliHeal:SetRotationPreset(presetKey)
    local preset = ns.AbilityLibrary:GetPreset(presetKey)
    if not preset or preset.class ~= self.classToken then
        return
    end
    self.db.profile.rotationPreset = presetKey
    self.db.profile.rotationDataVersion = ROTATION_DATA_VERSION
    self.db.profile.slots = ns.AbilityLibrary:BuildPresetSlots(presetKey, self.db.profile.bindings)
    self:ResetSession()
    self:RefreshOptionsUI()
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
    for _, slot in ipairs(self.db.profile.slots or {}) do
        if slot.enabled ~= false and not slot.derivedBindingFrom and slot.inputKey and slot.inputKey ~= "" then
            local group = grouped[slot.inputKey]
            if not group then
                group = { inputKey = slot.inputKey, abilityKeys = {}, names = {} }
                grouped[slot.inputKey] = group
            end
            if not group.abilityKeys[slot.abilityKey] then
                group.abilityKeys[slot.abilityKey] = true
                local resolved = ns.AbilityLibrary:Resolve(slot)
                group.names[#group.names + 1] = resolved.name or slot.abilityKey
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
    if self.riptideRechargeRateUntil and now >= self.riptideRechargeRateUntil then
        self.riptideRechargeRateUntil = nil
    end
    if self.pendingSwiftness and self.pendingSwiftness.expiresAt and now >= self.pendingSwiftness.expiresAt then
        self.pendingSwiftness = nil
    end
    self:IsDownpourReady(now)
    if not self:IsUnleashReady(now) then self.unleashConsumptionHistory = {} end
    self:IsArchdruidReady(now)
    self:RefreshDisplay()
    if not silent then self:Print(L("Lokalen Zustand außerhalb des Kampfes abgeglichen.")) end
    return true
end

local function countEntries(value)
    local count = 0
    for _ in pairs(value or {}) do count = count + 1 end
    return count
end

function HeliHeal:BuildDiagnosticReport()
    local version = "?"
    if C_AddOns and type(C_AddOns.GetAddOnMetadata) == "function" then
        version = C_AddOns.GetAddOnMetadata("HeliHeal", "Version") or version
    elseif type(GetAddOnMetadata) == "function" then
        version = GetAddOnMetadata("HeliHeal", "Version") or version
    end
    local build = type(GetBuildInfo) == "function" and select(2, GetBuildInfo()) or "?"
    local talent = self.talentSnapshot or {}
    local conflictKeys = {}
    for _, conflict in ipairs(self:GetBindingConflicts()) do conflictKeys[#conflictKeys + 1] = conflict.inputKey end
    local bindings = {}
    for abilityKey, inputKey in pairs(self.db.profile.bindings or {}) do
        if inputKey ~= "" then bindings[#bindings + 1] = abilityKey .. "=" .. inputKey end
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
        "spellHaste=" .. tostring(self.cachedSpellHaste or "unavailable"),
        "holyPower=" .. tostring(self.sessionHolyPower or 0),
        "freeSpenders=" .. tostring(self.pendingFreeHolyPowerSpenders or 0),
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

function HeliHeal:SetHealingMode(mode, silent)
    mode = HEALING_MODE_ALIASES[(mode or ""):lower()] or mode
    if not HEALING_MODE_LABELS[mode] then
        return false
    end
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
        }
        self.resolvedSlotCache[slotIndex] = cached
    end
    local ability = cached.ability
    ability.enabled = cached.baseEnabled
    ability.cooldown = cached.baseCooldown
    ability.maxCharges = cached.baseMaxCharges
    ability.trackedDuration = cached.baseTrackedDuration
    if ability.abilityKey == "riptide" and self.GetRiptideMaxCharges then
        ability.maxCharges = self:GetRiptideMaxCharges(ability.maxCharges)
    elseif ability.abilityKey == "downpour" and self.talentSnapshot and self.talentSnapshot.available then
        ability.enabled = ability.enabled and self:IsTalentActive("downpour")
    elseif ability.abilityKey == "unleash_life" and self.talentSnapshot and self.talentSnapshot.available then
        ability.enabled = ability.enabled and self:IsTalentActive("unleashLife")
        if self:IsTalentActive("restorationTier2") then ability.cooldown = 17 end
    elseif ability.abilityKey == "druid_rejuvenation" and self:IsTalentActive("druidGermination") then
        ability.trackedDuration = 14
    end
    if self.talentSnapshot and self.talentSnapshot.available then
        if ability.requiresTalent then
            ability.enabled = ability.enabled and self:IsTalentActive(ability.requiresTalent)
        end
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
        if ability.bonusChargeTalent and self:IsTalentActive(ability.bonusChargeTalent) then
            ability.maxCharges = ability.maxCharges + 1
        end
    end
    if ability.hastedCooldown and ability.cooldown > 0 then
        local haste = math.max(0, tonumber(self.cachedSpellHaste) or 0)
        ability.cooldown = math.floor(((ability.cooldown / (1 + haste / 100)) * 100) + 0.5) / 100
    end
    return ability
end

function HeliHeal:RefreshSpellHasteSnapshot(silent)
    if self.classToken ~= "PALADIN" or type(UnitSpellHaste) ~= "function" then return false end
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
    return gain, math.max(0, tonumber(ability.holyPowerCost) or 0)
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
        grantsFreeSpender = ability.grantsFreeSpenderTalent
            and self:IsTalentActive(ability.grantsFreeSpenderTalent) or false,
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

function HeliHeal:GetTrackedCapacity(ability)
    if ability.abilityKey ~= "druid_rejuvenation" then
        return math.max(1, self:GetTrackedGoal(ability))
    end
    local preset = ns.AbilityLibrary:GetPreset(self.db.profile.rotationPreset)
    local groupSize = preset and preset.content == "Raid" and 20 or 5
    return groupSize * (self:IsTalentActive("druidGermination") and 2 or 1)
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
        expiresAt = now + 15,
    }
    return true
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

function HeliHeal:AcknowledgeSlot(slotIndex, observedSpellID)
    slotIndex = tonumber(slotIndex)
    local slot = slotIndex and self:GetSlot(slotIndex)
    if not slot or not slot.enabled then
        self:Print(L("Prioritätsplatz %s ist nicht belegt.", tostring(slotIndex or "?")))
        return
    end

    local now = GetTime()
    if slot.abilityKey == "druid_swiftmend" and self:IsTalentActive("druidPowerArchdruid") then
        self.pendingArchdruid = { expiresAt = now + 15 }
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


    if slot.abilityKey == "druid_regrowth" and self:IsArchdruidReady(now) then
        self.pendingArchdruid = nil
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
        holylight = "paladin_holy_light", flashoflight = "paladin_flash_of_light", fol = "paladin_flash_of_light",
    }
    local key = (abilityName or ""):lower():gsub("[%s_%-]", "")
    key = aliases[key] or key
    if key == "natures_swiftness" and not self:GetSlotIndexByAbilityKey(key) then
        key = "ancestral_swiftness"
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
