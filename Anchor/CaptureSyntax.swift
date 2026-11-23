import Foundation

/// Ein Tag, wie er in der Erfassung getippt wurde — noch ohne Bezug auf „jetzt".
///
/// Der Parser bleibt dadurch rein: „morgen" ist ein Versatz, kein Datum. Erst `resolve` macht
/// mit dem heutigen Tag ein Datum daraus.
enum CaptureDate: Equatable {
    /// Tage ab heute: 0 heute, 1 morgen, 2 übermorgen, n „in n Tagen".
    case relative(days: Int)
    /// Der Montag der nächsten Woche.
    case nextWeek
    /// Ein Kalendertag. Ohne Jahr das nächste Vorkommen ab heute — ein vergangenes Datum
    /// ohne Jahr meint das nächste Jahr (am 30.11. ist „24.11." also der 24.11. im Folgejahr).
    case calendar(day: Int, month: Int, year: Int?)
}

/// Die Sprache der Kürzel. Nie beide zugleich: „so" ist im Englischen ein Wort, „today" im
/// Deutschen eine Aufgabe über Englischunterricht.
enum CaptureLanguage: Equatable {
    case german
    case english

    static var current: CaptureLanguage { AppLanguage.isGermanActive ? .german : .english }

    var weekdayTokens: [String: Int] {
        switch self {
        case .german: CaptureSyntax.germanWeekdayTokens
        case .english: CaptureSyntax.englishWeekdayTokens
        }
    }
}

/// Was in einer Erfassungszeile steht, nachdem die Kuerzel herausgelesen sind.
struct CaptureInput: Equatable {
    var title = ""
    /// `nil` heisst: keine Angabe, der Aufrufer setzt seine Vorgabe.
    var priority: Priority?
    /// 1 bis 4. Hoehere Zahlen sind keine Angabe, sondern Titeltext.
    var anchorNumber: Int?
    /// 1 = Montag bis 7 = Sonntag, nach ISO.
    var weekdayIndex: Int?
    /// „morgen", „in 3 Tagen", „24.11." — schließt `weekdayIndex` aus: das letzte gewinnt.
    var date: CaptureDate?

    var isEmpty: Bool { title.isEmpty }
}

/// Die aufgeloeste Absicht: welcher Tag, welche Prioritaet, welcher Anker.
struct CaptureTarget: Equatable {
    let date: Date
    let priority: Priority
    let anchorNumber: Int?
    /// Ein getippter Anker, der entfällt, weil der Tag in einer anderen Woche liegt — Anker
    /// gehören zu genau einer Woche (wie bei `TaskActions.move`).
    var droppedAnchorNumber: Int? = nil
}

/// Die Ein-Zeilen-Erfassung des Entwurfs: `Angebot pruefen !a #2 mi`.
///
/// Reiner Typ ohne View- und ohne Modellbezug, damit die Regeln pruefbar sind statt in einer
/// Ansicht zu verschwinden.
///
/// Zerlegt wird an Leerzeichen, nicht per Mustersuche im ganzen Text. Das ist der Grund, warum
/// „Somit" und „Modul" keinen Wochentag ergeben: ein Kuerzel muss ein **ganzes** Wort sein.
///
/// Wochentage und Datumsangaben zaehlen zudem nur **am Ende** der Zeile — als letzte Woerter
/// oder nur noch von Kuerzeln gefolgt (`Bericht mi #2`, `Arzt anrufen morgen`). „so", „da",
/// „mo" und „morgen" sind auch Woerter; „Mach das so gut wie moeglich" ist kein Sonntag und
/// „Ich ruf morgen nicht an" bleibt Titel. `#n` und `!x` gelten ueberall, sie sind nie
/// Satzbestandteil.
///
/// Datumsangaben:
/// - Deutsch: `heute`, `morgen`, `übermorgen`, `nächste Woche` (Montag), `in 3 Tagen`,
///   `24.11.`, `24.11.2026`, `24.11.26`. Ohne Jahr braucht das Datum den Schlusspunkt —
///   „Kapitel 1.5" ist kein 1. Mai.
/// - Englisch: `today`, `tomorrow`, `next week` (Montag), `in 3 days`, `Nov 24`, `24 Nov`,
///   auch mit Jahr (`Nov 24 2026`). **Kein** `11/24`: Monat oder Tag zuerst hängt von der
///   Region ab, und eine stille falsche Vermutung wäre schlimmer als ein Titel mit Schrägstrich.
enum CaptureSyntax {
    /// Deutsche Wochentagskuerzel. Reihenfolge nach ISO, Montag ist 1.
    static let germanWeekdayTokens: [String: Int] = [
        "mo": 1, "di": 2, "mi": 3, "do": 4, "fr": 5, "sa": 6, "so": 7,
    ]

