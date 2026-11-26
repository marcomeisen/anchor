import SwiftData
import XCTest
@testable import Anchorit

/// Befunde aus dem Testbericht vom 26.11.2026: Zeitzonen ab zwölf Stunden Abstand (H3),
/// Wiederholungen (N2, M5), Undo-Reste (N1), Zusammenführen (M6, M7) und die Archivserie (N7).
@MainActor
final class RobustnessTests: XCTestCase {

    // MARK: - H3 · Tagesschlüssel über zwölf und mehr Zeitzonen

    /// New York legt den Montag an (00:00 EST), Tokio liest ihn: dort ist es Montag 14 Uhr,
    /// die Zwölf-Stunden-Regel allein ergäbe Dienstag.
    func testNewYorkMondayStaysMondayInTokyo() throws {
        let newYork = try calendar("America/New_York")
        let tokyo = try calendar("Asia/Tokyo")
        let midnight = try XCTUnwrap(newYork.date(from: DateComponents(year: 2026, month: 11, day: 23)))

        let day = Day(date: midnight, dayKey: AnkerCalendar.dayKey(of: midnight, calendar: newYork))
        XCTAssertEqual(day.dayKey, "2026-11-23")

        let mondayInTokyo = try XCTUnwrap(tokyo.date(from: DateComponents(year: 2026, month: 11, day: 23, hour: 9)))
        XCTAssertTrue(AnkerCalendar.storedDay(day, isOn: mondayInTokyo, calendar: tokyo))
        XCTAssertEqual(tokyo.dateComponents([.year, .month, .day], from: AnkerCalendar.nominalDate(of: day, calendar: tokyo)),
                       DateComponents(year: 2026, month: 11, day: 23))

        // Altbestand ohne Schlüssel: die Regel von früher — genau der Fehler aus dem Bericht.
        day.dayKey = nil
        XCTAssertFalse(AnkerCalendar.storedDay(day, isOn: mondayInTokyo, calendar: tokyo))
    }

    /// Berlin und Neuseeland im Südsommer: genau zwölf Stunden.
    func testBerlinDayStaysTheSameInNewZealand() throws {
        let berlin = try calendar("Europe/Berlin")
        let auckland = try calendar("Pacific/Auckland")
        let midnight = try XCTUnwrap(berlin.date(from: DateComponents(year: 2026, month: 12, day: 7)))
        let day = Day(date: midnight, dayKey: AnkerCalendar.dayKey(of: midnight, calendar: berlin))

        let mondayInAuckland = try XCTUnwrap(auckland.date(from: DateComponents(year: 2026, month: 12, day: 7, hour: 8)))
        XCTAssertTrue(AnkerCalendar.storedDay(day, isOn: mondayInAuckland, calendar: auckland))
        day.dayKey = nil
        XCTAssertFalse(AnkerCalendar.storedDay(day, isOn: mondayInAuckland, calendar: auckland))
    }

    func testNewDaysCarryTheirKey() throws {
        let context = try makeContext()
        let date = AnkerCalendar.date(year: 2026, month: 11, day: 26)
        let week = TaskActions.ensureWeek(containing: date, weeks: [], modelContext: context)
        let day = TaskActions.ensureDay(containing: date, in: week)
        XCTAssertEqual(day.dayKey, "2026-11-26")
        XCTAssertTrue(AnkerCalendar.isSameDay(week.nominalMonday, AnkerCalendar.date(year: 2026, month: 11, day: 23)))
    }

    /// Zwei Tage, deren Rohdaten nach der alten Regel auf denselben Tag fielen, aber
    /// verschiedene Tage meinen, werden nicht mehr zusammengeführt.
    func testMergeRespectsDayKeys() throws {
        let context = try makeContext()
        let monday = AnkerCalendar.date(year: 2026, month: 11, day: 23)
        let week = TaskActions.ensureWeek(containing: monday, weeks: [], modelContext: context)

        // Aus einer Zone weit im Westen: Montag Mitternacht dort ist hier schon Montagnachmittag.
        let foreignRaw = AnkerCalendar.date(year: 2026, month: 11, day: 23, hour: 14)
        let foreign = Day(date: foreignRaw, week: week, dayKey: "2026-11-23")
        let tuesday = Day(date: AnkerCalendar.iso.startOfDay(for: AnkerCalendar.date(year: 2026, month: 11, day: 24)), week: week)
        context.insert(foreign)
        context.insert(tuesday)
        week.days = [foreign, tuesday]
        let task = try XCTUnwrap(TaskActions.create(title: "Montagsaufgabe", priority: .b, on: foreign, linkedGoal: nil, modelContext: context))

        StoreMaintenance.merge(weeks: [week], modelContext: context)

        XCTAssertEqual(week.dayList.filter { !$0.isDeleted }.count, 2, "Montag und Dienstag bleiben getrennt")
        XCTAssertTrue(AnkerCalendar.storedDay(try XCTUnwrap(task.day), isOn: monday))
    }

