# HeliHeal 0.9.16 Beta 1

For **World of Warcraft: Midnight 12.1**.

## Changes

- Fixed the `AUTO`/`MANA` badge overlapping the `OR` choice indicator.
- Kept `OR` directly above the situational ability pair while moving `AUTO`/`MANA` one stable row higher.
- Preserved the HUD position when either badge appears or disappears.

## Limitations

- The automatic mana feature remains an estimated local model and is marked as beta.

## Validation

- All 26 automated Lua tests passed.
- The release package includes `ManaTracker.lua` and all required runtime files.
- The package contains only runtime files, documentation and required embedded libraries.
- The version tag matches `HeliHeal.toc`.
- This beta release is intended for in-game testing and player feedback.
