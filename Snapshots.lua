local _, ns = ...
local HeliHeal = ns.addon

local MAX_SNAPSHOTS = 20
local ATTEMPT_WINDOW = 4
local ATTEMPT_THRESHOLD = 6
local ACKNOWLEDGEMENT_GRACE = 3
local FAILURE_THRESHOLD = 3
local REJECTION_BACKOFF = 5
local DUPLICATE_COOLDOWN = 60

local function countEntries(value)
    local count = 0
    for _ in pairs(value or {}) do count = count + 1 end
    return count
end

local function readableTimestamp()
    if type(GetServerTime) == "function" then
        local ok, value = pcall(GetServerTime)
        if ok and tonumber(value) then return tonumber(value) end
    end
    if type(time) == "function" then
        local ok, value = pcall(time)
        if ok and tonumber(value) then return tonumber(value) end
    end
    return 0
end

local function formatTimestamp(timestamp)
    if timestamp > 0 and type(date) == "function" then
        local ok, value = pcall(date, "%Y-%m-%d %H:%M:%S", timestamp)
        if ok and value then return value end
    end
    return "unknown"
end

local function safeText(value)
    value = tostring(value == nil and "nil" or value)
    return value:gsub("[\r\n]", " ")
end

function HeliHeal:GetRotationSnapshots()
    if not self.db or not self.db.global then return {} end
    if type(self.db.global.rotationSnapshots) ~= "table" then
        self.db.global.rotationSnapshots = {}
    end
    return self.db.global.rotationSnapshots
end

function HeliHeal:GetRotationStateFingerprint(now)
    if not self.db or not self.db.profile or not self.GetDisplayOrder then return nil end
    now = now or GetTime()
    local order = self:GetDisplayOrder(now)
    local parts = {
        tostring(self.db.profile.rotationPreset or "?"),
        tostring(self.GetHealingMode and self:GetHealingMode() or self.db.profile.healingMode or "standard"),
        tostring(self.sessionHolyPower or 0),
        tostring(self.pendingFreeHolyPowerSpenders or 0),
        tostring(self.paladinNextArmamentType or "none"),
        tostring(self.monkTeachingsStacks or 0),
    }
    for index = 1, math.min(5, #order) do
        local item = order[index]
        parts[#parts + 1] = table.concat({
            tostring(item.slotIndex or 0),
            tostring(item.ability and item.ability.abilityKey or "?"),
            tostring(item.charges or "-"),
            item.paladinResourceBlocked and "blocked" or "ready",
            tostring(item.trackedText or "-"),
        }, ":")
    end
    return table.concat(parts, "|")
end

