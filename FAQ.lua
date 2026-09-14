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
        answer = "Gib Holy Bulwark bevorzugt einem Tank, einem verwundbaren Verbündeten oder einem Spieler vor sicherem Schaden. Die einfache Standardlösung mit Solidarity ist ein Cast auf dich selbst: Du behältst den Schild und ein Verbündeter erhält ebenfalls ein Armament. Überschreibe möglichst keinen bereits aktiven Holy Bulwark.",
    },
    {
        group = "HOLY PALADIN",
        tag = "ZIELWAHL",
        spellIDs = { 432472 },
        question = "Auf wen caste ich Sacred Weapon?",
        answer = "Für mehr Schaden eignet sich ein aktiver DPS-Spieler; für Heilwert ein Spieler mit hoher Zauberaktivität. Mit Solidarity ist Selbst-Cast erneut die einfache sichere Lösung, weil zusätzlich ein Verbündeter profitiert. Überschreibe möglichst keine bereits aktive Sacred Weapon.",
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
