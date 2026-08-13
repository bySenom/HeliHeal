local _, ns = ...

local clientLocale = type(GetLocale) == "function" and GetLocale() or "enUS"

local enUS = {
    ["Einzelziel"] = "Single Target",
    ["Mana sparen"] = "Mana Saving",
    ["Hotkey %s ist mehrfach belegt: %s"] = "Hotkey %s is assigned more than once: %s",
    ["Lokalen Zustand außerhalb des Kampfes abgeglichen."] = "Local state reconciled outside combat.",
    ["Heilmodus: %s"] = "Healing mode: %s",
    ["Prioritätsplatz %s ist nicht belegt."] = "Priority slot %s is not configured.",
    ["Downpour lokal wiederhergestellt."] = "Downpour restored locally.",
    ["%s lokal zurückerstattet."] = "%s refunded locally.",
    ["Lokale Cooldown-Simulation zurückgesetzt."] = "Local cooldown simulation reset.",
    ["Unbekannte Fähigkeit. Beispiele: /hh refund hst, riptide, downpour, rain"] = "Unknown ability. Examples: /hh refund hst, riptide, downpour, rain",
    ["Modi: standard, aoe, single, mana, next"] = "Modes: standard, aoe, single, mana, next",
    ["Anzeige gesperrt."] = "Display locked.",
    ["Anzeige entsperrt."] = "Display unlocked.",
    ["Talent-Snapshot noch nicht verfügbar; bestehende Preset-Annahmen bleiben aktiv."] = "Talent snapshot is not available yet; existing preset assumptions remain active.",
    ["JA"] = "YES",
    ["nein"] = "no",
    ["Talente (Config %s): %s"] = "Talents (Config %s): %s",
    ["Nicht belegt"] = "Not configured",
    ["Übersicht"] = "Overview",
    ["Anzeige, Verhalten und Größe des statischen Priority-Trackers."] = "Display, behavior and size of the static priority tracker.",
    ["Tracker anzeigen"] = "Show tracker",
    ["Blendet die HeliHeal-Prioritätsleiste ein oder aus."] = "Show or hide the HeliHeal priority strip.",
    ["Position sperren"] = "Lock position",
    ["Verhindert das versehentliche Verschieben der Anzeige."] = "Prevents accidentally moving the display.",
    ["UI-Skalierung"] = "UI scale",
    ["Skaliert die vollständige Priority-Anzeige."] = "Scales the complete priority display.",
    ["Icon-Abstand"] = "Icon spacing",
    ["Bestimmt den Abstand zwischen Empfehlung und Folgeslots."] = "Controls the gap between the recommendation icons.",
    ["Sprache"] = "Language",
    ["Standard: WoW-Clientsprache. Ein Wechsel lädt die UI neu."] = "Default: WoW client language. Changing it reloads the UI.",
    ["CLIENTSPRACHE"] = "CLIENT LANGUAGE",
    ["DEUTSCH"] = "GERMAN",
    ["LOKALE TIMER ZURÜCKSETZEN"] = "RESET LOCAL TIMERS",
    ["ANZEIGE ZENTRIEREN"] = "CENTER DISPLAY",
    ["Inputs können während des Kampfes nicht neu belegt werden."] = "Inputs cannot be rebound during combat.",
    ["TASTE DRÜCKEN …"] = "PRESS A KEY …",
    ["Standard bleibt das Guide-Paket; Kontextmodi verändern nur dessen lokale Reihenfolge."] = "Standard retains the guide pack; context modes only change its local order.",
    ["EINZELZIEL"] = "SINGLE TARGET",
    ["MANA SPAREN"] = "MANA SAVING",
    ["FESTE GUIDE-FÄHIGKEIT"] = "STATIC GUIDE ABILITY",
    ["BEOBACHTETER ACTIONBAR-HOTKEY"] = "OBSERVED ACTION BAR HOTKEY",
    ["HUD-Elemente"] = "HUD Elements",
    ["Reduziere die Anzeige auf das Wesentliche oder aktiviere einzelne Details."] = "Reduce the display to essentials or enable individual details.",
    ["Panel-Hintergrund"] = "Panel background",
    ["Dunkler gemeinsamer Hintergrund um alle Icons."] = "Shared dark background around all icons.",
    ["HeliHeal-Header"] = "HeliHeal header",
    ["Zeigt die Überschrift über der Priority-Leiste."] = "Shows the heading above the priority strip.",
    ["Fähigkeitsname"] = "Ability name",
    ["Blendet den Namen der Fähigkeit am Icon ein."] = "Shows the ability name above its icon.",
    ["Prioritätsbadge"] = "Priority badge",
    ["Zeigt P1 bis P5 direkt auf dem jeweiligen Icon."] = "Shows P1 through P5 on the corresponding icon.",
    ["Icon-Rahmen"] = "Icon border",
    ["Schmaler Rahmen und Schatten um jedes Spell-Icon."] = "Thin border and shadow around every spell icon.",
    ["Hotkey"] = "Hotkey",
    ["Zeigt den beobachteten Input unter dem Icon."] = "Shows the observed input below the icon.",
    ["Cooldown-Zahl"] = "Cooldown number",
    ["Zeigt den lokal simulierten Cooldown mittig auf dem Icon."] = "Shows the locally simulated cooldown on the icon.",
    ["Profile & Reset"] = "Profiles & Reset",
    ["Separate Konfigurationen über AceDB verwalten oder sicher zurücksetzen."] = "Manage separate AceDB configurations or reset them safely.",
    ["AKTIVES PROFIL"] = "ACTIVE PROFILE",
    ["Profilname eingeben, um ein Profil anzulegen oder zu wechseln:"] = "Enter a profile name to create or switch profiles:",
    ["Profilname"] = "Profile name",
    ["PROFIL ÖFFNEN"] = "OPEN PROFILE",
    ["Cooldown-Simulation zurücksetzen"] = "Reset cooldown simulation",
    ["Entfernt nur die lokalen Laufzeittimer; deine Fähigkeiten bleiben erhalten."] = "Clears only local runtime timers; your abilities remain configured.",
    ["TIMER RESET"] = "RESET TIMERS",
    ["Alle Klassen-Hotkeys löschen"] = "Clear all class hotkeys",
    ["Entfernt nur deine hinterlegten Inputs; das feste 12.1-Prioritätspaket bleibt erhalten."] = "Clears configured inputs while retaining the static 12.1 priority pack.",
    ["HOTKEYS RESET"] = "RESET HOTKEYS",
    ["Komplettes Profil zurücksetzen"] = "Reset complete profile",
    ["Setzt Anzeige, Position und Prioritäten des aktiven Profils zurück."] = "Resets display, position and priorities for the active profile.",
    ["PROFIL RESET"] = "RESET PROFILE",
    ["Update-Verlauf"] = "Update History",
    ["Alle wichtigen Änderungen bleiben lokal und jederzeit einsehbar."] = "All important changes remain available locally at any time.",
    ["NEU IN HELIHEAL"] = "NEW IN HELIHEAL",
    ["UPDATE-VERLAUF"] = "UPDATE HISTORY",
    ["VERSTANDEN"] = "GOT IT",
    ["KONFIGURATION"] = "CONFIGURATION",
    ["ÜBERSICHT"] = "OVERVIEW",
    ["Anzeige & Verhalten"] = "Display & behavior",
    ["HUD-ELEMENTE"] = "HUD ELEMENTS",
    ["Icon, Hotkey & Cooldown"] = "Icon, hotkey & cooldown",
    ["PRIORITÄTEN"] = "PRIORITIES",
    ["Fähigkeiten & Inputs"] = "Abilities & inputs",
    ["PROFILE & RESET"] = "PROFILES & RESET",
    ["Konfiguration verwalten"] = "Manage configuration",
    ["Was ist neu?"] = "What's new?",
    ["SECURE INPUT TRACKER"] = "SECURE INPUT TRACKER",
    ["NO COMBAT DATA"] = "NO COMBAT DATA",
    ["/hh öffnet dieses Fenster  •  ESC schließt es"] = "/hh opens this window  •  ESC closes it",
    ["SCHLIESSEN"] = "CLOSE",
    ["Lokale Laufzeit: %ss • Ziel: %d"] = "Local duration: %ss • Goal: %d",
    ["Lokaler CD: %ss"] = "Local cooldown: %ss",
    ["Filler • kein lokaler CD"] = "Filler • no local cooldown",
    ["HOTKEY DOPPELT"] = "DUPLICATE HOTKEY",
    ["WIE HEALING RAIN"] = "SAME AS HEALING RAIN",
    ["HOTKEY HINTERLEGEN"] = "SET HOTKEY",
    ["DOPPELT"] = "DUPLICATE",
    ["What's New and Update History"] = "What's New and Update History",
    ["Einmaliges What's-New-Fenster beim ersten /hh nach einem Update."] = "One-time What's New window on the first /hh after an update.",
    ["Accountweiter Gesehen-Status statt wiederholter Hinweise pro Charakter oder Profil."] = "Account-wide seen state instead of repeated notices per character or profile.",
    ["Neue Update-History-Seite und direkter Zugriff über /hh changelog."] = "New Update History page with direct access through /hh changelog.",
    ["Automatische deutsche oder englische Oberfläche passend zur WoW-Clientsprache."] = "Automatic German or English interface based on the WoW client locale.",
    ["Warnungen für doppelt belegte unabhängige Hotkeys."] = "Warnings for duplicate independent hotkeys.",
    ["Versionierte Profilmigration und sicherer Out-of-Combat-Abgleich."] = "Versioned profile migration and safe out-of-combat reconciliation.",
    ["Diagnoseexport über /hh debug und automatisierte GitHub-Releases."] = "Diagnostic export through /hh debug and automated GitHub releases.",
    ["Nur Restoration Shaman und Restoration Druid aktivieren den Tracker."] = "Only Restoration Shaman and Restoration Druid activate the tracker.",
    ["Instant-GCD und veraltete Callback-Sperren korrigiert."] = "Fixed instant-GCD timing and stale callback locks.",
    ["Spec-, Talent- und Profilwechsel setzen lokale Zustände sicher zurück."] = "Spec, talent and profile changes safely reset local state.",
    ["Empfehlungen wechseln erst nach bestätigtem erfolgreichem Zauber."] = "Recommendations advance only after a confirmed successful spell.",
    ["Stormstream und Nature's-Swiftness-Aufladungen korrigiert."] = "Fixed Stormstream and Nature's Swiftness charge handling.",
    ["Instant-Cast-Erfolge vor Actionbar-Hooks werden kurz gepuffert."] = "Instant-cast successes before action-bar hooks are briefly cached.",
    ["Restoration-Druid-Prioritäten und lokale HoT-Zähler ergänzt."] = "Added Restoration Druid priorities and local HoT counters.",
    ["Optionale AoE-, Einzelziel- und Mana-Modi hinzugefügt."] = "Added optional AoE, Single Target and Mana modes.",
    ["Talentabhängige Shaman-Presets und Aufladungen verbessert."] = "Improved talent-aware Shaman presets and charges.",
    ["Statischer Hekili-inspirierter Healing-Priority-Tracker."] = "Static Hekili-inspired healing priority tracker.",
    ["Restoration-Shaman-Presets, Hotkey-Erfassung und lokale Timer."] = "Restoration Shaman presets, hotkey capture and local timers.",
    ["Modernes, bewegliches und anpassbares Icon-HUD."] = "Modern, movable and customizable icon HUD.",
    ["Selectable Interface Language"] = "Selectable Interface Language",
    ["Neue accountweite Sprachauswahl: Clientsprache, Deutsch oder English."] = "New account-wide language selection: Client Language, German or English.",
    ["Clientsprache bleibt der Standard und folgt automatisch der WoW-Einstellung."] = "Client Language remains the default and automatically follows the WoW setting.",
    ["Ein Sprachwechsel wird gespeichert und nach einem UI-Reload vollständig angewendet."] = "Language changes are saved and fully applied after a UI reload.",
    ["Wiederaufladezeit von Totem des Heilenden Flusses auf 17 Sekunden korrigiert."] = "Corrected Healing Stream Totem recharge time to 17 seconds.",
}

