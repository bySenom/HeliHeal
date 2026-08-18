# HeliHeal 0.9.13 Beta 1

For **World of Warcraft: Midnight 12.1**.

## Changes

- Added complete Mistweaver Monk support for Conduit of the Celestials and Master of Harmony in Mythic+ and Raid.
- Separated Conduit and Harmony priority paths while keeping every supported talent replacement bindable.
- Standard mode now exposes both single-target and AoE melee fillers, including Spinning Crane Kick.
- Added local Renewing Mist coverage, Sheilun cloud, Teachings of the Monastery and Thunder Focus Tea simulations.
- Added supported Heart of the Jade Serpent cooldown recovery for Renewing Mist, Rising Sun Kick, Life Cocoon and Thunder Focus Tea.
- Improved current hero-talent, choice-node and replacement-spell detection.
- Confirmed Sheilun's Gift directly from successful casts and prevented it from behaving like a fake cooldown ability.
- Preserved the last valid talent snapshot when Blizzard's trait API is temporarily unavailable.
- Improved the priorities page for larger talent packs and smaller UI resolutions.
- Aligned GitHub and CurseForge packages around the same lean runtime file set.

## Limitations

- Health, mana, targets, auras, combat logs and SecretValues remain unread.
- Random Spiritfont, Dance of Chi-Ji and Strength of the Black Ox procs cannot be recommended automatically.
- Mana Tea stacks and Master of Harmony vitality are not guessed.

## Validation

- All automated Lua tests passed.
- Runtime Lua syntax, TOC entries and package contents were verified.
- The version tag matches `HeliHeal.toc`.
- This beta release is intended for in-game testing and player feedback.
