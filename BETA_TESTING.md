# HeliHeal Beta Test Checklist

Record the WoW build, HeliHeal version, class, hero talents, content preset and configured hotkeys with every test run.

## Installation and lifecycle

- Fresh install loads without Lua errors.
- `/reload` preserves profile, position, style and bindings.
- The first `/hh` after an update shows What's New once; later openings stay quiet.
- `/hh changelog` opens the complete local update history and does not repeat the popup.
- `deDE` shows German UI text; `enUS`/`enGB` show English UI text and spell names follow the client locale.
- Language defaults to Client Language; selecting German or English persists account-wide after the automatic UI reload.
- Switching away from a supported healing specialization hides the tracker; switching back restores it.
- Profile switching clears pending inputs without losing the selected profile's bindings.
- Death, resurrection and loading screens do not advance recommendations.

## Input confirmation

- Keyboard, modifier, mouse button and mouse wheel inputs confirm only after the expected successful cast.
- Mouse buttons work over party and raid frames.
- Spamming a held or repeated key consumes exactly one cast or charge.
- Failed, interrupted, out-of-range and invalid-target casts keep the recommendation.
- One Button Assistant queueing does not advance HeliHeal before the actual spell succeeds.
- Holy Paladin: use Judgment, Crusader Strike and Shield of the Righteous through the One Button Assistant; `/hh diagnostics` must follow the real 0-5 Holy Power value.
- Cast Shift-bound Avenging Wrath: the recommendation must disappear immediately after `UNIT_SPELLCAST_SUCCEEDED`, even though Wings is off the GCD.
- Outside combat, verify Holy Shock's local recharge matches `6 / (1 + spell haste)`; entering combat must retain that safe snapshot.
- Verify Light of Dawn/Holy Light/Flash of Light show `AOE`/`SAVE`/`BURST`, while Chain Heal/Healing Wave show `AOE`/`SINGLE`.
- Open `/hh` > HUD Elements and verify the mouse wheel reaches every row without overlapping the fixed bottom bar.
- Change primary and secondary icon width, height, zoom and X/Y position; verify the preview updates immediately.
- Move and resize the hotkey badge, cooldown, role label, priority badge, ability name and header independently; Appearance Reset must restore every default.
- Change HUD font, outline and every color swatch; verify the preview updates immediately.
- Open the Font and Text Outline dropdowns; verify all choices are visible, the active choice is highlighted and clicking outside closes the menu.
- Verify all five HUD subcategories show only their relevant controls and retain changes when switching categories.
- Create an empty profile, copy the current profile, switch through the existing-profile dropdown, then delete only a non-active profile using the two-click confirmation.
- Instant casts such as Riptide and Rejuvenation advance without an extra 1.5-second delay.

## Restoration Shaman

- Riptide uses the talent-correct 6-second recharge and charge cap.
- Nature's/Ancestral Swiftness at 2/2 grants one Stormstream use, then leaves exactly 2/2 normal Healing Stream charges.
- Stormstream, normal Healing Stream and repeated mouse-button spam never double-spend charges.
- Downpour inherits Healing Rain's binding without a false duplicate-binding warning.
- Nature's Swiftness and Ancestral Swiftness immediately leave the recommendations after a successful off-GCD cast, including modifier bindings such as `SHIFT-3`.
- Unleash Life immediately starts its local cooldown and leaves the ready recommendations after a successful cast, even when its action hook is missed.
- Using an untracked random Stormstream proc keeps the current normal Healing Stream charge count unchanged; a following normal Healing Stream cast spends exactly one charge.
- Totemic and Farseer presets retain the chosen Mythic+ or Raid content type after talent changes.

## Restoration Druid

- Lifebloom refreshes its single local application instead of increasing the counter.
- Rejuvenation advances the local coverage counter and expires applications on schedule.
- Germination and Power of the Archdruid modify only the intended local counters.
- Mythic+ and Raid coverage goals match the selected Standard, AoE, Single Target or Mana mode.

## Holy Paladin

- Herald of the Sun uses Eternal Flame while Lightsmith uses Word of Glory and Holy Armaments.
- With Beacon of Virtue talented in Mythic+, verify it appears as a 15-second BURST setup in Standard/AoE, leaves after a confirmed cast, and stays out of Single Target/Mana Saving.
- Divine Toll or Holy Prism appears only for the selected talent; Holy Armaments accepts both alternating spell casts through one binding.
- Quickened Invocation reduces the local generator cooldown by 15 seconds and Light's Conviction adds the second Holy Shock charge.
- Confirmed generators increase the local Holy Power estimate; spenders stay hidden below 3 and are forced first at 5.
- Aurora's guaranteed free spender does not consume Holy Power; `/hh hp 0-5` manually corrects an unreadable random Divine Purpose proc.
- Raid Standard/AoE prioritizes Light of Dawn while Mythic+ Standard/Single Target prioritizes the hero-appropriate single-target spender.

## Holy Priest

- Archon exposes Halo at its 60-second cooldown; Oracle hides Halo and grants two 12-second Prayer of Mending charges.
- Holy Celerity reduces Holy Word recharge from 60 to 45 seconds; Oracle Prophet's Insight reduces it by another 5 seconds.
- Miracle Worker grants a second Serenity and Sanctify charge without changing their recharge duration.
- Flash Heal reduces Serenity by 6 seconds and Prayer of Healing reduces Sanctify by 6 seconds.
- Voice of Harmony additionally makes Prayer of Mending reduce Serenity and Halo reduce Sanctify by 4 seconds.
- Light of the Naaru scales all confirmed Serendipity reductions by 10% per selected rank.
- Apotheosis grants/resets the appropriate Holy Word charges, lasts locally for 20 seconds (32 with Eternal Sanctity) and triples confirmed Serendipity reductions during that window.
- With Ultimate Serenity selected, Sanctify stays hidden and Prayer of Healing reduces Serenity instead.
- At capped Holy Word charges with Apotheosis ready, HeliHeal recommends spending one charge before Apotheosis instead of wasting its reset/granted charge.
- Divine Hymn, Guardian Spirit, Apotheosis, Serenity, Sanctify and Prayer of Mending start their local cooldown or recharge only after a successful player cast; Prayer of Healing and Flash Heal only reduce Holy Words after success.

## Recovery and diagnostics

- Leaving combat clears stale input locks while preserving still-active cooldown estimates.
- `/hh sync` reconciles local estimates; `/hh reset` performs a full reset.
- Duplicate independent hotkeys are visibly marked in the priority settings.
- Long bindings such as `SHIFT-BUTTON5` remain fully readable without overlapping adjacent hotkey badges.
- After several minutes with the HUD active, addon memory remains stable after one forced garbage collection instead of rapidly rebuilding toward the previous usage level.
- `/hh debug` prints version, build, spec, preset, mode, talents, bindings and local-state counts without unit combat data.

For every failure, attach the `/hh debug` output, exact reproduction steps and whether `/hh sync` corrected the state.
