local _, ns = ...
local HeliHeal = ns.addon

local Tracker = {}
HeliHeal.ProcTracker = Tracker

local INFUSION_SPELL_IDS = {
    [53576] = true, -- Infusion of Light base spell used by the CDM definition.
    [54149] = true, -- Infusion of Light aura observed by current clients.
}
local SEARCH_RETRY_SECONDS = 2
local DIVINE_PURPOSE_IDS = { [408458] = true, [223819] = true,
    [408459] = true, [223817] = true }

local function isSecret(value)
    if type(issecretvalue) ~= "function" then return false end
    local ok, secret = pcall(issecretvalue, value)
    return ok and secret == true
end

local function cleanNumber(value)
    if type(value) ~= "number" or isSecret(value) then return nil end
    return value
end

local function cleanBoolean(value)
    if type(value) ~= "boolean" or isSecret(value) then return nil end
    return value
end

local function cleanString(value)
    if type(value) ~= "string" or isSecret(value) then return nil end
    if value == "" then return nil end
    return value
end

local function safeMethod(frame, methodName)
    local method = frame and frame[methodName]
    if type(method) ~= "function" then return nil end
    local ok, value = pcall(method, frame)
    if not ok then return nil end
    return value
end

local function addSpellID(result, value)
    value = cleanNumber(value)
    if value and not result.seenSpellIDs[value] then
        result.seenSpellIDs[value] = true
        result.spellIDs[#result.spellIDs + 1] = value
    end
    return value
end

local function inspectFrame(frame)
    local result = {
        frame = frame,
        spellIDs = {},
        seenSpellIDs = {},
    }
    result.cooldownID = cleanNumber(safeMethod(frame, "GetCooldownID"))
        or cleanNumber(frame and frame.cooldownID)
    result.baseSpellID = addSpellID(result, safeMethod(frame, "GetBaseSpellID"))
    result.auraSpellID = addSpellID(result, safeMethod(frame, "GetAuraSpellID"))
    result.spellID = addSpellID(result, safeMethod(frame, "GetSpellID"))

    local info = safeMethod(frame, "GetCooldownInfo")
    if type(info) ~= "table" then
        info = frame and type(frame.cooldownInfo) == "table" and frame.cooldownInfo or nil
    end
    if not info and result.cooldownID and C_CooldownViewer
        and type(C_CooldownViewer.GetCooldownViewerCooldownInfo) == "function" then
        local ok, value = pcall(C_CooldownViewer.GetCooldownViewerCooldownInfo, result.cooldownID)
        if ok and type(value) == "table" then info = value end
    end
    if info then
        addSpellID(result, info.spellID)
        addSpellID(result, info.overrideSpellID)
        if type(info.linkedSpellIDs) == "table" then
            for _, linkedSpellID in ipairs(info.linkedSpellIDs) do
                addSpellID(result, linkedSpellID)
            end
        end
    end

    result.name = cleanString(safeMethod(frame, "GetNameText"))
    local preferredSpellID = result.auraSpellID or result.spellID or result.baseSpellID
        or result.spellIDs[1]
    if not result.name and preferredSpellID and C_Spell
        and type(C_Spell.GetSpellName) == "function" then
        local ok, value = pcall(C_Spell.GetSpellName, preferredSpellID)
        if ok then result.name = cleanString(value) end
    end
    result.active = cleanBoolean(safeMethod(frame, "IsActive"))
    result.shown = cleanBoolean(safeMethod(frame, "IsShown"))
    result.placeholder = frame and frame._isPlaceholderFrame == true or false
    return result
end

local function getInfusionNames()
    local names = {}
    if C_Spell and type(C_Spell.GetSpellName) == "function" then
        for spellID in pairs(INFUSION_SPELL_IDS) do
            local ok, value = pcall(C_Spell.GetSpellName, spellID)
            value = ok and cleanString(value) or nil
            if value then names[value] = true end
        end
    end
    names["Infusion of Light"] = true
    return names
end

local function isInfusionInfo(info, infusionNames)
    for _, spellID in ipairs(info.spellIDs) do
        if INFUSION_SPELL_IDS[spellID] then return true end
    end
    return info.name and infusionNames[info.name] == true or false
end

function Tracker:IsHolyPaladin()
    return HeliHeal.classToken == "PALADIN" and HeliHeal.specializationID == 65
end

function Tracker:GetViewer()
    local viewer = _G.BuffBarCooldownViewer
    if not viewer or not viewer.itemFramePool
        or type(viewer.itemFramePool.EnumerateActive) ~= "function" then
        return nil
    end
    return viewer
end

function Tracker:IsCachedFrameValid()
    local frame = self.infusionFrame
    if not frame then return false end
    local cooldownID = cleanNumber(safeMethod(frame, "GetCooldownID"))
        or cleanNumber(frame.cooldownID)
    if self.cooldownID and cooldownID ~= self.cooldownID then return false end
    return cooldownID ~= nil
end

local function isConfiguredFrame(info)
    -- Edit Mode can leave acquired example shells in the pool. They have no
    -- cooldown identity and must not count as the dedicated tracked-bar item.
    return info and info.cooldownID ~= nil and not info.placeholder
end

-- Independent background sources. Only plain configuration and public item
-- visibility are used; no aura payload, stack count or cooldown is read.
function Tracker:GetProcEntries()
    if not HeliHeal.db or not HeliHeal.db.char then return {} end
    local char = HeliHeal.db.char
    if not char.procEntries then
        char.procEntries = { { key = "infusion_of_light", spellID = 53576,
            name = "Infusion of Light" } }
    end
    if HeliHeal.classToken == "PALADIN" and HeliHeal.specializationID == 65 then
        local configured = false
        for _, entry in ipairs(char.procEntries) do
            if DIVINE_PURPOSE_IDS[entry.spellID] then configured = true; break end
        end
        if not configured then
            char.procEntries[#char.procEntries + 1] = { key = "divine_purpose",
                spellID = 408458, name = "Divine Purpose" }
        end
    end
    return char.procEntries
end

function Tracker:GetDivinePurposeState()
    for _, entry in ipairs(self:GetProcEntries()) do
        if DIVINE_PURPOSE_IDS[entry.spellID] then return self:GetProcState(entry.key) end
    end
    return "UNKNOWN", "Not configured"
end

function Tracker:AddProc(spellID)
    spellID = cleanNumber(tonumber(spellID))
    if not spellID or spellID <= 0 or spellID % 1 ~= 0 then return false end
    local entries = self:GetProcEntries()
    for _, entry in ipairs(entries) do
        if entry.spellID == spellID then return false end
        if DIVINE_PURPOSE_IDS[entry.spellID] and DIVINE_PURPOSE_IDS[spellID] then
            local tracked, reason = self:RegisterProcWithBlizzard(entry.key)
            return true, tracked, reason
        end
    end
    if #entries >= 20 then return false end
    local entry = { key = "spell_" .. spellID, spellID = spellID }
    entries[#entries + 1] = entry
    local tracked, reason = self:RegisterProcWithBlizzard(entry.key)
    return true, tracked, reason
end

function Tracker:RegisterProcWithBlizzard(key)
    if InCombatLockdown and InCombatLockdown() then
        return false, "Out of combat only; click TRACK after combat"
    end
    local entry
    for _, candidate in ipairs(self:GetProcEntries()) do
        if candidate.key == key then entry = candidate; break end
    end
    if not entry then return false, "Not configured" end
    local settings = _G.CooldownViewerSettings
    local provider = safeMethod(settings, "GetDataProvider")
    local manager = safeMethod(provider, "GetLayoutManager")
    local categories = Enum and Enum.CooldownViewerCategory
    local success = Enum and Enum.CooldownLayoutStatus and Enum.CooldownLayoutStatus.Success
    if not provider or not manager or not categories or not categories.TrackedBar
        or success == nil or type(provider.SetCooldownToCategory) ~= "function"
        or type(manager.SaveLayouts) ~= "function" then
        return false, "Open Blizzard Cooldown Settings once, then click TRACK"
    end
    -- Read already-built data. Getters that build display data can write layout
    -- state, so do not call them from background polling or the priority engine.
    local data = safeMethod(provider, "GetDisplayData")
    if not data or type(data.cooldownInfoByID) ~= "table" then
        return false, "Open Blizzard Cooldown Settings once, then click TRACK"
    end
    if safeMethod(manager, "HasPendingChanges") == true then
        return false, "Save your Blizzard CDM edits first"
    end
    local found, foundID
    for cooldownID, info in pairs(data.cooldownInfoByID) do
        if type(info) == "table" then
            local ids = { spellIDs = {}, seenSpellIDs = {} }
            addSpellID(ids, info.spellID)
            addSpellID(ids, info.overrideSpellID)
            if type(info.linkedSpellIDs) == "table" then
                for _, id in ipairs(info.linkedSpellIDs) do addSpellID(ids, id) end
            end
            local matches = ids.seenSpellIDs[entry.spellID] == true
            if DIVINE_PURPOSE_IDS[entry.spellID] then
                for id in pairs(DIVINE_PURPOSE_IDS) do matches = matches or ids.seenSpellIDs[id] == true end
            end
            if key == "infusion_of_light" then
                for id in pairs(INFUSION_SPELL_IDS) do matches = matches or ids.seenSpellIDs[id] == true end
            end
            local category = cleanNumber(info.category)
            local buffCategory = category == categories.TrackedBuff or category == categories.TrackedBar
                or (categories.HiddenPassive ~= nil and category == categories.HiddenPassive)
            if matches and buffCategory and cleanNumber(cooldownID) then
                if found then return false, "Ambiguous Blizzard definition; configure manually" end
                found, foundID = info, cooldownID
            end
        end
    end
    if not found then return false, "No matching Blizzard buff definition; configure manually" end
    if cleanNumber(found.category) == categories.TrackedBar
        or cleanNumber(found.category) == categories.TrackedBuff then
        entry.cooldownID = foundID
        return true, "Already tracked; keeping current Blizzard category"
    end
    local ok, status = pcall(provider.SetCooldownToCategory, provider, foundID, categories.TrackedBar)
    if not ok or cleanNumber(status) ~= success then
        return false, "Blizzard rejected assignment; configure manually"
    end
    local saved = pcall(manager.SaveLayouts, manager)
    if not saved then return false, "Assignment could not be saved; check Blizzard settings" end
    -- Rebuild only the settings data, never invoke live viewer frame updates
    -- from addon execution. Blizzard's saved-layout event owns live refresh.
    if type(provider.MarkDirty) == "function" then pcall(provider.MarkDirty, provider) end
    entry.cooldownID = foundID
    return true, "Assigned to Blizzard Tracked Buff Bars"
end

function Tracker:RemoveProc(key)
    for index, entry in ipairs(self:GetProcEntries()) do
        if entry.key == key and key ~= "infusion_of_light" then
            table.remove(self:GetProcEntries(), index)
            return true
        end
    end
    return false
end

function Tracker:GetProcState(key)
    if self.disabled then return "UNKNOWN", "Tracker disabled" end
    local entry
    for _, candidate in ipairs(self:GetProcEntries()) do
        if candidate.key == key then entry = candidate; break end
    end
    if not entry then return "UNKNOWN", "Not configured" end
    local found, sourceViewer, sourceName
    for _, viewerName in ipairs({ "BuffIconCooldownViewer", "BuffBarCooldownViewer" }) do
    local viewer = _G[viewerName]
    if viewer and viewer.itemFramePool and type(viewer.itemFramePool.EnumerateActive) == "function" then
    for frame in viewer.itemFramePool:EnumerateActive() do
        local info = inspectFrame(frame)
        if isConfiguredFrame(info) then
            local matches = info.seenSpellIDs[entry.spellID] == true
                or (key == "infusion_of_light" and isInfusionInfo(info, getInfusionNames()))
            if DIVINE_PURPOSE_IDS[entry.spellID] then
                for id in pairs(DIVINE_PURPOSE_IDS) do matches = matches or info.seenSpellIDs[id] == true end
            end
            -- A known cooldown definition remains stable when spell fields
            -- become redacted. Never guess from the number of pooled items.
            if not matches and #info.spellIDs == 0 and not info.name then
                matches = entry.cooldownID ~= nil and info.cooldownID == entry.cooldownID
            end
            if matches then
                if found then return "UNKNOWN", "Ambiguous source" end
                found = info
                sourceViewer, sourceName = viewer, viewerName
            end
        end
    end
    end
    end
    if not found then return "UNKNOWN", "Add this proc to Blizzard Tracked Buffs or Bars" end
    entry.cooldownID = found.cooldownID
    entry.name = found.name or entry.name
    entry.sourceViewer = sourceName
    -- Icon managers may keep inactive icons shown. A readable Blizzard item
    -- active flag is independent of that presentation; never read aura data.
    if sourceName == "BuffIconCooldownViewer" and found.active ~= nil then
        return found.active and "ACTIVE" or "INACTIVE", "Tracked Buff item active state"
    end
    if cleanBoolean(safeMethod(sourceViewer, "GetHideWhenInactive")) ~= true
        or cleanBoolean(found.frame.allowHideWhenInactive) == false then
        return "UNKNOWN", "Enable Hide When Inactive for this source"
    end
    if cleanBoolean(safeMethod(found.frame, "IsEditing")) == true
        or cleanBoolean(safeMethod(_G.CooldownViewerSettings, "IsVisible")) == true then
        return "UNKNOWN", "Blizzard settings/edit preview is visible"
    end
    if found.shown == nil then return "UNKNOWN", "Visibility unavailable" end
    return found.shown and "ACTIVE" or "INACTIVE", sourceName .. " item visibility"
end

function Tracker:ClearFrame()
    self.infusionFrame = nil
    self.cooldownID = nil
    self.spellID = nil
    self.name = nil
    self.active = false
    self.registered = false
    self.dedicated = false
    self.configuredFrameCount = nil
    self.secretShown = false
    self.hideWhenInactive = nil
end

function Tracker:FindInfusionFrame(force)
    if self:IsCachedFrameValid() then return self.infusionFrame end
    self:ClearFrame()
    local now = GetTime and GetTime() or 0
    if not force and self.lastSearchAt and now >= self.lastSearchAt
        and now - self.lastSearchAt < SEARCH_RETRY_SECONDS then
        return nil
    end
    self.lastSearchAt = now

    local viewer = self:GetViewer()
    if not viewer then return nil end
    local infusionNames = getInfusionNames()
    local configured = {}
    for frame in viewer.itemFramePool:EnumerateActive() do
        local info = inspectFrame(frame)
        if isConfiguredFrame(info) then
            configured[#configured + 1] = info
        end
        if isInfusionInfo(info, infusionNames) then
            self.infusionFrame = frame
            self.cooldownID = info.cooldownID
            self.spellID = info.auraSpellID or info.spellID or info.baseSpellID
                or info.spellIDs[1]
            self.name = info.name
            self.active = info.shown == true
            self.registered = true
            self.dedicated = #configured == 1
            return frame
        end
    end


    -- Dedicated-viewer fallback: the user keeps exactly one real Blizzard
    -- Tracked Bar and that entry is Infusion of Light. During restricted
    -- states Blizzard may redact the spell identity, but the frame object,
    -- cooldownID and shown state remain usable. Never guess when multiple
    -- configured entries exist.
    if #configured == 1 and #configured[1].spellIDs == 0 and not configured[1].name then
        local info = configured[1]
        self.infusionFrame = info.frame
        self.cooldownID = info.cooldownID
        self.spellID = nil
        self.name = "Infusion of Light (dedicated viewer)"
        self.active = info.shown == true
        self.registered = true
        self.dedicated = true
        return info.frame
    end
    self.configuredFrameCount = #configured
    return nil
end

function Tracker:Refresh(forceSearch)
    if not self:IsHolyPaladin() then
        self:ClearFrame()
        return false
    end
    local frame = self:FindInfusionFrame(forceSearch == true)
    if not frame then
        self.active = false
        return false
    end
    self.hideWhenInactive = cleanBoolean(safeMethod(self:GetViewer(), "GetHideWhenInactive"))
    if self.hideWhenInactive ~= true then
        -- Visibility only represents proc state when Blizzard is configured to
        -- hide inactive tracked bars. Refuse an always-visible false positive.
        self.active = false
        return false
    end
    local shown = cleanBoolean(safeMethod(frame, "IsShown"))
    if shown == nil then
        self.active = false
        self.secretShown = true
        return false
    end
    self.secretShown = false
    self.active = shown
    return shown
end

function Tracker:HasInfusionOfLight()
    local active = self:GetInfusionOfLightState()
    return active == true
end

function Tracker:GetInfusionOfLightState()
    if HeliHeal.db and HeliHeal.db.char then
        if not self:IsHolyPaladin() then return false, false end
        local state = self:GetProcState("infusion_of_light")
        return state == "ACTIVE", state ~= "UNKNOWN"
    end
    local active = self:Refresh(false) == true
    local reliable = self.registered == true and self.hideWhenInactive == true
        and not self.secretShown and self:IsCachedFrameValid()
    return active, reliable
end

local function debugValue(value)
    if isSecret(value) then return "<secret>" end
    if value == nil then return "unavailable" end
    return tostring(value)
end

function Tracker:PrintStatus()
    if HeliHeal.db and HeliHeal.db.char then
        local state, reason = self:GetProcState("infusion_of_light")
        HeliHeal:Print("Infusion Tracker: " .. state .. "; " .. reason)
        for _, entry in ipairs(self:GetProcEntries()) do
            if entry.key == "infusion_of_light" then
                HeliHeal:Print("Source=" .. debugValue(entry.sourceViewer)
                    .. "; Cooldown ID=" .. debugValue(entry.cooldownID))
            end
        end
        return
    end
    self:Refresh(true)
    local frame = self.infusionFrame
    local info = frame and inspectFrame(frame) or nil
    HeliHeal:Print("Infusion Tracker: BuffBarCooldownViewer=" .. (self:GetViewer() and "FOUND" or "NOT FOUND"))
    HeliHeal:Print("Infusion Frame=" .. (frame and "FOUND" or "NOT FOUND"))
    HeliHeal:Print("Spell ID=" .. debugValue(info and (info.auraSpellID or info.spellID or info.baseSpellID or info.spellIDs[1])))
    HeliHeal:Print("Base Spell ID=" .. debugValue(info and info.baseSpellID))
    HeliHeal:Print("Cooldown ID=" .. debugValue(info and info.cooldownID))
    HeliHeal:Print("Name=" .. debugValue(info and info.name))
    HeliHeal:Print("IsActive=" .. debugValue(info and info.active))
    HeliHeal:Print("IsShown=" .. debugValue(info and info.shown))
    HeliHeal:Print("Hide When Inactive=" .. debugValue(self.hideWhenInactive))
    HeliHeal:Print("Detection=DEDICATED ITEM VISIBILITY")
    HeliHeal:Print("Tracker State=" .. (self.active and "ACTIVE" or "INACTIVE"))
    if self:GetViewer() and not frame then
        HeliHeal:Print("Dedicated Infusion viewer not ready. Keep exactly one Blizzard Tracked Bar and set it to Infusion of Light.")
    elseif frame and self.hideWhenInactive ~= true then
        HeliHeal:Print("Enable Hide When Inactive for Blizzard Tracked Bars so visibility can represent the Infusion proc.")
    end
end

function Tracker:PrintRegisteredBuffs()
    local viewer = self:GetViewer()
    if not viewer then
        HeliHeal:Print("CDM Buff Bars: BuffBarCooldownViewer NOT FOUND")
        return
    end
    local count = 0
    HeliHeal:Print("CDM Buff Bars (single scan):")
    for frame in viewer.itemFramePool:EnumerateActive() do
        count = count + 1
        local info = inspectFrame(frame)
        HeliHeal:Print(("%d. spell=%s base=%s cooldownID=%s name=%s active=%s shown=%s"):format(
            count,
            debugValue(info.auraSpellID or info.spellID or info.spellIDs[1]),
            debugValue(info.baseSpellID), debugValue(info.cooldownID),
            debugValue(info.name), debugValue(info.active), debugValue(info.shown)))
    end
    if count == 0 then HeliHeal:Print("No registered BuffBarCooldownViewer frames found.") end
end

function HeliHeal:InitializeProcTracker()
    Tracker.disabled = false
    if Tracker.listener then
        Tracker.listener:RegisterEvent("PLAYER_ENTERING_WORLD")
        Tracker.listener:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
        Tracker.listener:RegisterEvent("TRAIT_CONFIG_UPDATED")
        Tracker.listener:RegisterEvent("SPELLS_CHANGED")
        Tracker.listener:RegisterEvent("UNIT_AURA")
        Tracker:Refresh(true)
        return
    end
    local listener = CreateFrame("Frame")
    listener:RegisterEvent("PLAYER_ENTERING_WORLD")
    listener:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    listener:RegisterEvent("TRAIT_CONFIG_UPDATED")
    listener:RegisterEvent("SPELLS_CHANGED")
    listener:RegisterEvent("UNIT_AURA")
    listener:SetScript("OnEvent", function(_, event, unit)
        if event == "UNIT_AURA" and unit ~= "player" then return end
        local forceSearch = event ~= "UNIT_AURA"
        local function refreshTracker()
            local wasActive = Tracker.active == true
            local active = Tracker:Refresh(forceSearch) == true
            if active ~= wasActive and HeliHeal.RefreshDisplay then
                HeliHeal:RefreshDisplay()
            end
        end
        if C_Timer and type(C_Timer.After) == "function" then
            C_Timer.After(0, refreshTracker)
        else
            refreshTracker()
        end
    end)
    Tracker.listener = listener
    Tracker:Refresh(true)
end

function HeliHeal:DisableProcTracker()
    Tracker.disabled = true
    if Tracker.listener then Tracker.listener:UnregisterAllEvents() end
    Tracker:ClearFrame()
end
