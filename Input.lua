local _, ns = ...
local HeliHeal = ns.addon

local MULTI_BAR_BINDINGS = {
    MultiBarBottomLeft = "MULTIACTIONBAR1BUTTON",
    MultiBarBottomRight = "MULTIACTIONBAR2BUTTON",
    MultiBarRight = "MULTIACTIONBAR3BUTTON",
    MultiBarLeft = "MULTIACTIONBAR4BUTTON",
    MultiBar5 = "MULTIACTIONBAR5BUTTON",
    MultiBar6 = "MULTIACTIONBAR6BUTTON",
    MultiBar7 = "MULTIACTIONBAR7BUTTON",
}

local MULTI_BAR_ACTION_SLOTS = {
    MULTIACTIONBAR1BUTTON = 61,
    MULTIACTIONBAR2BUTTON = 49,
    MULTIACTIONBAR3BUTTON = 25,
    MULTIACTIONBAR4BUTTON = 37,
    MULTIACTIONBAR5BUTTON = 145,
    MULTIACTIONBAR6BUTTON = 157,
    MULTIACTIONBAR7BUTTON = 169,
}

local MOUSE_BUTTON_KEYS = {
    LeftButton = "BUTTON1",
    RightButton = "BUTTON2",
    MiddleButton = "BUTTON3",
}

