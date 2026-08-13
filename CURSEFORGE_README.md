# HeliHeal

## What is HeliHeal?

HeliHeal is a lightweight, Hekili-inspired healing priority tracker for **World of Warcraft: Midnight 12.1**.

It displays up to five recommended healing abilities as a movable icon strip. Instead of reading protected combat data, HeliHeal follows a fixed class priority and advances its local simulation when you press the configured keyboard or mouse binding.

Choose a Restoration Shaman or Restoration Druid preset, assign the same bindings you use on your action bars, and let HeliHeal keep the next priorities visible.

HeliHeal does not cast spells, choose healing targets, inspect health values or use SecretValues.

## Features

- 🎯 Shows up to five abilities in a Hekili-style priority strip
- 🥇 Enlarged first icon for the current recommendation
- 🌊 Restoration Shaman support for Totemic and Farseer
- 🌿 Restoration Druid support for Wildstalker and Keeper of the Grove
- 🏰 Separate Mythic+ and Raid priority presets
- 🔄 Standard mode plus optional AoE, Single Target and Mana Saving priorities
- ⌨️ Keyboard bindings with Shift, Ctrl and Alt modifiers
- 🖱️ Mouse buttons, extra mouse buttons and mouse-wheel bindings
- 🎯 Physical mouse-button observation also works over unit and raid frames
- ⏱️ Input-driven cooldown, charge and maintenance-timer simulation
- ✅ Advances only after the expected player spell succeeds
- 🕒 Reads only the universal GCD remainder for post-cast input locking
- 🛡️ Key-down/key-up latch and per-ability lockout protect local charges from button spam
- 🌧️ Shaman Downpour window derived from an observed Healing Rain input
- 💧 Shaman Healing Stream and synthetic Stormstream charge model
- 🌊 Talent-aware Riptide charge and recharge model
- 🌱 Druid Rejuvenation rolling counter with Germination support
- 🌸 Druid Lifebloom maintenance timer
- 🌳 Swiftmend into Power of the Archdruid sequence modeling
- 🧠 Out-of-combat talent snapshot with automatic hero-tree preset selection
- 📐 Movable and scalable display with configurable icon spacing
- 🎨 Optional header, panel, spell names, priority badges, borders, hotkeys and timer text
- 💾 Position, bindings, appearance and named AceDB profiles persist across sessions
- ⚙️ Modern custom settings panel opened with `/hh`

## Supported Specializations

### Restoration Shaman

- Totemic — Mythic+
- Totemic — Raid
- Farseer — Mythic+
- Farseer — Raid

HeliHeal locally models Healing Stream charges, synthetic Stormstream uses granted by Nature's Swiftness or Ancestral Swiftness, Riptide charges, Mystic Knowledge recharge acceleration, Unleash Life consumers and the contextual Downpour window.

Random Stormstream, Ascendance and other aura-based procs are intentionally not tracked during restricted combat.

### Restoration Druid

- Wildstalker — Mythic+
- Wildstalker — Raid
- Keeper of the Grove — Mythic+
- Keeper of the Grove — Raid

The Druid priority covers Lifebloom maintenance, Swiftmend, Wild Growth, Rejuvenation coverage, Nature's Swiftness and Regrowth.

Every observed Rejuvenation input adds one estimated application for 12 seconds. Germination changes the estimate to 14 seconds and permits two applications per party or raid member. The HUD displays the current estimate against the selected mode's goal, for example `3/5`.

With Power of the Archdruid selected, an observed Swiftmend arms a 15-second local state. The next Rejuvenation counts as three estimated applications; Regrowth consumes the state without increasing the Rejuvenation counter.

## How It Works

HeliHeal uses fixed, addon-owned priority packs. You only configure the observed input for each listed ability.

When a matching action-bar or physical mouse input is detected, HeliHeal creates a pending observation. It updates its local timer or charge state only when Blizzard reports that the configured player spell succeeded. Failed, interrupted or unmatched inputs do not consume the recommendation. This keeps the next icon visible when its key is spammed too early during another cast.

After a confirmed spell, HeliHeal samples only the universal GCD spell (`61304`) to lock repeated input for the real remaining GCD. If that value is unavailable or restricted, it safely falls back to 1.5 seconds. `/hh refund` and `/hh sync` remain available for exceptional state corrections.

## Installation

