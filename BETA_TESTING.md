# HeliHeal Beta Test Checklist

Record the WoW build, HeliHeal version, class, hero talents, content preset and configured hotkeys with every test run.

## Installation and lifecycle

- Fresh install loads without Lua errors.
- `/reload` preserves profile, position, style and bindings.
- The first `/hh` after an update shows What's New once; later openings stay quiet.
- `/hh changelog` opens the complete local update history and does not repeat the popup.
- `deDE` shows German UI text; `enUS`/`enGB` show English UI text and spell names follow the client locale.
- Switching away from Restoration hides the tracker; switching back restores it.
- Profile switching clears pending inputs without losing the selected profile's bindings.
- Death, resurrection and loading screens do not advance recommendations.

## Input confirmation

- Keyboard, modifier, mouse button and mouse wheel inputs confirm only after the expected successful cast.
- Mouse buttons work over party and raid frames.
- Spamming a held or repeated key consumes exactly one cast or charge.
- Failed, interrupted, out-of-range and invalid-target casts keep the recommendation.
- One Button Assistant queueing does not advance HeliHeal before the actual spell succeeds.
- Instant casts such as Riptide and Rejuvenation advance without an extra 1.5-second delay.

## Restoration Shaman

- Riptide uses the talent-correct 6-second recharge and charge cap.
- Nature's/Ancestral Swiftness at 2/2 grants one Stormstream use, then leaves exactly 2/2 normal Healing Stream charges.
- Stormstream, normal Healing Stream and repeated mouse-button spam never double-spend charges.
- Downpour inherits Healing Rain's binding without a false duplicate-binding warning.
- Totemic and Farseer presets retain the chosen Mythic+ or Raid content type after talent changes.

## Restoration Druid

- Lifebloom refreshes its single local application instead of increasing the counter.
- Rejuvenation advances the local coverage counter and expires applications on schedule.
- Germination and Power of the Archdruid modify only the intended local counters.
- Mythic+ and Raid coverage goals match the selected Standard, AoE, Single Target or Mana mode.

## Recovery and diagnostics

- Leaving combat clears stale input locks while preserving still-active cooldown estimates.
- `/hh sync` reconciles local estimates; `/hh reset` performs a full reset.
- Duplicate independent hotkeys are visibly marked in the priority settings.
- `/hh debug` prints version, build, spec, preset, mode, talents, bindings and local-state counts without unit combat data.

For every failure, attach the `/hh debug` output, exact reproduction steps and whether `/hh sync` corrected the state.
