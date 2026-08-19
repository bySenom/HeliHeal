# HeliHeal 0.9.14 Beta 1

For **World of Warcraft: Midnight 12.1**.

## Changes

- Added an optional healer-dispel cooldown icon beside the mouse cursor.
- Tracks Purify Spirit, Nature's Cure, Cleanse, Purify and Detox from Blizzard-confirmed successful casts.
- Moves the dispel icon smoothly every frame while keeping cooldown and rotation updates throttled.
- Added configurable cursor-icon size and horizontal/vertical offsets.
- Increased the default horizontal offset so the icon no longer overlaps the mouse pointer.
- Preserved local cooldowns, charges and simulated states across supported loading screens and zone transitions.
- Fixed multi-digit MultiActionBar button parsing, including buttons 10 through 12.

## Limitations

- The dispel display uses a local eight-second timer after a confirmed cast; it does not inspect debuffs, targets or combat auras.
- Health, mana, targets, range, healing results, combat logs and SecretValues remain unread.

## Validation

- All 25 automated Lua tests passed.
- All runtime Lua files passed syntax validation.
- The package contains only runtime files, documentation and required embedded libraries.
- The version tag matches `HeliHeal.toc`.
- This beta release is intended for in-game testing and player feedback.