1. Download and extract the archive. You should receive a `HeliHeal` folder.
2. Copy it to `World of Warcraft/_retail_/Interface/AddOns/`.
3. Enable HeliHeal at the character-selection screen.
4. Log in on a supported Restoration Shaman or Restoration Druid.
5. Enter `/hh` and select the desired Mythic+ or Raid preset.
6. Click each binding field and press the matching action-bar key or mouse button.
7. Drag the display into position and lock it when finished.

After updating, use `/reload` once if the new version is not immediately visible.

## Slash Commands

| Command | Description |
|---|---|
| `/hh` or `/heliheal` | Open the HeliHeal settings |
| `/hh show` | Show the priority display |
| `/hh hide` | Hide the priority display |
| `/hh lock` | Toggle display-position locking |
| `/hh mode standard` | Use the default guide priority |
| `/hh mode aoe` | Use the optional AoE priority |
| `/hh mode single` | Use the optional Single Target priority |
| `/hh mode mana` | Use the optional Mana Saving priority |
| `/hh mode next` | Cycle to the next healing mode |
| `/hh talents` | Print the cached talent snapshot |
| `/hh talents refresh` | Refresh talents outside combat |
| `/hh used <slot>` | Manually acknowledge a priority slot |
| `/hh reset` | Reset local timers and charges |
| `/hh sync` | Reset the complete local simulation |
| `/hh refund hst` | Restore the last local Healing Stream/Stormstream use |
| `/hh refund riptide` | Restore the last local Riptide use |
| `/hh refund downpour` | Restore a local Downpour use |
| `/hh refund rain` | Undo a failed Healing Rain input |
| `/hh refund unleash` | Undo a failed Unleash Life input |
| `/hh refund chain` | Undo Chain Heal and restore related local state |
| `/hh refund wave` | Undo Healing Wave and restore related local state |

## Settings

The custom `/hh` panel includes:

- Tracker visibility and position lock
- UI scale and icon spacing
- Mythic+ and Raid preset selection
- Standard, AoE, Single Target and Mana Saving modes
- Ability-specific keyboard and mouse bindings
- Optional panel background and header
- Optional spell names and priority badges
- Icon-border, hotkey and local-timer toggles
- Named profiles and safe local-state reset controls

The default display remains minimal: spell icons, configured hotkeys and local cooldown or counter text.

## Limitations

HeliHeal is an informational priority tracker, not an automated healer or a complete combat rotation solver.

It deliberately does not read:

- Player, party or raid health
- Mana or other combat resources
- Active auras on players or targets
- Actual spell cooldowns or charges
- Healing targets or mouseover units
- Range or target validity
- Combat-log events
- Cast targets or healing results
- Random combat procs
- SecretValues

All timers, charges and HoT counts are local estimates derived from observed inputs. Rejuvenation cannot distinguish a new target from refreshing the same target, because HeliHeal never reads the affected unit or its auras.

The addon cannot know when incoming raid damage occurs. AoE, Single Target and Mana Saving are therefore manual context modes rather than automatic encounter decisions.

## Privacy and Midnight Compatibility

HeliHeal does not collect combat data, send telemetry or communicate with an external service. Its priority engine uses no aura, health, power, target, range, combat-log or ability-cooldown APIs. Player-only spell success/failure events and the universal GCD remainder are used solely to confirm observed inputs and prevent premature recommendation changes.

The talent tree is read only outside combat from Blizzard's committed active configuration and cached for the static model. Spell names and icons are resolved only as presentation metadata.

## Credits

HeliHeal was inspired by Hekili's clear multi-icon priority presentation. It shares no code with Hekili and does not use Hekili's action-priority engine.

The class priority packs are based on current Restoration Shaman and Restoration Druid guidance for Midnight 12.1. HeliHeal is an independent informational addon and is not affiliated with Blizzard Entertainment, Wowhead or the Hekili project.

Embedded libraries:

- AceAddon-3.0
- AceConsole-3.0
- AceDB-3.0
- CallbackHandler-1.0
- LibStub

HeliHeal is distributed under the MIT License.

## Bugs & Feedback

Please report bugs and suggestions on the [GitHub Issues page](https://github.com/bySenom/HeliHeal/issues).

When reporting an issue, please include:

- HeliHeal version
- WoW version
- Class, hero tree and selected preset
- Selected healing mode
- Affected ability
- Configured keyboard or mouse binding
- Exact reproduction steps
- Screenshot or Lua error, if available
