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

function HeliHeal:GetSpellQueueDelay()
    local milliseconds
    if C_Spell and type(C_Spell.GetSpellQueueWindow) == "function" then
        milliseconds = tonumber(C_Spell.GetSpellQueueWindow())
    end
    if not milliseconds and type(GetCVar) == "function" then
        milliseconds = tonumber(GetCVar("SpellQueueWindow"))
    end

    -- SpellQueueWindow is expressed in milliseconds. Keep malformed or
    -- extreme values from delaying the static tracker indefinitely.
    milliseconds = math.max(0, math.min(milliseconds or 0, 1000))
    return milliseconds / 1000
end

function HeliHeal:GetInputCommitDelay(configuredSlot)
    -- HeliHeal deliberately does not read the live GCD or current cast. Keep
    -- the recommendation stable for one conservative base GCD after the
    -- queue window instead of treating the first early/spammed input as an
    -- immediately completed cast.
    local actionWindow = tonumber(configuredSlot and configuredSlot.inputLockout) or 1.5
    actionWindow = math.max(1.5, math.min(actionWindow, 4.0))
    return self:GetSpellQueueDelay() + actionWindow
end

function HeliHeal:CancelPendingAcknowledgements()
    for slotIndex, timer in pairs(self.pendingAcknowledgements or {}) do
        if timer and type(timer.Cancel) == "function" then
            timer:Cancel()
        end
        self.pendingAcknowledgements[slotIndex] = nil
    end
end

function HeliHeal:QueueSlotAcknowledgement(slotIndex, delay)
    self.pendingAcknowledgements = self.pendingAcknowledgements or {}
    if self.pendingAcknowledgements[slotIndex] then
        return
    end

    delay = delay or (self:GetSpellQueueDelay() + 1.5)
    if delay <= 0 or not C_Timer or type(C_Timer.NewTimer) ~= "function" then
        self:AcknowledgeSlot(slotIndex)
        return
    end

    local timer
    timer = C_Timer.NewTimer(delay, function()
        if HeliHeal.pendingAcknowledgements[slotIndex] ~= timer then
            return
        end
        HeliHeal.pendingAcknowledgements[slotIndex] = nil
        HeliHeal:AcknowledgeSlot(slotIndex)
    end)
    self.pendingAcknowledgements[slotIndex] = timer
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
    if self.suspendInput or not inputKey or inputKey == "" then
        return
    end

    for slotIndex, configured in ipairs(self.db.profile.slots) do
        local configuredSpellID = configured and tonumber(configured.spellID) or 0
        if configured and configured.enabled and not configured.derivedBindingFrom and configuredSpellID > 0 and configured.inputKey == inputKey then
            local now = GetTime()
            self.heldInputKeys = self.heldInputKeys or {}
            self.inputLockedUntil = self.inputLockedUntil or {}
            local impulseInput = isImpulseInput(inputKey)
            if (not impulseInput and self.heldInputKeys[inputKey]) or now < (self.inputLockedUntil[slotIndex] or 0) then
                return
            end

            if not self.lastObservedInput or now - self.lastObservedInput > 0.08 then
                self.lastObservedInput = now
                if not impulseInput then
                    self.heldInputKeys[inputKey] = true
                end
                local commitDelay = self:GetInputCommitDelay(configured)
                self.inputLockedUntil[slotIndex] = now + commitDelay
                self:QueueSlotAcknowledgement(slotIndex, commitDelay)
            end
            return
        end
    end
end

function HeliHeal:ObserveActionBinding(bindingAction)
    if self.suspendInput then
        return
    end

    local key1, key2 = GetBindingKey(bindingAction)
    if key1 then
        self:ObserveInputKey(key1)
    end
    if key2 and key2 ~= key1 then
        self:ObserveInputKey(key2)
    end
end

function HeliHeal:CreateInputListener()
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
end
