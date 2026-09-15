local _, ns = ...

ns.changelog = {
    currentVersion = "1.0.1",
    entries = {
        {
            version = "1.0.1",
            title = "Charge-Aware Shaman Priorities",
            changes = {
                "Hold the final regular Healing Stream Totem charge in Standard and Mana Saving modes.",
                "Recommend a known Stormstream bonus immediately without consuming a regular totem charge.",
                "Prioritize Nature's Swiftness and Totemic setup before Riptide in the Standard rotation.",
                "Pair Unleash Life with Ancestral Swiftness before Riptide in Farseer builds.",
                "Remove Surging Totem from the Single Target priority while retaining it in Standard and AoE.",
                "Add a specialization-aware healing FAQ covering Holy Paladin targeting, procs, Beacons, mana, content types, utility and movement.",
                "Rework the FAQ into collapsible sections with spell icons, related-spell tooltips and expand-all controls.",
                "Add collapsible FAQ categories, responsive spell cards, remembered open topics and mode guidance.",
                "Stop ready abilities in the DEF window from repeatedly replaying cooldown completion effects.",
                "Count Holy Bulwark or Sacred Weapon once per player cast without consuming another shared charge for its Solidarity copy.",
                "Apply Uther's Counsel to Divine Shield, Blessing of Protection and Lay on Hands in the DEF cooldown model.",
                "Consume a known Infusion between the two Hand of Divinity Holy Lights instead of overwriting the second four-piece proc.",
                "Keep Aura Mastery available without Ringing of the Heavens and apply Divine Toll effects only when Ringing is selected.",
                "Track the confirmed nine-second Beacon of Virtue window and pair ready Divine Toll or Ringing-enhanced Aura Mastery with it in Raid AoE mode.",
                "Detect Divine Favor, Divine Overload and the redesigned Rising Sunlight; show reliable Holy Light modifiers while leaving restricted Beacon-health scaling to the player.",
                "Predict Divine Resonance's three automatic Holy Shock timings and spend at four Holy Power when the next fixed tick would otherwise overcap.",
                "Apply Divine Spurs to Divine Steed's local recharge while documenting its shorter movement duration.",
                "Use Holy Armaments' current 60-second recharge without the obsolete Quickened Invocation reduction; Forewarning and Valiance remain supported.",
                "Apply Valiance correctly: every confirmed Infusion consumption reduces the shared Holy Armaments recharge by three seconds without extending active Armament effects.",
                "Reconcile one locally available charge after Blizzard rejects a charged ability three times, preventing phantom charges from returning as the primary recommendation.",
                "Add a read-only Infusion of Light proof-of-concept using Blizzard's Buff Bar Cooldown Viewer, with /hh iol and /hh cdmbuffs diagnostics.",
                "Use a dedicated Infusion of Light Tracked Bar's visibility as the proc signal and ignore empty Edit Mode pool frames.",
                "Synchronize Holy Paladin priorities and Infusion consumers with the confirmed Cooldown Manager proc state.",
                "Correct Judgment to its current six-second base cooldown and retain Crusader's Might and Shield of the Righteous reductions.",
            },
        },
        {
            version = "1.0.0",
            title = "First Stable Release",
            changes = {
                "Assign any saved Blizzard talent loadout to a rotation preset and healing mode per character.",
                "Automatically activate the assigned rotation when switching talent loadouts.",
                "Keep the selected preset and rotation mode visibly highlighted in the options.",
                "Handle the reversed One Button Assistant event order for Nature's Swiftness.",
                "Deduct Holy Power when Shield of the Righteous succeeds outside configured Paladin slots.",
                "Use a 20-second Healing Stream Totem recharge, reduced to 17 seconds by Totemic Momentum.",
                "Hide Healing Rain when Surging Totem replaces it in Totemic builds.",
                "Keep the complete in-game update history in English on every client language.",
                "Show HeliHeal memory usage and optional CPU profiling statistics in the options sidebar.",
                "Scale the complete options window from its bottom-right resize grip and retain the selected size.",
                "Customize the options background and accent or use the current character's class color.",
                "Use a compact profile manager with separate active, creation, maintenance and deletion sections.",
            },
        },
        {
            version = "0.9.17-beta.1",
            title = "Dynamic Shaman Talents and Mana Reliability",
            changes = {
                "Ignore free automatic Raid, tier-set and Totem follow-up spells in the local mana model.",
                "Confirm instant-cast mana spending only after a matching observed player input.",
                "Simulate Midnight food and drink mana regeneration with their ramping recovery rates.",
                "Reduce Riptide recharge from six to five seconds when Rip Current is talented.",
                "Show Unleash Life dynamically in the Totemic Raid preset when the talent is selected.",
            },
        },
        {
            version = "0.9.16-beta.1",
            title = "HUD Badge Layout Hotfix",
            changes = {
                "Prevent AUTO/MANA and OR labels from overlapping on situational ability choices.",
                "Keep OR directly above the choice icons while AUTO/MANA remains on a stable row above it.",
                "Keep the icon frame stationary when choice indicators appear or disappear.",
            },
        },
        {
            version = "0.9.15-beta.1",
            title = "Automatic Mana Saving and Shaman Mana Model",
            changes = {
                "Add an optional beta mode that enters Mana Saving below a configurable local mana threshold.",
                "Track fixed 12.1 spell costs and cached regeneration, including Water Shield, in a persistent Shaman mana model.",
                "Charge Healing Stream Totem and its Stormstream aliases only once per actual use.",
                "Recognize the automatic Chain Heal triggered by the Totem as a free follow-up cast.",
                "Use a more conservative Mana Saving priority without Chain Heal or Surging Totem.",
                "Show situational AoE and single-target fillers as a stable OR choice above the icons in Standard mode.",
                "Start Nature's Swiftness cooldown only when its empowered Nature spell is successfully consumed.",
            },
        },
        {
            version = "0.9.14-beta.1",
            title = "Dispel Cursor and Runtime Reliability",
            changes = {
                "Add an optional cursor display for the dispel cooldown after a confirmed successful cast.",
                "Move the dispel icon smoothly with the cursor while avoiding redundant layout updates.",
                "Make the dispel display size and offset configurable and keep its default position clear of the cursor.",
                "Preserve local timers and simulated states across supported loading screens and zone changes.",
                "Recognize multi-digit MultiActionBar button inputs without Lua errors.",
            },
        },
        {
            version = "0.9.13-beta.1",
            title = "Mistweaver Dual Hero Priorities",
            changes = {
                "Use separate Conduit and Harmony priorities for Mythic+ and Raid while keeping all talent variants bindable.",
                "Show Tiger Palm, Blackout Kick and Spinning Crane Kick together as a hybrid melee path in Standard mode.",
                "Simulate Thunder Focus Tea, Renewing Mist, Sheilun's Gift, Teachings of the Monastery and Heart of the Jade Serpent from confirmed casts.",
                "Recognize current Conduit and Aspect of Harmony spell variants while retaining the selected content type.",
                "Keep emergency heals, major cooldowns and unreadable procs limited to appropriate context modes.",
            },
        },
        {
            version = "0.9.12-beta.1",
            title = "Reliable Sheilun's Gift Recommendations",
            changes = {
                "Confirm Sheilun's Gift directly after a successful cast and remove it from the active recommendation.",
                "Model cloud generation with an eight-second recommendation lockout without displaying a false spell cooldown.",
            },
        },
        {
            version = "0.9.11-beta.1",
            title = "Mistweaver Support and Runtime Hardening",
            changes = {
                "Add Mistweaver Monk support for Conduit of the Celestials and Master of Harmony in Mythic+ and Raid.",
                "Keep talent abilities hidden when the talent tree is temporarily unreadable and retain the last valid snapshot.",
                "Account for Lotus Infusion, Thunder Focus Tea and Rising Mist in Renewing Mist duration displays.",
                "Name the actual replaced ability on shared talent hotkeys instead of always showing Healing Rain.",
                "Adapt the options window to smaller resolutions and UI scales.",
                "Keep GitHub and CurseForge packages lean by excluding unused AceConfig and AceGUI libraries.",
            },
        },
        {
            version = "0.9.10-beta.1",
            title = "Talent-Aware Restoration Druid Rotation",
            changes = {
                "Require a locally confirmed HoT before recommending Swiftmend unless Verdant Infusion removes that requirement.",
                "Adjust Rejuvenation duration, Swiftmend charges and Wild Growth, Swiftmend and Nature's Swiftness cooldowns for selected talents.",
                "Prioritize Rejuvenation or Regrowth after Soul of the Forest and gate Power of the Archdruid behind that effect.",
                "Show or hide Convoke the Spirits, Incarnation: Tree of Life and Tranquility according to the selected talents.",
                "Apply Inner Peace and Flourish to the local Tranquility and HoT state.",
                "Confirm successful Wild Growth, Nature's Swiftness, Swiftmend and major Druid cooldown casts directly.",
            },
        },
        {
            version = "0.9.9-beta.1",
            title = "Priest Support and Atonement Tracking",
            changes = {
                "Add Holy Priest Archon and Oracle priorities for Mythic+ and Raid.",
                "Add Discipline Priest Oracle and Voidweaver priorities for Mythic+ and Raid.",
                "Use corrected haste-aware timers for Penance, Mind Blast, Power Word: Shield and Power Word: Radiance.",
                "Estimate group and single-target Atonement separately from confirmed Radiance, Shield and Void Shield casts.",
                "Treat Power Word: Radiance as one 14-second group cycle and confirm it directly after a successful cast.",
                "Allow reliable Mouse Button 1 bindings and clear hotkeys by holding Escape for 1.5 seconds.",
            },
        },
        {
            version = "0.9.8-beta.1",
            title = "Advanced HUD Customization and Beacon of Virtue",
            changes = {
                "Add independent width, height, zoom and position controls for primary and secondary icons.",
                "Position and scale hotkeys, cooldowns, role labels, priority badges, ability names and the header independently.",
                "Add separate color controls for the panel, icon background and every HUD text element.",
                "Support talent-aware Beacon of Virtue in Holy Paladin Mythic+ Standard and AoE with a 15-second cooldown.",
                "Use maintained Markdown release notes without Git author metadata on CurseForge and GitHub.",
            },
        },
        {
            version = "0.9.7-beta.1",
            title = "Reliable Cast Tracking and Runtime Efficiency",
            changes = {
                "Expand icon spacing for wide hotkey badges to prevent overlap.",
                "Reduce ongoing memory churn with cached abilities and reusable HUD tables.",
                "Confirm Nature's Swiftness and Ancestral Swiftness directly after successful off-GCD casts.",
                "Confirm Unleash Life directly from a successful player cast.",
                "Recognize consumed random Stormstream procs by cast ID without spending a normal Healing Stream charge.",
            },
        },
        {
            version = "0.9.6-beta.1",
            title = "First Beta: Customizable HUD and Profiles",
            changes = {
                "Show AOE, SINGLE, BURST or SAVE labels on matching healing abilities.",
                "Label Holy Light as the mana-efficient SAVE option and Flash of Light as the fast BURST option.",
                "Enable role labels by default with a toggle in the HUD options.",
                "Add mouse-wheel scrolling and a subtle scroll indicator to the HUD options.",
                "Allow live font, text-outline, icon-size and text-size customization.",
                "Make accent, hotkey, cooldown and individual role colors configurable.",
                "Use real dropdown menus with live previews for fonts and text outlines.",
                "Organize HUD settings into visibility, text, size and color categories.",
                "List existing profiles and support switching, creating, copying and safe deletion.",
            },
        },
        {
            version = "0.9.5-alpha.1",
            title = "Haste-Aware Paladin Recharge",
            changes = {
                "Use spell-haste-adjusted recharge times for Holy Shock.",
                "Apply the same haste model to Judgment and Crusader Strike.",
                "Cache spell haste safely outside combat without processing it as a SecretValue in combat.",
                "Intentionally exclude temporary in-combat haste buffs from the static estimate.",
            },
        },
        {
            version = "0.9.4-alpha.1",
            title = "Compact Talent-Aware Priority List",
            changes = {
                "Remove empty rows left by hidden talent abilities.",
                "Renumber visible abilities continuously in the options.",
                "Preserve internal slots and saved hotkeys while compacting the list.",
            },
        },
        {
            version = "0.9.3-alpha.1",
            title = "Reliable Major Cooldown Confirmation",
            changes = {
                "Confirm Avenging Wrath directly after a successful player cast.",
                "Support modifier bindings, macros and off-GCD cooldowns without requiring a prior action-bar hook.",
                "Use the same safe confirmation path for Avenging Crusader and Aura Mastery.",
                "Discard duplicate success events within the cast window.",
            },
        },
        {
            version = "0.9.2-alpha.1",
            title = "One Button Assistant and Live Holy Power",
            changes = {
                "Detect Blizzard's One Button Assistant automatically on standard action bars.",
                "Update matching HeliHeal cooldowns and charges from successful OBA spells.",
                "Reconcile the local simulation with readable player Holy Power after every cast.",
                "Account for Crusader Strike and Shield of the Righteous in OBA resource changes.",
                "Stop generating Holy Power from Walk Into Light after its 12.0.5 redesign.",
            },
        },
        {
            version = "0.9.1-alpha.1",
            title = "Paladin Talent and Holy Power Model",
            changes = {
                "Use the correct 30-second cooldown for Divine Toll and Holy Prism with Quickened Invocation.",
                "Control Divine Toll, Holy Prism, Holy Armaments, Wings, Crusader and Aura Mastery through Paladin talents.",
                "Calculate Holy Power as an ordered sequence of confirmed casts and rebuild it correctly after refunds.",
                "Simulate Aurora, Walk Into Light, Ringing of the Heavens and rank-based cooldown talents locally.",
                "Allow manual Holy Power synchronization with /hh hp 0-5 when a random proc is unreadable.",
            },
        },
        {
            version = "0.9.0-alpha.1",
            title = "Holy Paladin Support",
            changes = {
                "Add Holy Paladin priorities for Herald of the Sun and Lightsmith.",
                "Add separate Mythic+ and Raid packs with Standard, AoE, Single Target and Mana Saving modes.",
                "Estimate Holy Power locally from confirmed player casts only.",
                "Make Divine Toll, Holy Prism, Holy Armaments and Holy Shock charges talent-aware.",
            },
        },
        {
            version = "0.8.7-alpha.1",
            title = "Reliable Rapid Inputs",
            changes = {
                "Debounce hotkeys per input instead of globally.",
                "Preserve cast confirmations for rapidly alternating abilities.",
                "Keep Riptide charges synchronized with successful instant casts.",
            },
        },
        {
            version = "0.8.6-alpha.1",
            title = "Selectable Interface Language",
            changes = {
                "Add an account-wide language selector for Client Language, German or English.",
                "Keep Client Language as the default and follow the WoW setting automatically.",
                "Save language changes and apply them fully after a UI reload.",
                "Correct Healing Stream Totem recharge to 17 seconds.",
            },
        },
        {
            version = "0.8.5-alpha.1",
            title = "What's New and Update History",
            changes = {
                "Show a one-time What's New window on the first /hh after an update.",
                "Store seen status account-wide instead of repeating notices per character or profile.",
                "Add an Update History page and direct access through /hh changelog.",
                "Select a German or English interface automatically from the WoW client language.",
            },
        },
        {
            version = "0.8.4-alpha.1",
            title = "Beta Hardening",
            changes = {
                "Warn about duplicate independent hotkey assignments.",
                "Add versioned profile migration and safe out-of-combat reconciliation.",
                "Add diagnostic export through /hh debug and automated GitHub releases.",
            },
        },
        {
            version = "0.8.3-alpha.1",
            title = "Input Lifecycle",
            changes = {
                "Activate the tracker only for Restoration Shaman and Restoration Druid.",
                "Correct instant-GCD handling and stale callback locks.",
                "Reset local state safely after specialization, talent and profile changes.",
            },
        },
        {
            version = "0.8.2-alpha.1",
            title = "Cast Confirmation",
            changes = {
                "Advance recommendations only after a confirmed successful spell.",
                "Correct Stormstream and Nature's Swiftness charge handling.",
                "Buffer instant-cast successes that arrive before action-bar hooks.",
            },
        },
        {
            version = "0.8.1-alpha.1",
            title = "Healing Modes and Druid Support",
            changes = {
                "Add Restoration Druid priorities and local HoT counters.",
                "Add optional AoE, Single Target and Mana Saving modes.",
                "Improve talent-aware Shaman presets and charge handling.",
            },
        },
        {
            version = "0.8.0-alpha.1",
            title = "Initial Alpha",
            changes = {
                "Add a static Hekili-inspired healing priority tracker.",
                "Add Restoration Shaman presets, hotkey capture and local timers.",
                "Add a modern, movable and customizable icon HUD.",
            },
        },
    },
}

function ns.changelog:GetEntry(version)
    for _, entry in ipairs(self.entries) do
        if entry.version == version then return entry end
    end
end
