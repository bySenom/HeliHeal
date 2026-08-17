# HeliHeal 0.9.10 Beta 1

For **World of Warcraft: Midnight 12.1**.

## Changes

- Swiftmend is no longer recommended until HeliHeal has locally confirmed a compatible heal-over-time effect; Verdant Infusion removes this restriction.
- Rejuvenation duration now responds to Germination and Lingering Healing.
- Prosperity, Early Spring and Passing Seasons now modify Swiftmend charges and supported cooldowns.
- Soul of the Forest prioritizes Rejuvenation or Regrowth after Swiftmend, and Power of the Archdruid is tied to the correct talent sequence.
- Convoke the Spirits, Incarnation: Tree of Life and Tranquility are shown only when their talents are selected.
- Inner Peace and Flourish modify the local Tranquility and heal-over-time model.
- Wild Growth, Nature's Swiftness, Swiftmend and major Restoration Druid cooldowns confirm directly from successful casts.
- Expanded the Restoration Druid talent snapshot and diagnostics for major rotation-impacting talents.

## Validation

- All automated Lua tests passed.
- The version tag matches `HeliHeal.toc`.
- The packaged addon contains only runtime files and documentation.
- This beta release is intended for continued in-game testing and player feedback.