    /// Englische Kuerzel, zweistellig wie im Deutschen und dreistellig wie im Kalender.
    /// „do" fehlt mit Absicht: „things to do" waere sonst ein Donnerstag.
    static let englishWeekdayTokens: [String: Int] = [
        "mo": 1, "tu": 2, "we": 3, "th": 4, "fr": 5, "sa": 6, "su": 7,
        "mon": 1, "tue": 2, "wed": 3, "thu": 4, "fri": 5, "sat": 6, "sun": 7,
    ]

    /// Die Kuerzel der Sprache, in der die App laeuft. Nie beide zugleich: „so" ist im
    /// Englischen ein Wort, „we" im Deutschen keins, aber „do" in beiden.
    static var weekdayTokens: [String: Int] {
        CaptureLanguage.current.weekdayTokens
    }

    static let defaultPriority: Priority = .b

    static var syntaxHelp: String { String(localized: "#1–#4 Anker · am Ende: morgen, Fr, 24.11.") }

    /// Ein Stück des Kürzelschwanzes, ein oder mehrere Wörter lang.
    private enum TailItem {
        case priority(Priority)
        case anchor(Int)
        case weekday(Int)
        case date(CaptureDate)
    }

    /// Zerlegt die Eingabe. Reihenfolge der Kuerzel ist beliebig.
    ///
    /// Bei mehreren Kuerzeln derselben Art gewinnt das **letzte** und alle werden entfernt —
    /// ein Einzeiler wird beim Tippen korrigiert, und „die letzte Angabe gilt" ist dabei die
    /// Erwartung. Wochentag und Datum sind dabei **eine** Art: `Bericht fr morgen` ist morgen.
    /// Die Hinweiszeile zeigt vorher, was gewonnen hat.
    ///
    /// - Parameters:
    ///   - language: Bestimmt Datumswörter und, ohne `weekdayTokens`, die Wochentagskürzel.
    ///   - weekdayTokens: Abweichende Wochentagskürzel; `nil` nimmt die der Sprache.
    static func parse(
        _ raw: String,
        language: CaptureLanguage = .current,
        weekdayTokens: [String: Int]? = nil
    ) -> CaptureInput {
        let weekdayTokens = weekdayTokens ?? language.weekdayTokens
        var input = CaptureInput()
        var titleParts: [String] = []

        let rawTokens = raw.split(whereSeparator: \.isWhitespace)
        // Kleinschreibung in einer festen Unicode-Form: „Ü" kann als ein oder zwei Zeichen kommen.
        let lowered = rawTokens.map { $0.lowercased().precomposedStringWithCanonicalMapping }
        // Ein nachgestellter Punkt gehoert zur Abkuerzung („Mi."), nicht zum Kuerzel.
        let tokens = lowered.map { $0.trimmingCharacters(in: CharacterSet(charactersIn: ".")) }

        // Der Kuerzelschwanz, von hinten gelesen: ab `tailStart` stehen nur noch Kuerzel. Nur
        // darin zaehlen Wochentag und Datum. Mehrwortausdruecke („in 3 Tagen") zuerst, damit
        // „Tagen" nicht als Titelwort den Schwanz abbricht.
        var tail: [TailItem] = []
        var tailStart = tokens.count
        scan: while tailStart > 0 {
            for length in stride(from: min(3, tailStart), through: 1, by: -1) {
                let range = (tailStart - length)..<tailStart
                if let item = tailItem(tokens: Array(tokens[range]), lowered: Array(lowered[range]),
                                       language: language, weekdayTokens: weekdayTokens) {
                    tail.insert(item, at: 0)
                    tailStart -= length
                    continue scan
                }
            }
            break
        }

        for index in 0..<tailStart {
            let token = tokens[index]
            if let priority = priority(from: token) {
                input.priority = priority
            } else if let anchor = anchorNumber(from: token) {
                input.anchorNumber = anchor
            } else {
                titleParts.append(String(rawTokens[index]))
            }
        }

        for item in tail {
            switch item {
            case .priority(let priority): input.priority = priority
            case .anchor(let anchor): input.anchorNumber = anchor
            case .weekday(let weekday):
                input.weekdayIndex = weekday
                input.date = nil
            case .date(let date):
                input.date = date
                input.weekdayIndex = nil
            }
        }

        input.title = titleParts.joined(separator: " ")
        return input
    }

