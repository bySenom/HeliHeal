# HeliHeal 1.0.0

For **World of Warcraft: Midnight 12.1**.

## Changes

- Assign any saved Blizzard talent loadout to a rotation preset and healing mode per character.
- Automatically restore assigned rotations when switching talent loadouts while retaining hero-talent detection for unassigned builds.
- Keep the selected build and rotation mode visibly highlighted in the options window.
- Correlate One Button Assistant Nature's Swiftness consumers even when Blizzard reports the consumer before the cooldown spell.
- Synchronize Holy Power when Shield of the Righteous or Crusader Strike succeeds outside HeliHeal's configured healing slots.
- Use a 20-second Healing Stream Totem recharge for Farseer and a talent-aware 17-second recharge with Totemic Momentum.
- Hide Healing Rain when Surging Totem replaces it in Totemic builds.
- Keep the complete in-game update history in English on every client language.
- Show HeliHeal memory usage and optional CPU profiling statistics in the options sidebar.
- Scale the complete options window from 65% to 135% with a persistent bottom-right resize grip.
- Customize the options-window background and accent or automatically use the current character's class color.
- Rework profile management into compact active-profile, creation, maintenance and protected deletion sections.

## Validation

- All 26 automated Lua tests passed.
- Lua syntax validation passed for every runtime file.
- The packaged addon contains only runtime files, documentation and required embedded libraries.
- The version tag matches `HeliHeal.toc`.

## Note

Automatic Mana Saving remains an optional estimated local model and continues to carry an in-game BETA label.
