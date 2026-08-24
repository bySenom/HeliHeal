# HeliHeal 0.9.17 Beta 1

For **World of Warcraft: Midnight 12.1**.

## Changes

- Ignore free automatic Raid, tier-set and Totem follow-up casts in the local mana ledger.
- Correlate mana costs with observed player input, including instant casts and the One Button Assistant.
- Add local Midnight buff-food and drink regeneration with ramping recovery rates.
- Detect Rip Current and reduce Riptide recharge from six to five seconds when talented.
- Show Unleash Life dynamically in the Totemic Raid priority when the talent is selected.

## Limitations

- The automatic mana feature remains an estimated local model and is marked as beta.

## Validation

- All 26 automated Lua tests passed.
- The release package includes `ManaTracker.lua` and all required runtime files.
- The package contains only runtime files, documentation and required embedded libraries.
- The version tag matches `HeliHeal.toc`.
- This beta release is intended for in-game testing and player feedback.