    /// Erkennt genau die gegebenen Woerter als **ein** Kuerzel — oder gar nicht.
    private static func tailItem(
        tokens: [String],
        lowered: [String],
        language: CaptureLanguage,
        weekdayTokens: [String: Int]
    ) -> TailItem? {
        if tokens.count == 1 {
            let token = tokens[0]
            if let priority = priority(from: token) { return .priority(priority) }
            if let anchor = anchorNumber(from: token) { return .anchor(anchor) }
            if let weekday = weekdayTokens[token] { return .weekday(weekday) }
        }
        return date(from: tokens, lowered: lowered, language: language).map(TailItem.date)
    }

    // MARK: - Datumswörter

    private static let germanRelativeWords: [String: Int] = [
        "heute": 0, "morgen": 1, "übermorgen": 2, "uebermorgen": 2,
    ]

    private static let englishRelativeWords: [String: Int] = [
        "today": 0, "tomorrow": 1,
    ]

    private static let englishMonths: [String: Int] = [
        "jan": 1, "january": 1, "feb": 2, "february": 2, "mar": 3, "march": 3,
        "apr": 4, "april": 4, "may": 5, "jun": 6, "june": 6, "jul": 7, "july": 7,
        "aug": 8, "august": 8, "sep": 9, "sept": 9, "september": 9, "oct": 10, "october": 10,
        "nov": 11, "november": 11, "dec": 12, "december": 12,
    ]

    /// Höchster Versatz für „in n Tagen" — „in 2026 Tagen" ist eher eine Jahreszahl.
    private static let maxRelativeDays = 365

    /// `tokens` ohne Punkte an den Raendern, `lowered` mit — der Schlusspunkt unterscheidet
    /// „24.11." von einer Dezimalzahl.
    private static func date(from tokens: [String], lowered: [String], language: CaptureLanguage) -> CaptureDate? {
        switch (language, tokens.count) {
        case (.german, 1):
            if let days = germanRelativeWords[tokens[0]] { return .relative(days: days) }
            return germanNumericDate(lowered[0])
        case (.german, 2):
            if ["nächste", "naechste"].contains(tokens[0]) && tokens[1] == "woche" { return .nextWeek }
            return nil
        case (.german, 3):
            guard tokens[0] == "in", ["tag", "tagen"].contains(tokens[2]) else { return nil }
            return relativeDays(tokens[1])
        case (.english, 1):
            return englishRelativeWords[tokens[0]].map { .relative(days: $0) }
        case (.english, 2):
            if tokens == ["next", "week"] { return .nextWeek }
            return englishMonthDay(tokens[0], tokens[1], year: nil)
        case (.english, 3):
            if tokens[0] == "in", ["day", "days"].contains(tokens[2]) { return relativeDays(tokens[1]) }
            guard tokens[2].count == 4, let year = Int(tokens[2]) else { return nil }
            return englishMonthDay(tokens[0], tokens[1], year: year)
        default:
            return nil
        }
    }

    private static func relativeDays(_ token: String) -> CaptureDate? {
        guard token.allSatisfy(\.isASCII), let days = Int(token), (0...maxRelativeDays).contains(days) else { return nil }
        return .relative(days: days)
    }