local function withModifiers(input)
    local modifiers = {}
    if IsControlKeyDown() then modifiers[#modifiers + 1] = "CTRL" end
    if IsAltKeyDown() then modifiers[#modifiers + 1] = "ALT" end
    if IsShiftKeyDown() then modifiers[#modifiers + 1] = "SHIFT" end
    modifiers[#modifiers + 1] = input
    return table.concat(modifiers, "-")
end

local function normalizeMouseButton(mouseButton)
    if not mouseButton then return nil end
    local bindingKey = MOUSE_BUTTON_KEYS[mouseButton]
    if not bindingKey then
        local number = mouseButton:match("^Button(%d+)$")
        bindingKey = number and ("BUTTON" .. number) or mouseButton:upper()
    end
    return withModifiers(bindingKey)
end

local function isImpulseInput(inputKey)
    return inputKey:match("MOUSEWHEELUP$") or inputKey:match("MOUSEWHEELDOWN$")
end

local RECENT_SUCCESS_WINDOW = 0.25

local function getActionSlot(bindingAction)
    local button = bindingAction and tonumber(bindingAction:match("^ACTIONBUTTON(%d+)$"))
    if button then
        local page = 1
        if C_ActionBar and type(C_ActionBar.GetActionBarPage) == "function" then
            local ok, currentPage = pcall(C_ActionBar.GetActionBarPage)
            if ok then page = tonumber(currentPage) or page end
        end
        return ((math.max(1, page) - 1) * 12) + button
    end
    local prefix, multiButton
    if bindingAction then
        prefix, multiButton = bindingAction:match("^(MULTIACTIONBAR%dBUTTON)(%d+)$")
    end
    multiButton = tonumber(multiButton)
    local firstSlot = prefix and MULTI_BAR_ACTION_SLOTS[prefix]
    return firstSlot and multiButton and (firstSlot + multiButton - 1) or nil
end

function HeliHeal:GetLiveGCDRemaining(now)
    if not C_Spell or type(C_Spell.GetSpellCooldown) ~= "function" then return nil end
    local ok, info = pcall(C_Spell.GetSpellCooldown, 61304)
    if not ok or type(info) ~= "table" then return nil end

    -- Midnight may restrict individual values. Keep every conversion and
    -- arithmetic operation inside pcall and fall back to the static window.
    local valid, remaining = pcall(function()
        local startTime = tonumber(info.startTime)
        local duration = tonumber(info.duration)
        local modRate = tonumber(info.modRate) or 1
        if duration == 0 then return 0 end
        if not startTime or not duration or duration < 0 or duration > 2.5 or modRate <= 0 then
            return nil
        end
        return math.max(0, startTime + (duration / modRate) - (now or GetTime()))
    end)
    return valid and remaining or nil
end

function HeliHeal:SlotAcceptsSpell(configuredSlot, spellID)
    spellID = tonumber(spellID)
    if not configuredSlot or not spellID then return false end
    if tonumber(configuredSlot.spellID) == spellID then return true end
    for _, acceptedID in ipairs(configuredSlot.castSpellIDs or {}) do
        if tonumber(acceptedID) == spellID then return true end
    end
    return false
end

function HeliHeal:CancelPendingAcknowledgements()
    for slotIndex, pending in pairs(self.pendingAcknowledgements or {}) do
        local timer = pending and pending.timer or pending
        if timer and type(timer.Cancel) == "function" then
            timer:Cancel()
        end
        self.pendingAcknowledgements[slotIndex] = nil
    end
    local assisted = self.pendingAssistedCombat
    if assisted and assisted.timer and type(assisted.timer.Cancel) == "function" then
        assisted.timer:Cancel()
    end
    self.pendingAssistedCombat = nil
end

function HeliHeal:ObserveAssistedCombatBinding(bindingAction)
    local actionSlot = getActionSlot(bindingAction)
    if not actionSlot or not C_ActionBar or type(C_ActionBar.IsAssistedCombatAction) ~= "function" then
        return false
    end
    local ok, isAssisted = pcall(C_ActionBar.IsAssistedCombatAction, actionSlot)
    if not ok or not isAssisted then return false end

    local expectedSpellID
    if C_AssistedCombat and type(C_AssistedCombat.GetNextCastSpell) == "function" then
        local spellOK, spellID = pcall(C_AssistedCombat.GetNextCastSpell, true)
        if spellOK then expectedSpellID = tonumber(spellID) end
    end
    local generation = self.inputGeneration or 0
    local previous = self.pendingAssistedCombat
    if previous and previous.timer and type(previous.timer.Cancel) == "function" then
        previous.timer:Cancel()
    end
    local pending = {
        actionSlot = actionSlot,
        expectedSpellID = expectedSpellID,
        observedAt = GetTime(),
        generation = generation,
    }
    self.pendingAssistedCombat = pending
    if C_Timer and type(C_Timer.NewTimer) == "function" then
        pending.timer = C_Timer.NewTimer(5, function()
            if HeliHeal.pendingAssistedCombat == pending then
                HeliHeal.pendingAssistedCombat = nil
            end
        end)
    end
    self:CommitRecentSpellForAssistedCombat()
    return true
end

function HeliHeal:QueueSlotAcknowledgement(slotIndex, delay)
    self.pendingAcknowledgements = self.pendingAcknowledgements or {}
    if self.pendingAcknowledgements[slotIndex] then
        return
    end

    local configuredSlot = self.db.profile.slots[slotIndex]
    if not configuredSlot then return end
    delay = math.max(5, tonumber(delay) or 0)
    local generation = self.inputGeneration or 0
    local pending = { spellID = configuredSlot.spellID, observedAt = GetTime(), generation = generation }
    self.pendingAcknowledgements[slotIndex] = pending

    if not C_Timer or type(C_Timer.NewTimer) ~= "function" then return end

    local timer
    timer = C_Timer.NewTimer(delay, function()
        if (HeliHeal.inputGeneration or 0) ~= generation
            or HeliHeal.pendingAcknowledgements[slotIndex] ~= pending then
            return
        end
        -- No matching successful cast arrived. Discard only the observation;
        -- never advance the rotation on a timeout or failed early queue input.
        HeliHeal.pendingAcknowledgements[slotIndex] = nil
        HeliHeal.inputLockedUntil[slotIndex] = nil
    end)
    pending.timer = timer
end

function HeliHeal:CommitObservedSpell(spellID)
    local now = GetTime()
    for slotIndex, pending in pairs(self.pendingAcknowledgements or {}) do
        local configuredSlot = self.db.profile.slots[slotIndex]
        local generation = self.inputGeneration or 0
        if pending.generation ~= nil and pending.generation ~= generation then
            self.pendingAcknowledgements[slotIndex] = nil
        elseif self:SlotAcceptsSpell(configuredSlot, spellID) then
            if pending.timer and type(pending.timer.Cancel) == "function" then pending.timer:Cancel() end
            self.pendingAcknowledgements[slotIndex] = nil
            local staticWindow = math.max(1.5, tonumber(configuredSlot.inputLockout) or 1.5)
            self.inputLockedUntil[slotIndex] = now + staticWindow
            local function refreshGCDLock()
                if (HeliHeal.inputGeneration or 0) ~= generation then return end
                local sampledAt = GetTime()
                local gcdRemaining = HeliHeal:GetLiveGCDRemaining(sampledAt)
                if gcdRemaining ~= nil then
                    HeliHeal.inputLockedUntil[slotIndex] = sampledAt + gcdRemaining
                end
            end
            -- Blizzard updates the GCD cooldown immediately after the success
            -- event. Sample on the next frame, as cast-bar addons do.
            if C_Timer and type(C_Timer.After) == "function" then
                C_Timer.After(0, refreshGCDLock)
            else
                refreshGCDLock()
            end
            self:AcknowledgeSlot(slotIndex, spellID)
            return true
        end
    end
    return false
end

function HeliHeal:RecordPlayerSpellSucceeded(spellID)
    spellID = tonumber(spellID)
    if not spellID then return false end
    local dispelConfirmed = self.RecordDispelSpellSucceeded
        and self:RecordDispelSpellSucceeded(spellID, GetTime()) or false
    self.recentSuccessfulSpells = self.recentSuccessfulSpells or {}
    self.recentSuccessfulSpells[spellID] = GetTime()
    if self:CommitObservedSpell(spellID) or self:CommitAssistedCombatSpell(spellID)
        or self:CommitConfiguredPlayerSpell(spellID) then
        self.recentSuccessfulSpells[spellID] = nil
        self:ScheduleHolyPowerSync()
        return true
    end
    self:ScheduleHolyPowerSync()
    return dispelConfirmed
end

function HeliHeal:CommitConfiguredPlayerSpell(spellID)
    local now = GetTime()
    self.recentDirectConfirmations = self.recentDirectConfirmations or {}
    for slotIndex, configuredSlot in ipairs(self.db.profile.slots or {}) do
        local ability = self.GetSlot and self:GetSlot(slotIndex) or configuredSlot
        if ability and ability.enabled and ability.confirmOnPlayerSuccess
            and self:SlotAcceptsSpell(configuredSlot, spellID) then
            local lastConfirmed = self.recentDirectConfirmations[slotIndex]
            if lastConfirmed and now - lastConfirmed < 0.25 then return false end
            self.recentDirectConfirmations[slotIndex] = now
            self.inputLockedUntil[slotIndex] = now
                + math.max(1.0, tonumber(configuredSlot.inputLockout) or 1.0)
            self:AcknowledgeSlot(slotIndex, spellID)
            return true
        end
    end
    return false
end

function HeliHeal:CommitAssistedCombatSpell(spellID)
    local pending = self.pendingAssistedCombat
    if not pending or pending.generation ~= (self.inputGeneration or 0) then
        self.pendingAssistedCombat = nil
        return false
    end
    if pending.expectedSpellID and pending.expectedSpellID ~= tonumber(spellID) then
        return false
    end
    if pending.timer and type(pending.timer.Cancel) == "function" then pending.timer:Cancel() end
    self.pendingAssistedCombat = nil

    for slotIndex, configuredSlot in ipairs(self.db.profile.slots or {}) do
        local ability = self.GetSlot and self:GetSlot(slotIndex) or configuredSlot
        if ability and ability.enabled and self:SlotAcceptsSpell(configuredSlot, spellID) then
            self.inputLockedUntil[slotIndex] = GetTime()
                + math.max(1.5, tonumber(configuredSlot.inputLockout) or 1.5)
            self:AcknowledgeSlot(slotIndex, spellID)
            return true
        end
    end
    local observedAbility = ns.AbilityLibrary and ns.AbilityLibrary:FindAbilityBySpellID(spellID, self.classToken)
    if observedAbility and ((observedAbility.holyPowerGain or 0) > 0
        or (observedAbility.holyPowerCost or 0) > 0) then
        self:RecordHolyPowerEvent(0, observedAbility)
        return true
    end
    return false
end

function HeliHeal:RejectAssistedCombatSpell(spellID)
    local pending = self.pendingAssistedCombat
    if not pending or (pending.expectedSpellID and pending.expectedSpellID ~= tonumber(spellID)) then
        return false
    end
    if pending.timer and type(pending.timer.Cancel) == "function" then pending.timer:Cancel() end
    self.pendingAssistedCombat = nil
    return true
end

function HeliHeal:GetLiveHolyPower()
    if self.classToken ~= "PALADIN" or type(UnitPower) ~= "function" then return nil end
    local powerType = Enum and Enum.PowerType and Enum.PowerType.HolyPower or 9
    local ok, value = pcall(function()
        local result = tonumber(UnitPower("player", powerType))
        if not result or result < 0 or result > 5 then return nil end
        return math.floor(result)
    end)
    return ok and value or nil
end

function HeliHeal:SyncLiveHolyPower()
    local value = self:GetLiveHolyPower()
    if value == nil then return false end
    return self:ApplyAuthoritativeHolyPower(value)
end

function HeliHeal:ScheduleHolyPowerSync()
    if self.classToken ~= "PALADIN" then return end
    local generation = self.inputGeneration or 0
    local sync = function()
        if generation == (HeliHeal.inputGeneration or 0) then HeliHeal:SyncLiveHolyPower() end
    end
    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(0, sync)
    else
        sync()
    end
end

function HeliHeal:CommitRecentSpellForSlot(slotIndex)
    local configuredSlot = self.db.profile.slots[slotIndex]
    local now = GetTime()
    for spellID, succeededAt in pairs(self.recentSuccessfulSpells or {}) do
        local age = now - succeededAt
        if age > RECENT_SUCCESS_WINDOW or age < 0 then
            self.recentSuccessfulSpells[spellID] = nil
        elseif self:SlotAcceptsSpell(configuredSlot, spellID) then
            self.recentSuccessfulSpells[spellID] = nil
            return self:CommitObservedSpell(spellID)
        end
    end
    return false
end

function HeliHeal:CommitRecentSpellForAssistedCombat()
    local pending = self.pendingAssistedCombat
    if not pending then return false end
    local now = GetTime()
    local newestSpellID, newestAt
    for spellID, succeededAt in pairs(self.recentSuccessfulSpells or {}) do
        local age = now - succeededAt
        if age > RECENT_SUCCESS_WINDOW or age < 0 then
            self.recentSuccessfulSpells[spellID] = nil
        elseif (not newestAt or succeededAt > newestAt)
            and (not pending.expectedSpellID or pending.expectedSpellID == tonumber(spellID)) then
            newestSpellID, newestAt = spellID, succeededAt
        end
    end
    -- An instant OBA cast can succeed synchronously before the secure
    -- ActionButtonDown post-hook. Blizzard may already expose the next spell
    -- by then, so fall back to the newest success inside the narrow window.
    if not newestSpellID then
        for spellID, succeededAt in pairs(self.recentSuccessfulSpells or {}) do
            local age = now - succeededAt
            if age >= 0 and age <= RECENT_SUCCESS_WINDOW and (not newestAt or succeededAt > newestAt) then
                newestSpellID, newestAt = spellID, succeededAt
            end
        end
    end
    if not newestSpellID then return false end
    self.recentSuccessfulSpells[newestSpellID] = nil
    pending.expectedSpellID = tonumber(newestSpellID)
    local committed = self:CommitAssistedCombatSpell(newestSpellID)
    if committed then self:ScheduleHolyPowerSync() end
    return committed
end

function HeliHeal:RejectObservedSpell(spellID)
    for slotIndex, pending in pairs(self.pendingAcknowledgements or {}) do
        local configuredSlot = self.db.profile.slots[slotIndex]
        if self:SlotAcceptsSpell(configuredSlot, spellID) then
            if pending.timer and type(pending.timer.Cancel) == "function" then pending.timer:Cancel() end
            self.pendingAcknowledgements[slotIndex] = nil
            self.inputLockedUntil[slotIndex] = nil
            return true
        end
    end
    return false
end

function HeliHeal:ReleaseInputKey(inputKey)
    if inputKey and self.heldInputKeys then
        self.heldInputKeys[inputKey] = nil
    end
end

function HeliHeal:ReleaseActionBinding(bindingAction)
    if not bindingAction then
        return
    end

    local key1, key2 = GetBindingKey(bindingAction)
    self:ReleaseInputKey(key1)
    if key2 and key2 ~= key1 then
        self:ReleaseInputKey(key2)
    end
end

function HeliHeal:ObserveInputKey(inputKey)
    if self.inputListenerEnabled == false or self.suspendInput or not inputKey or inputKey == "" then
        return
    end

    for slotIndex, configured in ipairs(self.db.profile.slots) do
        local configuredSpellID = configured and tonumber(configured.spellID) or 0
        local ability = configured and (self.GetSlot and self:GetSlot(slotIndex) or configured)
        local derivedSourceEnabled = false
        if configured and configured.derivedBindingFrom and self.GetSlotIndexByAbilityKey and self.GetSlot then
            local sourceIndex = self:GetSlotIndexByAbilityKey(configured.derivedBindingFrom)
            local sourceAbility = sourceIndex and self:GetSlot(sourceIndex)
            derivedSourceEnabled = sourceAbility and sourceAbility.enabled or false
        end
        if configured and ability and ability.enabled and not derivedSourceEnabled
            and configuredSpellID > 0 and configured.inputKey == inputKey then
            local now = GetTime()
            self.heldInputKeys = self.heldInputKeys or {}
            self.inputLockedUntil = self.inputLockedUntil or {}
            local impulseInput = isImpulseInput(inputKey)
            if (not impulseInput and self.heldInputKeys[inputKey]) or now < (self.inputLockedUntil[slotIndex] or 0) then
                return
            end

            self.lastObservedInputs = self.lastObservedInputs or {}
            local lastObservedAt = self.lastObservedInputs[inputKey]
            if not lastObservedAt or now - lastObservedAt > 0.08 then
                -- Debounce duplicate hooks for this physical binding only.
                -- A global timestamp could discard a different instant spell
                -- pressed immediately afterwards while WoW still casts it.
                self.lastObservedInputs[inputKey] = now
                if not impulseInput then
                    self.heldInputKeys[inputKey] = true
                end
                local safetyTimeout = 5
                self.inputLockedUntil[slotIndex] = now + safetyTimeout
                self:QueueSlotAcknowledgement(slotIndex, safetyTimeout)
                -- Instant spells can report success synchronously inside the
                -- protected action before our secure post-hook runs.
                self:CommitRecentSpellForSlot(slotIndex)
            end
            return
        end
    end
end

function HeliHeal:ObserveActionBinding(bindingAction)
    if self.inputListenerEnabled == false or self.suspendInput then
        return
    end

    if self:ObserveAssistedCombatBinding(bindingAction) then return end

    local key1, key2 = GetBindingKey(bindingAction)
    if key1 then
        self:ObserveInputKey(key1)
    end
    if key2 and key2 ~= key1 then
        self:ObserveInputKey(key2)
    end
end

function HeliHeal:CreateInputListener()
    if self.mouseInputListener and self.castInputListener then
        self.mouseInputListener:RegisterEvent("GLOBAL_MOUSE_DOWN")
        self.mouseInputListener:RegisterEvent("GLOBAL_MOUSE_UP")
        self.castInputListener:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
        self.castInputListener:RegisterEvent("UNIT_SPELLCAST_FAILED")
        self.castInputListener:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
        self.castInputListener:RegisterEvent("UNIT_POWER_UPDATE")
        return
    end
    -- Secure post-hooks observe Blizzard's normal action-button key path after
    -- it runs. HeliHeal never owns, replaces or propagates a combat key event.
    if type(ActionButtonDown) == "function" then
        hooksecurefunc("ActionButtonDown", function(buttonID)
            HeliHeal:ObserveActionBinding("ACTIONBUTTON" .. tostring(buttonID))
        end)
    end

    if type(ActionButtonUp) == "function" then
        hooksecurefunc("ActionButtonUp", function(buttonID)
            HeliHeal:ReleaseActionBinding("ACTIONBUTTON" .. tostring(buttonID))
        end)
    end

    if type(MultiActionButtonDown) == "function" then
        hooksecurefunc("MultiActionButtonDown", function(barName, buttonID)
            local prefix = MULTI_BAR_BINDINGS[barName]
            if prefix then
                HeliHeal:ObserveActionBinding(prefix .. tostring(buttonID))
            end
        end)
    end

    if type(MultiActionButtonUp) == "function" then
        hooksecurefunc("MultiActionButtonUp", function(barName, buttonID)
            local prefix = MULTI_BAR_BINDINGS[barName]
            if prefix then
                HeliHeal:ReleaseActionBinding(prefix .. tostring(buttonID))
            end
        end)
    end

    -- Unit and raid frames can consume mouse buttons before Blizzard's normal
    -- action-button path runs. This observes only the physical button without
    -- reading the hovered frame, its unit or any combat state.
    local mouseListener = CreateFrame("Frame")
    mouseListener:RegisterEvent("GLOBAL_MOUSE_DOWN")
    mouseListener:RegisterEvent("GLOBAL_MOUSE_UP")
    mouseListener:SetScript("OnEvent", function(_, event, mouseButton)
        HeliHeal.mouseHeldInputs = HeliHeal.mouseHeldInputs or {}
        if event == "GLOBAL_MOUSE_DOWN" then
            local inputKey = normalizeMouseButton(mouseButton)
            HeliHeal.mouseHeldInputs[mouseButton] = inputKey
            HeliHeal:ObserveInputKey(inputKey)
        else
            local inputKey = HeliHeal.mouseHeldInputs[mouseButton]
            HeliHeal.mouseHeldInputs[mouseButton] = nil
            HeliHeal:ReleaseInputKey(inputKey)
        end
    end)
    self.mouseInputListener = mouseListener

    local castListener = CreateFrame("Frame")
    castListener:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    castListener:RegisterEvent("UNIT_SPELLCAST_FAILED")
    castListener:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
    castListener:RegisterEvent("UNIT_POWER_UPDATE")
    castListener:SetScript("OnEvent", function(_, event, unit, castGUID, spellID)
        if event == "UNIT_POWER_UPDATE" then
            local powerType = castGUID
            if unit == "player" and powerType == "HOLY_POWER" then HeliHeal:SyncLiveHolyPower() end
            return
        end
        if unit ~= "player" or not spellID then return end
        if event == "UNIT_SPELLCAST_SUCCEEDED" then
            HeliHeal:RecordPlayerSpellSucceeded(spellID)
        else
            HeliHeal:RejectObservedSpell(spellID)
            HeliHeal:RejectAssistedCombatSpell(spellID)
        end
    end)
    self.castInputListener = castListener
end
