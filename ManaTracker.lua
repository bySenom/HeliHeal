local _, ns = ...
local HeliHeal = ns.addon
local L = ns.L or function(value, ...) return select("#", ...) > 0 and value:format(...) or value end

local Mana = {
    reliability = "UNKNOWN",
    costs = {},
    trackedSpells = {},
    spellNames = {},
}

HeliHeal.Mana = Mana

local MANA_POWER_TYPE = Enum and Enum.PowerType and Enum.PowerType.Mana or 0
local RELIABILITY_RANK = { UNKNOWN = 0, DEGRADED = 1, ESTIMATED = 2, EXACT = 3 }
local MANA_TIDE_TOTEM = 16191
local HEALING_STREAM_TOTEM = 5394
local CHAIN_HEAL = 1064
local TRIGGERED_CHAIN_HEAL_WINDOW = 1.25
local AUTO_MANA_RESUME_PERCENT = 0.50
local DEFAULT_RESTO_SHAMAN_MANA = 262500
local MANA_MODEL_VERSION = 4
-- Water Shield (52127) restores 714 mana every five seconds in the current
-- Midnight build. This deterministic periodic gain is separate from the
-- combat-dependent melee return, which the local ledger deliberately does not
-- guess without combat data.
local WATER_SHIELD_MANA_PER_TICK = 714
local WATER_SHIELD_TICK_SECONDS = 5
local WATER_SHIELD_REGEN_PER_SECOND = WATER_SHIELD_MANA_PER_TICK / WATER_SHIELD_TICK_SECONDS

local EXTRA_SHAMAN_SPELLS = {
    [77130] = "Purify Spirit",
    [16191] = "Mana Tide Totem",
    [52127] = "Water Shield",
    [974] = "Earth Shield",
    [370] = "Purge",
    [51514] = "Hex",
}

local function isCombatActive()
    if type(UnitAffectingCombat) == "function" then
        local ok, active = pcall(UnitAffectingCombat, "player")
        if ok and active then return true end
    end
    return type(InCombatLockdown) == "function" and InCombatLockdown() or false
end

local function plainNumber(value)
    if type(issecretvalue) == "function" then
        local ok, secret = pcall(issecretvalue, value)
        if not ok then return nil end
        if secret then
            if type(canaccessvalue) ~= "function" then return nil end
            local accessOK, accessible = pcall(canaccessvalue, value)
            if not accessOK or not accessible then return nil end
        end
    end
    if type(value) ~= "number" then return nil end
    local ok, valid = pcall(function() return value == value and value >= 0 end)
    return ok and valid and value or nil
end

local function formatMana(value)
    return tostring(math.floor((value or 0) + 0.5))
end

function Mana:IsSupported()
    return self.owner and self.owner.classToken == "SHAMAN"
        and self.owner.specializationID == 264
end

function Mana:Debug(message, ...)
    local profile = self.owner and self.owner.db and self.owner.db.profile
    if not profile or profile.manaDebug ~= true then return end
    if select("#", ...) > 0 then message = message:format(...) end
    self.owner:Print("[Mana] " .. message)
end

function Mana:SetReliability(state, reason)
    if not RELIABILITY_RANK[state] then state = "UNKNOWN" end
    if self.inCombat and RELIABILITY_RANK[state] > RELIABILITY_RANK[self.reliability or "UNKNOWN"] then
        return false
    end
    self.reliability = state
    self.reliabilityReason = reason
    return true
end

function Mana:ReadPlayerMaximum()
    -- The local ledger deliberately does not depend on UnitPowerMax. Preserve
    -- a previously configured/persisted maximum, otherwise use the Midnight
    -- Restoration Shaman baseline supplied by the player.
    return self.maximum and self.maximum > 0 and self.maximum or DEFAULT_RESTO_SHAMAN_MANA
end

