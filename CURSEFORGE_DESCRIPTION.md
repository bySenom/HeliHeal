# HeliHeal

HeliHeal is a lightweight, input-driven healing priority tracker for **World of Warcraft: Midnight**.

It displays up to five recommended abilities and updates its local rotation after confirming your configured keyboard or mouse inputs.

## Features

- Restoration Shaman and Restoration Druid support
- Mythic+ and Raid presets
- Standard, AoE, Single Target and Mana Saving modes
- Keyboard, modifier, mouse-button and mouse-wheel bindings
- Local cooldown, charge and HoT simulation
- GCD and successful-cast confirmation
- Movable and scalable Hekili-inspired display
- Persistent profiles and appearance settings

## Supported Builds

- Shaman: Totemic and Farseer
- Druid: Wildstalker and Keeper of the Grove

## Setup

1. Install HeliHeal in `World of Warcraft/_retail_/Interface/AddOns/`.
2. Open the settings with `/hh`.
3. Select a preset.
4. Assign the same hotkeys used on your action bars.
5. Move and lock the display.

## Commands

- `/hh` — Open settings
- `/hh lock` — Lock or unlock the display
- `/hh mode standard|aoe|single|mana` — Change healing mode
- `/hh talents` — Show detected talents
- `/hh sync` — Reset the local simulation

## Limitations

HeliHeal does not inspect health, mana, targets, auras, range, combat logs or SecretValues. Recommendations are based on fixed priorities, confirmed player spell casts and locally simulated states.

This is an **Alpha release**. Bug reports are welcome on [GitHub](https://github.com/bySenom/HeliHeal/issues).
