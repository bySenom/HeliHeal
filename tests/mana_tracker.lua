local now = 0
local epoch = 1000
local combat = false
local liveMaximum = 100000

GetTime = function() return now end
time = function() return epoch end
InCombatLockdown = function() return combat end
UnitAffectingCombat = function(unit) return unit == "player" and combat end
UnitPower = function() error("the local ledger must not read current mana") end
UnitPowerMax = function() error("the local ledger must not require maximum-mana APIs") end
GetManaRegen = function() return 400, 100 end
issecretvalue = function() return false end
Enum = { PowerType = { Mana = 0 } }
C_Spell = {
    GetSpellPowerCost = function(spellID)
        if spellID == 1064 then
            return { { type = 0, cost = 9000, costPercent = 9, costPerSec = 0 } }
        end
        return nil
    end,
}

local addon = {
    classToken = "SHAMAN",
    specializationID = 264,
    db = { profile = {
        manaDebug = false,
        healingMode = "standard",
        autoManaMode = false,
        autoManaThreshold = 25,
    }, char = { manaState = {
        current = 80000,
        maximum = 100000,
        reliability = "ESTIMATED",
        classToken = "SHAMAN",
        specializationID = 264,
        modelVersion = 4,
        savedAt = epoch,
    } } },
    Print = function() end,
}
function addon:GetHealingMode() return self.db.profile.healingMode end
function addon:SetHealingMode(mode, silent, automatic)
    if self.Mana and not automatic then self.Mana:OnManualModeChanged() end
    self.db.profile.healingMode = mode
    return true
end
local namespace = {
    addon = addon,
    AbilityLibrary = {
        abilities = {
            chain_heal = {
                class = "SHAMAN",
                spellID = 1064,
                name = "Chain Heal",
                manaCost = 1000,
            },
            healing_stream = {
                class = "SHAMAN",
                spellID = 5394,
                name = "Healing Stream Totem",
                manaCost = 4500,
                castSpellIDs = { 5394, 1267068, 1267089 },
            },
            riptide = {
                class = "SHAMAN",
                spellID = 61295,
                name = "Riptide",
                manaCost = 3800,
            },
            surging_totem = {
                class = "SHAMAN",
                spellID = 444995,
                name = "Surging Totem",
                manaCost = 16250,
            },
        },
    },
}

assert(loadfile("ManaTracker.lua"))("HeliHeal", namespace)
addon:CreateManaTracker()
assert(addon.Mana.staticCosts[1064] and addon.Mana.staticCosts[1064].cost == 1000,
    "known spell costs must be available without the spell-cost API")
assert(addon.Mana.costs[1064] and addon.Mana.costs[1064].cost == 1000
    and addon.Mana.costs[1064].source == "static-12.1",
    "the spell-cost API must never overwrite an authoritative static 12.1 cost")
assert(addon.Mana.costs[5394] and addon.Mana.costs[5394].cost == 4500,
    "Healing Stream Totem must cost exactly 4500 mana")
assert(addon.Mana.costs[61295] and addon.Mana.costs[61295].cost == 3800,
    "Riptide must cost exactly 3800 mana")
assert(addon.Mana.staticCosts[444995] and addon.Mana.staticCosts[444995].cost == 16250,
    "Surging Totem must retain its static 16250 mana cost without the spell-cost API")

assert(addon.Mana:GetCurrent() == 80000 and addon.Mana:GetMax() == 100000,
    "the tracker must restore its persisted local ledger without a mana API")
assert(addon.Mana:GetReliability() == "ESTIMATED",
    "a restored local ledger must disclose that it is estimated")

combat = true
addon.Mana.inCombat = true
addon.Mana.current = 100000
addon.Mana.lastUpdatedAt = now
assert(addon.Mana:OnSpellSucceeded(5394, "HST-Base", now),
    "the base Healing Stream success must spend mana")
assert(not addon.Mana:OnSpellSucceeded(1267068, "HST-Replacement", now + 0.01),
    "a replacement spell success from the same Healing Stream cast must be deduplicated")
assert(not addon.Mana:OnSpellSucceeded(1267089, "HST-Aura", now + 0.02),
    "the Stormstream aura alias from the same cast must be deduplicated")
assert(not addon.Mana:OnSpellSucceeded(1064, "HST-Free-Chain-Heal", now + 0.03),
    "the automatic Chain Heal following Healing Stream must not spend mana")
assert(addon.Mana.current == 95500,
    "Healing Stream aliases and its free Chain Heal must cost exactly 4500 mana in total")
addon.Mana.regenPerSecond = 0
addon.Mana.waterShieldRegenPerSecond = 0
addon.Mana.lastUpdatedAt = now + 1.5
assert(addon.Mana:OnSpellSucceeded(1064, "Manual-Chain-Heal", now + 1.5),
    "a later manually cast Chain Heal must still spend mana")