local function describePotentialSecret(value, callOK)
    if not callOK then return "call=ERROR" end
    local valueType = type(value)
    local secret, accessible = false, true
    if type(issecretvalue) == "function" then
        local secretOK, result = pcall(issecretvalue, value)
        secret = secretOK and result == true or false
        if not secretOK then return "secret-check=ERROR" end
    end
    if secret then
        accessible = false
        if type(canaccessvalue) == "function" then
            local accessOK, result = pcall(canaccessvalue, value)
            accessible = accessOK and result == true or false
        end
    end
    local arithmeticOK = false
    if valueType == "number" and accessible then
        arithmeticOK = pcall(function() return value >= 0 end)
    end
    return ("type=%s secret=%s accessible=%s arithmetic=%s"):format(
        valueType, tostring(secret), tostring(accessible), tostring(arithmeticOK))
end

function Mana:GetAPIProbeText()
    if type(UnitPower) ~= "function" or type(UnitPowerMax) ~= "function" then
        return "UnitPower API missing"
    end
    local explicitCurrentOK, explicitCurrent = pcall(UnitPower, "player", MANA_POWER_TYPE)
    local explicitMaximumOK, explicitMaximum = pcall(UnitPowerMax, "player", MANA_POWER_TYPE)
    local defaultCurrentOK, defaultCurrent = pcall(UnitPower, "player")
    local defaultMaximumOK, defaultMaximum = pcall(UnitPowerMax, "player")
    return table.concat({
        "combat=" .. tostring(isCombatActive()),
        "explicitCurrent{" .. describePotentialSecret(explicitCurrent, explicitCurrentOK) .. "}",
        "explicitMax{" .. describePotentialSecret(explicitMaximum, explicitMaximumOK) .. "}",
        "defaultCurrent{" .. describePotentialSecret(defaultCurrent, defaultCurrentOK) .. "}",
        "defaultMax{" .. describePotentialSecret(defaultMaximum, defaultMaximumOK) .. "}",
        "failure=" .. tostring(self.lastReadFailure or "none"),
    }, "; ")
end

function Mana:ReadManaRegenRates()
    if isCombatActive() or type(GetManaRegen) ~= "function" then return nil end
    local ok, baseRegen, castingRegen = pcall(GetManaRegen)
    if not ok then return nil end
    baseRegen, castingRegen = plainNumber(baseRegen), plainNumber(castingRegen)
    return castingRegen or baseRegen, baseRegen or castingRegen
end

function Mana:RefreshRegenSnapshot()
    local combatRegen, outOfCombatRegen = self:ReadManaRegenRates()
    self.regenPerSecond = combatRegen
    self.outOfCombatRegenPerSecond = outOfCombatRegen
    return combatRegen ~= nil
end

function Mana:GetEffectiveRegenPerSecond()
    local regen = self.inCombat and self.regenPerSecond or self.outOfCombatRegenPerSecond
    regen = math.max(0, tonumber(regen) or 0)
    if regen > 0 then
        -- GetManaRegen already reflects the passive Water Shield MP5 in the
        -- live client. Adding the tooltip tick again would double-count it.
        return regen
    end
    -- If the regen snapshot is unavailable, retain the one deterministic
    -- component we know from Water Shield's tooltip.
    return math.max(0, tonumber(self.waterShieldRegenPerSecond) or 0)
end

function Mana:PersistState(force)
    local db = self.owner and self.owner.db
    if not db or not db.char or not self.localTracking or self.current == nil or self.maximum == nil then
        return false
    end
    local now = type(GetTime) == "function" and GetTime() or 0
    if not force and self.lastPersistedAt and now - self.lastPersistedAt < 1 then return false end
    local state = db.char.manaState or {}
    db.char.manaState = state
    state.current = self.current
    state.maximum = self.maximum
    state.reliability = self.reliability
    state.reason = self.reliabilityReason
    state.classToken = self.owner.classToken
    state.specializationID = self.owner.specializationID
    state.modelVersion = MANA_MODEL_VERSION
    state.savedAt = type(time) == "function" and time() or nil
    self.lastPersistedAt = now
    return true
