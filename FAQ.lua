local _, ns = ...

local FAQ = {}
ns.FAQ = FAQ

local GENERAL = {
    {
        group = "ALLGEMEIN",
        tag = "SYSTEM",
        icon = "Interface\\Icons\\INV_Misc_Book_09",
        question = "Was entscheidet HeliHeal wirklich?",
        answer = "HeliHeal ordnet eine feste Guide-Priorität anhand bestätigter eigener Zauber und lokal berechneter Zustände. Es sieht keine Gesundheit, Ziele, Reichweite, Auren oder eingehenden Schaden. Die erste Empfehlung ist daher eine Priorität, kein automatischer Heilbefehl.",
    },
    {
        group = "ALLGEMEIN",
        tag = "ANZEIGE",
        icon = "Interface\\Icons\\INV_Misc_Eye_01",
        question = "Wie lese ich die fünf Empfehlungen?",
        answer = "Das große erste Icon ist die aktuell höchste lokale Priorität. Die kleineren Icons zeigen sinnvolle Folgeschritte. Ein entsättigtes Icon mit Timer ist noch nicht bereit; ein entsättigter Paladin-Spender mit 3 HP ist nur ein späterer Schritt und darf erst mit genügend Holy Power benutzt werden.",
    },
    {
        group = "ALLGEMEIN",
        tag = "PRIORITÄT",
        icon = "Interface\\Icons\\Ability_Paladin_BeaconofLight",
        question = "Wann sollte ich von der Empfehlung abweichen?",
        answer = "Immer wenn die Spielsituation es verlangt: Dispel, Bewegung, Mechaniken, ein sterbender Spieler oder ein geplanter defensiver Cooldown sind wichtiger. HeliHeal ersetzt keine Zielwahl und keine Begegnungskenntnis.",
    },
}

