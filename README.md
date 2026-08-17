# HeliHeal

<p align="center">
  <img src="Media/HeliHealLogo.png" alt="HeliHeal" width="320">
</p>

HeliHeal is a lightweight, input-driven healing priority tracker for **World of Warcraft: Midnight 12.1**. It presents up to five recommended abilities in a movable, Hekili-inspired icon strip.

> HeliHeal is currently a **Beta release** intended for in-game testing and feedback.

## Features

- Restoration Shaman, Restoration Druid, Holy Paladin, Holy Priest and Discipline Priest priority packs
- Separate Mythic+ and Raid presets
- Standard, AoE, Single Target and Mana Saving modes
- Keyboard, modifier, mouse-button and mouse-wheel bindings
- Mouse-button support over unit and raid frames
- Successful-cast confirmation and live GCD locking
- Local cooldown, charge and HoT estimates
- Optional AOE, SINGLE, BURST and SAVE role labels on contextual healing icons
- Per-element HUD sizing, positioning, icon zoom, fonts, outlines and colors
- Out-of-combat spell-haste snapshots for haste-scaled healer cooldowns
- Automatic Blizzard One Button Assistant detection on standard action bars
- Live Holy Power synchronization for the player, with confirmed-cast fallback
- Talent-aware Holy Priest Holy Word charges, recharge times and Serendipity reductions
- Discipline Priest group/single-target Atonement estimates, Penance charges and haste-scaled cooldowns
- Movable, scalable and customizable display
- Persistent AceDB profiles
- One-time What's New popup and local update history
- Selectable Client Language, German or English UI with client-localized spell names

## Supported builds

| Class | Hero talents | Content |
|---|---|---|
| Restoration Shaman | Totemic, Farseer | Mythic+, Raid |
| Restoration Druid | Wildstalker, Keeper of the Grove | Mythic+, Raid |
| Holy Paladin | Herald of the Sun, Lightsmith | Mythic+, Raid |
| Holy Priest | Archon, Oracle | Mythic+, Raid |
| Discipline Priest | Oracle, Voidweaver | Mythic+, Raid |

## Installation

1. Download the latest ZIP from [GitHub Releases](https://github.com/bySenom/HeliHeal/releases).
2. Extract the `HeliHeal` folder into `World of Warcraft/_retail_/Interface/AddOns/`.
3. Enable HeliHeal at character selection.
4. Open the settings with `/hh`.
5. Select a preset and assign the same hotkeys used on your action bars.

## How it works

HeliHeal observes configured action-bar and physical mouse inputs without replacing Blizzard's protected input handling. A recommendation advances only after Blizzard confirms that the expected player spell succeeded. Failed, interrupted or unmatched inputs do not consume it.

Class mechanics such as Healing Stream charges, Stormstream uses, Riptide recharge, Rejuvenation coverage, Holy Power, Holy Word cooldown reduction and Discipline Priest charge/recharge rules are simulated locally from confirmed casts and an out-of-combat talent snapshot.

## Commands

| Command | Description |
|---|---|
| `/hh` | Open settings |
| `/hh lock` | Lock or unlock the display |
| `/hh mode standard\|aoe\|single\|mana` | Change healing mode |
| `/hh talents` | Show detected talents |
| `/hh hp 0-5` | Manually synchronize the local Holy Power estimate |
| `/hh sync` | Reconcile local estimates outside combat |
| `/hh reset` | Reset local timers and charges |
| `/hh debug` | Print a compact diagnostic report |
| `/hh changelog` | Open the in-game update history |

## Limitations

HeliHeal does not inspect health, mana, targets, auras, range, healing results, combat logs or SecretValues. The only live combat resource it reads is the player's Blizzard-permitted secondary Holy Power value. Spell haste is cached outside combat, so temporary in-combat haste buffs do not alter local recharge estimates. It cannot automatically know when raid damage is incoming, whether a HoT was refreshed on the same target, or recommend unreadable random procs such as Divine Purpose, Surge of Light or Benediction before they are consumed. Guaranteed talent effects and confirmed casts remain available as a fallback; `/hh hp 0-5` can manually synchronize the Holy Power estimate.

## Feedback

Please report reproducible bugs and suggestions through [GitHub Issues](https://github.com/bySenom/HeliHeal/issues).
Use the [Beta Test Checklist](BETA_TESTING.md) for structured in-game verification.

HeliHeal is available under the [MIT License](LICENSE). Embedded Ace3 libraries retain their upstream license.