local deDE = {
    ["NEXT PRIORITY"] = "NÄCHSTE PRIORITÄT",
    ["What's New and Update History"] = "Neuigkeiten und Update-Verlauf",
    ["Beta Hardening"] = "Beta-Stabilisierung",
    ["Input Lifecycle"] = "Input-Lebenszyklus",
    ["Cast Confirmation"] = "Zauberbestätigung",
    ["Healing Modes and Druid Support"] = "Heilmodi und Druiden-Support",
    ["Initial Alpha"] = "Erste Alpha",
    ["Selectable Interface Language"] = "Auswählbare Oberflächensprache",
}

local translations = enUS

function ns.SetLocale(mode)
    mode = mode == "deDE" and "deDE" or (mode == "enUS" and "enUS" or "auto")
    local requestedLocale = mode == "auto" and clientLocale or mode
    local effectiveLocale = requestedLocale == "deDE" and "deDE" or "enUS"
    translations = effectiveLocale == "deDE" and deDE or enUS
    ns.clientLocale = clientLocale
    ns.localeMode = mode
    ns.locale = effectiveLocale
    ns.localeFallback = mode == "auto"
        and clientLocale ~= "deDE" and clientLocale ~= "enUS" and clientLocale ~= "enGB"
    return effectiveLocale
end

function ns.Localize(key, ...)
    local value = translations[key] or (ns.locale == "deDE" and key) or enUS[key] or key
    if select("#", ...) > 0 then return value:format(...) end
    return value
end

ns.L = ns.Localize
ns.SetLocale("auto")
