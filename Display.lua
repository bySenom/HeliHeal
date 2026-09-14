local _, ns = ...
local HeliHeal = ns.addon
local L = ns.L or function(value, ...) return select("#", ...) > 0 and value:format(...) or value end

local DISPLAY_SLOT_COUNT = 5
local SUPPORT_SLOT_COUNT = 6
local WHITE = "Interface\\Buttons\\WHITE8X8"
local DEFAULT_ROLE_COLORS = {
    AOE = { 0.2, 0.82, 1.0 },
    SINGLE = { 0.35, 1.0, 0.62 },
    BURST = { 1.0, 0.55, 0.18 },
    SAVE = { 0.15, 0.95, 0.72 },
}
local DEFAULT_ACCENT = { 0.02, 0.88, 0.7 }
local DEFAULT_HOTKEY = { 0.92, 0.98, 0.97 }
local DEFAULT_COOLDOWN = { 1.0, 0.86, 0.32 }
local DEFAULT_PANEL = { 0.018, 0.026, 0.034 }
local DEFAULT_PANEL_BORDER = { 0.08, 0.14, 0.16 }
local DEFAULT_ICON_BACKGROUND = { 0.025, 0.035, 0.045 }
local DEFAULT_NAME = { 1.0, 1.0, 1.0 }

local function clamp(value, minimum, maximum, fallback)
    value = tonumber(value) or fallback
    return math.max(minimum, math.min(maximum, value))
end

local function getColor(value, fallback)
    if type(value) ~= "table" then return fallback[1], fallback[2], fallback[3] end
    return clamp(value[1], 0, 1, fallback[1]),
        clamp(value[2], 0, 1, fallback[2]),
        clamp(value[3], 0, 1, fallback[3])
end

local function clearArray(array)
    for index = #array, 1, -1 do array[index] = nil end
end

local function readyBefore(a, b)
    if a.monkTeaPriority ~= b.monkTeaPriority then
        if not a.monkTeaPriority then return false end
        if not b.monkTeaPriority then return true end
        return a.monkTeaPriority < b.monkTeaPriority
    end
    if a.priestPreApotheosisSpend ~= b.priestPreApotheosisSpend then
        return a.priestPreApotheosisSpend
    end
    if a.priestHoldForApotheosis ~= b.priestHoldForApotheosis then
        return not a.priestHoldForApotheosis
    end
    if a.preferSpender ~= b.preferSpender then return a.preferSpender end
    if a.paladinHandPriority ~= b.paladinHandPriority then
        if not a.paladinHandPriority then return false end
        if not b.paladinHandPriority then return true end
        return a.paladinHandPriority < b.paladinHandPriority
    end
    if a.paladinInfusionPriority ~= b.paladinInfusionPriority then
        if not a.paladinInfusionPriority then return false end
        if not b.paladinInfusionPriority then return true end
        return a.paladinInfusionPriority < b.paladinInfusionPriority
    end
    if a.paladinCrusaderPriority ~= b.paladinCrusaderPriority then
        if not a.paladinCrusaderPriority then return false end
        if not b.paladinCrusaderPriority then return true end
        return a.paladinCrusaderPriority < b.paladinCrusaderPriority
    end
    if a.preferredConsumer ~= b.preferredConsumer then return a.preferredConsumer end
    if a.druidSoulConsumer ~= b.druidSoulConsumer then return a.druidSoulConsumer end
    if a.unleashPriority ~= b.unleashPriority then
        if not a.unleashPriority then return false end
        if not b.unleashPriority then return true end
        return a.unleashPriority < b.unleashPriority
    end
    return a.priorityRank < b.priorityRank
end

local function waitingBefore(a, b)
    if a.readyAt == b.readyAt then return a.priorityRank < b.priorityRank end
    return a.readyAt < b.readyAt
end

local function getHudFont(profile)
    local fonts = ns.media.fonts or {}
    local entry = fonts[profile.hudFont] or fonts.friz
    return entry and entry.path or ns.media.font
end

local function getFontFlags(profile)
    local value = profile.hudFontOutline
    if value == "NONE" then return "" end
    if value == "THICKOUTLINE" then return "THICKOUTLINE" end
    return "OUTLINE"
end

local function formatRemaining(seconds)
    if seconds >= 10 then
        return tostring(math.ceil(seconds))
    end
    return ("%.1f"):format(seconds)
end

local HOTKEY_TOKEN_LABELS = {
    SHIFT = "S",
    CTRL = "C",
    ALT = "A",
    MOUSEWHEELUP = "WU",
    MOUSEWHEELDOWN = "WD",
}