    func testBackfillOnlyWritesUnambiguousKeys() throws {
        let context = try makeContext()
        let monday = AnkerCalendar.date(year: 2026, month: 11, day: 23)
        let week = TaskActions.ensureWeek(containing: monday, weeks: [], modelContext: context)
        let near = Day(date: AnkerCalendar.iso.startOfDay(for: monday), week: week)
        let far = Day(date: AnkerCalendar.date(year: 2026, month: 11, day: 24, hour: 13), week: week)
        near.dayKey = nil
        far.dayKey = nil
        context.insert(near)
        context.insert(far)
        week.days = [near, far]

        XCTAssertEqual(StoreMaintenance.backfillDayKeys(in: [week]), 1)
        XCTAssertEqual(near.dayKey, "2026-11-23")
        XCTAssertNil(far.dayKey, "Mittags gespeichert: kann aus einer Zone zwölf Stunden weiter stammen")
    }

    // MARK: - N2 · Monatlich ohne Drift

    func testMonthlyChainKeepsItsDayOfMonth() throws {
        let context = try makeContext()
        let january = AnkerCalendar.iso.startOfDay(for: AnkerCalendar.date(year: 2027, month: 1, day: 31))
        let task = try recurringTask(.monthly, on: january, context: context)

        let february = try XCTUnwrap(TaskActions.toggleDone(task, modelContext: context))
        XCTAssertTrue(AnkerCalendar.storedDay(try XCTUnwrap(february.day), isOn: AnkerCalendar.date(year: 2027, month: 2, day: 28)))
        XCTAssertEqual(february.recurrence, .monthly)
        XCTAssertEqual(february.recurrenceRaw, "monthly:31")

        let march = try XCTUnwrap(TaskActions.toggleDone(february, modelContext: context))
        XCTAssertTrue(AnkerCalendar.storedDay(try XCTUnwrap(march.day), isOn: AnkerCalendar.date(year: 2027, month: 3, day: 31)),
                      "Nach dem 28. Februar wieder der 31., nicht der 28.")
    }

    func testMonthlyRawValues() {
        XCTAssertEqual(TaskRecurrence.parse("monthly")?.rule, .monthly)
        XCTAssertEqual(TaskRecurrence.parse("monthly:30")?.monthDay, 30)
        XCTAssertNil(TaskRecurrence.parse("weekly:3"))
        XCTAssertNil(TaskRecurrence.parse("monthly:40"))
        XCTAssertEqual(TaskRecurrence.monthlyRaw(monthDay: 15), "monthly", "Ältere Versionen verstehen den schlichten Wert")
    }

    // MARK: - M5 · Loslassen beendet die Wiederholung nicht

    func testDroppingARecurringTaskContinuesTheChain() throws {
        let context = try makeContext()
        let wednesday = AnkerCalendar.iso.startOfDay(for: AnkerCalendar.date(year: 2026, month: 11, day: 25))
        let task = try recurringTask(.weekly, on: wednesday, context: context, title: "Sport")
        let week = try XCTUnwrap(task.day?.week)

        let report = WeekActions.close(week, at: AnkerCalendar.date(year: 2026, month: 11, day: 29),
                                       decisions: [task.id: .drop], weeks: [week], modelContext: context)

        XCTAssertEqual(report.droppedTasks, 1)
        XCTAssertEqual(report.continuedRecurrences, 1)
        let all = try context.fetch(FetchDescriptor<AnkerTask>()).filter { !$0.isDeleted }
        let next = try XCTUnwrap(all.first { $0.title == "Sport" })
        XCTAssertEqual(next.recurrence, .weekly)
        XCTAssertFalse(next.isDone)
        XCTAssertTrue(AnkerCalendar.storedDay(try XCTUnwrap(next.day), isOn: AnkerCalendar.date(year: 2026, month: 12, day: 2)))
    }

    func testDroppingADailyTaskContinuesInTheNextWeek() throws {
        let context = try makeContext()
        let wednesday = AnkerCalendar.iso.startOfDay(for: AnkerCalendar.date(year: 2026, month: 11, day: 25))
        let task = try recurringTask(.daily, on: wednesday, context: context, title: "Lesen")
        let week = try XCTUnwrap(task.day?.week)

        WeekActions.close(week, decisions: [task.id: .drop], weeks: [week], modelContext: context)

        let next = try XCTUnwrap(try context.fetch(FetchDescriptor<AnkerTask>()).first { !$0.isDeleted && $0.title == "Lesen" })
        XCTAssertTrue(AnkerCalendar.storedDay(try XCTUnwrap(next.day), isOn: AnkerCalendar.date(year: 2026, month: 11, day: 30)),
                      "Nicht in der abgeschlossenen Woche, sondern am Montag danach")
    }