    /// `24.11.`, `24.11.2026`, `24.11.26`. Ohne Jahr nur mit Schlusspunkt.
    private static func germanNumericDate(_ token: String) -> CaptureDate? {
        let parts = token.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        let numbers: [String]
        switch parts.count {
        case 3 where parts[2].isEmpty:                     // „24.11."
            numbers = [parts[0], parts[1]]
        case 3:                                            // „24.11.2026"
            numbers = parts
        case 4 where parts[3].isEmpty:                     // „24.11.2026."
            numbers = Array(parts.prefix(3))
        default:
            return nil
        }
        guard numbers.allSatisfy({ !$0.isEmpty && $0.count <= 4 && $0.allSatisfy(\.isASCII) && Int($0) != nil }),
              numbers[0].count <= 2, numbers[1].count <= 2 else { return nil }
        let day = Int(numbers[0])!, month = Int(numbers[1])!
        var year: Int?
        if numbers.count == 3 {
            switch numbers[2].count {
            case 2: year = 2000 + Int(numbers[2])!
            case 4: year = Int(numbers[2])!
            default: return nil
            }
        }
        return validated(day: day, month: month, year: year)
    }

    /// `Nov 24`, `24 Nov`, `November 24th`.
    private static func englishMonthDay(_ first: String, _ second: String, year: Int?) -> CaptureDate? {
        if let month = englishMonths[first], let day = ordinalDay(second) {
            return validated(day: day, month: month, year: year)
        }
        if let day = ordinalDay(first), let month = englishMonths[second] {
            return validated(day: day, month: month, year: year)
        }
        return nil
    }

    private static func ordinalDay(_ token: String) -> Int? {
        var digits = token
        for suffix in ["st", "nd", "rd", "th"] where digits.hasSuffix(suffix) {
            digits.removeLast(suffix.count)
            break
        }
        guard (1...2).contains(digits.count), digits.allSatisfy(\.isASCII), let day = Int(digits) else { return nil }
        return day
    }

    /// Nur Tage, die es gibt: „31.02." bleibt Titeltext. Ohne Jahr gilt ein Schaltjahr, damit
    /// der 29.02. erkannt wird; `resolve` sucht dann das nächste Jahr, das ihn hat.
    private static func validated(day: Int, month: Int, year: Int?) -> CaptureDate? {
        guard (1...12).contains(month), (1...31).contains(day) else { return nil }
        guard calendarDate(day: day, month: month, year: year ?? 2028) != nil else { return nil }
        return .calendar(day: day, month: month, year: year)
    }

    /// Mitternacht des Tages oder `nil`, wenn es ihn nicht gibt (kein Überlauf in den März).
    private static func calendarDate(day: Int, month: Int, year: Int) -> Date? {
        let calendar = AnkerCalendar.iso
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else { return nil }
        let check = calendar.dateComponents([.year, .month, .day], from: date)
        guard check.year == year, check.month == month, check.day == day else { return nil }
        return calendar.startOfDay(for: date)
    }

    /// `!a`, `!B`, `!c`. Alles andere hinter dem Ausrufezeichen bleibt Titeltext — eine stille
    /// Vermutung waere schlechter als ein sichtbar nicht erkanntes Kuerzel.
    private static func priority(from token: String) -> Priority? {
        guard token.count == 2, token.hasPrefix("!") else { return nil }
        return Priority(rawValue: String(token.dropFirst()))
    }

    /// `#1` bis `#4`. `#0`, `#5`, `#12` und `#` bleiben **woertlich** im Titel: der Nutzer
    /// sieht dann, dass nichts passiert ist, statt eine Zahl zu verlieren.
    private static func anchorNumber(from token: String) -> Int? {
        guard token.count == 2, token.hasPrefix("#"),
              let value = Int(token.dropFirst()), (1...4).contains(value) else {
            return nil
        }
        return value
    }