local HOLY_PALADIN = {
    {
        group = "HOLY PALADIN",
        tag = "GRUNDLAGEN",
        spellIDs = { 20473, 85673, 156322, 85222 },
        question = "Wie funktioniert die Holy-Paladin-Grundrotation?",
        answer = "Erzeuge Holy Power, ohne bei 5 weiter zu überfüllen, und gib sie mit Word of Glory oder Eternal Flame aus. Light of Dawn ist im HeliHeal-Modell nur für Raid vorgesehen. Holy Shock bleibt ein zentraler Generator; große Cooldowns solltest du für echte Schadensfenster planen.",
    },
    {
        group = "HOLY PALADIN",
        tag = "ZIELWAHL",
        spellIDs = { 432459 },
        question = "Auf wen caste ich Holy Bulwark?",
        answer = "Mit Solidarity ist der Self-Cast die starke Standardlösung: Der zusätzliche Holy Bulwark springt auf einen Tank und skaliert mit dessen hoher maximaler Gesundheit. Caste direkt auf einen verwundbaren oder besonders gefährdeten Verbündeten, wenn du das Ziel bewusst kontrollieren musst. Seit 12.1 verlängert ein erneuter Cast desselben Casters die laufende Armament-Dauer; HeliHeal bildet diese Verlängerung lokal nach.",
    },
    {
        group = "HOLY PALADIN",
        tag = "ZIELWAHL",
        spellIDs = { 432472 },
        question = "Auf wen caste ich Sacred Weapon?",
        answer = "Caste Sacred Weapon normalerweise auf dich selbst. Mit Solidarity erhält zusätzlich ein anderer Heiler oder in Mythic+ ein DPS-Spieler die Waffe; ihr Heilungs- oder Schadenswert hängt nicht davon ab, welchen DPS oder Heiler sie trifft. Nutze einen direkten Fremd-Cast nur bewusst, etwa für die Verbindung von Tempered in Battle.",
    },
    {
        group = "HOLY PALADIN",
        tag = "MECHANIK",
        spellIDs = { 432459, 432472 },
        question = "Warum wechseln Holy Bulwark und Sacred Weapon?",
        answer = "Holy Armaments ist eine einzige Fähigkeit mit zwei gemeinsamen Charges. Jeder bestätigte Cast wechselt zur anderen Variante: Holy Bulwark wird Sacred Weapon und danach wieder Holy Bulwark. Beide benutzen in HeliHeal denselben Hotkey.",
    },
    {
        group = "HOLY PALADIN",
        tag = "PROC",
        spellIDs = { 414273, 82326, 54149 },
        question = "Was mache ich mit Infusion of Light und Hand of Divinity?",
        answer = "Eine lokal bekannte Infusion priorisiert Flash of Light in Heilmodi und Judgment beziehungsweise Hammer of Wrath im Mana-Sparmodus. Hand of Divinity macht nach Wings die nächsten zwei Holy Lights sofort wirkbar und günstiger; HeliHeal stellt diese Holy Lights deshalb an die erste Stelle.",
    },
    {
        group = "HOLY PALADIN",
        tag = "DEFENSIV",
        spellIDs = { 498, 6940, 633 },
        question = "Was bedeutet das separate DEF-Fenster?",
        answer = "DEF zeigt nur, welche defensiven und unterstützenden Fähigkeiten lokal bereit sind. Es bedeutet nicht, dass du sie sofort casten sollst. Nutze Divine Protection, Blessing of Sacrifice, Lay on Hands und ähnliche Werkzeuge passend zur Mechanik und zum Ziel.",
    },
    {
        group = "HOLY PALADIN",
        tag = "BEACON",
        spellIDs = { 53563, 200025 },
        question = "Wie wähle ich Beacon-Ziele richtig?",
        answer = "Beacon of Light oder Faith liegt häufig gut auf entfernten Spielern, weil das Ziel zusätzlich als Zentrum für Mastery: Lightbringer dient. Heile ein Beacon-Ziel nur direkt, wenn es die Heilung wirklich braucht, da normale Beacon-Übertragung von Heilung an anderen Zielen entsteht. Beacon of Virtue kommt auf einen verletzten Verbündeten, nicht auf dich selbst; plane die folgenden starken Heilzauber in sein kurzes Fenster.",
    },
    {
        group = "HOLY PALADIN",
        tag = "RAID / M+",
        spellIDs = { 200025, 31821, 375576 },
        question = "Wie unterscheiden sich Raid und Mythic+?",
        answer = "Im Raid ist Beacon of Virtue ein wichtiges Burst-Fenster: Ringing of the Heavens und Divine Toll gewinnen viel Wert, wenn Virtue bereits aktiv ist. In Mythic+ kann diese vollständige Kombination unnötig viel auf einmal sein; trenne Virtue und große Cooldowns, um mehrere Schadenswellen abzudecken. Light of Dawn bleibt in HeliHeal eine Raid-Option, während Mythic+ den Einzelziel-Spender nutzt.",
    },
    {
        group = "HOLY PALADIN",
        tag = "MANA",
        spellIDs = { 82326, 53600, 20473 },
        question = "Wie spare ich Mana als Holy Paladin?",
        answer = "Holy Light ist dein größter regelbarer Mana-Hebel: caste es häufiger für hohen Durchsatz und seltener, wenn du zu schnell Mana verlierst. Wenn gerade keine Heilung nötig ist, gibt Shield of the Righteous bei einem Treffer Mana zurück; ein offensiver Holy Shock kann mit Light's Conviction ebenfalls günstiger sein. Das sind bewusste Heilungsverluste und gehören deshalb in den Mana-Saving-Kontext, nicht in ein akutes Heilfenster.",
    },
    {
        group = "HOLY PALADIN",
        tag = "DISPEL / UTILITY",
        spellIDs = { 4987, 1022, 6940 },
        question = "Warum empfiehlt HeliHeal keinen Dispel automatisch?",
        answer = "Midnight erlaubt HeliHeal nicht, einen Debuff zuverlässig auszuwerten und daraus eine eigene Kampfentscheidung zu berechnen. Nutze die Blizzard-Raidframes für Cleanse. Blessing of Protection entfernt oder verhindert physische Effekte, nimmt dem Ziel aber Aggro — deshalb nicht ohne Absprache auf den Tank. Blessing of Sacrifice ist dein häufiges externes Defensive; achte dabei selbst auf den übertragenen Schaden.",
    },
    {
        group = "HOLY PALADIN",
        tag = "BEWEGUNG",
        spellIDs = { 190784, 20473, 85673 },
        question = "Was mache ich während Bewegung?",
        answer = "HeliHeal kann nicht zuverlässig erkennen, ob du gerade laufen musst. Nutze während Bewegung verfügbare Instant-Zauber wie Holy Shock und Holy-Power-Spender und verschiebe einen normalen Holy-Light-Cast. Ein durch Hand of Divinity vorbereiteter Holy Light ist instant und bleibt deshalb auch in Bewegung nutzbar. Divine Steed gehört zur Positionierung, nicht automatisch zur Heilpriorität.",
    },
}

local function append(target, source)
    for _, entry in ipairs(source) do target[#target + 1] = entry end
end

function FAQ:GetEntries(classToken, specializationID)
    local entries = {}
    append(entries, GENERAL)
    if classToken == "PALADIN" and tonumber(specializationID) == 65 then
        append(entries, HOLY_PALADIN)
    end
    return entries
end
