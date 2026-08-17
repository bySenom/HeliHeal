local _, ns = ...
local HeliHeal = ns.addon
local L = ns.L or function(value, ...) return select("#", ...) > 0 and value:format(...) or value end

local TALENTS = {
    echoOfTheElements = { 333919 },
    elementalReverb = { 443418 },
    downpour = { 462488 },
    doubleDip = { 1252882 },
    mysticKnowledge = { 1270453 },
    surgingTotem = { 444995 },
    unleashLife = { 73685 },
    druidGermination = { 155675 },
    druidLingeringHealing = { 231040 },
    druidVerdantInfusion = { 392410 },
    druidProsperity = { 200383 },
    druidPassingSeasons = { 382550 },
    druidEarlySpring = { 428937 },
    druidPowerArchdruid = { 392302 },
    druidLifetreading = { 1217941 },
    druidKeeper = { 433831, 428731 },
    druidWildstalker = { 439926, 439530 },
    druidConvoke = { 391528 },
    druidCenariusGuidance = { 393371 },
    druidIncarnationTree = { 33891 },
    druidTranquility = { 740 },
    druidInnerPeace = { 197073 },
    druidFlourish = { 197721 },
    druidSoulOfTheForest = { 158478 },
    druidReforestation = { 392360 },
    druidControlOfTheDream = { 434249 },
    paladinHerald = { 431377, 156322 },
    paladinLightsmith = { 432459, 432472, 434132 },
    paladinDivineToll = { 375576, 304971 },
    paladinHolyPrism = { 114165 },
    paladinQuickenedInvocation = { 379391 },
    paladinLightsConviction = { 414073 },
    paladinAvengingWrath = { 31884 },
    paladinAvengingCrusader = { 216331 },
    paladinRingingHeavens = { 1241542 },
    paladinWalkIntoLight = { 1263782 },
    paladinAurora = { 439760 },
    paladinCallOfRighteous = { 1241511 },
    paladinUnwaveringSpirit = { 392911 },
    paladinDivinePurpose = { 408459, 223817 },
    paladinBeaconVirtue = { 200025 },
    priestArchon = { 120517 },
    priestOracle = { 1248423 },
    priestSanctify = { 34861 },
    priestPrayerOfHealing = { 596 },
    priestChastise = { 88625 },
    priestUltimateSerenity = { 1246517 },
    priestMiracleWorker = { 235587 },
    priestEternalSanctity = { 1215245 },
    priestHolyCelerity = { 1215275 },
    priestVoiceHarmony = { 390994 },
    priestLightNaaru = { 196985 },
    priestProphetInsight = { 1272359 },
    priestApotheosis = { 200183 },
    priestDivineHymn = { 64843 },
    priestGuardianSpirit = { 47788 },
    discVoidweaver = { 450405, 447445 },
    discEvangelism = { 472433 },
    discVoidShield = { 1253593 },
    discLightsPromise = { 322115 },
    discBrightPupil = { 390684 },
    discUltimatePenitence = { 421453 },
    discPowerWordBarrier = { 62618 },
    discPainSuppression = { 33206 },
}

local SNAPSHOT_FLAGS = {
    "echoOfTheElements", "elementalReverb", "downpour", "doubleDip",
    "mysticKnowledge", "surgingTotem", "unleashLife", "restorationTier2", "restorationTier4",
    "druidGermination", "druidLingeringHealing", "druidVerdantInfusion", "druidProsperity",
    "druidPassingSeasons", "druidEarlySpring", "druidPowerArchdruid", "druidLifetreading", "druidKeeper", "druidWildstalker",
    "druidConvoke", "druidCenariusGuidance", "druidIncarnationTree", "druidTranquility",
    "druidInnerPeace", "druidFlourish", "druidSoulOfTheForest", "druidReforestation",
    "druidControlOfTheDream",
    "paladinHerald", "paladinLightsmith", "paladinDivineToll", "paladinHolyPrism",
    "paladinQuickenedInvocation", "paladinLightsConviction",
    "paladinAvengingWrath", "paladinAvengingCrusader", "paladinRingingHeavens", "paladinWalkIntoLight",
    "paladinAurora",
    "paladinCallOfRighteous", "paladinCallOfRighteousRank", "paladinUnwaveringSpirit",
    "paladinDivinePurpose", "paladinBeaconVirtue",
    "priestArchon", "priestOracle", "priestSanctify", "priestPrayerOfHealing",
    "priestChastise", "priestUltimateSerenity",
    "priestMiracleWorker", "priestEternalSanctity", "priestHolyCelerity", "priestVoiceHarmony",
    "priestLightNaaru", "priestLightNaaruRank", "priestProphetInsight",
    "priestApotheosis", "priestDivineHymn", "priestGuardianSpirit",
    "discVoidweaver", "discEvangelism", "discVoidShield", "discLightsPromise",
    "discBrightPupil", "discUltimatePenitence", "discPowerWordBarrier", "discPainSuppression",
}