end

function Mana:RestorePersistedState()
    local db = self.owner and self.owner.db
    local state = db and db.char and db.char.manaState
    if type(state) ~= "table" or state.classToken ~= self.owner.classToken
        or state.specializationID ~= self.owner.specializationID
        or state.modelVersion ~= MANA_MODEL_VERSION then
        return false
    end
    local current = tonumber(state.current)
    local maximum = tonumber(state.maximum)
    if not current or not maximum or maximum <= 0 or current < 0 then return false end
    self.current = math.min(current, maximum)
    self.maximum = maximum
    self.localTracking = true
    self.manualBaseline = false
    self.baselineDegraded = state.reliability == "DEGRADED"
    self.reliability = self.baselineDegraded and "DEGRADED" or "ESTIMATED"
    self.reliabilityReason = self.baselineDegraded and "persisted-degraded-estimate"
        or "persisted-local-estimate"
    self.lastUpdatedAt = GetTime()
    -- Restore the exact simulated value. Wall-clock time cannot tell whether
    -- the character spent the interval loading, offline, in combat or out of
    -- combat, so treating all of it as out-of-combat regeneration can refill
    -- the estimate incorrectly after a reload or loading screen.
    return true
end

function Mana:AssumeAutomaticFullBaseline()
    if not self:IsSupported() then return false end
    local maximum = self:ReadPlayerMaximum()
    self.maximum = maximum
    self.current = maximum
    self.localTracking = true
    self.manualBaseline = false
    self.baselineDegraded = false
    self.lastUpdatedAt = GetTime()
    self:SetReliability("ESTIMATED", "automatic-full-baseline")
    self:PersistState(true)
    return true
end

function Mana:BuildTrackedSpellSet()
    local tracked, names, staticCosts = {}, {}, {}
    local library = ns.AbilityLibrary
    for _, ability in pairs(library and library.abilities or {}) do
        if ability.class == "SHAMAN" then
            local baseSpellID = tonumber(ability.spellID)
            if baseSpellID and baseSpellID > 0 then
                tracked[baseSpellID] = baseSpellID
                names[baseSpellID] = ability.name
                if ability.manaCost ~= nil then
                    staticCosts[baseSpellID] = {
                        cost = ability.manaCost,
                        dynamic = false,
                        source = "static-12.1",
                    }
                end
                for _, alias in ipairs(ability.castSpellIDs or {}) do
                    alias = tonumber(alias)
                    if alias and alias > 0 then
                        tracked[alias] = baseSpellID
                        names[alias] = ability.name
                        if ability.manaCost ~= nil then staticCosts[alias] = staticCosts[baseSpellID] end
                    end
                end
            end
        end
    end
    for spellID, name in pairs(EXTRA_SHAMAN_SPELLS) do
        tracked[spellID] = spellID
        names[spellID] = name
    end
    self.trackedSpells = tracked
    self.spellNames = names
    self.staticCosts = staticCosts
end

function Mana:ReadSpellCost(spellID)
    if isCombatActive() or not C_Spell or type(C_Spell.GetSpellPowerCost) ~= "function" then
        return nil
    end
    local ok, powerCosts = pcall(C_Spell.GetSpellPowerCost, spellID)
    if not ok then return nil end
    if powerCosts == nil then return { cost = 0, dynamic = false, source = "spell-api" } end
    if type(powerCosts) ~= "table" then return nil end

    for _, info in ipairs(powerCosts) do
        local powerType = plainNumber(info.type) or plainNumber(info.powerType)
        if powerType == MANA_POWER_TYPE then
            local cost = plainNumber(info.cost)
            local costPercent = plainNumber(info.costPercent)
            if cost == nil and costPercent and self.maximum then
                cost = self.maximum * costPercent / 100
            end
            if cost == nil then return nil end
            local costPerSecond = plainNumber(info.costPerSec) or 0
            return {
                cost = cost,
                dynamic = info.hasRequiredAura == true or costPerSecond > 0,
                costPerSecond = costPerSecond,
                source = "spell-api",
            }
        end
    end
    return { cost = 0, dynamic = false, source = "spell-api" }
