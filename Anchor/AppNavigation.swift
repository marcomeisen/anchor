import Foundation

/// `nonisolated`: ein reiner Wert ohne Zustand — sonst wären Vergleiche außerhalb des
/// Hauptakteurs (Tests, `@SceneStorage`-Dekodierung) in Swift 6 ein Fehler.
nonisolated enum AppDestination: Hashable, Codable {
    case today
    case year
    case week
    /// Detailansicht des aktuell gewaehlten Tages. Ohne Nutzlast, damit die Auswahl wie bei
    /// `.week` allein aus `dayDate` folgt und ein Zusammenfuehren doppelter Tage nach einem
    /// iCloud-Import die Navigation nicht ins Leere laufen laesst.
    case day
    case review
    /// Abgeschlossene Wochen. Ein eigener Ort statt eines permanenten Baums in der Sidebar.
    case archive
    case goal(UUID)

    /// Ziele, die als Tab bzw. als oberste Sidebar-Ebene erreichbar sind.
    ///
    /// `.day` und `.goal` sind keine: sie werden aus einer Liste heraus geoeffnet und auf dem
    /// iPhone auf den Navigationsstapel gelegt, damit die Zurueck-Gestik funktioniert.
    var isTopLevel: Bool {
        switch self {
        case .today, .week, .year, .review, .archive: true
        case .day, .goal: false
        }
    }
}