local function isKnownSpell(spellID)
    if C_SpellBook and type(C_SpellBook.IsSpellKnown) == "function" then
        local ok, known = pcall(C_SpellBook.IsSpellKnown, spellID)
        if ok and known then return true end
    end
    if type(IsPlayerSpell) == "function" then
        local ok, known = pcall(IsPlayerSpell, spellID)
        if ok and known then return true end
    end
    return false
end

local function containsTalent(spells, spellIDs)
    for _, spellID in ipairs(spellIDs) do
        if spells[spellID] then return true end
    end
    return false
end

local function snapshotsEqual(a, b)
    if not a or not b then return false end
    if a.available ~= b.available or a.configID ~= b.configID then return false end
    for _, flag in ipairs(SNAPSHOT_FLAGS) do
        if a[flag] ~= b[flag] then return false end
    end
    return true
end

function HeliHeal:ReadActiveTalentSpells()
    if not C_ClassTalents or type(C_ClassTalents.GetActiveConfigID) ~= "function"
        or not C_Traits or type(C_Traits.GetConfigInfo) ~= "function" then
        return nil, nil
    end

    local configID = C_ClassTalents.GetActiveConfigID()
    if not configID then return nil, nil end
    local configInfo = C_Traits.GetConfigInfo(configID)
    if not configInfo or type(configInfo.treeIDs) ~= "table" then return nil, configID end

    local spells = {}
    local ranks = {}
    local committedEntryCount = 0
    for _, treeID in ipairs(configInfo.treeIDs) do
        local nodeIDs = C_Traits.GetTreeNodes(treeID) or {}
        for _, nodeID in ipairs(nodeIDs) do
            local nodeInfo = C_Traits.GetNodeInfo(configID, nodeID)
            -- This committed list represents the selected live loadout, not
            -- uncommitted talent-preview changes in the talent window.
            local committedRanks = nodeInfo and (not nodeInfo.subTreeID or nodeInfo.subTreeActive)
                and nodeInfo.entryIDsWithCommittedRanks or {}
            for _, rankInfo in ipairs(committedRanks) do
                local entryID = type(rankInfo) == "table" and rankInfo.entryID or rankInfo
                if entryID then committedEntryCount = committedEntryCount + 1 end
                local entryInfo = entryID and C_Traits.GetEntryInfo(configID, entryID)
                local definitionInfo = entryInfo and entryInfo.definitionID
                    and C_Traits.GetDefinitionInfo(entryInfo.definitionID)
                if definitionInfo and definitionInfo.spellID then
                    spells[definitionInfo.spellID] = true
                    local rank = type(rankInfo) == "table" and tonumber(rankInfo.rank)
                        or tonumber(nodeInfo and nodeInfo.activeRank) or 1
                    ranks[definitionInfo.spellID] = math.max(ranks[definitionInfo.spellID] or 0, rank or 1)
                end
            end
        end
    end
    -- A max-level active combat config cannot legitimately have zero
    -- committed entries. Treat that as an API-not-ready state and retain the
    -- static preset assumptions instead of hiding valid abilities.
    if committedEntryCount == 0 then return nil, configID end
    return spells, configID, ranks
end

