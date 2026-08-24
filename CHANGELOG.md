# HeliHeal 0.9.15 Beta 1

For **World of Warcraft: Midnight 12.1**.

## Changes

- Added an optional beta mode that automatically enters Mana Saving below a configurable 20–30% local mana threshold.
- Added a persistent Restoration Shaman mana ledger based on Blizzard-confirmed successful casts and cached out-of-combat regeneration.
- Added maintained 12.1 mana costs for Healing Stream Totem, Riptide, Chain Heal, Healing Wave, Unleash Life and Surging Totem.
- Prevented spell-cost API results from overriding maintained static mana costs.
- Deduplicated Healing Stream and Stormstream spell aliases so one physical Totem cast spends mana only once.
- Recognized the automatic Chain Heal triggered by Healing Stream or Stormstream as a free follow-up cast.
- Included Water Shield in the regeneration model without counting its passive gain twice.
- Made the Shaman Mana Saving priority genuinely conservative by excluding Chain Heal and Surging Totem.
- Added an `AUTO`/`MANA` HUD badge for the local estimate and automatic mode state.
- Displayed situational AoE and single-target fillers as a stable `OR` choice pair above the icons.
- Delayed Nature's Swiftness cooldown consumption until its empowered Nature spell succeeds.

## Limitations

- Reactive mana gains such as Resurgence critical refunds and melee-triggered Water Shield returns remain untracked because HeliHeal does not inspect combat logs, healing results or combat auras.
- The automatic mana feature is an estimated local model and remains marked as beta.

## Validation

- All 26 automated Lua tests passed.
- The release package includes `ManaTracker.lua` and all required runtime files.
- The package contains only runtime files, documentation and required embedded libraries.
- The version tag matches `HeliHeal.toc`.
- This beta release is intended for in-game testing and player feedback.