end

function Mana:RefreshCostCache()
    if not self:IsSupported() then return false end
    self:BuildTrackedSpellSet()
    local costs = {}
    for spellID, record in pairs(self.staticCosts or {}) do costs[spellID] = record end
    local apiReadable = not isCombatActive() and C_Spell
        and type(C_Spell.GetSpellPowerCost) == "function"
    if apiReadable then
        for spellID in pairs(self.trackedSpells) do
            local record = self:ReadSpellCost(spellID)
            -- Explicit 12.1 data is authoritative. The spell API is only a
            -- fallback for abilities without a maintained static mana cost.
            if record and not costs[spellID] then costs[spellID] = record end
        end
    end
    for spellID, baseSpellID in pairs(self.trackedSpells) do
        local record, baseRecord = costs[spellID], costs[baseSpellID]
        if baseRecord and (not record
            or (spellID ~= baseSpellID and record.cost == 0 and baseRecord.cost > 0)) then
            costs[spellID] = baseRecord
        end
    end
    self.costs = costs
    self.costCacheAvailable = true
    for spellID in pairs(self.trackedSpells) do
        if not costs[spellID] then
            self.costCacheAvailable = false
            break
        end
    end
    return self.costCacheAvailable
end

function Mana:SyncOutOfCombat(refreshCosts)
    if not self:IsSupported() or isCombatActive() then return false end
    if not self.localTracking or self.current == nil or self.maximum == nil then
        return self:AssumeAutomaticFullBaseline()
    end
    self:Update(type(GetTime) == "function" and GetTime() or 0)
    self:RefreshRegenSnapshot()
    self.inCombat = false
    self.localTracking = true
    self.manualBaseline = false
    self:SetReliability(self.baselineDegraded and "DEGRADED" or "ESTIMATED",
        self.baselineDegraded and "local-ledger-degraded" or "local-ledger")
    if refreshCosts ~= false then self:RefreshCostCache() end
    self:PersistState(true)
    return true
end

function Mana:RefreshOutOfCombatSnapshot(refreshCosts)
    if not self:IsSupported() then
        self.current, self.maximum, self.lastUpdatedAt = nil, nil, nil
        self.inCombat = false
        self:SetReliability("UNKNOWN", "unsupported-specialization")
        return false
    end
    if self.inCombat and not isCombatActive() then return self:EndCombat(GetTime()) end
    return self:SyncOutOfCombat(refreshCosts ~= false)
end

function Mana:BeginCombat(now)
    if self.inCombat or not self:IsSupported() then return false end
    now = now or GetTime()
    if self.current == nil or self.maximum == nil then
        self:AssumeAutomaticFullBaseline()
    end
    -- Apply all locally simulated out-of-combat regeneration before the
    -- combat clock starts. No live UnitPower read is involved.
    self:Update(now)
    self.inCombat = true
    self.combatStartMana = self.current
    self.combatStartedAt = now
    self.lastUpdatedAt = now
    self.pendingRegenDebug = 0
    self.autoModeManualOverride = false
    self.reliability = self.baselineDegraded and "DEGRADED" or "ESTIMATED"
    self.reliabilityReason = self.baselineDegraded and "manual-recalibration-required"
        or "unobservable-resto-shaman-procs"
    if self.regenPerSecond == nil or not self.costCacheAvailable then
        self:SetReliability("DEGRADED", self.regenPerSecond == nil and "regen-unavailable" or "cost-cache-incomplete")
    end
    self:Debug("Combat start: %s (%s)", formatMana(self.current), self.reliability)
    if (tonumber(self.regenPerSecond) or 0) > 0 then
        self:Debug("Regen model: %.1f/s cached total (includes Water Shield); reactive gains excluded",
            tonumber(self.regenPerSecond) or 0)
    else
        self:Debug("Regen model: %.1f/s Water Shield fallback; reactive gains excluded",
            tonumber(self.waterShieldRegenPerSecond) or 0)
    end
    return true
