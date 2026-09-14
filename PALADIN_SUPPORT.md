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
- Hand of Divinity tracks and immediately prioritizes two Holy Light uses after Avenging Wrath, or one after Avenging Crusader, in every rotation mode for up to 20 seconds.
- The deterministic 12.1 four-piece Holy Light trigger arms one local Infusion of Light. Random Holy Shock and Judgment Infusion procs are not guessed.
- Infusion prefers Flash of Light in healing modes and Judgment or its Hammer replacement in Mana Saving mode.
- Flash of Light is shown only while an Infusion is locally known; otherwise the static tracker cannot justify recommending the expensive emergency cast.
- When a locally known Infusion is consumed, Imbued Infusions reduces the locally tracked Holy Shock recharge by one second.
- Forewarning reduces Holy Armaments' two-charge recharge by 20%. When a locally known Infusion is consumed, Valiance also advances the running Holy Armaments recharge by three seconds.
- With both Solidarity and Laying Down Arms selected, every confirmed Holy Armament cast starts a local 20-second self-Armament timer. Its expiration grants the guaranteed Infusion of Light and advances a running Lay on Hands cooldown by 15 seconds. Holy Bulwark and Sacred Weapon are tracked separately, including same-caster duration extensions.
- Locally known Infusions expire after 15 seconds. Inflorescence of the Sunwell permits two locally tracked charges instead of silently overwriting the first.
- A separate **DEF / UTILITY** readiness strip tracks confirmed casts of Divine Protection, Divine Shield, Blessing of Sacrifice, Lay on Hands, Blessing of Protection and Divine Steed. It applies detected cooldown and charge talents without inserting these tools into the healing priority.
- Mythic+ omits Light of Dawn from the priority packs. Raid keeps it as a situational alternative behind the stronger single-target spender.
- Judgment and its Avenging Wrath replacement, Hammer of Wrath, share one editable hotkey while retaining separate local cooldown and Holy Power effects.

## Player-selected contexts

The mode is the player's statement of intent because HeliHeal cannot legally infer the healing situation:

- **Standard** — sustainable core priority; no forced major defensive or throughput cooldown.
- **AoE** — group damage and planned raid cooldown context. Aura Mastery and major throughput cooldowns may enter the priority.
- **Single Target** — urgent focused healing. Damage fillers are deprioritized and an available Hand of Divinity Holy Light is surfaced.
- **Mana Saving** — low-pressure or damage context. Judgment and Shield of the Righteous are favored over expensive direct healing.

## Deliberate limitations

HeliHeal cannot decide which player is injured, whether a cast would overheal, whether Beacon of Virtue is currently active on useful targets, whether a dispel is required, whether an enemy is in range, or when a boss mechanic requires a defensive. Those decisions need the player's unit frames, Blizzard's Cooldown Manager, encounter knowledge, and explicit mode choice.

The DEF / UTILITY strip means **available**, not **cast now**. It cannot evaluate incoming damage, Forbearance, whether an external target is eligible, or whether movement is required. Blizzard-confirmed player casts start its local timers; encounter resets and effects not reconstructable from confirmed casts can still require `/hh sync` outside combat.

Random procs such as Infusion of Light from Holy Shock or Judgment, Divine Purpose, Awakening, Empyrean Legacy, Glorious Dawn, and Divine Inspiration are not predicted. Veneration's critical-heal Judgment reset and Armament changes caused by other players or effects remain unknown because the successful player cast alone does not prove that they occurred. The Laying Down Arms timer is intentionally enabled only when Solidarity guarantees the self-copy. When Blizzard allows a non-secret player resource update, Holy Power is reconciled after the cast; otherwise the confirmed-cast ledger remains the fallback.

Cooldown values are local estimates. Temporary in-combat haste, cooldown resets not caused by a confirmed modeled cast, death, encounter-specific resets, and unobserved casts can make them diverge. `/hh sync`, `/hh reset`, and `/hh hp 0-5` are the recovery controls.

## Source baseline

The priority was reviewed for Midnight 12.1 on 2026-09-14 against the current [Wowhead Holy Paladin rotation guide](https://www.wowhead.com/guide/classes/paladin/holy/rotation-cooldowns-pve-healer), [Wowhead abilities and talents guide](https://www.wowhead.com/guide/classes/paladin/holy/abilities-talents-pve-healer), [Method playstyle guide](https://www.method.gg/guides/holy-paladin/playstyle-and-rotation), and Blizzard's Midnight addon-combat restrictions and 12.1 class notes. Static tests validate the model; an in-game test is still required for actual action-bar replacements, cast IDs, and timing.
