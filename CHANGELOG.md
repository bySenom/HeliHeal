# HeliHeal 0.9.9 Beta 1

For **World of Warcraft: Midnight 12.1**.

## Changes

- Added Midnight 12.1 Holy Priest support for Archon and Oracle in Mythic+ and Raid.
- Added Midnight 12.1 Discipline Priest support for Oracle and Voidweaver in Mythic+ and Raid.
- Added talent-aware Holy Word, Radiance and Penance charge handling.
- Added safe out-of-combat haste scaling for Penance, Mind Blast, Power Word: Shield and other supported healer cooldowns.
- Added separate local group and single-target Atonement estimates from confirmed Radiance, Shield and Void Shield casts.
- Power Word: Radiance now uses one logical 14-second group-Atonement cycle and confirms directly from successful casts.
- Power Word: Shield and Void Shield now share one binding and successful-cast confirmation path.
- Fixed Mouse Button 1 hotkey capture.
- Added hold-Escape hotkey removal with progress feedback while keeping the options window open.

## Validation

- All automated Lua tests passed.
- The version tag matches `HeliHeal.toc`.
- The packaged addon contains only runtime files and documentation.
- This beta release is intended for continued in-game testing and player feedback.
