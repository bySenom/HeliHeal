# HeliHeal 0.8.2 Alpha 1 (Midnight 12.1)

![HeliHeal logo](Media/HeliHealLogo.png)

HeliHeal is a static, player-driven healing priority display for World of Warcraft: Midnight. It deliberately does not inspect combat state.

## Data contract

HeliHeal does **not** call aura, ability-cooldown, health, power, target, range, combat-log, encounter or secret-value APIs. A configured ability cooldown remains a local timer. Player-only spell-success/failure events confirm whether an observed input actually produced the expected spell, and the universal GCD spell (`61304`) is sampled only for its remaining lockout.

Talent selections are read only outside combat from the player's committed active Blizzard trait config and cached as a local build snapshot. During combat HeliHeal uses that snapshot and performs no talent-tree scan.

For Shaman, the snapshot recognizes Echo of the Elements, Elemental Reverb, Surging Totem, Unleash Life, Downpour, Double Dip, Mystic Knowledge and the Restoration Season 1 two-/four-piece bonuses. For Druid, it recognizes Germination, Power of the Archdruid, Lifetreading and the active Wildstalker/Keeper hero subtree. Active hero talents automatically synchronize the hero half of the selected preset while preserving the player's Mythic+ or Raid content choice. Inactive hero subtrees are ignored.

The only spell API call is `C_Spell.GetSpellInfo(spellID)`, used to resolve static display metadata (name and icon). That metadata never changes priority decisions.

## Setup

1. Enter `/hh` to open HeliHeal's custom modern configuration window.
2. Select the guide preset for the character's supported Restoration specialization.
3. Assign the observed action-bar input for each listed ability.
4. Keep the default Standard mode or select the optional AoE, Single Target or Mana Saving view.
5. Drag the display and then lock it.

The default HUD contains only the spell icon, observed hotkey and local cooldown number. Header, shared panel background, ability name, priority badge, icon border, hotkey and cooldown text can each be toggled under `/hh` → `HUD-Elemente`.

## Restoration Shaman 12.1 rotations

HeliHeal 0.8.0 ships fixed Restoration Shaman priority packs for Totemic Mythic+, Totemic Raid, Farseer Mythic+ and Farseer Raid. The data follows the Wowhead Midnight rotation guide updated on 2026-08-10:

https://www.wowhead.com/guide/classes/shaman/restoration/rotation-cooldowns-pve-healer

## Restoration Druid 12.1 rotations

HeliHeal 0.8.0 adds Wildstalker and Keeper packs for Mythic+ and Raid. Their static priorities emphasize Lifebloom maintenance, frequent Swiftmend and Wild Growth use, pre-emptive Rejuvenation coverage, Nature's Swiftness and Regrowth. They follow the current Wowhead Midnight rotation guide:

https://www.wowhead.com/guide/classes/druid/restoration/rotation-cooldowns-pve-healer

Rejuvenation uses a strictly input-derived rolling estimate. Every acknowledged Rejuvenation input adds one local application for 12 seconds, or 14 seconds when the out-of-combat talent snapshot contains Germination. The HUD shows the estimated active count against the current mode's goal, for example `3/5`. When the goal is reached, Rejuvenation moves into the waiting list until the oldest estimated application expires. Mythic+ caps the estimate at five targets, Raid at twenty; Germination doubles that capacity because two applications may coexist on one target.

Because HeliHeal reads no target or aura data, refreshing Rejuvenation on an already covered player cannot be distinguished from applying it to a new player. The counter is an intentionally conservative estimate, not an authoritative aura count. Swiftmend also does not subtract an application because the addon cannot know which HoT Blizzard consumed.

Lifebloom uses the same local model with one assumed 15-second application. Power of the Archdruid is armed locally for 15 seconds after an acknowledged Swiftmend; the next acknowledged Rejuvenation adds three estimated applications, while Regrowth consumes the pending state without changing the Rejuvenation count.

Spell IDs, names, cooldowns and priority positions are addon-owned and cannot be edited in the UI. The player configures only the observed WoW action-bar hotkey for each ability. Up to five entries from the active priority view are visible in the HUD at once.

Standard remains the unchanged guide-preset order and is the default. AoE, Single Target and Mana Saving are optional contextual reorderings of the same preset; they do not replace it or inspect the combat situation. Switch with the mode buttons under `/hh`, `/hh mode standard|aoe|single|mana`, or `/hh mode next` from a macro.

In AoE mode, observing Healing Rain arms Downpour for 16 seconds only when the cached build contains the talent. Because Downpour temporarily replaces Healing Rain on the action bar, it automatically inherits the Healing Rain input and requires no second binding. Double Dip raises the local state from one to two uses.

Binding capture supports keyboard keys, `BUTTON1`/`BUTTON2`/`BUTTON3`, extra mouse buttons such as `BUTTON4` and `BUTTON5`, mouse wheel up/down, and Shift/Ctrl/Alt combinations. Mouse capture exists only while the player explicitly clicks a binding field outside combat.