end

function Mana:Update(now)
    if (not self.inCombat and not self.localTracking) or self.current == nil then return self.current end
    now = now or GetTime()
    local previous = self.lastUpdatedAt or now
    local elapsed = math.max(0, now - previous)
    self.lastUpdatedAt = now
    local regen = self:GetEffectiveRegenPerSecond()
    if elapsed > 0 and regen > 0 then
        local before = self.current
        self.current = math.min(self.maximum or self.current,
            self.current + (regen * elapsed))
        self.pendingRegenDebug = (self.pendingRegenDebug or 0) + (self.current - before)
    end
    self:PersistState(false)
    return self.current
end

function Mana:FlushRegenDebug()
    local gain = self.pendingRegenDebug or 0
    self.pendingRegenDebug = 0
    if gain >= 1 then self:Debug("Passive regen: +%s", formatMana(gain)) end
end

function Mana:OnSpellSucceeded(spellID, castGUID, now)
    if not self:IsSupported() then return false end
    spellID = tonumber(spellID)
    if not spellID then return false end
    now = now or GetTime()
    if not self.inCombat and isCombatActive() then self:BeginCombat(now) end
    if not self.inCombat and not self.localTracking then return false end
    if castGUID and castGUID == self.lastCastGUID then return false end
    if castGUID then self.lastCastGUID = castGUID end

    -- Some replacement/proc actions emit multiple UNIT_SPELLCAST_SUCCEEDED
    -- events with different spell IDs and GUIDs for one physical cast. Fold
    -- every alias back to its maintained base spell so Healing Stream /
    -- Stormstream can only spend mana once per action.
    local canonicalSpellID = self.trackedSpells[spellID] or spellID
    self.recentManaSpellSuccess = self.recentManaSpellSuccess or {}
    local previousSuccess = self.recentManaSpellSuccess[canonicalSpellID]
    if previousSuccess and now - previousSuccess < 0.35 then
        self:Debug("%s: duplicate success alias ignored",
            self.spellNames[spellID] or ("Spell " .. spellID))
        return false
    end

    -- Healing Stream / Stormstream can trigger a server-side Chain Heal. It
    -- produces a normal player success event but has no separate mana cost.
    -- A real manual Chain Heal cannot complete inside the Totem's GCD window.
    local recentHealingStream = self.recentManaSpellSuccess[HEALING_STREAM_TOTEM]
    if canonicalSpellID == CHAIN_HEAL and recentHealingStream
        and now - recentHealingStream < TRIGGERED_CHAIN_HEAL_WINDOW then
        self:Debug("Chain Heal: free Totem-triggered follow-up ignored")
        return false
    end
    self.recentManaSpellSuccess[canonicalSpellID] = now

    self:Update(now)
    self:FlushRegenDebug()
    if spellID == MANA_TIDE_TOTEM then
        self:SetReliability("DEGRADED", "mana-tide-effect-unobservable")
        self:Debug("Mana Tide Totem detected; dynamic gain is not readable")
    end

    local record = self.costs[spellID]
    if not record then
        if self.trackedSpells[spellID] then
            self:SetReliability("DEGRADED", "spell-cost-missing")
            self:Debug("Spell %d: cost unavailable", spellID)
        end
        return false
    end
    if record.dynamic then self:SetReliability("DEGRADED", "dynamic-spell-cost") end
    local cost = math.max(0, record.cost or 0)
    if cost > 0 and self.current ~= nil then
        self.current = math.max(0, self.current - cost)
        self:Debug("%s: -%s (%s)", self.spellNames[spellID] or ("Spell " .. spellID),
            formatMana(cost), record.source or "unknown-source")
    end
    self:PersistState(true)
    return true