function HeliHeal:FormatHotkeyLabel(inputKey)
    if type(inputKey) ~= "string" or inputKey == "" then return inputKey or "" end
    local parts = {}
    for token in inputKey:gmatch("[^%-]+") do
        local mouseButton = token:match("^BUTTON(%d+)$")
        parts[#parts + 1] = mouseButton and ("M" .. mouseButton)
            or HOTKEY_TOKEN_LABELS[token] or token
    end
    return table.concat(parts, "-")
end

local function getIconCrop(zoom)
    zoom = clamp(zoom, 0.7, 1.6, 1)
    return clamp(0.08 + ((zoom - 1) * 0.18), 0, 0.28, 0.08)
end

function HeliHeal:GetHotkeyBadgeOverhang(iconSize, badgeWidth)
    return math.max(0, ((badgeWidth or iconSize) - iconSize) / 2)
end

function HeliHeal:GetBadgeAwareSpacing(previousIconSize, previousBadgeWidth, iconSize, badgeWidth, preferredSpacing)
    local previousOverhang = self:GetHotkeyBadgeOverhang(previousIconSize, previousBadgeWidth)
    local currentOverhang = self:GetHotkeyBadgeOverhang(iconSize, badgeWidth)
    return math.max(preferredSpacing or 0, previousOverhang + currentOverhang + 2)
end

function HeliHeal:GetChoiceBadgeBottomOffset(showAbilityName, abilityNameFontSize, abilityNameOffsetY)
    if not showAbilityName then return 4 end
    return math.max(4, (abilityNameOffsetY or 4) + (abilityNameFontSize or 9) + 2)
end

function HeliHeal:GetManaBadgeBottomOffset(baseOffset, hasChoicePair)
    -- AUTO/MANA and OR share the same horizontal area above the first two
    -- icons. Keep OR closest to the choice and move AUTO/MANA one row higher.
    return (baseOffset or 4) + (hasChoicePair and 18 or 0)
end

function HeliHeal:GetPrimaryChoiceGroup(order, mode)
    if type(order) ~= "table" or (mode or self:GetHealingMode()) ~= "standard" then return nil end
    local first, second = order[1], order[2]
    local firstGroup = first and first.ability and first.ability.choiceGroup
    local secondGroup = second and second.ability and second.ability.choiceGroup
    if not firstGroup or firstGroup == "" or firstGroup ~= secondGroup then return nil end
    if (first.remaining or 0) > 0 or (second.remaining or 0) > 0 then return nil end
    return firstGroup
end

function HeliHeal:ShouldShowAutomaticManaBadge()
    local profile = self.db and self.db.profile
    return profile and profile.autoManaMode == true and self.Mana
        and self.Mana.current ~= nil and self.Mana.maximum ~= nil
end

local function createSupportFrame()
    local frame = CreateFrame("Frame", "HeliHealSupportFrame", UIParent, "BackdropTemplate")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    frame:SetBackdropColor(0.018, 0.026, 0.034, 0.92)
    frame:SetBackdropBorderColor(0.08, 0.14, 0.16, 0.95)
    frame.accent = frame:CreateTexture(nil, "ARTWORK")
    frame.accent:SetTexture(WHITE)
    frame.accent:SetPoint("TOPLEFT", 1, -1)
    frame.accent:SetPoint("TOPRIGHT", -1, -1)
    frame.accent:SetHeight(2)
    frame:SetScript("OnDragStart", function(display)
        if not HeliHeal.db.profile.locked then display:StartMoving() end
    end)
    frame:SetScript("OnDragStop", function(display)
        display:StopMovingOrSizing()
        local point, _, relativePoint, x, y = display:GetPoint(1)
        local profile = HeliHeal.db.profile
        profile.supportWindowPoint = point
        profile.supportWindowRelativePoint = relativePoint
        profile.supportWindowX = x
        profile.supportWindowY = y
    end)
    frame.title = frame:CreateFontString(nil, "OVERLAY")
    frame.title:SetFont(ns.media.font, 9, "OUTLINE")
    frame.title:SetPoint("TOPLEFT", 8, -6)
    frame.title:SetText("DEF / UTILITY")
    frame.slots = {}
    for index = 1, SUPPORT_SLOT_COUNT do
        local button = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        button:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
        button.shadow = button:CreateTexture(nil, "BACKGROUND", nil, -1)
        button.shadow:SetTexture(WHITE)
        button.shadow:SetColorTexture(0, 0, 0, 0.55)
        button.shadow:SetPoint("TOPLEFT", -4, 4)
        button.shadow:SetPoint("BOTTOMRIGHT", 4, -4)
        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetAllPoints()
        button.cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
        button.cooldown:SetAllPoints(button.icon)
        button.cooldown:SetDrawEdge(false)
        button.cooldown:SetHideCountdownNumbers(true)
        button.remaining = button:CreateFontString(nil, "OVERLAY")
        button.remaining:SetFont(ns.media.font, 14, "OUTLINE")
        button.remaining:SetPoint("CENTER")
        button.keyBadge = CreateFrame("Frame", nil, button, "BackdropTemplate")
        button.keyBadge:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
        button.key = button.keyBadge:CreateFontString(nil, "OVERLAY")
        button.key:SetFont(ns.media.font, 9, "OUTLINE")
        button.key:SetPoint("CENTER")
        button.name = button:CreateFontString(nil, "OVERLAY")
        button.name:SetFont(ns.media.font, 9, "OUTLINE")
        button.name:SetPoint("BOTTOM", button, "TOP", 0, 4)
        button.name:SetWidth(106)
        button.name:SetMaxLines(1)
        frame.slots[index] = button
    end
    frame:Hide()
    return frame
end

function HeliHeal:CreateDisplay()
    local frame = CreateFrame("Frame", "HeliHealPriorityFrame", UIParent, "BackdropTemplate")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetBackdrop({
        bgFile = WHITE,
        edgeFile = WHITE,
        edgeSize = 1,
    })
    frame:SetBackdropColor(0.018, 0.026, 0.034, 0.92)
    frame:SetBackdropBorderColor(0.08, 0.14, 0.16, 0.95)

    frame.accent = frame:CreateTexture(nil, "ARTWORK")
    frame.accent:SetTexture(WHITE)
    frame.accent:SetColorTexture(0.02, 0.88, 0.7, 1)
    frame.accent:SetPoint("TOPLEFT", 1, -1)
    frame.accent:SetPoint("TOPRIGHT", -1, -1)
    frame.accent:SetHeight(2)

    frame.title = frame:CreateFontString(nil, "OVERLAY")
    frame.title:SetFont(ns.media.font, 9, "OUTLINE")
    frame.title:SetText("HELIHEAL  •  " .. L("NEXT PRIORITY"))
    frame.title:SetTextColor(0.02, 0.88, 0.7, 1)
    frame.title:SetPoint("TOPLEFT", 10, -9)

    frame:SetScript("OnDragStart", function(display)
        if not HeliHeal.db.profile.locked then
            display:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function(display)
        display:StopMovingOrSizing()
        local point, _, relativePoint, x, y = display:GetPoint(1)
        local profile = HeliHeal.db.profile
        profile.point = point
        profile.relativePoint = relativePoint
        profile.x = x
        profile.y = y
    end)

    frame.slots = {}
    for index = 1, DISPLAY_SLOT_COUNT do
        local button = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        button:SetBackdrop({
            bgFile = WHITE,
            edgeFile = WHITE,
            edgeSize = 1,
        })
        button:SetBackdropColor(0.025, 0.035, 0.045, 1)
        button:SetBackdropBorderColor(0.13, 0.18, 0.21, 1)

        button.shadow = button:CreateTexture(nil, "BACKGROUND", nil, -1)
        button.shadow:SetTexture(WHITE)
        button.shadow:SetColorTexture(0, 0, 0, 0.55)
        button.shadow:SetPoint("TOPLEFT", -4, 4)
        button.shadow:SetPoint("BOTTOMRIGHT", 4, -4)

        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetPoint("TOPLEFT", 4, -4)
        button.icon:SetPoint("BOTTOMRIGHT", -4, 4)
        button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        button.cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
        button.cooldown:SetAllPoints(button.icon)
        button.cooldown:SetDrawEdge(false)
        button.cooldown:SetHideCountdownNumbers(true)

        button.keyBadge = CreateFrame("Frame", nil, button, "BackdropTemplate")
        button.keyBadge:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
        button.keyBadge:SetBackdropColor(0.018, 0.026, 0.034, 0.94)
        button.keyBadge:SetBackdropBorderColor(0.02, 0.88, 0.7, 0.8)
        button.keyBadge:SetHeight(18)
        button.keyBadge:SetPoint("BOTTOM", button, "BOTTOM", 0, -8)
        button.key = button.keyBadge:CreateFontString(nil, "OVERLAY")
        button.key:SetFont(ns.media.font, 9, "OUTLINE")
        button.key:SetPoint("CENTER", 0, 0)
        button.key:SetTextColor(0.92, 0.98, 0.97)

        button.priorityBadge = button:CreateFontString(nil, "OVERLAY")
        button.priorityBadge:SetFont(ns.media.font, 9, "OUTLINE")
        button.priorityBadge:SetPoint("TOPLEFT", 7, -7)
        button.priorityBadge:SetTextColor(0.02, 0.88, 0.7)

        button.remaining = button:CreateFontString(nil, "OVERLAY")
        button.remaining:SetFont(ns.media.font, 14, "OUTLINE")
        button.remaining:SetPoint("CENTER")
        button.remaining:SetTextColor(1, 0.86, 0.32)

        button.roleLabel = button:CreateFontString(nil, "OVERLAY")
        button.roleLabel:SetFont(ns.media.font, 9, "OUTLINE")
        button.roleLabel:SetPoint("CENTER")

        button.name = button:CreateFontString(nil, "OVERLAY")
        button.name:SetFont(ns.media.font, 9, "OUTLINE")
        button.name:SetPoint("BOTTOM", button, "TOP", 0, 4)
        button.name:SetWidth(106)
        button.name:SetMaxLines(1)
        button.name:SetTextColor(0.78, 0.84, 0.87)

        frame.slots[index] = button
    end

    frame.choiceBadge = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.choiceBadge:SetSize(24, 16)
    frame.choiceBadge:SetFrameLevel(frame:GetFrameLevel() + 10)
    frame.choiceBadge:EnableMouse(false)
    frame.choiceBadge:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    frame.choiceBadge:SetBackdropColor(0.018, 0.026, 0.034, 0.98)
    frame.choiceBadge:SetBackdropBorderColor(0.02, 0.88, 0.7, 1)
    frame.choiceBadge.label = frame.choiceBadge:CreateFontString(nil, "OVERLAY")
    frame.choiceBadge.label:SetFont(ns.media.font, 8, "OUTLINE")
    frame.choiceBadge.label:SetPoint("CENTER", 0, 0)
    frame.choiceBadge.label:SetText(L("ODER"))
    frame.choiceBadge.label:SetTextColor(0.02, 0.88, 0.7, 1)
    frame.choiceBadge:Hide()

    frame.manaBadge = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.manaBadge:SetSize(58, 16)
    frame.manaBadge:SetFrameLevel(frame:GetFrameLevel() + 10)
    frame.manaBadge:EnableMouse(false)
    frame.manaBadge:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    frame.manaBadge:SetBackdropColor(0.018, 0.026, 0.034, 0.98)
    frame.manaBadge:SetBackdropBorderColor(0.02, 0.88, 0.7, 1)
    frame.manaBadge.label = frame.manaBadge:CreateFontString(nil, "OVERLAY")
    frame.manaBadge.label:SetFont(ns.media.font, 8, "OUTLINE")
    frame.manaBadge.label:SetPoint("CENTER", 0, 0)
    frame.manaBadge.label:SetText("MANA")
    frame.manaBadge.label:SetTextColor(0.02, 0.88, 0.7, 1)
    frame.manaBadge:Hide()

    frame:SetScript("OnUpdate", function(_, elapsed)
        HeliHeal.updateElapsed = (HeliHeal.updateElapsed or 0) + elapsed
        if HeliHeal.updateElapsed >= 0.1 then
            HeliHeal.updateElapsed = 0
            HeliHeal:RefreshDisplay()
        end
    end)

    self.frame = frame
    self.supportFrame = createSupportFrame()

    local dispelFrame = CreateFrame("Frame", "HeliHealDispelCursorFrame", UIParent, "BackdropTemplate")
    dispelFrame:SetFrameStrata("TOOLTIP")
    dispelFrame:EnableMouse(false)
    dispelFrame:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    dispelFrame.icon = dispelFrame:CreateTexture(nil, "ARTWORK")
    dispelFrame.icon:SetPoint("TOPLEFT", 3, -3)
    dispelFrame.icon:SetPoint("BOTTOMRIGHT", -3, 3)
    dispelFrame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    dispelFrame.cooldown = CreateFrame("Cooldown", nil, dispelFrame, "CooldownFrameTemplate")
    dispelFrame.cooldown:SetAllPoints(dispelFrame.icon)
    dispelFrame.cooldown:SetDrawEdge(false)
    dispelFrame.cooldown:SetHideCountdownNumbers(true)
    dispelFrame.remaining = dispelFrame:CreateFontString(nil, "OVERLAY")
    dispelFrame.remaining:SetPoint("CENTER")
    dispelFrame:SetScript("OnUpdate", function(display)
        HeliHeal:UpdateDispelCursorPosition(display)
    end)
    dispelFrame:Hide()
    self.dispelCursorFrame = dispelFrame
end

function HeliHeal:GetSupportDisplayOrder(now)
    if self.classToken ~= "PALADIN" or self.specializationID ~= 65 then return {} end
    now = now or GetTime()
    self:ProcessPaladinArmamentExpirations(now)
    self.supportReadyScratch = self.supportReadyScratch or {}
    self.supportWaitingScratch = self.supportWaitingScratch or {}
    self.supportItemScratch = self.supportItemScratch or {}
    local ready, waiting = self.supportReadyScratch, self.supportWaitingScratch
    clearArray(ready)
    clearArray(waiting)
    local keys = ns.AbilityLibrary:GetPresetSupportKeys(self.db.profile.rotationPreset)
    local ranks = {}
    for rank, abilityKey in ipairs(keys) do ranks[abilityKey] = rank end
    for slotIndex, configuredSlot in ipairs(self.db.profile.slots or {}) do
        local ability = configuredSlot and self:GetSlot(slotIndex)
        local priorityRank = ability and ranks[ability.abilityKey]
        if ability and ability.enabled and priorityRank then
            local usedAt, readyAt, charges
            if ability.maxCharges > 1 then
                local state = self:GetChargeState(slotIndex, ability, now)
                charges = state.baseCharges + state.bonusCharges
                readyAt = charges > 0 and 0 or (state.nextRechargeAt or 0)
                usedAt = readyAt > 0 and (readyAt - ability.cooldown) or nil
            else
                usedAt = self.sessionUses[slotIndex]
                readyAt = usedAt and (usedAt + ability.cooldown) or 0
            end
            local item = self.supportItemScratch[slotIndex] or {}
            self.supportItemScratch[slotIndex] = item
            item.slotIndex = slotIndex
            item.ability = ability
            item.usedAt = usedAt
            item.readyAt = readyAt
            item.remaining = math.max(0, readyAt - now)
            item.charges = charges
            item.cooldownDuration = ability.cooldown
            item.priorityRank = priorityRank
            if item.remaining <= 0 then ready[#ready + 1] = item else waiting[#waiting + 1] = item end
        end
    end
    table.sort(ready, function(a, b) return a.priorityRank < b.priorityRank end)
    table.sort(waiting, waitingBefore)
    for _, item in ipairs(waiting) do ready[#ready + 1] = item end
    return ready
end

function HeliHeal:GetDisplayOrder(now)
    self:ProcessPaladinArmamentExpirations(now)
    if self.monkConduitHeartAt and now >= self.monkConduitHeartAt then
        self.monkConduitHeartAt = nil
        self:ApplyMonkJadeSerpentRecovery(now)
    end
    self.displayReadyScratch = self.displayReadyScratch or {}
    self.displayWaitingScratch = self.displayWaitingScratch or {}
    self.displayItemScratch = self.displayItemScratch or {}
    local ready = self.displayReadyScratch
    local waiting = self.displayWaitingScratch
    clearArray(ready)
    clearArray(waiting)
    local priorityRanks = self:GetActivePriorityRanks()
    local downpourReady = self:IsDownpourReady(now)
    local preferHolyPowerSpender = self.classToken == "PALADIN"
        and ((self.pendingFreeHolyPowerSpenders or 0) > 0 or (self.sessionHolyPower or 0) >= 5)
    local preferredConsumer = self.pendingSwiftness and self.pendingSwiftness.consumerAbilityKey
    local priestApotheosisReady = false
    if self.classToken == "PRIEST" then
        local apotheosisIndex = self:GetSlotIndexByAbilityKey("priest_apotheosis")
        local apotheosis = apotheosisIndex and self:GetSlot(apotheosisIndex)
        local usedAt = apotheosisIndex and self.sessionUses[apotheosisIndex]
        priestApotheosisReady = apotheosis and apotheosis.enabled
            and (not usedAt or now >= usedAt + apotheosis.cooldown) or false
    end

    for slotIndex, configuredSlot in ipairs(self.db.profile.slots) do
        local ability = configuredSlot and self:GetSlot(slotIndex)
        local swiftnessIsArmed = self.pendingSwiftness and self.pendingSwiftness.slotIndex == slotIndex
        local priorityRank = ability and priorityRanks[ability.abilityKey]
        local contextAvailable = ability and ability.abilityKey ~= "downpour" or downpourReady
        if ability and ability.abilityKey == "druid_swiftmend"
            and not self:IsTalentActive("druidVerdantInfusion")
            and not self:HasLocalDruidHot(now) then
            contextAvailable = false
        end
        if ability and self.classToken == "MONK" then
            local mode = self:GetHealingMode()
            local abilityKey = ability.abilityKey
            local teachings = self.monkTeachingsStacks or 0
            if abilityKey == "monk_sheiluns_gift" then
                local clouds = self:GetMonkSheilunCloudState(now)
                contextAvailable = clouds.count >= clouds.goal
            elseif abilityKey == "monk_life_cocoon" then
                contextAvailable = mode == "single"
            elseif abilityKey == "monk_revival" or abilityKey == "monk_restoral"
                or abilityKey == "monk_celestial_conduit" or abilityKey == "monk_yulon"
                or abilityKey == "monk_chiji" then
                contextAvailable = mode == "aoe"
            elseif abilityKey == "monk_enveloping_mist" or abilityKey == "monk_soothing_mist" then
                contextAvailable = mode == "single"
            elseif abilityKey == "monk_vivify" then
                contextAvailable = mode == "single"
            elseif abilityKey == "monk_spinning_crane_kick" then
                -- Standard is the hybrid dungeon/raid strip and deliberately
                -- exposes both melee branches. Only Single and Mana Saving
                -- suppress the AoE filler completely.
                contextAvailable = mode == "standard" or mode == "aoe"
            elseif abilityKey == "monk_tiger_palm" then
                contextAvailable = mode ~= "aoe" and teachings == 0
            elseif abilityKey == "monk_blackout_kick" then
                contextAvailable = mode ~= "aoe" and teachings > 0
            end
        end
        if ability and self.classToken == "PALADIN" then
            local holyPower = self.sessionHolyPower or 0
            local wingsActive = self:IsPaladinWingsActive(now)
            local crusaderActive = self:IsPaladinCrusaderActive(now)
            if (ability.holyPowerCost or 0) > holyPower
                and (self.pendingFreeHolyPowerSpenders or 0) <= 0 then
                contextAvailable = false
            elseif ability.maxHolyPower and holyPower > ability.maxHolyPower then
                contextAvailable = false
            elseif ability.abilityKey == "paladin_judgment" and self:GetPaladinInfusionCharges(now) > 0
                and holyPower > 3 then
                -- Infused Judgment generates two Holy Power. Hold it at four
                -- points so the healing consumer can be used without waste.
                contextAvailable = false
            end
            if ability.abilityKey == "paladin_hammer_of_wrath" then
                contextAvailable = contextAvailable and wingsActive
            elseif ability.abilityKey == "paladin_judgment" then
                contextAvailable = contextAvailable and not wingsActive
            elseif ability.abilityKey == "paladin_flash_of_light" then
                -- Without a locally proven Infusion this expensive emergency
                -- heal must not occupy the deterministic priority strip.
                contextAvailable = contextAvailable and self:GetPaladinInfusionCharges(now) > 0
            elseif ability.abilityKey == "paladin_crusader_strike" then
                contextAvailable = contextAvailable and crusaderActive
            end
            -- Keep ordinary generators in the secondary queue at the Holy
            -- Power cap. The ready-order sorter forces a healing spender into
            -- the primary position first; after that cast, these become valid
            -- follow-up actions. Removing them from the entire queue left the
            -- five-icon strip with only three useful entries.
        end
        if ability and ability.enabled and priorityRank and contextAvailable and not swiftnessIsArmed then
            -- In contextual modes Downpour temporarily occupies Healing Rain's
            -- action-button input, so showing both would duplicate one hotkey.
            if ability.abilityKey == "healing_rain" and downpourReady and priorityRanks.downpour then
                contextAvailable = false
            end
        end
        if ability and ability.enabled and priorityRank and contextAvailable and not swiftnessIsArmed then
            local usedAt
            local readyAt
            local charges
            local trackedText
            local cooldownDuration = ability.cooldown
            if ability.abilityKey == "downpour" and self.pendingDownpour then
                charges = self.pendingDownpour.uses
                readyAt = 0
            elseif ability.abilityKey == "monk_sheiluns_gift" then
                local clouds = self:GetMonkSheilunCloudState(now)
                trackedText = ("%dC"):format(clouds.count)
                readyAt = 0
            elseif (ability.trackedDuration or 0) > 0 then
                local state = self:GetTrackedState(ability, now)
                charges = state.count
                trackedText = ("%d/%d"):format(state.count, state.goal)
                if state.count >= state.goal and state.nextExpiresAt then
                    readyAt = state.nextExpiresAt
                    usedAt = readyAt - ability.trackedDuration
                    cooldownDuration = ability.trackedDuration
                else
                    readyAt = 0
                end
            elseif ability.maxCharges > 1 then
                local state = self:GetChargeState(slotIndex, ability, now)
                charges = state.baseCharges + state.bonusCharges
                local modeMinimums = ability.minimumRecommendedChargesByMode
                local minimumCharges = modeMinimums and tonumber(modeMinimums[self:GetHealingMode()]) or 1
                minimumCharges = math.max(1, math.min(ability.maxCharges, minimumCharges or 1))
                local chargeThresholdMet = state.bonusCharges > 0 or state.baseCharges >= minimumCharges
                readyAt = chargeThresholdMet and 0 or (state.nextRechargeAt or 0)
                usedAt = readyAt > 0 and (readyAt - ability.cooldown) or nil
                if ability.abilityKey == "monk_renewing_mist" then
                    local coverage = self:GetMonkRenewingMistState(now)
                    trackedText = ("%dC %d/%d"):format(charges, coverage.count, coverage.goal)
                    if charges < ability.maxCharges and coverage.count >= coverage.goal
                        and coverage.nextExpiresAt and coverage.nextExpiresAt > readyAt then
                        readyAt = coverage.nextExpiresAt
                        usedAt = coverage.nextStartedAt or (readyAt - (ability.trackedDuration or 20))
                        cooldownDuration = math.max(1, readyAt - usedAt)
                    end
                end
            else
                usedAt = self.sessionUses[slotIndex]
                local localDelay = math.max(ability.cooldown, ability.recommendationLockout or 0)
                readyAt = usedAt and (usedAt + localDelay) or 0
                if (ability.recommendationLockout or 0) > ability.cooldown then
                    cooldownDuration = ability.recommendationLockout
                end
            end
            local atonementReadyAt, atonementStartedAt, atonementDuration =
                self:GetAtonementWindow(ability, now)
            if atonementReadyAt and atonementReadyAt > readyAt then
                readyAt = atonementReadyAt
                usedAt = atonementStartedAt
                cooldownDuration = atonementDuration
            end
            local item = self.displayItemScratch[slotIndex]
            if not item then
                item = {}
                self.displayItemScratch[slotIndex] = item
            end
            item.slotIndex = slotIndex
            item.ability = ability
            item.usedAt = usedAt
            item.readyAt = readyAt
            item.remaining = math.max(0, readyAt - now)
            item.charges = charges
            item.trackedText = trackedText
            item.cooldownDuration = cooldownDuration
            item.priorityRank = priorityRank
            item.preferSpender = preferHolyPowerSpender and (ability.holyPowerCost or 0) > 0 or false
            item.paladinInfusionPriority = self:GetPaladinInfusionConsumerPriority(ability.abilityKey, now)
            item.paladinHandPriority = self:GetPaladinHandOfDivinityPriority(ability.abilityKey, now)
            item.paladinCrusaderPriority = self:IsPaladinCrusaderActive(now)
                and (ability.abilityKey == "paladin_judgment" and 1
                    or ability.abilityKey == "paladin_crusader_strike" and 2 or nil)
                or nil
            item.preferredConsumer = preferredConsumer == ability.abilityKey
            item.druidSoulConsumer = self:IsDruidSoulReady(now)
                and (ability.abilityKey == "druid_rejuvenation" or ability.abilityKey == "druid_regrowth")
                or false
            item.unleashPriority = self:GetUnleashConsumerPriority(ability.abilityKey)
            item.monkTeaPriority = self.classToken == "MONK"
                and self:GetMonkTeaConsumerPriority(ability.abilityKey, now) or nil
            local priestHolyWord = ability.abilityKey == "priest_holy_word_serenity"
                or ability.abilityKey == "priest_holy_word_sanctify"
            item.priestPreApotheosisSpend = priestApotheosisReady and priestHolyWord
                and (charges or 1) >= ability.maxCharges or false
            item.priestHoldForApotheosis = priestApotheosisReady and priestHolyWord
                and (charges or 0) > 0 and (charges or 0) < ability.maxCharges or false
            if item.remaining <= 0 then
                ready[#ready + 1] = item
            else
                waiting[#waiting + 1] = item
            end
        end
    end
    table.sort(ready, readyBefore)
    table.sort(waiting, waitingBefore)

    for _, item in ipairs(waiting) do
        ready[#ready + 1] = item
    end
    return ready
end

function HeliHeal:ApplyDisplaySettings()
    local profile = self.db.profile
    local frame = self.frame
    frame:ClearAllPoints()
    frame:SetPoint(profile.point, UIParent, profile.relativePoint, profile.x, profile.y)
    frame:SetScale(profile.scale)
    frame:EnableMouse(not profile.locked)
    frame:SetShown(profile.enabled and self.supportedClass)
    if self.supportFrame then
        self.supportFrame:ClearAllPoints()
        self.supportFrame:SetPoint(profile.supportWindowPoint or "CENTER", UIParent,
            profile.supportWindowRelativePoint or "CENTER",
            profile.supportWindowX or 0, profile.supportWindowY or -250)
        self.supportFrame:SetScale(profile.supportWindowScale or 1)
        self.supportFrame:EnableMouse(not profile.locked)
        if not profile.enabled or not self.supportedClass or profile.showSupportWindow == false then
            self.supportFrame:Hide()
        end
    end
    if self.dispelCursorFrame and (not profile.enabled or not self.supportedClass
        or not profile.showDispelCursor) then
        self.dispelCursorFrame:Hide()
    end
    self:RefreshDisplay()
end

function HeliHeal:RefreshSupportWindow(now)
    local frame = self.supportFrame
    local profile = self.db and self.db.profile
    local order = frame and self:GetSupportDisplayOrder(now) or nil
    if not frame or not profile or not profile.enabled or profile.showSupportWindow == false
        or not order or #order == 0 then
        if frame then frame:Hide() end
        return
    end
    local width = clamp(profile.supportWindowIconWidth, 24, 128, 46)
    local height = clamp(profile.supportWindowIconHeight, 24, 128, 46)
    local spacing = clamp(profile.supportWindowSpacing, 0, 40, 7)
    local vertical = profile.supportWindowOrientation == "VERTICAL"
    local showPanelBackground = profile.supportWindowShowPanelBackground == true
    local showHeader = profile.supportWindowShowHeader == true
    local showAbilityName = profile.supportWindowShowAbilityName == true
    local showIconBorder = profile.supportWindowShowIconBorder ~= false
    local showHotkey = profile.supportWindowShowHotkey ~= false
    local showCooldown = profile.supportWindowShowCooldown ~= false
    local font, flags = getHudFont(profile), getFontFlags(profile)
    local hotkeySize = clamp(profile.hotkeyFontSize, 7, 20, 9)
    local cooldownSize = clamp(profile.cooldownFontSize, 10, 30, 14)
    local abilityNameSize = clamp(profile.abilityNameFontSize, 7, 20, 9)
    local headerSize = clamp(profile.headerFontSize, 7, 20, 9)
    local hotkeyHeight = clamp(profile.hotkeyBadgeHeight, 12, 44, 18)
    local hotkeyOffsetX = clamp(profile.hotkeyOffsetX, -80, 80, 0)
    local hotkeyOffsetY = clamp(profile.hotkeyOffsetY, -40, 40, -8)
    local iconInset = clamp(profile.supportWindowIconInset, 0, 12, 4)
    local secondaryOffsetX = clamp(profile.supportWindowIconOffsetX, -40, 40, 0)
    local secondaryOffsetY = clamp(profile.supportWindowIconOffsetY, -40, 40, 0)
    local configuredPaddingX = clamp(profile.supportWindowPaddingX, 0, 40, 2)
    local configuredPaddingY = clamp(profile.supportWindowPaddingY, 0, 40, 2)
    local sidePadding = showPanelBackground and math.max(10, configuredPaddingX) or configuredPaddingX
    local crop = getIconCrop(profile.supportWindowIconZoom)
    local accentR, accentG, accentB = getColor(profile.accentColor, DEFAULT_ACCENT)
    local hotkeyR, hotkeyG, hotkeyB = getColor(profile.hotkeyColor, DEFAULT_HOTKEY)
    local cooldownR, cooldownG, cooldownB = getColor(profile.cooldownColor, DEFAULT_COOLDOWN)
    local panelR, panelG, panelB = getColor(profile.panelBackgroundColor, DEFAULT_PANEL)
    local borderR, borderG, borderB = getColor(profile.panelBorderColor, DEFAULT_PANEL_BORDER)
    local iconR, iconG, iconB = getColor(profile.iconBackgroundColor, DEFAULT_ICON_BACKGROUND)
    local nameR, nameG, nameB = getColor(profile.abilityNameColor, DEFAULT_NAME)
    local headerR, headerG, headerB = getColor(profile.headerColor, DEFAULT_ACCENT)
    local hotkeyBackgroundR, hotkeyBackgroundG, hotkeyBackgroundB =
        getColor(profile.hotkeyBackgroundColor, DEFAULT_PANEL)
    local count = math.min(SUPPORT_SLOT_COUNT, #order)
    local bottomPadding = configuredPaddingY
    if showHotkey then
        bottomPadding = math.max(bottomPadding, math.max(0, -hotkeyOffsetY + (hotkeyHeight / 2)) + 2)
    end
    bottomPadding = bottomPadding + math.max(0, -secondaryOffsetY)
    local topPadding = configuredPaddingY
        + (showHeader and (headerSize + 13) or 0)
        + (showAbilityName and (abilityNameSize
            + math.max(6, clamp(profile.abilityNameOffsetY, -40, 60, 4))) or 0)
        + math.max(0, secondaryOffsetY)
    local hotkeyExtra = showHotkey and math.max(0, -hotkeyOffsetY + (hotkeyHeight / 2)) + 2 or 0
    local nameExtra = showAbilityName and (abilityNameSize
        + math.max(6, clamp(profile.abilityNameOffsetY, -40, 60, 4))) or 0
    local verticalGap = spacing + hotkeyExtra + nameExtra
    frame:SetScale(profile.supportWindowScale or 1)
    if showPanelBackground then
        frame:SetBackdropColor(panelR, panelG, panelB,
            clamp(profile.supportWindowPanelBackgroundAlpha, 0, 1, 0.92))
        frame:SetBackdropBorderColor(borderR, borderG, borderB, 0.95)
    else
        frame:SetBackdropColor(0, 0, 0, 0)
        frame:SetBackdropBorderColor(0, 0, 0, 0)
    end
    frame.accent:SetColorTexture(accentR, accentG, accentB, 1)
    frame.accent:SetShown(showPanelBackground)
    frame.title:SetFont(font, headerSize, flags)
    frame.title:ClearAllPoints()
    frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT",
        clamp(profile.headerOffsetX, -80, 80, 10), clamp(profile.headerOffsetY, -50, 30, -9))
    frame.title:SetTextColor(headerR, headerG, headerB, 1)
    frame.title:SetText("DEF / UTILITY")
    frame.title:SetShown(showHeader)
    local totalWidth, previousBadgeWidth, lastOverhang, maxOverhang = 0, nil, 0, 0
    for index = 1, SUPPORT_SLOT_COUNT do
        local button, item = frame.slots[index], order[index]
        if item then
            button:SetSize(width, height)
            button:SetBackdropColor(iconR, iconG, iconB, 1)
            button:ClearAllPoints()
            local configuredSlot = self.db.profile.slots[item.slotIndex]
            local hotkey = configuredSlot.inputKey or ("P" .. item.slotIndex)
            if profile.compactHotkeys ~= false then hotkey = self:FormatHotkeyLabel(hotkey) end
            button.key:SetFont(font, hotkeySize, flags)
            button.key:SetTextColor(hotkeyR, hotkeyG, hotkeyB, 1)
            button.key:SetText(hotkey)
            button.keyBadge:SetHeight(math.max(hotkeyHeight, hotkeySize + 4))
            local badgeWidth = math.max(clamp(profile.hotkeyBadgeMinWidth, 20, 180, 46),
                button.key:GetStringWidth() + clamp(profile.hotkeyBadgePadding, 0, 60, 16))
            button.keyBadge:SetWidth(badgeWidth)
            local layoutBadgeWidth = showHotkey
                and (badgeWidth + (math.abs(hotkeyOffsetX) * 2)) or width
            local overhang = self:GetHotkeyBadgeOverhang(width, layoutBadgeWidth)
            maxOverhang = math.max(maxOverhang, overhang)
            if index == 1 then
                button:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT",
                    sidePadding + overhang + math.max(0, -secondaryOffsetX) + secondaryOffsetX,
                    bottomPadding + secondaryOffsetY)
                totalWidth = overhang + math.max(0, -secondaryOffsetX) + secondaryOffsetX + width
            elseif vertical then
                button:SetPoint("BOTTOM", frame.slots[index - 1], "TOP", 0, verticalGap)
            else
                local badgeSpacing = self:GetBadgeAwareSpacing(
                    width, previousBadgeWidth, width, layoutBadgeWidth, spacing)
                button:SetPoint("LEFT", frame.slots[index - 1], "RIGHT", badgeSpacing, 0)
                totalWidth = totalWidth + badgeSpacing + width
            end
            button:SetBackdropBorderColor(item.remaining <= 0 and accentR or 0.15,
                item.remaining <= 0 and accentG or 0.2,
                item.remaining <= 0 and accentB or 0.23,
                showIconBorder and 1 or 0)
            button.icon:ClearAllPoints()
            if showIconBorder then
                button.icon:SetPoint("TOPLEFT", iconInset, -iconInset)
                button.icon:SetPoint("BOTTOMRIGHT", -iconInset, iconInset)
                button.shadow:Show()
            else
                button.icon:SetAllPoints()
                button.shadow:Hide()
            end
            button.icon:SetTexture(item.ability.icon)
            button.icon:SetTexCoord(crop, 1 - crop, crop, 1 - crop)
            button.icon:SetDesaturated(item.remaining > 0)
            if item.usedAt and item.cooldownDuration > 0 then
                button.cooldown:SetCooldown(item.usedAt, item.cooldownDuration)
            else
                button.cooldown:Clear()
            end
            button.remaining:SetFont(font, cooldownSize, flags)
            button.remaining:ClearAllPoints()
            button.remaining:SetPoint("CENTER", button, "CENTER",
                clamp(profile.cooldownOffsetX, -80, 80, 0),
                clamp(profile.cooldownOffsetY, -80, 80, 0))
            button.remaining:SetTextColor(cooldownR, cooldownG, cooldownB, 1)
            if item.remaining > 0 then
                button.remaining:SetText(formatRemaining(item.remaining))
            elseif item.charges and item.charges > 1 then
                button.remaining:SetText(("×%d"):format(item.charges))
            else
                button.remaining:SetText("")
            end
            button.remaining:SetShown(showCooldown)
            button.keyBadge:ClearAllPoints()
            button.keyBadge:SetPoint("BOTTOM", button, "BOTTOM", hotkeyOffsetX, hotkeyOffsetY)
            button.keyBadge:SetBackdropColor(hotkeyBackgroundR, hotkeyBackgroundG, hotkeyBackgroundB, 0.94)
            button.keyBadge:SetBackdropBorderColor(accentR, accentG, accentB, 0.8)
            button.keyBadge:SetShown(showHotkey)
            button.name:SetFont(font, abilityNameSize, flags)
            button.name:SetTextColor(nameR, nameG, nameB, 1)
            button.name:SetWidth(clamp(profile.abilityNameWidth, 40, 240, 106))
            button.name:ClearAllPoints()
            button.name:SetPoint("BOTTOM", button, "TOP",
                clamp(profile.abilityNameOffsetX, -100, 100, 0),
                clamp(profile.abilityNameOffsetY, -40, 60, 4))
            button.name:SetText(item.ability.name)
            button.name:SetShown(showAbilityName)
            button:Show()
            previousBadgeWidth = layoutBadgeWidth
            lastOverhang = overhang
        else
            button:Hide()
        end
    end
    if vertical then
        local nameWidth = showAbilityName and clamp(profile.abilityNameWidth, 40, 240, 106) or 0
        local contentWidth = math.max(width + (maxOverhang * 2), nameWidth)
        frame:SetSize(contentWidth + (sidePadding * 2) + math.abs(secondaryOffsetX),
            (count * height) + ((count - 1) * verticalGap) + topPadding + bottomPadding)
    else
        frame:SetSize(totalWidth + sidePadding + lastOverhang + math.max(0, secondaryOffsetX),
            height + topPadding + bottomPadding)
    end
    frame:Show()
end

function HeliHeal:UpdateDispelCursorPosition(frame)
    frame = frame or self.dispelCursorFrame
    local profile = self.db and self.db.profile
    if not frame or not profile or type(GetCursorPosition) ~= "function" then return false end

    local cursorX, cursorY = GetCursorPosition()
    local uiScale = UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    uiScale = tonumber(uiScale) or 1
    if uiScale <= 0 then uiScale = 1 end
    local offsetX = clamp(profile.dispelCursorOffsetX, -100, 100, 24)
    local offsetY = clamp(profile.dispelCursorOffsetY, -100, 100, -24)
    local anchorX = (cursorX / uiScale) + offsetX
    local anchorY = (cursorY / uiScale) + offsetY
    if frame.cursorAnchorX == anchorX and frame.cursorAnchorY == anchorY then return true end

    frame.cursorAnchorX = anchorX
    frame.cursorAnchorY = anchorY
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", anchorX, anchorY)
    return true
end

function HeliHeal:RefreshDispelCursor(now)
    local frame = self.dispelCursorFrame
    local profile = self.db and self.db.profile
    if not frame or not profile or not profile.enabled or not self.supportedClass
        or not profile.showDispelCursor or type(GetCursorPosition) ~= "function" then
        if frame then frame:Hide() end
        return
    end
    local dispel, remaining, usedAt = self:GetDispelCooldownState(now)
    if not dispel or remaining <= 0 or not usedAt then
        frame:Hide()
        return
    end

    local size = clamp(profile.dispelCursorSize, 20, 80, 34)
    local font = getHudFont(profile)
    local flags = getFontFlags(profile)
    local accentR, accentG, accentB = getColor(profile.accentColor, DEFAULT_ACCENT)
    local cooldownR, cooldownG, cooldownB = getColor(profile.cooldownColor, DEFAULT_COOLDOWN)
    local backgroundR, backgroundG, backgroundB = getColor(profile.iconBackgroundColor, DEFAULT_ICON_BACKGROUND)

    frame:SetSize(size, size)
    self:UpdateDispelCursorPosition(frame)
    frame:SetBackdropColor(backgroundR, backgroundG, backgroundB, 0.96)
    frame:SetBackdropBorderColor(accentR, accentG, accentB, 1)
    frame.icon:SetTexture(dispel.icon)
    frame.icon:SetDesaturated(true)
    frame.cooldown:SetCooldown(usedAt, dispel.cooldown)
    frame.remaining:SetFont(font, clamp(profile.cooldownFontSize, 10, 30, 14), flags)
    frame.remaining:SetTextColor(cooldownR, cooldownG, cooldownB, 1)
    frame.remaining:SetText(formatRemaining(remaining))
    frame:Show()
end

function HeliHeal:RefreshDisplay()
    if not self.frame or not self.db.profile.enabled then
        if self.supportFrame then self.supportFrame:Hide() end
        if self.dispelCursorFrame then self.dispelCursorFrame:Hide() end
        return
    end

    local now = GetTime()
    self:RefreshDispelCursor(now)
    self:RefreshSupportWindow(now)
    if self.Mana and self.Mana:EvaluateAutoMode(now) then return end
    local order = self:GetDisplayOrder(now)
    local profile = self.db.profile
    local primaryChoiceGroup = profile.showChoiceIndicator ~= false
        and self:GetPrimaryChoiceGroup(order) or nil
    local primaryWidth = clamp(profile.primaryIconWidth or profile.primaryIconSize, 32, 160, 62)
    local primaryHeight = clamp(profile.primaryIconHeight or profile.primaryIconSize, 32, 160, 62)
    local secondaryWidth = clamp(profile.secondaryIconWidth or profile.secondaryIconSize, 24, 128, 46)
    local secondaryHeight = clamp(profile.secondaryIconHeight or profile.secondaryIconSize, 24, 128, 46)
    local primaryOffsetX = clamp(profile.primaryIconOffsetX, -40, 40, 0)
    local primaryOffsetY = clamp(profile.primaryIconOffsetY, -40, 40, 0)
    local secondaryOffsetX = clamp(profile.secondaryIconOffsetX, -40, 40, 0)
    local secondaryOffsetY = clamp(profile.secondaryIconOffsetY, -40, 40, 0)
    local iconInset = clamp(profile.iconInset, 0, 12, 4)
    local hudFont = getHudFont(profile)
    local fontFlags = getFontFlags(profile)
    local hotkeyFontSize = clamp(profile.hotkeyFontSize, 7, 20, 9)
    local abilityNameFontSize = clamp(profile.abilityNameFontSize, 7, 20, 9)
    local headerFontSize = clamp(profile.headerFontSize, 7, 20, 9)
    local accentR, accentG, accentB = getColor(profile.accentColor, DEFAULT_ACCENT)
    local hotkeyR, hotkeyG, hotkeyB = getColor(profile.hotkeyColor, DEFAULT_HOTKEY)
    local cooldownR, cooldownG, cooldownB = getColor(profile.cooldownColor, DEFAULT_COOLDOWN)
    local panelR, panelG, panelB = getColor(profile.panelBackgroundColor, DEFAULT_PANEL)
    local panelBorderR, panelBorderG, panelBorderB = getColor(profile.panelBorderColor, DEFAULT_PANEL_BORDER)
    local iconBackgroundR, iconBackgroundG, iconBackgroundB = getColor(profile.iconBackgroundColor, DEFAULT_ICON_BACKGROUND)
    local hotkeyBackgroundR, hotkeyBackgroundG, hotkeyBackgroundB = getColor(profile.hotkeyBackgroundColor, DEFAULT_PANEL)
    local nameR, nameG, nameB = getColor(profile.abilityNameColor, DEFAULT_NAME)
    local headerR, headerG, headerB = getColor(profile.headerColor, DEFAULT_ACCENT)
    local priorityR, priorityG, priorityB = getColor(profile.priorityColor, DEFAULT_ACCENT)
    local spacing = profile.spacing
    local totalWidth = 0
    local previousSize
    local previousBadgeWidth
    local previousOffsetY
    local lastOverhang = 0
    local configuredPaddingX = clamp(profile.panelPaddingX, 0, 40, 2)
    local configuredPaddingY = clamp(profile.panelPaddingY, 0, 40, 2)
    local sidePadding = profile.showPanelBackground and math.max(10, configuredPaddingX) or configuredPaddingX
    local primaryLeftSafety = math.max(0, -primaryOffsetX)
    local hotkeyHeight = clamp(profile.hotkeyBadgeHeight, 12, 44, 18)
    local hotkeyOffsetY = clamp(profile.hotkeyOffsetY, -40, 40, -8)
    local bottomPadding = configuredPaddingY
    if profile.showHotkey then
        bottomPadding = math.max(bottomPadding, math.max(0, -hotkeyOffsetY + (hotkeyHeight / 2)) + 2)
    end
    bottomPadding = bottomPadding + math.max(0, -math.min(primaryOffsetY, secondaryOffsetY))
    local topPadding = configuredPaddingY
        + (profile.showHeader and (headerFontSize + 13) or 0)
        + (profile.showAbilityName and (abilityNameFontSize
            + math.max(6, clamp(profile.abilityNameOffsetY, -40, 60, 4))) or 0)
        + math.max(0, math.max(primaryOffsetY, secondaryOffsetY))

    if profile.showPanelBackground then
        self.frame:SetBackdropColor(panelR, panelG, panelB,
            clamp(profile.panelBackgroundAlpha, 0, 1, 0.92))
        self.frame:SetBackdropBorderColor(panelBorderR, panelBorderG, panelBorderB, 0.95)
    else
        self.frame:SetBackdropColor(0, 0, 0, 0)
        self.frame:SetBackdropBorderColor(0, 0, 0, 0)
    end
    self.frame.accent:SetColorTexture(accentR, accentG, accentB, 1)
    self.frame.accent:SetShown(profile.showPanelBackground)
    self.frame.title:SetShown(profile.showHeader)
    self.frame.title:SetFont(hudFont, headerFontSize, fontFlags)
    self.frame.title:ClearAllPoints()
    self.frame.title:SetPoint("TOPLEFT", self.frame, "TOPLEFT",
        clamp(profile.headerOffsetX, -80, 80, 10), clamp(profile.headerOffsetY, -50, 30, -9))
    self.frame.title:SetTextColor(headerR, headerG, headerB, 1)
    self.frame.title:SetText("HELIHEAL  •  " .. self:GetHealingModeLabel():upper())
    self.frame.choiceBadge:Hide()
    self.frame.manaBadge:Hide()

    for displayIndex = 1, DISPLAY_SLOT_COUNT do
        local button = self.frame.slots[displayIndex]
        local item = order[displayIndex]
        if item then
            local choiceMember = primaryChoiceGroup and displayIndex <= 2
                and item.ability.choiceGroup == primaryChoiceGroup or false
            local usePrimaryStyle = displayIndex == 1 or choiceMember
            local width = usePrimaryStyle and primaryWidth or secondaryWidth
            local height = usePrimaryStyle and primaryHeight or secondaryHeight
            local currentOffsetY = usePrimaryStyle and primaryOffsetY or secondaryOffsetY
            local configuredSlot = self.db.profile.slots[item.slotIndex]
            local hotkeyLabel = configuredSlot.inputKey or ("P" .. item.slotIndex)
            if profile.compactHotkeys ~= false then
                hotkeyLabel = self:FormatHotkeyLabel(hotkeyLabel)
            end
            button.key:SetText(hotkeyLabel)
            button.key:SetFont(hudFont, hotkeyFontSize, fontFlags)
            button.key:SetTextColor(hotkeyR, hotkeyG, hotkeyB, 1)
            button.keyBadge:SetHeight(math.max(hotkeyHeight, hotkeyFontSize + 4))
            button.keyBadge:SetBackdropColor(hotkeyBackgroundR, hotkeyBackgroundG, hotkeyBackgroundB, 0.94)
            local badgeWidth = math.max(clamp(profile.hotkeyBadgeMinWidth, 20, 180, 46),
                button.key:GetStringWidth() + clamp(profile.hotkeyBadgePadding, 0, 60, 16))
            button.keyBadge:SetWidth(badgeWidth)
            button.keyBadge:ClearAllPoints()
            button.keyBadge:SetPoint("BOTTOM", button, "BOTTOM",
                clamp(profile.hotkeyOffsetX, -80, 80, 0), hotkeyOffsetY)
            local layoutBadgeWidth = profile.showHotkey
                and (badgeWidth + (math.abs(clamp(profile.hotkeyOffsetX, -80, 80, 0)) * 2)) or width
            local overhang = self:GetHotkeyBadgeOverhang(width, layoutBadgeWidth)

            button:SetSize(width, height)
            button:SetBackdropColor(iconBackgroundR, iconBackgroundG, iconBackgroundB, 1)
            button:ClearAllPoints()
            if displayIndex == 1 then
                button:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMLEFT",
                    sidePadding + overhang + primaryLeftSafety + primaryOffsetX, bottomPadding + primaryOffsetY)
                totalWidth = overhang + primaryLeftSafety + primaryOffsetX + width
                if self:ShouldShowAutomaticManaBadge() then
                    local badgeBottomOffset = self:GetChoiceBadgeBottomOffset(
                        profile.showAbilityName,
                        abilityNameFontSize,
                        clamp(profile.abilityNameOffsetY, -40, 60, 4))
                    badgeBottomOffset = self:GetManaBadgeBottomOffset(
                        badgeBottomOffset, primaryChoiceGroup ~= nil)
                    self.frame.manaBadge:ClearAllPoints()
                    self.frame.manaBadge:SetPoint("BOTTOM", button, "TOP", 0, badgeBottomOffset)
                    self.frame.manaBadge:SetBackdropColor(panelR, panelG, panelB, 0.98)
                    local manaSavingActive = self.Mana.autoModeActive == true
                        and self:GetHealingMode() == "mana"
                    self.frame.manaBadge:SetBackdropBorderColor(accentR, accentG, accentB,
                        manaSavingActive and 1 or 0.55)
                    self.frame.manaBadge.label:SetFont(hudFont, 8, fontFlags)
                    local manaPercent = self.Mana and self.Mana:GetPercent()
                    self.frame.manaBadge.label:SetText(manaPercent
                        and ("%s %d%%"):format(manaSavingActive and "MANA" or "AUTO",
                            math.floor((manaPercent * 100) + 0.5))
                        or (manaSavingActive and "MANA" or "AUTO"))
                    self.frame.manaBadge.label:SetTextColor(
                        manaSavingActive and accentR or 0.60,
                        manaSavingActive and accentG or 0.70,
                        manaSavingActive and accentB or 0.74, 1)
                    self.frame.manaBadge:Show()
                end
            else
                local badgeSpacing = self:GetBadgeAwareSpacing(
                    previousSize, previousBadgeWidth, width, layoutBadgeWidth, spacing)
                if displayIndex == 2 and not primaryChoiceGroup then
                    badgeSpacing = badgeSpacing + secondaryOffsetX
                end
                button:SetPoint("LEFT", self.frame.slots[displayIndex - 1], "RIGHT",
                    badgeSpacing, currentOffsetY - (previousOffsetY or 0))
                totalWidth = totalWidth + badgeSpacing + width
                if displayIndex == 2 and primaryChoiceGroup then
                    local choiceBadgeBottomOffset = self:GetChoiceBadgeBottomOffset(
                        profile.showAbilityName,
                        abilityNameFontSize,
                        clamp(profile.abilityNameOffsetY, -40, 60, 4))
                    self.frame.choiceBadge:ClearAllPoints()
                    self.frame.choiceBadge:SetPoint("BOTTOM", self.frame.slots[1], "TOPRIGHT",
                        badgeSpacing / 2, choiceBadgeBottomOffset)
                    self.frame.choiceBadge:SetBackdropColor(panelR, panelG, panelB, 0.98)
                    self.frame.choiceBadge:SetBackdropBorderColor(accentR, accentG, accentB, 1)
                    self.frame.choiceBadge.label:SetFont(hudFont, 8, fontFlags)
                    self.frame.choiceBadge.label:SetText(L("ODER"))
                    self.frame.choiceBadge.label:SetTextColor(accentR, accentG, accentB, 1)
                    self.frame.choiceBadge:Show()
                end
            end

            button.icon:ClearAllPoints()
            if profile.showIconBorder then
                button.icon:SetPoint("TOPLEFT", iconInset, -iconInset)
                button.icon:SetPoint("BOTTOMRIGHT", -iconInset, iconInset)
                button.shadow:Show()
            else
                button.icon:SetAllPoints()
                button.shadow:Hide()
            end
            local crop = getIconCrop(usePrimaryStyle and profile.primaryIconZoom or profile.secondaryIconZoom)
            button.icon:SetTexCoord(crop, 1 - crop, crop, 1 - crop)

            button.icon:SetTexture(item.ability.icon)
            button.icon:SetDesaturated(item.remaining > 0)
            button.name:SetText(item.ability.name)
            button.priorityBadge:SetFont(hudFont, clamp(profile.priorityFontSize, 7, 20, 9), fontFlags)
            button.priorityBadge:ClearAllPoints()
            button.priorityBadge:SetPoint("TOPLEFT", button, "TOPLEFT",
                clamp(profile.priorityOffsetX, -80, 80, 7), clamp(profile.priorityOffsetY, -80, 80, -7))
            button.priorityBadge:SetTextColor(priorityR, priorityG, priorityB, 1)
            button.priorityBadge:SetText(("P%d"):format(item.priorityRank))
            local roleLabel = profile.showRoleLabel and item.ability.roleLabel or nil
            local roleR, roleG, roleB
            if roleLabel then
                roleR, roleG, roleB = getColor(
                    profile.roleColors and profile.roleColors[roleLabel], DEFAULT_ROLE_COLORS[roleLabel])
            end
            local roleSize = clamp(profile.roleLabelSize, 7, 24, 10)
            button.roleLabel:SetFont(hudFont, usePrimaryStyle and roleSize or math.max(7, roleSize - 2), fontFlags)
            button.roleLabel:ClearAllPoints()
            button.roleLabel:SetPoint("CENTER", button, "CENTER",
                clamp(profile.roleLabelOffsetX, -80, 80, 0), clamp(profile.roleLabelOffsetY, -80, 80, 0))
            button.roleLabel:SetText(roleLabel or "")
            if roleR then button.roleLabel:SetTextColor(roleR, roleG, roleB) end
            button.remaining:SetFont(hudFont, clamp(profile.cooldownFontSize, 10, 30, 14), fontFlags)
            button.remaining:ClearAllPoints()
            button.remaining:SetPoint("CENTER", button, "CENTER",
                clamp(profile.cooldownOffsetX, -80, 80, 0), clamp(profile.cooldownOffsetY, -80, 80, 0))
            button.remaining:SetTextColor(cooldownR, cooldownG, cooldownB, 1)
            button.name:SetFont(hudFont, abilityNameFontSize, fontFlags)
            button.name:SetTextColor(nameR, nameG, nameB, 1)
            button.name:SetWidth(clamp(profile.abilityNameWidth, 40, 240, 106))
            button.name:ClearAllPoints()
            button.name:SetPoint("BOTTOM", button, "TOP",
                clamp(profile.abilityNameOffsetX, -100, 100, 0), clamp(profile.abilityNameOffsetY, -40, 60, 4))
            if item.trackedText then
                button.remaining:SetText(item.trackedText)
            elseif item.remaining > 0 then
                button.remaining:SetText(formatRemaining(item.remaining))
            elseif item.charges and item.charges > 1 then
                button.remaining:SetText(("×%d"):format(item.charges))
            else
                button.remaining:SetText("")
            end
            button.keyBadge:SetShown(profile.showHotkey)
            button.remaining:SetShown(profile.showCooldown)
            button.roleLabel:SetShown(roleLabel ~= nil and item.remaining <= 0
                and not item.trackedText and not (item.charges and item.charges > 1))
            button.name:SetShown(profile.showAbilityName)
            button.priorityBadge:SetShown(profile.showPriorityBadge and not choiceMember)

            if item.remaining > 0 and item.usedAt and item.cooldownDuration > 0 then
                button.cooldown:SetCooldown(item.usedAt, item.cooldownDuration)
                button:SetBackdropBorderColor(0.15, 0.2, 0.23, profile.showIconBorder and 1 or 0)
                button.keyBadge:SetBackdropBorderColor(0.18, 0.24, 0.27, 1)
            else
                button.cooldown:Clear()
                if displayIndex == 1 or choiceMember then
                    button:SetBackdropBorderColor(accentR, accentG, accentB, profile.showIconBorder and 1 or 0)
                    button.keyBadge:SetBackdropBorderColor(accentR, accentG, accentB, 1)
                else
                    button:SetBackdropBorderColor(0.22, 0.3, 0.34, profile.showIconBorder and 1 or 0)
                    button.keyBadge:SetBackdropBorderColor(0.16, 0.24, 0.27, 1)
                end
            end
            button:Show()
            previousSize = width
            previousBadgeWidth = layoutBadgeWidth
            previousOffsetY = currentOffsetY
            lastOverhang = overhang
        else
            button:Hide()
        end
    end

    if #order == 0 then
        self.frame:SetSize(profile.showPanelBackground and 280 or 1, profile.showPanelBackground and 76 or 1)
    else
        self.frame:SetSize(totalWidth + lastOverhang + (sidePadding * 2),
            math.max(primaryHeight, secondaryHeight) + topPadding + bottomPadding)
    end
end