Configured mouse buttons are additionally observed through `GLOBAL_MOUSE_DOWN`. This keeps inputs such as `BUTTON5` visible when a unit or raid frame consumes the click for mouseover healing. HeliHeal reads neither the hovered frame nor its unit; every matching physical mouse press is treated as an acknowledgement.

Stormstream Totem is proc-driven and does not consume the normal Healing Stream charge. Since HeliHeal intentionally reads no aura/proc state, both variants are represented by one `Healing Stream / Stormstream Totem` input. This is an explicit static approximation, not a claim that the proc is active.

Healing Stream uses a local two-charge model with sequential 30-second recharge. Observing Nature's Swiftness or Ancestral Swiftness adds one synthetic Stormstream use (up to two stored uses). That use is consumed before the normal charges, so a full `3/2` state keeps Healing Stream recommended for Stormstream plus both normal casts. While more than one simulated use is ready, the existing cooldown text area displays `×3` or `×2`. Random Stormstream procs from Riptide cannot be observed in restricted combat and are intentionally not added.

Riptide uses a six-second sequential base recharge. Its maximum local charges are derived from the cached talents: one base charge, plus one for Echo of the Elements and one for Elemental Reverb. Mystic Knowledge accelerates the simulated recharge rate by 10% for eight seconds after an observed Swiftness input. After observing Nature's Swiftness or Ancestral Swiftness, HeliHeal arms a local pending state, hides the already-pressed Swiftness entry and moves Chain Heal ahead of Stormstream. The Swiftness cooldown starts only after an observed Riptide, Chain Heal, Healing Wave or Healing Rain input consumes that state.

Observing Unleash Life arms a ten-second local empower state for Riptide, Chain Heal or Healing Wave. The preferred ready consumer follows the selected healing mode: Chain Heal in AoE, Riptide then Healing Wave in Single Target, and Healing Wave in Mana Saving. Standard retains its guide order with Riptide as the first valid consumer. The Season 1 two-piece changes the local Unleash Life cooldown from 20 to 17 seconds; the four-piece stores two empowered consumers. No aura is read, so a failed consumer can be corrected with `/hh refund riptide|chain|wave`.

HeliHeal observes the secure post-hooks of Blizzard's `ActionButtonDown` and `MultiActionButtonDown` paths. If the configured key (for example `Shift+1`) is bound to that action-bar button, HeliHeal creates a pending local observation after Blizzard processes the key. It never owns or propagates the combat key event and never casts abilities.

An observation advances the rotation only when `UNIT_SPELLCAST_SUCCEEDED` reports the configured player spell. Failed or interrupted matching casts clear the pending observation without consuming the recommendation, and an unmatched five-second timeout does the same. This keeps recommendations visible when their keys are spammed too early during another cast. After success, HeliHeal samples `C_Spell.GetSpellCooldown(61304)` on the next frame and uses the live universal GCD remainder for the input lock; restricted or unavailable values fall back safely to 1.5 seconds.

Input spam is guarded by a complete press/release latch, one pending observation per ability and the live universal GCD lock. Holding a key counts once until Blizzard's matching action-button-up path, and mouse buttons remain latched until `GLOBAL_MOUSE_UP`. Repeated physical presses cannot remove recommendations or spend local charges before the expected spell succeeds.

Commands: `/hh`, `/hh talents [refresh]`, `/hh used 1`, `/hh mode standard|aoe|single|mana|next`, `/hh refund hst|riptide|downpour|rain|unleash|chain|wave`, `/hh sync`, `/hh reset`, `/hh show`, `/hh hide`, `/hh lock`.

`/hh refund` restores the named local state after an input that did not produce a successful cast. `/hh sync` performs a complete local state reset. Neither command validates the real spell state.

## Architecture

- `AbilityLibrary.lua`: stable public registration and metadata-resolution API for future class data packs.
- `Core.lua`: profiles, slash commands and player acknowledgements.
- `Input.lua`: taint-safe observation of Blizzard action-bar key post-hooks and physical mouse-button events.
- `Display.lua`: Hekili-inspired five-icon presentation driven only by local timers.
- `Options.lua`: custom Midnight-native configuration window with overview, priority and profile pages.

AceAddon, AceConsole and AceDB are embedded under `Libs/` and retain the upstream Ace3 license. The embedded source revision is recorded in `Libs/ACE3_REVISION.txt`. The visible UI uses lightweight native WoW frames rather than the legacy AceConfig skin.

Aura/proc tracking is intentionally absent. Midnight 12.1's filtered aura display APIs are designed to render filtered aura sets without exposing underlying data for decision logic; a future visual-only adapter must remain separate from the priority engine.

## Bugs and feedback

Please report reproducible issues and suggestions through [GitHub Issues](https://github.com/bySenom/HeliHeal/issues).
