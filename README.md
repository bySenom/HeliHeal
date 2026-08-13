# HeliHeal

<p align="center">
  <img src="Media/HeliHealLogo.png" alt="HeliHeal" width="320">
</p>

HeliHeal is a lightweight, input-driven healing priority tracker for **World of Warcraft: Midnight 12.1**. It presents up to five recommended abilities in a movable, Hekili-inspired icon strip.

> HeliHeal is currently an **Alpha release** intended for testing.

## Features

- Restoration Shaman, Restoration Druid and Holy Paladin priority packs
- Separate Mythic+ and Raid presets
- Standard, AoE, Single Target and Mana Saving modes
- Keyboard, modifier, mouse-button and mouse-wheel bindings
- Mouse-button support over unit and raid frames
- Successful-cast confirmation and live GCD locking
- Local cooldown, charge and HoT estimates
- Automatic Blizzard One Button Assistant detection on standard action bars
- Live Holy Power synchronization for the player, with confirmed-cast fallback
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

## Installation

1. Download the latest ZIP from [GitHub Releases](https://github.com/bySenom/HeliHeal/releases).
2. Extract the `HeliHeal` folder into `World of Warcraft/_retail_/Interface/AddOns/`.
3. Enable HeliHeal at character selection.
4. Open the settings with `/hh`.
5. Select a preset and assign the same hotkeys used on your action bars.

## How it works

HeliHeal observes configured action-bar and physical mouse inputs without replacing Blizzard's protected input handling. A recommendation advances only after Blizzard confirms that the expected player spell succeeded. Failed, interrupted or unmatched inputs do not consume it.

Class mechanics such as Healing Stream charges, Stormstream uses, Riptide recharge, Rejuvenation coverage and Holy Power are simulated locally from confirmed casts and an out-of-combat talent snapshot.

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

HeliHeal does not inspect health, mana, targets, auras, range, healing results, combat logs or SecretValues. The only live combat resource it reads is the player's Blizzard-permitted secondary Holy Power value. It cannot automatically know when raid damage is incoming, whether a HoT was refreshed on the same target, or recommend an unreadable random Divine Purpose proc before it is consumed. Guaranteed talent effects and confirmed casts remain available as a fallback; `/hh hp 0-5` can manually synchronize the estimate.

## Feedback

Please report reproducible bugs and suggestions through [GitHub Issues](https://github.com/bySenom/HeliHeal/issues).
Use the [Beta Test Checklist](BETA_TESTING.md) for structured in-game verification.

HeliHeal is available under the [MIT License](LICENSE). Embedded Ace3 libraries retain their upstream license.
