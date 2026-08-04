import XCTest
@testable import Daivento

/// Der Parser der Ein-Zeilen-Erfassung. Ohne Container und ohne View — genau deshalb steht er
/// als eigener Typ und nicht in einer Ansicht.
final class CaptureSyntaxTests: XCTestCase {

    // MARK: - Zerlegen

    func testParsesPriorityAnchorAndWeekdayInAnyOrder() {
        let expected = CaptureInput(title: "Angebot prüfen", priority: .a, anchorNumber: 2, weekdayIndex: 3)

        for raw in [
            "Angebot prüfen !a #2 mi",
            "!a Angebot #2 prüfen mi",
            "mi #2 !a Angebot prüfen",
            "Angebot !a prüfen mi #2",
        ] {
            let input = CaptureSyntax.parse(raw)
            XCTAssertEqual(input.priority, expected.priority, raw)
            XCTAssertEqual(input.anchorNumber, expected.anchorNumber, raw)
            XCTAssertEqual(input.weekdayIndex, expected.weekdayIndex, raw)
            XCTAssertEqual(input.title, "Angebot prüfen", raw)
        }
    }

    func testIsCaseInsensitiveAndToleratesTrailingDot() {
        let input = CaptureSyntax.parse("Bericht !B #3 Mi.")
        XCTAssertEqual(input.priority, .b)
        XCTAssertEqual(input.anchorNumber, 3)
        XCTAssertEqual(input.weekdayIndex, 3)
        XCTAssertEqual(input.title, "Bericht")
    }

    func testWeekdayInsideAWordIsNotAToken() {
        // Genau der Grund, warum an Leerzeichen zerlegt wird und nicht im Text gesucht.
        for raw in ["Somit erledigt", "Modul abschließen", "Sonntag planen", "mo-fr blocken"] {
            let input = CaptureSyntax.parse(raw)
            XCTAssertNil(input.weekdayIndex, raw)
            XCTAssertEqual(input.title, raw, raw)
        }
    }

    func testStandaloneWeekdayWordIsATokenEvenWhenAmbiguous() {
        // „so" ist auch ein deutsches Wort. Bewusste Grenze: das Kuerzel gewinnt, und die
        // Hinweiszeile zeigt es **vor** dem Anlegen. Kein Rateverhalten.
        let input = CaptureSyntax.parse("Mach es so")
        XCTAssertEqual(input.weekdayIndex, 7)
        XCTAssertEqual(input.title, "Mach es")
    }

    func testInvalidTokensStayInTheTitle() {
        for raw in ["Kapitel #5 lesen", "Regel #0 prüfen", "Norm #12 lesen",
                    "Rätsel # lösen", "Ausruf !d testen", "Nur ! hier"] {
            let input = CaptureSyntax.parse(raw)
            XCTAssertNil(input.anchorNumber, raw)
            XCTAssertEqual(input.title, raw, "Ungültige Kürzel müssen wörtlich stehen bleiben: \(raw)")
        }
    }

    func testLastTokenOfAKindWins() {
        let input = CaptureSyntax.parse("Sache !a !c #1 #4 mo di")
        XCTAssertEqual(input.priority, .c)
        XCTAssertEqual(input.anchorNumber, 4)
        XCTAssertEqual(input.weekdayIndex, 2)
        XCTAssertEqual(input.title, "Sache")
    }

    func testCollapsesWhitespaceAndTrims() {
        let input = CaptureSyntax.parse("   Zwei\t\tWörter \n  ")
        XCTAssertEqual(input.title, "Zwei Wörter")
    }

    func testTokensOnlyYieldsAnEmptyTitle() {
        let input = CaptureSyntax.parse("mo !a #2")
        XCTAssertTrue(input.isEmpty)
        XCTAssertEqual(input.priority, .a)
        XCTAssertEqual(input.anchorNumber, 2)
    }

    func testEmptyInput() {
        XCTAssertTrue(CaptureSyntax.parse("").isEmpty)
        XCTAssertTrue(CaptureSyntax.parse("   ").isEmpty)
    }

    // MARK: - Auflösen

