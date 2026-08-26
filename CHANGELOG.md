# HeliHeal 1.0.0

For **World of Warcraft: Midnight 12.1**.

## Changes

- Link a character's active Blizzard talent loadout to the currently selected rotation preset and healing mode.
- Automatically restore linked rotations when switching talent loadouts while retaining hero-talent detection for unlinked builds.
- Keep the selected build and rotation mode visibly highlighted in the options window.
- Correlate One Button Assistant Nature's Swiftness consumers even when Blizzard reports the consumer before the cooldown spell.
- Synchronize Holy Power when Shield of the Righteous or Crusader Strike succeeds outside HeliHeal's configured healing slots.
- Use a 20-second Healing Stream Totem recharge for Farseer and a talent-aware 17-second recharge with Totemic Momentum.

## Validation

- All 26 automated Lua tests passed.
- Lua syntax validation passed for every runtime file.
- The packaged addon contains only runtime files, documentation and required embedded libraries.
- The version tag matches `HeliHeal.toc`.

## Note

Automatic Mana Saving remains an optional estimated local model and continues to carry an in-game BETA label.