assert(addon.Mana.current == 94500,
    "the Totem suppression window must not hide a later manual Chain Heal")
combat = false
addon.Mana.inCombat = false

addon.Mana.regenPerSecond = 0
addon.Mana.outOfCombatRegenPerSecond = 0
addon.Mana.waterShieldRegenPerSecond = 714 / 5
addon.Mana.current = 80000
addon.Mana.lastUpdatedAt = now
now = 5
assert(addon.Mana:Update(now) == 80714,
    "Water Shield must restore exactly 714 mana for each simulated five-second interval")

addon.Mana.current = 80000
addon.Mana.lastUpdatedAt = now
addon.Mana.regenPerSecond = 100
addon.Mana.inCombat = true
now = 10
assert(addon.Mana:Update(now) == 80500,
    "a readable regen snapshot must already include Water Shield and must not be counted twice")

-- Keep the existing base-regeneration cases isolated from the dedicated
-- Water Shield assertion above.
addon.Mana.waterShieldRegenPerSecond = 0
addon.Mana.regenPerSecond = 100
addon.Mana.outOfCombatRegenPerSecond = 400
addon.Mana.current = 80000
addon.Mana.lastUpdatedAt = now
addon.Mana.inCombat = false

combat = true
assert(addon.Mana:BeginCombat(now), "a valid snapshot must start combat tracking")
assert(addon.Mana:GetReliability() == "ESTIMATED" and addon.Mana:IsReliable(),
    "Resto Shaman combat tracking must disclose unobservable proc uncertainty")

now = 15
assert(addon.Mana:OnSpellSucceeded(1064, "Cast-1", now),
    "a successful tracked spell must consume its cached mana cost")
assert(addon.Mana:GetCurrent() == 79500,
    "lazy regeneration and the confirmed spell cost must be applied exactly once")
assert(not addon.Mana:OnSpellSucceeded(1064, "Cast-1", now),
    "a duplicate cast GUID must not spend mana twice")
assert(addon.Mana:GetCurrent() == 79500,
    "duplicate success events must leave the estimate unchanged")

now = 25
assert(addon.Mana:GetCurrent() == 80500,
    "timestamp-based regeneration must not require an OnUpdate loop")
assert(math.abs(addon.Mana:GetPercent() - 0.805) < 0.0001,
    "the internal API must expose the locally simulated mana percentage")

now = 30
combat = false
assert(addon.Mana:EndCombat(now), "combat end must preserve the local ledger")
assert(addon.Mana:GetCurrent() == 81000 and addon.Mana:GetReliability() == "ESTIMATED",
    "combat transitions must not require or overwrite from UnitPower")

now = 40
combat = true
addon.Mana:BeginCombat(now)
assert(addon.Mana:OnSpellSucceeded(16191, "Cast-2", now),
    "Mana Tide must be recognized as a tracked successful player cast")
assert(addon.Mana:GetReliability() == "DEGRADED" and not addon.Mana:IsReliable(),
    "an unobservable dynamic Mana Tide gain must downgrade reliability")
addon.db.profile.autoManaMode = true
addon.Mana.current = 20000
assert(addon.Mana:CanDriveAutoMode() and addon.Mana:EvaluateAutoMode(now)
    and addon:GetHealingMode() == "mana",
    "a degraded but available estimate must still activate the beta Mana Saving mode")
addon.db.profile.autoManaMode = false

now = 41
combat = false
addon.Mana:EndCombat(now)
addon.db.profile.autoManaMode = true
now = 50
addon.Mana:SyncOutOfCombat(false)
addon.Mana.current = 24000
addon.Mana.lastUpdatedAt = now
combat = true
addon.Mana:BeginCombat(now)
assert(addon.Mana:EvaluateAutoMode(now) and addon:GetHealingMode() == "mana",
    "the optional automatic mode must enter Mana Saving at the configured threshold")
now = 51
combat = false
addon.Mana:EndCombat(now)
assert(addon:GetHealingMode() == "mana" and addon.Mana.autoModeActive,
    "automatic Mana Saving must remain active between combats while mana stays low")
now = 116
assert(addon.Mana:EvaluateAutoMode(now) and addon:GetHealingMode() == "standard",
    "out-of-combat regeneration must restore the previous mode at the safe fifty-percent reserve")

combat = false
now = 60
addon.Mana.current = nil
addon.Mana.localTracking = false
assert(addon.Mana:SetManualPercent(25) and addon.Mana:GetCurrent() == 25000,
    "optional manual calibration must use the existing local maximum")
assert(addon.Mana:GetReliability() == "EXACT",
    "a user-confirmed manual baseline must be exact at the calibration timestamp")

now = 70
combat = true
assert(addon.Mana:BeginCombat(now) and addon.Mana:GetCurrent() == 29000,
    "out-of-combat regeneration must be applied locally before the next combat")