function HeliHeal:RefreshTalentSnapshot(silent)
    if InCombatLockdown and InCombatLockdown() then
        self.talentSnapshotPending = true
        return false
    end

    local ok, spells, configID, ranks = pcall(self.ReadActiveTalentSpells, self)
    if not ok then
        spells, configID, ranks = nil, nil, nil
    end
    local snapshot = {
        available = spells ~= nil,
        configID = configID,
        spells = spells or {},
        ranks = ranks or {},
    }
    for talentKey, spellIDs in pairs(TALENTS) do
        snapshot[talentKey] = spells and containsTalent(spells, spellIDs) or false
    end
    snapshot.paladinCallOfRighteousRank = 0
    for _, spellID in ipairs(TALENTS.paladinCallOfRighteous) do
        snapshot.paladinCallOfRighteousRank = math.max(snapshot.paladinCallOfRighteousRank,
            tonumber(snapshot.ranks[spellID]) or 0)
    end
    snapshot.priestLightNaaruRank = 0
    for _, spellID in ipairs(TALENTS.priestLightNaaru) do
        snapshot.priestLightNaaruRank = math.max(snapshot.priestLightNaaruRank,
            tonumber(snapshot.ranks[spellID]) or 0)
    end
    snapshot.restorationTier2 = self.classToken == "SHAMAN" and isKnownSpell(1264866)
    snapshot.restorationTier4 = self.classToken == "SHAMAN" and isKnownSpell(1264867)

    local changed = not snapshotsEqual(self.talentSnapshot, snapshot)
    self.talentSnapshot = snapshot
    self.talentSnapshotPending = false
    if changed then
        local currentPreset = self.db and self.db.profile and self.db.profile.rotationPreset
        local _, content
        if currentPreset then
            _, content = currentPreset:match("^[a-z]+_([a-z]+)_([a-z]+)$")
            if content ~= "mythicplus" and content ~= "raid" then content = nil end
        end
        local detectedHero
        if self.classToken == "DRUID" then
            detectedHero = snapshot.druidKeeper and "keeper" or (snapshot.druidWildstalker and "wildstalker")
        elseif self.classToken == "PALADIN" then
            detectedHero = snapshot.paladinLightsmith and "lightsmith" or (snapshot.paladinHerald and "herald")
        elseif self.classToken == "PRIEST" and self.specializationID == 256 then
            detectedHero = snapshot.priestOracle and "oracle" or (snapshot.discVoidweaver and "voidweaver")
        elseif self.classToken == "PRIEST" then
            detectedHero = snapshot.priestOracle and "oracle" or (snapshot.priestArchon and "archon")
        else
            detectedHero = (snapshot.elementalReverb or snapshot.mysticKnowledge) and "farseer"
                or (snapshot.surgingTotem and "totemic")
        end
        local classPrefix = self.classToken == "DRUID" and "druid"
            or (self.classToken == "PALADIN" and "paladin"
            or (self.classToken == "PRIEST" and (self.specializationID == 256 and "disc" or "priest")
            or "shaman"))
        local detectedPreset = detectedHero and content and (classPrefix .. "_" .. detectedHero .. "_" .. content)
        if detectedPreset and ns.AbilityLibrary:GetPreset(detectedPreset) and detectedPreset ~= currentPreset then
            self.db.profile.rotationPreset = detectedPreset
            self.db.profile.slots = ns.AbilityLibrary:BuildPresetSlots(detectedPreset, self.db.profile.bindings)
        end
        self:ResetRuntimeState()
        if self.frame then self:RefreshDisplay() end
        if self.RefreshOptionsUI then self:RefreshOptionsUI() end
    end

    if not silent then self:PrintTalentSnapshot() end
    return snapshot.available
end

function HeliHeal:IsTalentActive(talentKey)
    return self.talentSnapshot and self.talentSnapshot.available
        and self.talentSnapshot[talentKey] == true
end

function HeliHeal:GetTalentRank(talentKey)
    if not self.talentSnapshot or not self.talentSnapshot.available then return 0 end
    local explicit = tonumber(self.talentSnapshot[talentKey .. "Rank"])
    if explicit then return explicit end
    return self.talentSnapshot[talentKey] and 1 or 0
end

function HeliHeal:GetRiptideMaxCharges(fallback)
    if not self.talentSnapshot or not self.talentSnapshot.available then
        return fallback or 2
    end
    return 1
        + (self.talentSnapshot.echoOfTheElements and 1 or 0)
        + (self.talentSnapshot.elementalReverb and 1 or 0)
end