end

function Mana:AddGain(amount, source, now)
    if not self.inCombat then return false end
    amount = plainNumber(amount)
    if not amount then return false end
    self:Update(now)
    self.current = math.min(self.maximum or (self.current + amount), self.current + amount)
    self:Debug("%s: +%s", source or "Mana gain", formatMana(amount))
    self:PersistState(true)
    return true
end

function Mana:EndCombat(now)
    if not self.inCombat then return self:SyncOutOfCombat(false) end
    now = now or GetTime()
    self:Update(now)
    self:FlushRegenDebug()
    self.inCombat = false
    self:RefreshRegenSnapshot()
    self.lastUpdatedAt = now
    self.localTracking = self.current ~= nil
    self.manualBaseline = false
    self.baselineDegraded = self.reliability == "DEGRADED"
    self:SetReliability(self.localTracking and (self.baselineDegraded and "DEGRADED" or "ESTIMATED") or "UNKNOWN",
        self.localTracking and (self.baselineDegraded and "unobservable-mana-effect"
            or "local-ledger") or "missing-local-ledger")
    self.autoModeManualOverride = false
    if self.owner.db.profile.autoManaMode == true then
        self:EvaluateAutoMode(now)
    else
        self:RestoreAutoMode()
    end
    self:PersistState(true)
    return true
end

function Mana:OnManualModeChanged()
    if self.autoModeTransition then return end
    if self.autoModeActive then
        self.autoModeActive = false
        self.autoModePrevious = nil
        self.autoModeManualOverride = self.inCombat == true
    end
end

function Mana:RestoreAutoMode()
    if not self.autoModeActive then return false end
    local previous = self.autoModePrevious or "standard"
    self.autoModeActive = false
    self.autoModePrevious = nil
    if not self.owner or self.owner:GetHealingMode() ~= "mana" then return false end
    self.autoModeTransition = true
    self.owner:SetHealingMode(previous, true, true)
    self.autoModeTransition = false
    self:Debug("Auto Mana Saving: restored %s", previous)
    return true
end

function Mana:SetAutoModeEnabled(enabled)
    if not enabled then self:RestoreAutoMode() end
end

function Mana:ResetAutoModeState()
    self.autoModeActive = false
    self.autoModePrevious = nil
    self.autoModeManualOverride = false
    self.autoModeTransition = false
end

function Mana:EvaluateAutoMode(now)
    local profile = self.owner and self.owner.db and self.owner.db.profile
    if not profile or profile.autoManaMode ~= true or self.autoModeTransition
        or self.autoModeManualOverride or not self:CanDriveAutoMode() then
        return false
    end
    local current = self:Update(now)
    if not current or not self.maximum or self.maximum <= 0 then return false end
    local percent = current / self.maximum
    local threshold = math.max(20, math.min(30, tonumber(profile.autoManaThreshold) or 25)) / 100
    if not self.autoModeActive and percent <= threshold then
        local currentMode = self.owner:GetHealingMode()
        if currentMode == "mana" then return false end
        self.autoModePrevious = currentMode
        self.autoModeActive = true
        self.autoModeTransition = true
        self.owner:SetHealingMode("mana", true, true)
        self.autoModeTransition = false
        self:Debug("Auto Mana Saving: %.1f%% <= %.0f%%", percent * 100, threshold * 100)
        self.owner:Print(L("Automatischer Mana-Sparmodus bei %.1f%% aktiviert.", percent * 100))
        return true
    elseif self.autoModeActive and percent >= AUTO_MANA_RESUME_PERCENT then
        local restored = self:RestoreAutoMode()
        if restored then
            self.owner:Print(L("Automatischer Mana-Sparmodus bei %.1f%% beendet.", percent * 100))
        end
        return restored
    end
    return false
end

function Mana:GetCurrent()
    if self.inCombat then return self:Update(GetTime()) end
    if self.localTracking then return self:Update(GetTime()) end
    self:SyncOutOfCombat(false)
    return self.current