/// Der gesamte Navigationszustand der App.
///
/// Bewusst ein `Codable`-Wertetyp ohne SwiftData-Bezug. Vorher lagen Ziel, Woche und Tag als
/// drei einzelne `@State`-Variablen in `AnkerRootView`, zusammen mit der Logik, die sie
/// verschiebt — nur ueber die Oberflaeche testbar, nicht wiederherstellbar und nicht per URL
/// ansprechbar. Hier ist alles davon eine reine Funktion.
nonisolated struct AnkerNavigationState: Codable, Equatable {
    var destination: AppDestination
    /// Wohin ein Zurueck aus `.day` oder `.goal` fuehrt.
    var topLevel: AppDestination
    var weekStart: Date
    var dayDate: Date

    init(now: Date = Date()) {
        destination = .today
        topLevel = .today
        weekStart = AnkerCalendar.weekInterval(containing: now).monday
        dayDate = now
    }

    /// Steht gerade eine Detailansicht offen, die auf dem iPhone auf dem Stapel liegt?
    var isPushed: Bool { !destination.isTopLevel }

    // MARK: - Auswahl

    mutating func select(_ destination: AppDestination) {
        if destination.isTopLevel {
            topLevel = destination
        }
        self.destination = destination
    }

    /// Zurueck aus einer Detailansicht auf die Ebene, aus der sie geoeffnet wurde.
    mutating func popToTopLevel() {
        destination = topLevel
    }

    // MARK: - Zeitliche Spruenge
    //
    // Alle Spruenge verschieben Woche **und** Tag um denselben Betrag. Sonst zeigte die
    // Wochenansicht die neue Woche, waehrend neue Aufgaben weiter im alten Tag landeten.

    mutating func moveWeek(by offset: Int) {
        move(by: .weekOfYear, value: offset)
        select(.week)
    }

    mutating func moveMonth(by offset: Int) {
        move(by: .month, value: offset)
        select(.week)
    }

    mutating func moveToToday(now: Date = Date()) {
        weekStart = AnkerCalendar.weekInterval(containing: now).monday
        dayDate = now
        select(.today)
    }

    mutating func moveToWeek(startingAt monday: Date) {
        weekStart = AnkerCalendar.weekInterval(containing: monday).monday
        dayDate = monday
    }

    /// Nach dem Anlegen einer Aufgabe fuer ein anderes Datum: dorthin wechseln.
    mutating func moveToPlannedDate(_ date: Date) {
        focus(on: date)
        select(.week)
    }

    /// Setzt nur den Zieltag, ohne die Ansicht zu wechseln.
    ///
    /// Nach einem Drag-and-Drop soll der Blick dort bleiben, wo gezogen wurde; der Tag ist
    /// danach aber das Ziel fuer neue Aufgaben.
    mutating func focus(on date: Date) {
        weekStart = AnkerCalendar.weekInterval(containing: date).monday
        dayDate = date
    }

    /// Klick auf einen Tag: oeffnet die Tagesdetailansicht.
    mutating func openDay(on date: Date) {
        focus(on: date)
        select(.day)
    }

    mutating func openGoal(_ id: UUID, inWeekContaining date: Date) {
        focus(on: date)
        select(.goal(id))
    }

    private mutating func move(by component: Calendar.Component, value: Int) {
        let calendar = AnkerCalendar.iso
        let targetWeek = calendar.date(byAdding: component, value: value, to: weekStart) ?? weekStart
        let targetDay = calendar.date(byAdding: component, value: value, to: dayDate) ?? targetWeek
        weekStart = AnkerCalendar.weekInterval(containing: targetWeek).monday
        dayDate = targetDay
    }

    // MARK: - Suchtreffer

    /// Springt zum Treffer aus der Suche.
    ///
    /// Wochenziele brauchen erst den Wochenwechsel: die Detailansicht loest `.goal(id)` gegen
    /// die Ziele der ausgewaehlten Woche auf und wuerde sonst auf die Wochenuebersicht
    /// zurueckfallen. Fuer alles andere ist der Tag das Ziel; sein Datum kommt vom Aufrufer,
    /// weil nur der die geladenen Tage kennt.
    ///
    /// Jeder Treffer hat ein Ziel. Ohne Tag (Rückblick einer Woche, Aufgabe ohne Tag) fällt der
    /// Sprung auf den Anker zurück, sonst auf die Woche von `result.date` — vorher passierte
    /// bei diesen Treffern beim Antippen schlicht nichts.
    @MainActor
    mutating func open(_ result: AnkerSearch.Result, dayDate: Date?) {
        if result.kind == .goal, let goalID = result.goalID {
            openGoal(goalID, inWeekContaining: result.date)
            return
        }

        if let dayDate {
            openDay(on: dayDate)
            return
        }

        // Aufgabe ohne Tag mit Anker: zum Anker in seiner Woche.
        if result.kind == .task, let goalID = result.goalID {
            openGoal(goalID, inWeekContaining: result.date)
            return
        }

        // Rückblick, Eingang, oder ein Tag, den es nicht mehr gibt: die Woche.
        focus(on: result.date)
        select(.week)
    }

    // MARK: - Wiederherstellung

    /// JSON fuer `@SceneStorage`. Ohne das faengt jeder Start wieder bei "Heute" an, auch
    /// wenn der Nutzer zuletzt in einer anderen Woche gearbeitet hat.
    var encoded: String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        guard let data = try? encoder.encode(self) else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    init?(encoded: String?) {
        guard let encoded,
              let data = encoded.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(AnkerNavigationState.self, from: data) else {
            return nil
        }
        self = decoded
    }

    // MARK: - Deep Links

    static let urlScheme = "anchorit"

    /// Das Schema des früheren Produktnamens. Vorhandene Links und Kurzbefehle sollen nach der
    /// Umbenennung weiter funktionieren.
    static let legacyURLSchemes: Set<String> = ["daivento"]

    /// `anchorit://today`, `anchorit://week`, `anchorit://year`, `anchorit://review`,
    /// `anchorit://archive`, `anchorit://day/2026-08-05`, `anchorit://week/2026-08-03`,
    /// `anchorit://goal/<UUID>`.
    ///
    /// Gibt zurueck, ob die URL verstanden wurde — eine unbekannte URL darf den Zustand nicht
    /// anfassen, sonst landet der Nutzer nach einem Tippfehler im Link irgendwo. Das gilt auch
    /// für ein ungültiges Argument: `week/murks` und `day/2026-02-30` sind kein Sprung.
    ///
    /// `review` setzt nur `.review`. Den Rückblick öffnet `AnkerRootView` als Blatt über einen
    /// eigenen Zustand; wer den Link auswertet, muss das dort tun.
    @discardableResult
    mutating func apply(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(),
              scheme == Self.urlScheme || Self.legacyURLSchemes.contains(scheme),
              let host = url.host?.lowercased() else { return false }

        let argument = url.pathComponents.first { $0 != "/" }

        switch host {
        case "today":
            moveToToday()
        case "year":
            select(.year)
        case "review":
            select(.review)
        case "archive":
            select(.archive)
        case "week":
            if let argument {
                guard let date = Self.date(from: argument) else { return false }
                moveToWeek(startingAt: date)
            }
            select(.week)
        case "day":
            guard let date = Self.date(from: argument) else { return false }
            openDay(on: date)
        case "goal":
            guard let argument, let id = UUID(uuidString: argument) else { return false }
            // Ohne Datum bleibt die aktuelle Woche stehen; das Ziel wird dort gesucht.
            select(.goal(id))
        default:
            return false
        }

        return true
    }

    /// `2026-08-05` — bewusst ISO und nicht das Anzeigeformat: ein Link muss unabhaengig von
    /// der Regionseinstellung des Empfaengers funktionieren.
    ///
    /// Strikt: genau `JJJJ-MM-TT`, Jahr 2000–2100, und das Datum muss es geben. `DateComponents`
    /// rollt sonst über — `2026-02-30` wurde still zum 2. März, `2026-13-45` zu einem Tag 2027.
    static func date(from text: String?) -> Date? {
        guard let text else { return nil }
        let fields = text.split(separator: "-", omittingEmptySubsequences: false)
        guard fields.count == 3,
              fields[0].count == 4, (1...2).contains(fields[1].count), (1...2).contains(fields[2].count),
              fields.allSatisfy({ $0.allSatisfy(\.isASCII) && $0.allSatisfy(\.isNumber) }),
              let year = Int(fields[0]), let month = Int(fields[1]), let day = Int(fields[2]),
              (2000...2100).contains(year), (1...12).contains(month), (1...31).contains(day) else { return nil }

        let date = AnkerCalendar.date(year: year, month: month, day: day, hour: 12, minute: 0)
        let roundTrip = AnkerCalendar.iso.dateComponents([.year, .month, .day], from: date)
        guard roundTrip.year == year, roundTrip.month == month, roundTrip.day == day else { return nil }
        return date
    }
}
