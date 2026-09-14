# Holy Paladin 12.1 support

HeliHeal models Holy Paladin as a player-driven priority helper, not an automatic healer. It never selects a unit, casts a spell, or evaluates secret combat values.

## What is modeled

- The active Herald of the Sun or Lightsmith preset and its selected talents are read outside combat.
- Holy Power is updated from confirmed player casts and reconciled against Blizzard's permitted player Holy Power value after the cast.
- Holy Shock charges and haste-scaled recharge use the last safe out-of-combat haste snapshot.
- Shield of the Righteous spends three Holy Power and reduces the local Holy Shock recharge by two seconds.
- Holy Shock reduces Judgment's local cooldown when Crusader's Might is selected.
- Hammer of Wrath replaces Judgment only during a confirmed Avenging Wrath window and inherits Judgment's Holy Power bonuses.
- Avenging Crusader has its own timed window. Judgment remains available and Crusader Strike is added only during that window.
- Call of the Righteous and Sanctified Wrath alter the locally simulated Avenging Wrath or Avenging Crusader duration.
- Hand of Divinity tracks two Holy Light uses after Avenging Wrath, or one after Avenging Crusader, for up to 20 seconds.
- The deterministic 12.1 four-piece Holy Light trigger arms one local Infusion of Light. Random Holy Shock and Judgment Infusion procs are not guessed.
- Infusion prefers Flash of Light in healing modes and Judgment or its Hammer replacement in Mana Saving mode.
- When a locally known Infusion is consumed, Imbued Infusions reduces the locally tracked Holy Shock recharge by one second.
- Locally known Infusions expire after 15 seconds. Inflorescence of the Sunwell permits two locally tracked charges instead of silently overwriting the first.
- A separate **DEF / UTILITY** readiness strip tracks confirmed casts of Divine Protection, Divine Shield, Blessing of Sacrifice, Lay on Hands, Blessing of Protection and Divine Steed. It applies detected cooldown and charge talents without inserting these tools into the healing priority.
- Mythic+ omits Light of Dawn from the priority packs. Raid keeps it as a situational alternative behind the stronger single-target spender.

## Player-selected contexts

The mode is the player's statement of intent because HeliHeal cannot legally infer the healing situation:

- **Standard** — sustainable core priority; no forced major defensive or throughput cooldown.
- **AoE** — group damage and planned raid cooldown context. Aura Mastery and major throughput cooldowns may enter the priority.
- **Single Target** — urgent focused healing. Damage fillers are deprioritized and an available Hand of Divinity Holy Light is surfaced.
- **Mana Saving** — low-pressure or damage context. Judgment and Shield of the Righteous are favored over expensive direct healing.

## Deliberate limitations

HeliHeal cannot decide which player is injured, whether a cast would overheal, whether Beacon of Virtue is currently active on useful targets, whether a dispel is required, whether an enemy is in range, or when a boss mechanic requires a defensive. Those decisions need the player's unit frames, Blizzard's Cooldown Manager, encounter knowledge, and explicit mode choice.

The DEF / UTILITY strip means **available**, not **cast now**. It cannot evaluate incoming damage, Forbearance, whether an external target is eligible, or whether movement is required. Blizzard-confirmed player casts start its local timers; encounter resets and effects not reconstructable from confirmed casts can still require `/hh sync` outside combat.

Random procs such as Infusion of Light from Holy Shock or Judgment, Divine Purpose, Awakening, Empyrean Legacy, and Glorious Dawn are not predicted. When Blizzard allows a non-secret player resource update, Holy Power is reconciled after the cast; otherwise the confirmed-cast ledger remains the fallback.

Cooldown values are local estimates. Temporary in-combat haste, cooldown resets not caused by a confirmed modeled cast, death, encounter-specific resets, and unobserved casts can make them diverge. `/hh sync`, `/hh reset`, and `/hh hp 0-5` are the recovery controls.

## Source baseline

The priority was reviewed for Midnight 12.1 on 2026-09-13 against the current Wowhead, Icy Veins, and Method Holy Paladin guides, plus Blizzard's Midnight addon-combat restrictions and 12.1 class notes. Static tests validate the model; an in-game test is still required for actual action-bar replacements, cast IDs, and timing.
