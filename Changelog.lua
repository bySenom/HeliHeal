local _, ns = ...

ns.changelog = {
    currentVersion = "0.9.2-alpha.1",
    entries = {
        {
            version = "0.9.2-alpha.1",
            title = "One Button Assistant and Live Holy Power",
            changes = {
                "Der Blizzard One Button Assistant wird auf Standard-Aktionsleisten automatisch erkannt.",
                "Erfolgreiche OBA-Zauber aktualisieren passende HeliHeal-Cooldowns und Aufladungen.",
                "Die lesbare Holy Power des Spielers korrigiert die lokale Simulation nach jedem Cast.",
                "Crusader Strike und Shield of the Righteous werden für OBA-Ressourcenänderungen berücksichtigt.",
                "Walk Into Light erzeugt seit seiner 12.0.5-Überarbeitung keine Holy Power mehr.",
            },
        },
        {
            version = "0.9.1-alpha.1",
            title = "Paladin Talent and Holy Power Model",
            changes = {
                "Divine Toll und Holy Prism verwenden mit Quickened Invocation jetzt korrekt 30 Sekunden Cooldown.",
                "Paladin-Talentwahl steuert Divine Toll, Holy Prism, Holy Armaments, Wings, Crusader und Aura Mastery.",
                "Holy Power wird als geordnete Folge bestätigter Casts berechnet und bei Refunds korrekt neu aufgebaut.",
                "Aurora, Walk Into Light, Ringing of the Heavens und rangabhängige Cooldown-Talente werden lokal simuliert.",
                "Mit /hh hp 0-5 kann die lokale Schätzung bei einem nicht lesbaren Zufallsproc synchronisiert werden.",
            },
        },
        {
            version = "0.9.0-alpha.1",
            title = "Holy Paladin Support",
            changes = {
                "Holy-Paladin-Prioritäten für Herald of the Sun und Lightsmith ergänzt.",
                "Eigene Mythic+- und Raid-Pakete mit Standard-, AoE-, Einzelziel- und Mana-Modus hinzugefügt.",
                "Holy Power wird ausschließlich aus bestätigten eigenen Casts lokal geschätzt.",
                "Divine Toll, Holy Prism, Holy Armaments und Holy-Shock-Aufladungen reagieren auf den Talent-Snapshot.",
            },
        },
        {
            version = "0.8.7-alpha.1",
            title = "Reliable Rapid Inputs",
            changes = {
                "Hotkey-Entprellung arbeitet jetzt pro Taste statt global.",
                "Schnell aufeinanderfolgende unterschiedliche Fähigkeiten verlieren keine Cast-Bestätigung mehr.",
                "Riptide-Aufladungen bleiben dadurch mit erfolgreichen Instant-Casts synchron.",
            },
        },
        {
            version = "0.8.6-alpha.1",
            title = "Selectable Interface Language",
            changes = {
                "Neue accountweite Sprachauswahl: Clientsprache, Deutsch oder English.",
                "Clientsprache bleibt der Standard und folgt automatisch der WoW-Einstellung.",
                "Ein Sprachwechsel wird gespeichert und nach einem UI-Reload vollständig angewendet.",
                "Wiederaufladezeit von Totem des Heilenden Flusses auf 17 Sekunden korrigiert.",
            },
        },
        {
            version = "0.8.5-alpha.1",
            title = "What's New and Update History",
            changes = {
                "Einmaliges What's-New-Fenster beim ersten /hh nach einem Update.",
                "Accountweiter Gesehen-Status statt wiederholter Hinweise pro Charakter oder Profil.",
                "Neue Update-History-Seite und direkter Zugriff über /hh changelog.",
                "Automatische deutsche oder englische Oberfläche passend zur WoW-Clientsprache.",
            },
        },
        {
            version = "0.8.4-alpha.1",
            title = "Beta Hardening",
            changes = {
                "Warnungen für doppelt belegte unabhängige Hotkeys.",
                "Versionierte Profilmigration und sicherer Out-of-Combat-Abgleich.",
                "Diagnoseexport über /hh debug und automatisierte GitHub-Releases.",
            },
        },
        {
            version = "0.8.3-alpha.1",
            title = "Input Lifecycle",
            changes = {
                "Nur Restoration Shaman und Restoration Druid aktivieren den Tracker.",
                "Instant-GCD und veraltete Callback-Sperren korrigiert.",
                "Spec-, Talent- und Profilwechsel setzen lokale Zustände sicher zurück.",
            },
        },
        {
            version = "0.8.2-alpha.1",
            title = "Cast Confirmation",
            changes = {
                "Empfehlungen wechseln erst nach bestätigtem erfolgreichem Zauber.",
                "Stormstream und Nature's-Swiftness-Aufladungen korrigiert.",
                "Instant-Cast-Erfolge vor Actionbar-Hooks werden kurz gepuffert.",
            },
        },
        {
            version = "0.8.1-alpha.1",
            title = "Healing Modes and Druid Support",
            changes = {
                "Restoration-Druid-Prioritäten und lokale HoT-Zähler ergänzt.",
                "Optionale AoE-, Einzelziel- und Mana-Modi hinzugefügt.",
                "Talentabhängige Shaman-Presets und Aufladungen verbessert.",
            },
        },
        {
            version = "0.8.0-alpha.1",
            title = "Initial Alpha",
            changes = {
                "Statischer Hekili-inspirierter Healing-Priority-Tracker.",
                "Restoration-Shaman-Presets, Hotkey-Erfassung und lokale Timer.",
                "Modernes, bewegliches und anpassbares Icon-HUD.",
            },
        },
    },
}

function ns.changelog:GetEntry(version)
    for _, entry in ipairs(self.entries) do
        if entry.version == version then return entry end
    end
end