    /// Loest die Eingabe gegen die angezeigte Woche auf.
    ///
    /// Ein Wochentagskuerzel bezieht sich immer auf die Woche, die gerade offen ist — nicht auf
    /// „den naechsten Mittwoch". Ein Datum („morgen", „24.11.") bezieht sich auf `now` und darf
    /// in eine andere Woche zeigen; ein getippter Anker entfällt dann (`droppedAnchorNumber`),
    /// denn Anker gehören zu genau einer Woche. Ohne Angabe bleibt es beim gewaehlten Tag.
    static func resolve(_ input: CaptureInput, weekStart: Date, fallbackDate: Date, now: Date = Date()) -> CaptureTarget {
        let date: Date
        if let captured = input.date {
            date = self.date(for: captured, now: now) ?? fallbackDate
        } else if let weekday = input.weekdayIndex {
            let monday = AnkerCalendar.weekInterval(containing: weekStart).monday
            date = AnkerCalendar.iso.date(byAdding: .day, value: weekday - 1, to: monday) ?? fallbackDate
        } else {
            date = fallbackDate
        }

        var anchorNumber = input.anchorNumber
        var dropped: Int?
        if let anchor = anchorNumber,
           AnkerCalendar.weekKey(containing: date) != AnkerCalendar.weekKey(containing: weekStart) {
            anchorNumber = nil
            dropped = anchor
        }

        return CaptureTarget(
            date: date,
            priority: input.priority ?? defaultPriority,
            anchorNumber: anchorNumber,
            droppedAnchorNumber: dropped
        )
    }

    /// Der Kalendertag einer Datumsangabe, Mitternacht in dieser Zone.
    static func date(for captured: CaptureDate, now: Date) -> Date? {
        let calendar = AnkerCalendar.iso
        let today = calendar.startOfDay(for: now)
        switch captured {
        case .relative(let days):
            return calendar.date(byAdding: .day, value: days, to: today)
        case .nextWeek:
            let monday = AnkerCalendar.weekInterval(containing: today).monday
            return calendar.date(byAdding: .day, value: 7, to: monday)
        case .calendar(let day, let month, let year?):
            return calendarDate(day: day, month: month, year: year)
        case .calendar(let day, let month, nil):
            // Das nächste Vorkommen ab heute; der 29.02. wartet bis zum nächsten Schaltjahr.
            let thisYear = calendar.component(.year, from: today)
            for year in thisYear...(thisYear + 8) {
                if let date = calendarDate(day: day, month: month, year: year), date >= today {
                    return date
                }
            }
            return nil
        }
    }

    /// Die Zeile unter dem Eingabefeld.
    ///
    /// Zeigt immer den **aufgeloesten** Stand, also mit den wirksamen Vorgaben, nicht nur das
    /// Getippte. Sonst waere nicht erkennbar, wo die Aufgabe ohne weitere Angabe landet.
    static func hint(raw: String, target: CaptureTarget?, anchorCount: Int, language: CaptureLanguage = .current) -> String {
        let input = parse(raw, language: language)

        guard !raw.trimmingCharacters(in: .whitespaces).isEmpty else { return syntaxHelp }
        guard let target else { return syntaxHelp }
        guard !input.isEmpty else { return String(localized: "nur Kürzel — Titel fehlt") }

        // „Blatt" zeigt keine Prioritaetsstufen. Die Hinweiszeile nennt sie nur, wenn sie
        // ausdruecklich getippt wurde — sonst verschwaende `!a` spurlos aus dem Titel.
        var parts = [AnkerDateFormat.weekdayShortCommaDayMonth(target.date)]
        if let priority = input.priority {
            parts.append(priority == .a ? String(localized: "wichtig") : String(localized: "Prio \(priority.label)"))
        }

        if let anchor = target.anchorNumber {
            parts.append(anchor <= anchorCount ? String(localized: "Anker \(anchor)") : String(localized: "Anker \(anchor) gibt es nicht"))
        } else if target.droppedAnchorNumber != nil {
            parts.append(String(localized: "ohne Anker — andere Woche"))
        } else {
            parts.append(String(localized: "ohne Anker"))
        }

        return "→ " + parts.joined(separator: " · ")
    }
}