end

function Mana:GetMax()
    if not self.inCombat then self:SyncOutOfCombat(false) end
    return self.maximum
end

function Mana:GetPercent()
    local current, maximum = self:GetCurrent(), self.maximum
    if not current or not maximum or maximum <= 0 then return nil end
    return current / maximum
end

function Mana:GetReliability()
    return self.reliability or "UNKNOWN", self.reliabilityReason
end

function Mana:IsReliable()
    return self.reliability == "EXACT" or self.reliability == "ESTIMATED"
end

function Mana:CanDriveAutoMode()
    -- DEGRADED still represents a usable estimate; it only warns that an
    -- unobservable proc or dynamic effect may have introduced drift. Stop the
    -- beta automation only when no local estimate exists at all.
    return self.reliability ~= "UNKNOWN" and self.current ~= nil
        and self.maximum ~= nil and self.maximum > 0
end

function Mana:SetManualPercent(value)
    if not self:IsSupported() or isCombatActive() then return false end
    value = tonumber(value)
    if not value or value < 0 or value > 100 then return false end
    local maximum = self:ReadPlayerMaximum()
    if not maximum then return false end
    self.maximum = maximum
    self.current = maximum * value / 100
    self:RefreshRegenSnapshot()
    self.lastUpdatedAt = GetTime()
    self.localTracking = true
    self.manualBaseline = true
    self.baselineDegraded = false
    self.inCombat = false
    self:SetReliability("EXACT", "manual-baseline")
    self:RefreshCostCache()
    self:PersistState(true)
    self:Debug("Manual baseline: %.1f%% (%s)", value, formatMana(self.current))
    return true
end

function Mana:GetStatusText()
    local current = self:GetCurrent()
    local maximum = self.maximum
    local snapshot = tonumber(self.inCombat and self.regenPerSecond
        or self.outOfCombatRegenPerSecond) or 0
    local regenDescription
    if snapshot > 0 then
        regenDescription = ("%.1f/s cached-total-including-Water-Shield"):format(snapshot)
    else
        regenDescription = ("%.1f/s Water-Shield-fallback"):format(
            tonumber(self.waterShieldRegenPerSecond) or 0)
    end
    return ("%s / %s; reliability=%s; reason=%s; regen=%s; reactive=untracked"):format(
        current and formatMana(current) or "?",
        maximum and formatMana(maximum) or "?",
        self.reliability or "UNKNOWN",
        self.reliabilityReason or "none",
        regenDescription)
end

function Mana:Initialize(owner)
    self.owner = owner
    self.current = nil
    self.maximum = nil
    self.lastUpdatedAt = nil
    self.lastPersistedAt = nil
    self.pendingRegenDebug = 0
    -- Restoration Shaman is modelled with Water Shield maintained. Its fixed
    -- five-second mana tick is safe to simulate; hit-triggered returns and
    -- Resurgence remain intentionally outside the deterministic ledger.
    self.waterShieldRegenPerSecond = self:IsSupported()
        and WATER_SHIELD_REGEN_PER_SECOND or 0
    self.reliability = "UNKNOWN"
    self.reliabilityReason = "initializing-local-ledger"
    self.costs = {}
    self.staticCosts = {}
    self.trackedSpells = {}
    self.spellNames = {}
    self.inCombat = false
    self.localTracking = false
    self.manualBaseline = false
    self.baselineDegraded = false
    self.lastCastGUID = nil
    self.recentManaSpellSuccess = {}
    self:ResetAutoModeState()
    self:RefreshRegenSnapshot()
    if not self:RestorePersistedState() then
        self:AssumeAutomaticFullBaseline()
    end
    self:RefreshCostCache()
end

function Mana:Disable()
    self:PersistState(true)
    self.inCombat = false
    self.lastUpdatedAt = nil
end

function HeliHeal:CreateManaTracker()
    self.Mana:Initialize(self)
end