function HeliHeal:PrintTalentSnapshot()
    local snapshot = self.talentSnapshot
    if not snapshot or not snapshot.available then
        self:Print(L("Talent-Snapshot noch nicht verfügbar; bestehende Preset-Annahmen bleiben aktiv."))
        return
    end
    local function yesNo(value) return L(value and "JA" or "nein") end
    if self.classToken == "DRUID" then
        local details = ("Germination %s | Lingering Healing %s | Verdant Infusion %s | Prosperity %s | Passing Seasons %s | Early Spring %s | Soul of the Forest %s | Power of the Archdruid %s | Reforestation %s | Lifetreading %s | Keeper %s | Wildstalker %s | Convoke %s | Tree %s | Tranquility %s | Inner Peace %s | Flourish %s | Cenarius' Guidance %s | Control of the Dream %s")
            :format(yesNo(snapshot.druidGermination), yesNo(snapshot.druidLingeringHealing),
                yesNo(snapshot.druidVerdantInfusion), yesNo(snapshot.druidProsperity),
                yesNo(snapshot.druidPassingSeasons), yesNo(snapshot.druidEarlySpring),
                yesNo(snapshot.druidSoulOfTheForest), yesNo(snapshot.druidPowerArchdruid),
                yesNo(snapshot.druidReforestation),
                yesNo(snapshot.druidLifetreading), yesNo(snapshot.druidKeeper), yesNo(snapshot.druidWildstalker),
                yesNo(snapshot.druidConvoke), yesNo(snapshot.druidIncarnationTree),
                yesNo(snapshot.druidTranquility), yesNo(snapshot.druidInnerPeace), yesNo(snapshot.druidFlourish),
                yesNo(snapshot.druidCenariusGuidance), yesNo(snapshot.druidControlOfTheDream))
        self:Print(L("Talente (Config %s): %s", tostring(snapshot.configID or "?"), details))
        return
    end
    if self.classToken == "PALADIN" then
        local details = ("Herald %s | Lightsmith %s | Divine Toll %s | Holy Prism %s | Virtue %s | Quickened Invocation %s | Light's Conviction %s | Wings %s | Crusader %s | Ringing %s | Walk Into Light %s | Aurora %s | Call %d/2 | Unwavering %s | Divine Purpose %s")
            :format(yesNo(snapshot.paladinHerald), yesNo(snapshot.paladinLightsmith),
                yesNo(snapshot.paladinDivineToll), yesNo(snapshot.paladinHolyPrism),
                yesNo(snapshot.paladinBeaconVirtue),
                yesNo(snapshot.paladinQuickenedInvocation), yesNo(snapshot.paladinLightsConviction),
                yesNo(snapshot.paladinAvengingWrath), yesNo(snapshot.paladinAvengingCrusader),
                yesNo(snapshot.paladinRingingHeavens), yesNo(snapshot.paladinWalkIntoLight),
                yesNo(snapshot.paladinAurora), snapshot.paladinCallOfRighteousRank or 0,
                yesNo(snapshot.paladinUnwaveringSpirit), yesNo(snapshot.paladinDivinePurpose))
        self:Print(L("Talente (Config %s): %s", tostring(snapshot.configID or "?"), details))
        return
    end
    if self.classToken == "PRIEST" then
        if self.specializationID == 256 then
            local details = ("Oracle %s | Voidweaver %s | Evangelism %s | Void Shield %s | Light's Promise %s | Bright Pupil %s | Ultimate Penitence %s | Barrier %s | Pain Suppression %s")
                :format(yesNo(snapshot.priestOracle), yesNo(snapshot.discVoidweaver),
                    yesNo(snapshot.discEvangelism), yesNo(snapshot.discVoidShield),
                    yesNo(snapshot.discLightsPromise), yesNo(snapshot.discBrightPupil),
                    yesNo(snapshot.discUltimatePenitence), yesNo(snapshot.discPowerWordBarrier),
                    yesNo(snapshot.discPainSuppression))
            self:Print(L("Talente (Config %s): %s", tostring(snapshot.configID or "?"), details))
            return
        end
        local details = ("Archon %s | Oracle %s | Sanctify %s | Prayer of Healing %s | Chastise %s | Ultimate Serenity %s | Miracle Worker %s | Eternal Sanctity %s | Holy Celerity %s | Voice of Harmony %s | Light of the Naaru %d/2 | Prophet's Insight %s | Apotheosis %s | Divine Hymn %s | Guardian Spirit %s")
            :format(yesNo(snapshot.priestArchon), yesNo(snapshot.priestOracle),
                yesNo(snapshot.priestSanctify), yesNo(snapshot.priestPrayerOfHealing),
                yesNo(snapshot.priestChastise), yesNo(snapshot.priestUltimateSerenity),
                yesNo(snapshot.priestMiracleWorker), yesNo(snapshot.priestEternalSanctity),
                yesNo(snapshot.priestHolyCelerity),
                yesNo(snapshot.priestVoiceHarmony), snapshot.priestLightNaaruRank or 0,
                yesNo(snapshot.priestProphetInsight), yesNo(snapshot.priestApotheosis),
                yesNo(snapshot.priestDivineHymn), yesNo(snapshot.priestGuardianSpirit))
        self:Print(L("Talente (Config %s): %s", tostring(snapshot.configID or "?"), details))
        return
    end
    local details = ("Echo %s | Elemental Reverb %s | Surging Totem %s | Unleash Life %s | Downpour %s | Double Dip %s | Mystic Knowledge %s | Set 2p %s | Set 4p %s")
        :format(yesNo(snapshot.echoOfTheElements),
            yesNo(snapshot.elementalReverb), yesNo(snapshot.surgingTotem), yesNo(snapshot.unleashLife),
            yesNo(snapshot.downpour), yesNo(snapshot.doubleDip), yesNo(snapshot.mysticKnowledge),
            yesNo(snapshot.restorationTier2), yesNo(snapshot.restorationTier4))
    self:Print(L("Talente (Config %s): %s", tostring(snapshot.configID or "?"), details))
