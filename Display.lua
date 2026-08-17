local _, ns = ...
local HeliHeal = ns.addon
local L = ns.L or function(value, ...) return select("#", ...) > 0 and value:format(...) or value end

local DISPLAY_SLOT_COUNT = 5
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
    if a.priestPreApotheosisSpend ~= b.priestPreApotheosisSpend then
        return a.priestPreApotheosisSpend
    end
    if a.priestHoldForApotheosis ~= b.priestHoldForApotheosis then
        return not a.priestHoldForApotheosis
    end
    if a.preferSpender ~= b.preferSpender then return a.preferSpender end
    if a.preferredConsumer ~= b.preferredConsumer then return a.preferredConsumer end
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

    frame:SetScript("OnUpdate", function(_, elapsed)
        HeliHeal.updateElapsed = (HeliHeal.updateElapsed or 0) + elapsed
        if HeliHeal.updateElapsed >= 0.1 then
            HeliHeal.updateElapsed = 0
            HeliHeal:RefreshDisplay()
        end
    end)

    self.frame = frame
end

function HeliHeal:GetDisplayOrder(now)
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
        if ability and self.classToken == "PALADIN" then
            local holyPower = self.sessionHolyPower or 0
            local holyPowerGain = self:GetHolyPowerDelta(ability)
            if (ability.holyPowerCost or 0) > holyPower
                and (self.pendingFreeHolyPowerSpenders or 0) <= 0 then
                contextAvailable = false
            elseif ability.maxHolyPower and holyPower > ability.maxHolyPower then
                contextAvailable = false
            elseif holyPowerGain > 0 and holyPower >= 5 then
                contextAvailable = false
            end
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
            if ability.abilityKey == "downpour" and self.pendingDownpour then
                charges = self.pendingDownpour.uses
                readyAt = 0
            elseif (ability.trackedDuration or 0) > 0 then
                local state = self:GetTrackedState(ability, now)
                charges = state.count
                trackedText = ("%d/%d"):format(state.count, state.goal)
                if state.count >= state.goal and state.nextExpiresAt then
                    readyAt = state.nextExpiresAt
                    usedAt = readyAt - ability.trackedDuration
                else
                    readyAt = 0
                end
            elseif ability.maxCharges > 1 then
                local state = self:GetChargeState(slotIndex, ability, now)
                charges = state.baseCharges + state.bonusCharges
                readyAt = charges > 0 and 0 or (state.nextRechargeAt or 0)
                usedAt = readyAt > 0 and (readyAt - ability.cooldown) or nil
            else
                usedAt = self.sessionUses[slotIndex]
                readyAt = usedAt and (usedAt + ability.cooldown) or 0
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
            item.priorityRank = priorityRank
            item.preferSpender = preferHolyPowerSpender and (ability.holyPowerCost or 0) > 0 or false
            item.preferredConsumer = preferredConsumer == ability.abilityKey
            item.unleashPriority = self:GetUnleashConsumerPriority(ability.abilityKey)
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
    self:RefreshDisplay()
end

function HeliHeal:RefreshDisplay()
    if not self.frame or not self.db.profile.enabled then
        return
    end

    local now = GetTime()
    local order = self:GetDisplayOrder(now)
    local profile = self.db.profile
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

    for displayIndex = 1, DISPLAY_SLOT_COUNT do
        local button = self.frame.slots[displayIndex]
        local item = order[displayIndex]
        if item then
            local width = displayIndex == 1 and primaryWidth or secondaryWidth
            local height = displayIndex == 1 and primaryHeight or secondaryHeight
            local currentOffsetY = displayIndex == 1 and primaryOffsetY or secondaryOffsetY
            local configuredSlot = self.db.profile.slots[item.slotIndex]
            button.key:SetText(configuredSlot.inputKey or ("P" .. item.slotIndex))
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
            else
                local badgeSpacing = self:GetBadgeAwareSpacing(
                    previousSize, previousBadgeWidth, width, layoutBadgeWidth, spacing)
                if displayIndex == 2 then badgeSpacing = badgeSpacing + secondaryOffsetX end
                local previousOffsetY = displayIndex == 2 and primaryOffsetY or secondaryOffsetY
                button:SetPoint("LEFT", self.frame.slots[displayIndex - 1], "RIGHT",
                    badgeSpacing, currentOffsetY - previousOffsetY)
                totalWidth = totalWidth + badgeSpacing + width
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
            local crop = getIconCrop(displayIndex == 1 and profile.primaryIconZoom or profile.secondaryIconZoom)
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
            button.roleLabel:SetFont(hudFont, displayIndex == 1 and roleSize or math.max(7, roleSize - 2), fontFlags)
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
            button.priorityBadge:SetShown(profile.showPriorityBadge)

            if item.remaining > 0 and item.usedAt and item.ability.cooldown > 0 then
                button.cooldown:SetCooldown(item.usedAt, item.ability.cooldown)
                button:SetBackdropBorderColor(0.15, 0.2, 0.23, profile.showIconBorder and 1 or 0)
                button.keyBadge:SetBackdropBorderColor(0.18, 0.24, 0.27, 1)
            else
                button.cooldown:Clear()
                if displayIndex == 1 then
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