    // MARK: - N1 · Undo räumt leere Gerüste weg

    func testUndoOfAMoveRemovesTheEmptyWeekItCreated() throws {
        let context = try makeContext()
        let thursday = AnkerCalendar.date(year: 2026, month: 11, day: 26)
        let week = TaskActions.ensureWeek(containing: thursday, weeks: [], modelContext: context)
        let day = TaskActions.ensureDay(containing: thursday, in: week)
        let task = try XCTUnwrap(TaskActions.create(title: "Bericht", priority: .b, on: day, linkedGoal: nil, modelContext: context))

        let snapshot = TaskActions.snapshot(task)
        let later = AnkerCalendar.date(year: 2026, month: 12, day: 10)
        TaskActions.move(task, to: later, weeks: [week], modelContext: context)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Week>()).count, 2)

        let weeks = try context.fetch(FetchDescriptor<Week>())
        TaskActions.restore([snapshot], weeks: weeks, modelContext: context)

        let remaining = try context.fetch(FetchDescriptor<Week>()).filter { !$0.isDeleted }
        XCTAssertEqual(remaining.map(\.id), [week.id], "Die leere Woche des Verschiebens ist wieder weg")
        XCTAssertEqual(try context.fetch(FetchDescriptor<Day>()).filter { !$0.isDeleted }.map(\.id), [day.id])
        XCTAssertTrue(task.day === day)
    }

    func testUndoKeepsDaysThatStillHoldSomething() throws {
        let context = try makeContext()
        let thursday = AnkerCalendar.date(year: 2026, month: 11, day: 26)
        let friday = AnkerCalendar.date(year: 2026, month: 11, day: 27)
        let week = TaskActions.ensureWeek(containing: thursday, weeks: [], modelContext: context)
        let source = TaskActions.ensureDay(containing: thursday, in: week)
        let target = TaskActions.ensureDay(containing: friday, in: week)
        target.focusNote = "Fokus"
        let task = try XCTUnwrap(TaskActions.create(title: "Bericht", priority: .b, on: source, linkedGoal: nil, modelContext: context))

        let snapshot = TaskActions.snapshot(task)
        TaskActions.move(task, to: friday, weeks: [week], modelContext: context)
        TaskActions.restore([snapshot], weeks: [week], modelContext: context)

        XCTAssertFalse(target.isDeleted, "Ein Tag mit Fokus ist kein leeres Gerüst")
    }

    // MARK: - M6 · Gleichstand beim Zusammenführen

    func testOlderAnchorsBeatFreshOnboardingAnchorsOnATie() throws {
        let context = try makeContext()
        let interval = AnkerCalendar.weekInterval(containing: AnkerCalendar.date(year: 2026, month: 8, day: 3))
        let onboarding = Week(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                              isoYear: interval.isoYear, isoWeek: interval.isoWeek, monday: interval.monday, sunday: interval.sunday)
        let synced = Week(id: UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")!,
                          isoYear: interval.isoYear, isoWeek: interval.isoWeek, monday: interval.monday, sunday: interval.sunday)
        context.insert(onboarding)
        context.insert(synced)

        // Echte Anker: echte Titel, kein Warum — Rang 1 wie die frisch getippten.
        let created = Date(timeIntervalSinceNow: -7 * 24 * 60 * 60)
        for (index, title) in ["Echt 1", "Echt 2", "Echt 3", "Echt 4"].enumerated() {
            let goal = Goal(title: title, colorHex: "#000000", order: index, week: synced)
            goal.createdAt = created
            context.insert(goal)
            synced.appendGoal(goal)
        }
        for (index, title) in ["Neu 1", "Neu 2", "Neu 3", "Neu 4"].enumerated() {
            let goal = Goal(title: title, colorHex: "#000000", order: index, week: onboarding)
            context.insert(goal)
            onboarding.appendGoal(goal)
        }

        StoreMaintenance.merge(weeks: [synced, onboarding], modelContext: context)

        let survivor = try XCTUnwrap(try context.fetch(FetchDescriptor<Week>()).first { !$0.isDeleted })
        XCTAssertEqual(GoalOrdering.anchors(in: survivor).map(\.title), ["Echt 1", "Echt 2", "Echt 3", "Echt 4"])
    }

    // MARK: - M7 · Karenzzeit vor dem Lösen

    func testStrandedTasksKeepTheirAnchorDuringTheGracePeriod() throws {
        let context = try makeContext()
        let goal = Goal(title: "Unterwegs", colorHex: "#000000")
        context.insert(goal)
        let task = try XCTUnwrap(TaskActions.createUnscheduled(title: "Ohne Tag", goal: goal, modelContext: context))
        goal.week = nil

        let start = Date()
        StoreMaintenance.adoptOrphans(weeks: [], modelContext: context, now: start)
        XCTAssertTrue(task.linkedGoal === goal, "Im ersten Lauf ist das Ziel vielleicht nur kurz ohne Woche")

        StoreMaintenance.adoptOrphans(weeks: [], modelContext: context, now: start.addingTimeInterval(StoreMaintenance.strandedGrace + 1))
        XCTAssertNil(task.linkedGoal, "Nach der Frist in den Eingang, damit die Aufgabe sichtbar ist")
    }

    // MARK: - N7 · Leere Anker brechen die Serie nicht

    func testEmptyAnchorDoesNotBreakTheStreak() {
        XCTAssertTrue(ArchiveSummary.isAllHeld([.held, .empty]))
        XCTAssertFalse(ArchiveSummary.isAllHeld([.empty]))
        XCTAssertFalse(ArchiveSummary.isAllHeld([.held, .unanswered]))
        let first = AnkerCalendar.WeekKey(isoYear: 2026, isoWeek: 10)
        XCTAssertEqual(ArchiveSummary.longestHeldStreak(marks: [first: [.held, .empty], first.next: [.held]]), 2)
    }

    // MARK: - Hilfen

    private func calendar(_ identifier: String) throws -> Calendar {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: identifier))
        return calendar
    }

    private func recurringTask(_ rule: TaskRecurrence, on date: Date, context: ModelContext, title: String = "Wiederkehrend") throws -> AnkerTask {
        let week = TaskActions.ensureWeek(containing: date, weeks: [], modelContext: context)
        let day = TaskActions.ensureDay(containing: date, in: week)
        let task = try XCTUnwrap(TaskActions.create(title: title, priority: .b, on: day, linkedGoal: nil, modelContext: context))
        task.recurrence = rule
        return task
    }

    private func makeContext() throws -> ModelContext {
        let schema = Schema(AnkerSchema.models)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        containers.append(container)
        return container.mainContext
    }

    // MARK: - N9 · Rückblickantwort über die Mutationsschicht

    func testVerdictIsOnlyWrittenWhenItChanges() throws {
        let context = try makeContext()
        let week = TaskActions.ensureWeek(containing: Date(), weeks: [], modelContext: context)
        let goal = try XCTUnwrap(GoalActions.create(title: "Release", why: nil, in: week, modelContext: context))

        XCTAssertTrue(GoalActions.setVerdict(goal, to: .held, modelContext: context))
        XCTAssertEqual(goal.verdict, .held)
        XCTAssertFalse(GoalActions.setVerdict(goal, to: .held, modelContext: context), "Unverändert schreibt nichts")
        XCTAssertTrue(GoalActions.setVerdict(goal, to: nil, modelContext: context))
        XCTAssertNil(goal.verdict)
        XCTAssertFalse(GoalActions.update(goal, title: "Release", why: "", modelContext: context), "Gleicher Titel, leeres Warum")
    }

    // MARK: - M10 · Ablegen in den Eingang aus einer fremden Woche

    func testDropIntoInboxFromAnotherWeekSaysWhereTheTaskWent() throws {
        let context = try makeContext()
        let now = Date()
        let nextMonday = try XCTUnwrap(AnkerCalendar.iso.date(byAdding: .weekOfYear, value: 2,
                                                              to: AnkerCalendar.weekInterval(containing: now).monday))
        let task = AnkerTask(title: "Lose", priority: .b, order: 0)
        context.insert(task)

        let otherWeek = WeekSheet(monday: nextMonday, weeks: [], inbox: [task], now: now)
        XCTAssertEqual(WeekDropSupport.message(for: task, in: otherWeek, fallback: "Ohne Anker gelegt"),
                       String(localized: "In den Eingang gelegt"))

        let thisWeek = WeekSheet(monday: now, weeks: [], inbox: [task], now: now)
        XCTAssertEqual(WeekDropSupport.message(for: task, in: thisWeek, fallback: "Ohne Anker gelegt"), "Ohne Anker gelegt")
    }

    /// Der Container muss den Test überleben, sonst ist der Kontext tot.
    private var containers: [ModelContainer] = []
}
