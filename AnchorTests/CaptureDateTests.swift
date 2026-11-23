import SwiftData
import XCTest
@testable import Anchorit

/// Natürliche Datumsangaben in der Erfassung („morgen", „in 3 Tagen", „24.11.", „Nov 24") und
/// „Noch offen aus dieser Woche" auf Heute.
///
/// Die Sprache wird ausdrücklich übergeben — der Testlauf ist auf Deutsch festgelegt, die
/// englischen Wörter wären sonst nicht prüfbar.
@MainActor
final class CaptureDateTests: XCTestCase {

    private let de = CaptureLanguage.german
    private let en = CaptureLanguage.english

    /// Donnerstag, 26.11.2026 (KW 48).
    private let thursday = AnkerCalendar.date(year: 2026, month: 11, day: 26)

    private func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        AnkerCalendar.date(year: year, month: month, day: day)
    }

    private func resolvedDate(_ raw: String, language: CaptureLanguage, now: Date) -> Date? {
        let input = CaptureSyntax.parse(raw, language: language)
        guard let captured = input.date else { return nil }
        return CaptureSyntax.date(for: captured, now: now)
    }

    private func assertDay(_ date: Date?, _ expected: Date, _ message: String = "", file: StaticString = #filePath, line: UInt = #line) {
        guard let date else { return XCTFail("kein Datum erkannt \(message)", file: file, line: line) }
        XCTAssertTrue(AnkerCalendar.isSameDay(date, expected), "\(date) statt \(expected) \(message)", file: file, line: line)
    }

    // MARK: - Deutsch: Wörter

    func testGermanRelativeWordsAtTheEnd() {
        let cases: [(String, CaptureDate, String)] = [
            ("Arzt anrufen morgen", .relative(days: 1), "Arzt anrufen"),
            ("Steuer heute", .relative(days: 0), "Steuer"),
            ("Steuer Übermorgen", .relative(days: 2), "Steuer"),
            ("Bericht nächste Woche", .nextWeek, "Bericht"),
            ("Bericht Nächste Woche", .nextWeek, "Bericht"),
            ("Paket abholen in 3 Tagen", .relative(days: 3), "Paket abholen"),
            ("Paket abholen in 1 Tag", .relative(days: 1), "Paket abholen"),
        ]
        for (raw, date, title) in cases {
            let input = CaptureSyntax.parse(raw, language: de)
            XCTAssertEqual(input.date, date, raw)
            XCTAssertEqual(input.title, title, raw)
            XCTAssertNil(input.weekdayIndex, raw)
        }
    }

    func testGermanDateWordInsideASentenceStaysInTheTitle() {
        for raw in [
            "Ich ruf morgen nicht an",
            "Heute Abend kochen",
            "Wir sehen uns in 3 Tagen wieder",
            "Nächste Woche planen",
            "Morgenroutine",
        ] {
            let input = CaptureSyntax.parse(raw, language: de)
            XCTAssertNil(input.date, raw)
            XCTAssertEqual(input.title, raw, raw)
        }
    }

    func testGermanResolvesRelativeToToday() {
        assertDay(resolvedDate("Arzt morgen", language: de, now: thursday), day(2026, 11, 27))
        assertDay(resolvedDate("Arzt übermorgen", language: de, now: thursday), day(2026, 11, 28))
        assertDay(resolvedDate("Arzt heute", language: de, now: thursday), thursday)
        assertDay(resolvedDate("Arzt in 3 Tagen", language: de, now: thursday), day(2026, 11, 29))
        // „nächste Woche" ist der Montag der nächsten Woche, nicht heute plus sieben.
        assertDay(resolvedDate("Arzt nächste Woche", language: de, now: thursday), day(2026, 11, 30))
    }

    // MARK: - Deutsch: Datum

    func testGermanNumericDates() {
        XCTAssertEqual(CaptureSyntax.parse("Termin 24.11.", language: de).date, .calendar(day: 24, month: 11, year: nil))
        XCTAssertEqual(CaptureSyntax.parse("Termin 24.11.2026", language: de).date, .calendar(day: 24, month: 11, year: 2026))
        XCTAssertEqual(CaptureSyntax.parse("Termin 24.11.26", language: de).date, .calendar(day: 24, month: 11, year: 2026))
        XCTAssertEqual(CaptureSyntax.parse("Termin 1.2.", language: de).date, .calendar(day: 1, month: 2, year: nil))
        XCTAssertEqual(CaptureSyntax.parse("Termin 24.11.", language: de).title, "Termin")
    }

    func testDateWithoutYearMeansTheNextOccurrence() {
        // Am 20.11. ist der 24.11. noch in diesem Jahr.
        assertDay(resolvedDate("Termin 24.11.", language: de, now: day(2026, 11, 20)), day(2026, 11, 24))
        // Am 30.11. ist er vorbei: gemeint ist das nächste Jahr.
        assertDay(resolvedDate("Termin 24.11.", language: de, now: day(2026, 11, 30)), day(2027, 11, 24))
        // Heute selbst bleibt heute.
        assertDay(resolvedDate("Termin 30.11.", language: de, now: day(2026, 11, 30)), day(2026, 11, 30))
        // Mit Jahr gilt das Jahr, auch wenn es vorbei ist.
        assertDay(resolvedDate("Termin 24.11.2025", language: de, now: thursday), day(2025, 11, 24))
    }

    func testLeapDayWaitsForTheNextLeapYear() {
        XCTAssertEqual(CaptureSyntax.parse("Schalttag 29.02.", language: de).date, .calendar(day: 29, month: 2, year: nil))
        assertDay(resolvedDate("Schalttag 29.02.", language: de, now: thursday), day(2028, 2, 29))
        // Mit Jahr ohne Schalttag gibt es den Tag nicht — er bleibt Titeltext.
        XCTAssertNil(CaptureSyntax.parse("Schalttag 29.02.2027", language: de).date)
    }

    func testInvalidOrAmbiguousNumbersStayInTheTitle() {
        for raw in ["Termin 31.02.", "Termin 32.1.", "Termin 1.13.", "Kapitel 1.5", "Version 2.1", "Version 1.2.345", "Preis 3."] {
            let input = CaptureSyntax.parse(raw, language: de)
            XCTAssertNil(input.date, raw)
            XCTAssertEqual(input.title, raw, raw)
        }
    }

    func testYearBoundary() {
        let silvesterEve = day(2026, 12, 30)
        assertDay(resolvedDate("Feuerwerk morgen", language: de, now: silvesterEve), day(2026, 12, 31))
        assertDay(resolvedDate("Ausschlafen übermorgen", language: de, now: silvesterEve), day(2027, 1, 1))
        assertDay(resolvedDate("Steuer in 5 Tagen", language: de, now: silvesterEve), day(2027, 1, 4))
        // 30.12.2026 ist Mittwoch der KW 53; die nächste Woche beginnt am Montag, 04.01.2027.
        assertDay(resolvedDate("Planen nächste Woche", language: de, now: silvesterEve), day(2027, 1, 4))
        assertDay(resolvedDate("Termin 3.1.", language: de, now: silvesterEve), day(2027, 1, 3))
    }

    // MARK: - Kürzelschwanz

    func testDateCombinesWithTrailingTokens() {
        let input = CaptureSyntax.parse("Bericht in 3 Tagen #2 !a", language: de)
        XCTAssertEqual(input.title, "Bericht")
        XCTAssertEqual(input.date, .relative(days: 3))
        XCTAssertEqual(input.anchorNumber, 2)
        XCTAssertEqual(input.priority, .a)

        let mixed = CaptureSyntax.parse("#1 Bericht morgen !c", language: de)
        XCTAssertEqual(mixed.title, "Bericht")
        XCTAssertEqual(mixed.date, .relative(days: 1))
        XCTAssertEqual(mixed.anchorNumber, 1)
    }

    func testLastOfDateAndWeekdayWins() {
        let weekdayLast = CaptureSyntax.parse("Bericht morgen fr", language: de)
        XCTAssertEqual(weekdayLast.weekdayIndex, 5)
        XCTAssertNil(weekdayLast.date)
        XCTAssertEqual(weekdayLast.title, "Bericht")

        let dateLast = CaptureSyntax.parse("Bericht fr 24.11.", language: de)
        XCTAssertNil(dateLast.weekdayIndex)
        XCTAssertEqual(dateLast.date, .calendar(day: 24, month: 11, year: nil))
        XCTAssertEqual(dateLast.title, "Bericht")

        let twoDates = CaptureSyntax.parse("Bericht morgen in 3 Tagen", language: de)
        XCTAssertEqual(twoDates.date, .relative(days: 3))
        XCTAssertEqual(twoDates.title, "Bericht")
    }

    func testOnlyDateTokensIsNotATitle() {
        XCTAssertTrue(CaptureSyntax.parse("morgen", language: de).isEmpty)
        XCTAssertTrue(CaptureSyntax.parse("nächste Woche #2", language: de).isEmpty)
    }

    func testLanguagesDoNotMix() {
        XCTAssertNil(CaptureSyntax.parse("Call tomorrow", language: de).date)
        XCTAssertEqual(CaptureSyntax.parse("Call tomorrow", language: de).title, "Call tomorrow")
        XCTAssertNil(CaptureSyntax.parse("Kuchen morgen", language: en).date)
        XCTAssertNil(CaptureSyntax.parse("Pick up 24.11.", language: en).date)
    }

    // MARK: - Englisch

    func testEnglishWordsAtTheEnd() {
        let cases: [(String, CaptureDate, String)] = [
            ("Call mom tomorrow", .relative(days: 1), "Call mom"),
            ("Things to do today", .relative(days: 0), "Things to do"),
            ("Plan Next Week", .nextWeek, "Plan"),
            ("Renew passport in 3 days", .relative(days: 3), "Renew passport"),
            ("Renew passport in 1 day", .relative(days: 1), "Renew passport"),
            ("Dentist Nov 24", .calendar(day: 24, month: 11, year: nil), "Dentist"),
            ("Dentist 24 Nov", .calendar(day: 24, month: 11, year: nil), "Dentist"),
            ("Dentist November 24th", .calendar(day: 24, month: 11, year: nil), "Dentist"),
            ("Dentist Nov. 24", .calendar(day: 24, month: 11, year: nil), "Dentist"),
            ("Dentist Nov 24 2027", .calendar(day: 24, month: 11, year: 2027), "Dentist"),
            ("Dentist 3 Jan #2", .calendar(day: 3, month: 1, year: nil), "Dentist"),
        ]
        for (raw, date, title) in cases {
            let input = CaptureSyntax.parse(raw, language: en)
            XCTAssertEqual(input.date, date, raw)
            XCTAssertEqual(input.title, title, raw)
        }
    }

    func testEnglishSlashDatesAreNotGuessed() {
        // Monat oder Tag zuerst hängt von der Region ab — keine Vermutung.
        for raw in ["Dentist 11/24", "Dentist 24/11", "Dentist 11/24/2026"] {
            let input = CaptureSyntax.parse(raw, language: en)
            XCTAssertNil(input.date, raw)
            XCTAssertEqual(input.title, raw, raw)
        }
    }

    func testEnglishInsideASentenceStaysInTheTitle() {
        for raw in ["Tomorrow never comes", "Call in 3 days or so later", "Next week planning", "Nov 24 report draft"] {
            let input = CaptureSyntax.parse(raw, language: en)
            XCTAssertNil(input.date, raw)
            XCTAssertEqual(input.title, raw, raw)
        }
    }

    func testEnglishResolves() {
        assertDay(resolvedDate("Call tomorrow", language: en, now: thursday), day(2026, 11, 27))
        assertDay(resolvedDate("Call next week", language: en, now: thursday), day(2026, 11, 30))
        assertDay(resolvedDate("Call Nov 24", language: en, now: thursday), day(2027, 11, 24))
        assertDay(resolvedDate("Call Dec 1", language: en, now: thursday), day(2026, 12, 1))
        XCTAssertNil(CaptureSyntax.parse("Call Feb 30", language: en).date)
    }

    func testEnglishWeekdayAndDateLastWins() {
        let input = CaptureSyntax.parse("Report tomorrow fri", language: en)
        XCTAssertEqual(input.weekdayIndex, 5)
        XCTAssertNil(input.date)
    }

    // MARK: - Auflösen und Hinweiszeile

    func testDateInsideTheShownWeekKeepsTheAnchor() {
        let monday = AnkerCalendar.weekInterval(containing: thursday).monday
        let input = CaptureSyntax.parse("Arzt anrufen morgen #2", language: de)
        let target = CaptureSyntax.resolve(input, weekStart: monday, fallbackDate: thursday, now: thursday)

        XCTAssertTrue(AnkerCalendar.isSameDay(target.date, day(2026, 11, 27)))
        XCTAssertEqual(target.anchorNumber, 2)
        XCTAssertNil(target.droppedAnchorNumber)

        let hint = CaptureSyntax.hint(raw: "Arzt anrufen morgen #2", target: target, anchorCount: 4, language: de)
        XCTAssertEqual(hint, "→ \(AnkerDateFormat.weekdayShortCommaDayMonth(day(2026, 11, 27))) · Anker 2")
        XCTAssertTrue(hint.contains("27.11."), hint)
    }

    func testDateInAnotherWeekDropsTheAnchor() {
        let monday = AnkerCalendar.weekInterval(containing: thursday).monday
        let input = CaptureSyntax.parse("Bericht nächste Woche #2", language: de)
        let target = CaptureSyntax.resolve(input, weekStart: monday, fallbackDate: thursday, now: thursday)

        XCTAssertTrue(AnkerCalendar.isSameDay(target.date, day(2026, 11, 30)))
        XCTAssertNil(target.anchorNumber, "Anker gehören zu genau einer Woche")
        XCTAssertEqual(target.droppedAnchorNumber, 2)
        let hint = CaptureSyntax.hint(raw: "Bericht nächste Woche #2", target: target, anchorCount: 4, language: de)
        XCTAssertTrue(hint.contains("ohne Anker — andere Woche"), hint)
        XCTAssertTrue(hint.contains("30.11."), hint)
    }

    func testDateIsRelativeToTodayNotToTheShownWeek() {
        // Die Woche in drei Wochen ist offen, „morgen" bleibt trotzdem morgen.
        let shown = AnkerCalendar.weekInterval(containing: day(2026, 12, 16)).monday
        let input = CaptureSyntax.parse("Bericht morgen", language: de)
        let target = CaptureSyntax.resolve(input, weekStart: shown, fallbackDate: shown, now: thursday)
        XCTAssertTrue(AnkerCalendar.isSameDay(target.date, day(2026, 11, 27)))
    }

    func testCreateFromCaptureLandsInAnotherWeekWithoutAnchor() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = Date()
        let week = TaskActions.ensureWeek(containing: now, weeks: [], modelContext: context)
        let goal = Goal(title: "Anker", colorHex: "#000000", order: 0, week: week)
        context.insert(goal)
        week.appendGoal(goal)

        let input = CaptureSyntax.parse("Bericht in 7 Tagen #1", language: de)
        let task = try XCTUnwrap(TaskActions.create(
            input,
            weekStart: AnkerCalendar.weekInterval(containing: now).monday,
            fallbackDate: now,
            weeks: [week],
            modelContext: context
        ))

        XCTAssertEqual(task.title, "Bericht")
        XCTAssertNil(task.linkedGoal, "Ein Anker dieser Woche gilt nicht in der nächsten")
        let expected = try XCTUnwrap(AnkerCalendar.iso.date(byAdding: .day, value: 7, to: now))
        XCTAssertTrue(AnkerCalendar.storedDay(try XCTUnwrap(task.day).date, isOn: expected))
    }

    func testSyntaxHelpNamesTheDateWords() {
        XCTAssertTrue(CaptureSyntax.syntaxHelp.contains("#1–#4"), CaptureSyntax.syntaxHelp)
        XCTAssertTrue(CaptureSyntax.syntaxHelp.contains("morgen"), CaptureSyntax.syntaxHelp)
    }

    // MARK: - Noch offen aus dieser Woche

    func testOverdueTasksAreOpenTasksOfEarlierDaysThisWeek() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let week = TaskActions.ensureWeek(containing: thursday, weeks: [], modelContext: context)
        let goal = Goal(title: "Anker", colorHex: "#000000", order: 0, week: week)
        context.insert(goal)
        week.appendGoal(goal)

        let monday = try add("Montag offen", on: day(2026, 11, 23), week: week, context: context)
        let tuesdayDone = try add("Dienstag erledigt", on: day(2026, 11, 24), week: week, context: context)
        tuesdayDone.isDone = true
        let wednesday = try add("Mittwoch verankert", on: day(2026, 11, 25), week: week, goal: goal, context: context)
        _ = try add("Heute", on: thursday, week: week, context: context)
        _ = try add("Freitag", on: day(2026, 11, 27), week: week, context: context)
        _ = TaskActions.createUnscheduled(title: "Ohne Tag", goal: goal, modelContext: context)

        let sheet = WeekSheet(monday: thursday, weeks: [week], inbox: [], now: thursday)
        XCTAssertEqual(sheet.overdueTasks(before: thursday).map(\.title), [monday.title, wednesday.title])
        // Am Montag gibt es nichts davor.
        XCTAssertEqual(sheet.overdueTasks(before: day(2026, 11, 23)), [])
    }

    func testOverdueIgnoresThePreviousWeek() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let previous = TaskActions.ensureWeek(containing: day(2026, 11, 20), weeks: [], modelContext: context)
        _ = try add("Freitag der Vorwoche", on: day(2026, 11, 20), week: previous, context: context)
        let week = TaskActions.ensureWeek(containing: thursday, weeks: [previous], modelContext: context)
        let goal = Goal(title: "Anker", colorHex: "#000000", order: 0, week: week)
        context.insert(goal)
        week.appendGoal(goal)
        // Ein Anker dieser Woche hält eine Aufgabe, deren Tag in der Vorwoche liegt.
        _ = try add("Alter Tag am neuen Anker", on: day(2026, 11, 19), week: previous, goal: goal, context: context)

        let sheet = WeekSheet(monday: thursday, weeks: [previous, week], inbox: [], now: thursday)
        XCTAssertEqual(sheet.overdueTasks(before: thursday), [], "Die Vorwoche hat ihren Rückblick")
    }

    /// Ein Dienstag, angelegt acht Stunden östlich, ist hier Montag 16 Uhr — er bleibt Dienstag.
    func testOverdueComparesTheNominalDayAcrossTimeZones() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let week = TaskActions.ensureWeek(containing: thursday, weeks: [], modelContext: context)
        let tuesday = day(2026, 11, 24)
        let stored = AnkerCalendar.iso.startOfDay(for: tuesday).addingTimeInterval(-8 * 60 * 60)
        let tokyoDay = Day(date: stored, week: week)
        context.insert(tokyoDay)
        week.days = [tokyoDay]
        let task = AnkerTask(title: "Tokio", priority: .b, order: 0, day: tokyoDay)
        context.insert(task)
        tokyoDay.appendTask(task)
        try context.save()

        let sheet = WeekSheet(monday: thursday, weeks: [week], inbox: [], now: thursday)
        XCTAssertEqual(sheet.overdueTasks(before: tuesday), [], "Am Dienstag selbst liegt er nicht davor")
        XCTAssertEqual(sheet.overdueTasks(before: day(2026, 11, 25)).map(\.title), ["Tokio"])
    }

    func testMovingOverdueToTodayKeepsTheAnchorAndUndoes() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let week = TaskActions.ensureWeek(containing: thursday, weeks: [], modelContext: context)
        let goal = Goal(title: "Anker", colorHex: "#000000", order: 0, week: week)
        context.insert(goal)
        week.appendGoal(goal)
        let task = try add("Mittwoch", on: day(2026, 11, 25), week: week, goal: goal, context: context)

        let snapshots = [TaskActions.snapshot(task)]
        TaskActions.move(task, to: thursday, weeks: [week], modelContext: context)
        XCTAssertTrue(AnkerCalendar.storedDay(try XCTUnwrap(task.day).date, isOn: thursday))
        XCTAssertEqual(task.linkedGoal?.id, goal.id, "Gleiche Woche: der Anker bleibt")
        XCTAssertEqual(task.carryOverCount, 0)
        XCTAssertEqual(WeekSheet(monday: thursday, weeks: [week], inbox: [], now: thursday).overdueTasks(before: thursday), [])

        TaskActions.undo(TaskUndoNotice(message: "1 Aufgabe auf heute gelegt", snapshots: snapshots), weeks: [week], modelContext: context)
        XCTAssertTrue(AnkerCalendar.storedDay(try XCTUnwrap(task.day).date, isOn: day(2026, 11, 25)))
    }

    // MARK: - Hilfen

    @discardableResult
    private func add(_ title: String, on date: Date, week: Week, goal: Goal? = nil, context: ModelContext) throws -> AnkerTask {
        let day = TaskActions.ensureDay(containing: date, in: week)
        return try XCTUnwrap(TaskActions.create(title: title, priority: .b, on: day, linkedGoal: goal, modelContext: context))
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(AnkerSchema.models)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
