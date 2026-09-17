# HeliHeal 1.0.2

For **World of Warcraft: Midnight** (Interface 120007 / 120100).

## Changes

- Track Infusion of Light and Divine Purpose through individually identified Blizzard Tracked Buffs or Bars, preserving Ellesmere icon assignments.
- Add the background PROCS editor with spell icons, ACTIVE / INACTIVE / UNKNOWN status and automatic out-of-combat assignment of uniquely matching buffs.
- Integrate confirmed Divine Purpose into Holy Paladin priorities and free-spender Holy Power accounting without simulating random procs.
- Correct Holy Armaments talent modifiers, Valiance reductions, charge reconciliation and duplicate cast handling.
- Correct Judgment cooldown modeling and apply Crusader's Might and Shield of the Righteous cooldown reductions.
- Improve individually customizable windows, defensive display behavior, collapsible spell-icon FAQs and copyable rotation snapshots.
- Fix release packaging to include all runtime modules and check every TOC module.

## Validation

- All 32 automated Lua tests passed locally. The release workflow also runs the suite with Lua 5.1.
- Lua syntax validation passed for every runtime file.
- The packaged addon contains only runtime files, documentation and required embedded libraries.
- The version tag matches `HeliHeal.toc`.

## Note

Automatic Mana Saving remains an optional estimated local model and continues to carry an in-game BETA label.

The user reports Holy Paladin is working well; this does not establish runtime correctness for every specialization, talent build or Ellesmere configuration. Missing or unreadable proc sources report UNKNOWN. Cooldown and resource tracking remain local estimates.
