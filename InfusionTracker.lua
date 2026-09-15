local _, ns = ...
local HeliHeal = ns.addon

local Tracker = {}
HeliHeal.ProcTracker = Tracker

local INFUSION_SPELL_IDS = {
    [53576] = true, -- Infusion of Light base spell used by the CDM definition.
    [54149] = true, -- Infusion of Light aura observed by current clients.
}
local SEARCH_RETRY_SECONDS = 2

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
    return self:Refresh(false) == true
end

local function debugValue(value)
    if isSecret(value) then return "<secret>" end
    if value == nil then return "unavailable" end
    return tostring(value)
end

function Tracker:PrintStatus()
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
        if C_Timer and type(C_Timer.After) == "function" then
            C_Timer.After(0, function() Tracker:Refresh(forceSearch) end)
        else
            Tracker:Refresh(forceSearch)
        end
    end)
    Tracker.listener = listener
    Tracker:Refresh(true)
end

function HeliHeal:DisableProcTracker()
    if Tracker.listener then Tracker.listener:UnregisterAllEvents() end
    Tracker:ClearFrame()
end