function HeliHeal:BuildRotationSnapshotReport(reason, context, now)
    now = now or GetTime()
    context = context or {}
    local timestamp = readableTimestamp()
    local lines = {
        "HeliHeal rotation snapshot",
        "Classification: suspected stuck rotation (diagnostic candidate, not proof of an addon fault)",
        "Captured: " .. formatTimestamp(timestamp),
        "Reason: " .. safeText(reason or "manual"),
        "Input: key=" .. safeText(context.inputKey or "manual")
            .. "; attempts=" .. safeText(context.attempts or 0)
            .. "; failures=" .. safeText(context.failures or 0)
            .. "; window=" .. safeText(context.window or 0) .. "s"
            .. "; pendingAge=" .. safeText(context.pendingAge or 0) .. "s"
            .. "; slot=" .. safeText(context.slotIndex or "n/a"),
    }

    if self.BuildDiagnosticReport then
        lines[#lines + 1] = "Diagnostic: " .. self:BuildDiagnosticReport(true)
    end

    local order = self.GetDisplayOrder and self:GetDisplayOrder(now) or {}
    lines[#lines + 1] = "Recommendations:"
    for index = 1, math.min(5, #order) do
        local item = order[index]
        local ability = item.ability or {}
        lines[#lines + 1] = ("  %d. %s [%s, spell=%s, slot=%s, remaining=%.1f, charges=%s, tracked=%s, blocked=%s]"):format(
            index,
            safeText(ability.name or ability.abilityKey or "unknown"),
            safeText(ability.abilityKey or "unknown"),
            safeText(ability.spellID or "?"),
            safeText(item.slotIndex or "?"),
            tonumber(item.remaining) or 0,
            safeText(item.charges or "-"),
            safeText(item.trackedText or "-"),
            tostring(item.paladinResourceBlocked == true))
    end
    if #order == 0 then lines[#lines + 1] = "  none" end

    local talent = self.talentSnapshot or {}
    local activeTalents = {}
    for key, value in pairs(talent) do
        if value == true and key ~= "available" then activeTalents[#activeTalents + 1] = tostring(key) end
    end
    table.sort(activeTalents)
    lines[#lines + 1] = "Active talents: " .. (#activeTalents > 0 and table.concat(activeTalents, ",") or "none/read unavailable")

    local pending = {}
    for slotIndex, acknowledgement in pairs(self.pendingAcknowledgements or {}) do
        pending[#pending + 1] = tostring(slotIndex) .. "@" .. safeText(acknowledgement.observedAt or "?")
    end
    table.sort(pending)
    lines[#lines + 1] = "Pending acknowledgements: " .. (#pending > 0 and table.concat(pending, ",") or "none")
    lines[#lines + 1] = ("Local state: uses=%d; charges=%d; tracked=%d; spendHistory=%d; holyPower=%s; freeSpenders=%s; infusion=%s; handUses=%s; armament=%s; armamentEffects=%d"):format(
        countEntries(self.sessionUses), countEntries(self.sessionCharges), countEntries(self.sessionTimedEffects),
        countEntries(self.sessionSpendHistory), safeText(self.sessionHolyPower or 0),
        safeText(self.pendingFreeHolyPowerSpenders or 0),
        safeText(self.GetPaladinInfusionCharges and self:GetPaladinInfusionCharges(now) or 0),
        safeText(self.pendingPaladinHandOfDivinity and self.pendingPaladinHandOfDivinity.uses or 0),
        safeText(self.paladinNextArmamentType or "none"), countEntries(self.paladinArmamentExpirations))
    local chargeLines = {}
    for slotIndex, state in pairs(self.sessionCharges or {}) do
        local ability = self.GetSlot and self:GetSlot(slotIndex)
        local nextRechargeAt = tonumber(state.nextRechargeAt)
        chargeLines[#chargeLines + 1] = ("slot%s:%s base=%s bonus=%s next=%.1fs rejected=%s history=%s"):format(
            safeText(slotIndex), safeText(ability and ability.abilityKey or "unknown"),
            safeText(state.baseCharges or 0), safeText(state.bonusCharges or 0),
            nextRechargeAt and math.max(0, nextRechargeAt - now) or 0,
            safeText(state.rejectedChargeReconciliations or 0),
            table.concat((self.sessionSpendHistory and self.sessionSpendHistory[slotIndex]) or {}, ","))
    end
    table.sort(chargeLines)
    lines[#lines + 1] = "Charge ledger: " .. (#chargeLines > 0 and table.concat(chargeLines, " | ") or "none")
    lines[#lines + 1] = "Fingerprint: " .. safeText(context.fingerprint or self:GetRotationStateFingerprint(now) or "unavailable")
    return table.concat(lines, "\n"), timestamp
end

function HeliHeal:CaptureRotationSnapshot(reason, context, now)
    local snapshots = self:GetRotationSnapshots()
    local report, timestamp = self:BuildRotationSnapshotReport(reason, context, now)
    local primary = self.GetDisplayOrder and self:GetDisplayOrder(now or GetTime())[1]
    self.rotationSnapshotSequence = (self.rotationSnapshotSequence or 0) + 1
    local snapshot = {
        id = tostring(timestamp) .. "-" .. tostring(self.rotationSnapshotSequence),
        timestamp = timestamp,
        capturedAt = formatTimestamp(timestamp),
        reason = tostring(reason or "manual"),
        abilityName = primary and primary.ability and primary.ability.name or "No recommendation",
        abilityKey = primary and primary.ability and primary.ability.abilityKey or nil,
        report = report,
    }
    table.insert(snapshots, 1, snapshot)
    while #snapshots > MAX_SNAPSHOTS do table.remove(snapshots) end
    if self.optionsWindow and self.optionsWindow.pages and self.optionsWindow.pages.snapshots
        and self.optionsWindow.pages.snapshots.RefreshSnapshots then
        self.optionsWindow.pages.snapshots:RefreshSnapshots(snapshot.id)
    end
    return snapshot
end

function HeliHeal:ClearRotationSnapshots()
    local snapshots = self:GetRotationSnapshots()
    for index = #snapshots, 1, -1 do snapshots[index] = nil end
    self.rotationStuckCandidate = nil
    if self.optionsWindow and self.optionsWindow.pages and self.optionsWindow.pages.snapshots
        and self.optionsWindow.pages.snapshots.RefreshSnapshots then
        self.optionsWindow.pages.snapshots:RefreshSnapshots()
    end
end

function HeliHeal:CaptureRotationStuckCandidate(candidate, reason, context, now)
    if not candidate or candidate.captured then return false end
    now = now or GetTime()
    local previous = self.lastAutomaticRotationSnapshot
    if previous and ((previous.abilityKey and previous.abilityKey == candidate.abilityKey)
            or (not previous.abilityKey and previous.fingerprint == candidate.fingerprint))
        and now - previous.capturedAt < DUPLICATE_COOLDOWN then
        candidate.captured = true
        return false
    end
    candidate.captured = true
    self.lastAutomaticRotationSnapshot = {
        abilityKey = candidate.abilityKey,
        fingerprint = candidate.fingerprint,
        capturedAt = now,
    }
    context = context or {}
    context.inputKey = context.inputKey or candidate.inputKey
    context.slotIndex = context.slotIndex or candidate.slotIndex
    context.attempts = context.attempts or candidate.attempts
    context.window = context.window
        or math.floor((now - candidate.startedAt) * 10 + 0.5) / 10
    context.fingerprint = context.fingerprint or candidate.fingerprint
    local snapshot = self:CaptureRotationSnapshot(reason, context, now)
    if self.Print then
        self:Print((ns.L or function(value, ...) return value:format(...) end)(
            "Rotations-Snapshot gespeichert: %s", snapshot.abilityName or "?"))
    end
    return true
end

function HeliHeal:GetRotationRejectionReadyAt(slotIndex, now)
    local state = self.rotationRejectionBackoff and self.rotationRejectionBackoff[slotIndex]
    if not state then return nil end
    now = now or GetTime()
    if now >= (tonumber(state.untilAt) or 0) then
        self.rotationRejectionBackoff[slotIndex] = nil
        return nil
    end
    return state.untilAt, state.duration
end

function HeliHeal:BackoffRejectedRotationSlot(slotIndex, now)
    now = now or GetTime()
    self.rotationRejectionBackoff = self.rotationRejectionBackoff or {}
    self.rotationRejectionBackoff[slotIndex] = {
        untilAt = now + REJECTION_BACKOFF,
        duration = REJECTION_BACKOFF,
    }
    self.rotationStuckCandidate = nil
    if self.RefreshDisplay then self:RefreshDisplay() end
    return true
end

function HeliHeal:ClearRotationRejectionBackoff(slotIndex)
    if self.rotationRejectionBackoff then self.rotationRejectionBackoff[slotIndex] = nil end
end

function HeliHeal:ReconcileRejectedChargeSlot(slotIndex, now)
    local ability = self.GetSlot and self:GetSlot(slotIndex)
    if not ability or (tonumber(ability.maxCharges) or 1) <= 1 then
        return false
    end
    now = now or GetTime()
    local state = self.GetChargeState and self:GetChargeState(slotIndex, ability, now)
    if not state or (tonumber(state.baseCharges) or 0) <= 0 then return false end

    -- A generic failed cast does not establish a missing charge (range,
    -- target and GCD failures use the same event). Keep this compatibility
    -- entry point non-mutating; only the retry backoff is justified.
    return false
end

function HeliHeal:RecordRotationInputFailure(slotIndex, spellID, now)
    now = now or GetTime()
    local candidate = self.rotationStuckCandidate
    if not candidate or candidate.slotIndex ~= slotIndex or candidate.captured then return false end
    local primary = self.GetDisplayOrder and self:GetDisplayOrder(now)[1]
    local fingerprint = self:GetRotationStateFingerprint(now)
    if not primary or primary.slotIndex ~= slotIndex or fingerprint ~= candidate.fingerprint then
        self.rotationStuckCandidate = nil
        return false
    end
    if not candidate.firstFailureAt or now < candidate.firstFailureAt
        or now - candidate.firstFailureAt > ATTEMPT_WINDOW then
        candidate.firstFailureAt = now
        candidate.failures = 1
    else
        candidate.failures = (candidate.failures or 0) + 1
    end
    if candidate.failures < FAILURE_THRESHOLD then return false end
    local pending = self.pendingAcknowledgements and self.pendingAcknowledgements[slotIndex]
    local pendingAt = pending and tonumber(pending.observedAt)
    local captured = self:CaptureRotationStuckCandidate(candidate,
        "Blizzard repeatedly rejected the still-recommended primary ability", {
            spellID = spellID,
            failures = candidate.failures,
            pendingAge = pendingAt and math.max(0, now - pendingAt) or 0,
        }, now)
    local reconciled = self:ReconcileRejectedChargeSlot(slotIndex, now)
    local backedOff = self:BackoffRejectedRotationSlot(slotIndex, now)
    return captured or reconciled or backedOff
end

function HeliHeal:RecordRotationAcknowledgementTimeout(slotIndex, pending, now)
    now = now or GetTime()
    local candidate = self.rotationStuckCandidate
    if not candidate or candidate.slotIndex ~= slotIndex or candidate.captured
        or (candidate.attempts or 0) < ATTEMPT_THRESHOLD then
        return false
    end
    local pendingAt = pending and tonumber(pending.observedAt)
    local primary = self.GetDisplayOrder and self:GetDisplayOrder(now)[1]
    local fingerprint = self:GetRotationStateFingerprint(now)
    if not pendingAt or now < pendingAt or now - pendingAt < 4.9
        or not primary or primary.slotIndex ~= slotIndex or fingerprint ~= candidate.fingerprint then
        return false
    end
    local captured = self:CaptureRotationStuckCandidate(candidate,
        "No cast result arrived before the input acknowledgement timed out", {
            pendingAge = math.floor((now - pendingAt) * 10 + 0.5) / 10,
            failures = candidate.failures or 0,
        }, now)
    local backedOff = self:BackoffRejectedRotationSlot(slotIndex, now)
    return captured or backedOff
end

function HeliHeal:TrackRotationInputAttempt(inputKey, slotIndex, now)
    if not self.GetDisplayOrder or not inputKey then return false end
    now = now or GetTime()
    local order = self:GetDisplayOrder(now)
    local primary = order[1]
    if not primary or primary.slotIndex ~= slotIndex then
        self.rotationStuckCandidate = nil
        return false
    end
    local fingerprint = self:GetRotationStateFingerprint(now)
    local candidate = self.rotationStuckCandidate
    if not candidate or candidate.inputKey ~= inputKey or candidate.slotIndex ~= slotIndex
        or candidate.fingerprint ~= fingerprint or now < candidate.startedAt
        or now - candidate.startedAt > ATTEMPT_WINDOW then
        candidate = {
            inputKey = inputKey,
            slotIndex = slotIndex,
            fingerprint = fingerprint,
            abilityKey = primary.ability and primary.ability.abilityKey,
            startedAt = now,
            lastAttemptAt = now,
            attempts = 1,
        }
        self.rotationStuckCandidate = candidate
    else
        if now - candidate.lastAttemptAt < 0.08 then return false end
        candidate.lastAttemptAt = now
        candidate.attempts = candidate.attempts + 1
    end
    if candidate.attempts < ATTEMPT_THRESHOLD or candidate.captured then return false end

    local pending = self.pendingAcknowledgements and self.pendingAcknowledgements[slotIndex]
    local pendingAt = pending and tonumber(pending.observedAt)
    if not pending or not pendingAt or now < pendingAt or now - pendingAt < ACKNOWLEDGEMENT_GRACE
        or (pending.generation ~= nil and pending.generation ~= (self.inputGeneration or 0)) then
        return false
    end

    local captured = self:CaptureRotationStuckCandidate(candidate,
        "Repeated primary input without a successful acknowledgement or local rotation-state change", {
        inputKey = inputKey,
        slotIndex = slotIndex,
        attempts = candidate.attempts,
        window = math.floor((now - candidate.startedAt) * 10 + 0.5) / 10,
        pendingAge = math.floor((now - pendingAt) * 10 + 0.5) / 10,
        fingerprint = fingerprint,
    }, now)
    local backedOff = self:BackoffRejectedRotationSlot(slotIndex, now)
    return captured or backedOff
end

function HeliHeal:ResetRotationStuckCandidate()
    self.rotationStuckCandidate = nil
end
