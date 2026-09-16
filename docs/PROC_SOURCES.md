# Background proc sources

The PROCS options tab stores one source definition per proc on the current
character. Infusion of Light is the built-in rotation source. Additional entries
are available to rotation modules through `HeliHeal.ProcTracker:GetProcState(key)`;
adding a source does not automatically change a specialization's priorities.

1. Open Blizzard Cooldown Settings once so its catalog is available.
2. Enable Hide When Inactive for the Blizzard viewer.
3. Add its spell ID in HeliHeal's PROCS tab. HeliHeal attempts to move the
   uniquely matching buff definition into Tracked Buff Bars outside combat.
   TRACK retries existing entries. No unrelated category or order is changed.
4. Check ACTIVE when the proc is present and INACTIVE after it is consumed.

HeliHeal does not create, reparent, hide or replace Blizzard's tracked frames.
Assignment uses the settings data provider's SetCooldownToCategory and saves
the layout. Missing APIs/catalog, ambiguous definitions, pending user edits,
combat, or Blizzard rejection require a retry or manual configuration. Removal
only removes the HeliHeal source, never a Blizzard setting. Hide When Inactive
is not automatically changed because that is a shared viewer-wide setting.
Its entries are background source definitions, not extra on-screen buff bars.
The options tab is a diagnostic view and refreshes twice per second while open.

Sources match readable spell identities, then remember the cooldown definition
ID for times when identity fields are redacted. A readable conflicting spell,
missing source, ambiguous source, unavailable visibility, disabled tracker, or
disabled Hide When Inactive yields UNKNOWN. An unidentified lone item is never
assumed to be a configured proc by this API.

Visibility reports presence only, not stacks or individual consumption events.
Additional sources need explicit rotation integration before affecting decisions.
This uses Blizzard item visibility, not aura payloads or cooldown values.