now = 75
addon.Mana:OnSpellSucceeded(1064, "Cast-3", now)
assert(addon.Mana:GetCurrent() == 28500,
    "the calibrated estimate must continue through a later combat")
now = 80
combat = false
assert(addon.Mana:EndCombat(now),
    "combat end must remain entirely local when current mana is inaccessible")
assert(addon.Mana:GetCurrent() == 29000 and addon.Mana:GetReliability() == "ESTIMATED",
    "a clean local model must remain available across combat boundaries")
now = 90
combat = true
assert(addon.Mana:BeginCombat(now) and addon.Mana:GetCurrent() == 33000,
    "the next combat must reuse the estimate without another manual command")

combat = false
local automaticAddon = {
    classToken = "SHAMAN",
    specializationID = 264,
    db = { profile = { manaDebug = false }, char = { manaState = {} } },
    Print = function() end,
}
local automaticNamespace = {
    addon = automaticAddon,
    AbilityLibrary = namespace.AbilityLibrary,
}
assert(loadfile("ManaTracker.lua"))("HeliHeal", automaticNamespace)
automaticAddon:CreateManaTracker()
assert(automaticAddon.Mana:GetCurrent() == 262500
    and automaticAddon.Mana:GetReliability() == "ESTIMATED",
    "a first run must start automatically from the static max mana without requiring a command")
assert(automaticAddon.db.char.manaState.current == 262500,
    "the command-free estimate must be persisted per character")

automaticAddon.db.char.manaState.current = 50000
automaticAddon.db.char.manaState.reliability = "ESTIMATED"
automaticAddon.db.char.manaState.reason = "test"
automaticAddon.db.char.manaState.savedAt = epoch - 600
local restoredAddon = {
    classToken = "SHAMAN",
    specializationID = 264,
    db = automaticAddon.db,
    Print = function() end,
}
local restoredNamespace = { addon = restoredAddon, AbilityLibrary = namespace.AbilityLibrary }
assert(loadfile("ManaTracker.lua"))("HeliHeal", restoredNamespace)
restoredAddon:CreateManaTracker()
assert(restoredAddon.Mana:GetCurrent() == 50000,
    "reloads must restore the exact character estimate without inventing offline regeneration")

restoredAddon.db.char.manaState = {}
restoredAddon.Mana.current = 1
restoredAddon.Mana.maximum = 1
restoredAddon:CreateManaTracker()
assert(restoredAddon.Mana:GetCurrent() == 262500 and restoredAddon.Mana:GetMax() == 262500,
    "reinitialization must clear stale runtime values and create a fresh static baseline")

local thresholdAddon = {
    classToken = "SHAMAN",
    specializationID = 264,
    db = { profile = {
        manaDebug = false,
        healingMode = "standard",
        autoManaMode = true,
        autoManaThreshold = 25,
    }, char = { manaState = {
        current = 221750,
        maximum = 262500,
        reliability = "ESTIMATED",
        classToken = "SHAMAN",
        specializationID = 264,
        modelVersion = 4,
    } } },
    Print = function() end,
}
function thresholdAddon:GetHealingMode() return self.db.profile.healingMode end
function thresholdAddon:SetHealingMode(mode) self.db.profile.healingMode = mode; return true end
local thresholdNamespace = { addon = thresholdAddon, AbilityLibrary = namespace.AbilityLibrary }
assert(loadfile("ManaTracker.lua"))("HeliHeal", thresholdNamespace)
combat = false
now = 200
thresholdAddon:CreateManaTracker()
combat = true
thresholdAddon.Mana:BeginCombat(now)
thresholdAddon.Mana.current = 262500
thresholdAddon.Mana.lastUpdatedAt = now
assert(thresholdAddon.Mana:OnSpellSucceeded(444995, "Surging-Test", now)
    and thresholdAddon.Mana:GetCurrent() == 246250,
    "a confirmed Surging Totem cast must subtract exactly 16250 mana")
thresholdAddon.Mana.current = 221750
thresholdAddon.Mana.lastUpdatedAt = now
assert(not thresholdAddon.Mana:EvaluateAutoMode(now)
    and thresholdAddon:GetHealingMode() == "standard",
    "the observed 221750 / 262500 ledger must remain Standard at roughly 84.5 percent")
thresholdAddon.Mana.current = 65000
thresholdAddon.Mana.lastUpdatedAt = now
assert(thresholdAddon.Mana:EvaluateAutoMode(now)
    and thresholdAddon:GetHealingMode() == "mana",
    "the same local ledger must activate Mana Saving once it falls below 25 percent")
thresholdAddon.Mana:ResetAutoModeState()
assert(not thresholdAddon.Mana.autoModeActive and not thresholdAddon.Mana.autoModePrevious,
    "profile and specialization lifecycle resets must clear stale automatic mode state")

print("mana_tracker.lua: OK")