end

function HeliHeal:CreateTalentListener()
    if self.talentListener then
        local listener = self.talentListener
        listener:RegisterEvent("PLAYER_ENTERING_WORLD")
        listener:RegisterEvent("TRAIT_CONFIG_LIST_UPDATED")
        listener:RegisterEvent("TRAIT_CONFIG_UPDATED")
        listener:RegisterEvent("ACTIVE_COMBAT_CONFIG_CHANGED")
        listener:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
        listener:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
        listener:RegisterEvent("UNIT_STATS")
        listener:RegisterEvent("SPELLS_CHANGED")
        listener:RegisterEvent("PLAYER_REGEN_ENABLED")
        self:RefreshTalentSnapshot(true)
        self:RefreshSpellHasteSnapshot(true)
        return
    end
    local listener = CreateFrame("Frame")
    listener:RegisterEvent("PLAYER_ENTERING_WORLD")
    listener:RegisterEvent("TRAIT_CONFIG_LIST_UPDATED")
    listener:RegisterEvent("TRAIT_CONFIG_UPDATED")
    listener:RegisterEvent("ACTIVE_COMBAT_CONFIG_CHANGED")
    listener:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    listener:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    listener:RegisterEvent("UNIT_STATS")
    listener:RegisterEvent("SPELLS_CHANGED")
    listener:RegisterEvent("PLAYER_REGEN_ENABLED")
    listener:SetScript("OnEvent", function(_, event, argument)
        if event == "PLAYER_SPECIALIZATION_CHANGED" and argument and argument ~= "player" then return end
        if event == "UNIT_STATS" and argument ~= "player" then return end
        if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_SPECIALIZATION_CHANGED" then
            HeliHeal:RefreshPlayerSupport(true)
        end
        if event == "TRAIT_CONFIG_UPDATED" then
            local activeConfigID = C_ClassTalents and C_ClassTalents.GetActiveConfigID
                and C_ClassTalents.GetActiveConfigID()
            if activeConfigID and argument and argument ~= activeConfigID then return end
        end
        HeliHeal:RefreshTalentSnapshot(true)
        HeliHeal:RefreshSpellHasteSnapshot(true)
        if event == "PLAYER_REGEN_ENABLED" then
            HeliHeal:ReconcileOutOfCombatState(true)
        end
    end)
    self.talentListener = listener
    self:RefreshTalentSnapshot(true)
    self:RefreshSpellHasteSnapshot(true)
end
