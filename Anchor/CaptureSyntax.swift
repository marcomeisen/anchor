import Foundation

/// Was in einer Erfassungszeile steht, nachdem die Kuerzel herausgelesen sind.
struct CaptureInput: Equatable {
    var title = ""
    /// `nil` heisst: keine Angabe, der Aufrufer setzt seine Vorgabe.
    var priority: Priority?
    /// 1 bis 4. Hoehere Zahlen sind keine Angabe, sondern Titeltext.
    var anchorNumber: Int?
    /// 1 = Montag bis 7 = Sonntag, nach ISO.
    var weekdayIndex: Int?

    var isEmpty: Bool { title.isEmpty }
}

/// Die aufgeloeste Absicht: welcher Tag, welche Prioritaet, welcher Anker.
struct CaptureTarget: Equatable {
    let date: Date
    let priority: Priority
    let anchorNumber: Int?
}

/// Die Ein-Zeilen-Erfassung des Entwurfs: `Angebot pruefen !a #2 mi`.
///
/// Reiner Typ ohne View- und ohne Modellbezug, damit die Regeln pruefbar sind statt in einer
/// Ansicht zu verschwinden.
///
/// Zerlegt wird an Leerzeichen, nicht per Mustersuche im ganzen Text. Das ist der Grund, warum
/// „Somit" und „Modul" keinen Wochentag ergeben: ein Kuerzel muss ein **ganzes** Wort sein.
enum CaptureSyntax {
    /// Deutsche Wochentagskuerzel. Reihenfolge nach ISO, Montag ist 1.
    static let weekdayTokens: [String: Int] = [
        "mo": 1, "di": 2, "mi": 3, "do": 4, "fr": 5, "sa": 6, "so": 7,
    ]

    static let defaultPriority: Priority = .b

    static let syntaxHelp = "!a Prio · #1 Anker · mo–so Tag"

    /// Zerlegt die Eingabe. Reihenfolge der Kuerzel ist beliebig.
    ///
    /// Bei mehreren Kuerzeln derselben Art gewinnt das **letzte** und alle werden entfernt —
    /// ein Einzeiler wird beim Tippen korrigiert, und „die letzte Angabe gilt" ist dabei die
    /// Erwartung. Die Hinweiszeile zeigt vorher, was gewonnen hat.
    static func parse(_ raw: String) -> CaptureInput {
        var input = CaptureInput()
        var titleParts: [String] = []

        for rawToken in raw.split(whereSeparator: \.isWhitespace) {
            // Ein nachgestellter Punkt gehoert zur Abkuerzung („Mi."), nicht zum Kuerzel.
            let token = rawToken.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))

            if let priority = priority(from: token) {
                input.priority = priority
                continue
            }
            if let anchor = anchorNumber(from: token) {
                input.anchorNumber = anchor
                continue
            }
            if let weekday = weekdayTokens[token] {
                input.weekdayIndex = weekday
                continue
            }

            titleParts.append(String(rawToken))
        }

        input.title = titleParts.joined(separator: " ")
        return input
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
    /// „den naechsten Mittwoch". Ohne Kuerzel bleibt es beim gewaehlten Tag.
    static func resolve(_ input: CaptureInput, weekStart: Date, fallbackDate: Date) -> CaptureTarget {
        let date: Date
        if let weekday = input.weekdayIndex {
            let monday = AnkerCalendar.weekInterval(containing: weekStart).monday
            date = AnkerCalendar.iso.date(byAdding: .day, value: weekday - 1, to: monday) ?? fallbackDate
        } else {
            date = fallbackDate
        }

        return CaptureTarget(
            date: date,
            priority: input.priority ?? defaultPriority,
            anchorNumber: input.anchorNumber
        )
    }

    /// Die Zeile unter dem Eingabefeld.
    ///
    /// Zeigt immer den **aufgeloesten** Stand, also mit den wirksamen Vorgaben, nicht nur das
    /// Getippte. Sonst waere nicht erkennbar, wo die Aufgabe ohne weitere Angabe landet.
    static func hint(raw: String, target: CaptureTarget?, anchorCount: Int) -> String {
        let input = parse(raw)

        guard !raw.trimmingCharacters(in: .whitespaces).isEmpty else { return syntaxHelp }
        guard let target else { return syntaxHelp }
        guard !input.isEmpty else { return "nur Kürzel — Titel fehlt" }

        var parts = [
            AnkerDateFormat.weekdayShort(target.date),
            "Prio \(target.priority.label)",
        ]

        if let anchor = target.anchorNumber {
            parts.append(anchor <= anchorCount ? "Anker \(anchor)" : "Anker \(anchor) gibt es nicht")
        } else {
            parts.append("ohne Anker")
        }

        return "→ " + parts.joined(separator: " · ")
    }
}