    func testWeekdayResolvesInsideTheDisplayedWeek() {
        // KW 32/2026 beginnt am Montag, 03.08.
        let monday = AnkerCalendar.weekInterval(containing: AnkerCalendar.date(year: 2026, month: 8, day: 5)).monday
        let input = CaptureSyntax.parse("Bericht mi")
        let target = CaptureSyntax.resolve(input, weekStart: monday, fallbackDate: monday)

        XCTAssertTrue(AnkerCalendar.isSameDay(target.date, AnkerCalendar.date(year: 2026, month: 8, day: 5)))
        XCTAssertEqual(target.priority, CaptureSyntax.defaultPriority)
        XCTAssertNil(target.anchorNumber)
    }

    func testWithoutWeekdayTheSelectedDayWins() {
        let monday = AnkerCalendar.date(year: 2026, month: 8, day: 3)
        let friday = AnkerCalendar.date(year: 2026, month: 8, day: 7)
        let target = CaptureSyntax.resolve(CaptureSyntax.parse("Bericht !a"), weekStart: monday, fallbackDate: friday)

        XCTAssertTrue(AnkerCalendar.isSameDay(target.date, friday))
        XCTAssertEqual(target.priority, .a)
    }

    func testWeekdayIsRelativeToTheShownWeekNotToToday() {
        // Eine Woche im Dezember, Kuerzel „mo" — das Ziel muss in *dieser* Woche liegen.
        let december = AnkerCalendar.date(year: 2026, month: 12, day: 16)
        let monday = AnkerCalendar.weekInterval(containing: december).monday
        let target = CaptureSyntax.resolve(CaptureSyntax.parse("Jahresabschluss mo"),
                                           weekStart: monday, fallbackDate: december)

        XCTAssertTrue(AnkerCalendar.isSameDay(target.date, monday))
        XCTAssertEqual(AnkerCalendar.weekInterval(containing: target.date).isoWeek,
                       AnkerCalendar.weekInterval(containing: december).isoWeek)
    }

    // MARK: - Hinweiszeile

    func testHintShowsSyntaxHelpWhenEmpty() {
        XCTAssertEqual(CaptureSyntax.hint(raw: "", target: nil, anchorCount: 4), CaptureSyntax.syntaxHelp)
        XCTAssertEqual(CaptureSyntax.hint(raw: "   ", target: nil, anchorCount: 4), CaptureSyntax.syntaxHelp)
    }

    func testHintShowsTheResolvedStateNotJustWhatWasTyped() {
        let monday = AnkerCalendar.date(year: 2026, month: 8, day: 3)
        let input = CaptureSyntax.parse("Bericht mi")
        let target = CaptureSyntax.resolve(input, weekStart: monday, fallbackDate: monday)
        let hint = CaptureSyntax.hint(raw: "Bericht mi", target: target, anchorCount: 4)

        XCTAssertTrue(hint.hasPrefix("→ "), hint)
        // Prioritaet steht da, obwohl sie nicht getippt wurde — sonst waere nicht erkennbar,
        // wo die Aufgabe landet.
        XCTAssertTrue(hint.contains("Prio B"), hint)
        XCTAssertTrue(hint.contains("ohne Anker"), hint)
    }

    func testHintNamesAnAnchorThatDoesNotExist() {
        let monday = AnkerCalendar.date(year: 2026, month: 8, day: 3)
        let input = CaptureSyntax.parse("Bericht #4")
        let target = CaptureSyntax.resolve(input, weekStart: monday, fallbackDate: monday)

        XCTAssertTrue(CaptureSyntax.hint(raw: "Bericht #4", target: target, anchorCount: 2)
            .contains("Anker 4 gibt es nicht"))
        XCTAssertTrue(CaptureSyntax.hint(raw: "Bericht #4", target: target, anchorCount: 4)
            .contains("Anker 4"))
    }

    func testHintSaysWhenOnlyTokensWereTyped() {
        let monday = AnkerCalendar.date(year: 2026, month: 8, day: 3)
        let input = CaptureSyntax.parse("mo !a")
        let target = CaptureSyntax.resolve(input, weekStart: monday, fallbackDate: monday)

        XCTAssertEqual(CaptureSyntax.hint(raw: "mo !a", target: target, anchorCount: 4),
                       "nur Kürzel — Titel fehlt")
    }
}
