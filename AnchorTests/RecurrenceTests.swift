import SwiftData
import XCTest
@testable import Anchorit

/// Wiederkehrende Aufgaben: „wiederholen nach Plan" — Abhaken erzeugt die nächste Instanz am
/// nächsten Termin ab dem geplanten Tag, einmal pro Instanz, rückgängig machbar.
final class RecurrenceTests: XCTestCase {

    // MARK: - Regeln

    func testNextDateForEveryRule() {
        let wednesday = day(2026, 11, 25)
        XCTAssertTrue(isSameDay(TaskRecurrence.daily.nextDate(after: wednesday), day(2026, 11, 26)))
        XCTAssertTrue(isSameDay(TaskRecurrence.weekly.nextDate(after: wednesday), day(2026, 12, 2)))
        XCTAssertTrue(isSameDay(TaskRecurrence.biweekly.nextDate(after: wednesday), day(2026, 12, 9)))
        XCTAssertTrue(isSameDay(TaskRecurrence.monthly.nextDate(after: wednesday), day(2026, 12, 25)))
        XCTAssertTrue(isSameDay(TaskRecurrence.weekdays.nextDate(after: wednesday), day(2026, 11, 26)))
    }

    func testWeekdaysSkipsTheWeekend() {
        // Freitag, Samstag und Sonntag führen alle auf den Montag.
        for start in [day(2026, 11, 27), day(2026, 11, 28), day(2026, 11, 29)] {
            XCTAssertTrue(isSameDay(TaskRecurrence.weekdays.nextDate(after: start), day(2026, 11, 30)))
        }
        XCTAssertTrue(isSameDay(TaskRecurrence.weekdays.nextDate(after: day(2026, 11, 30)), day(2026, 12, 1)))
    }

    func testMonthlyFallsBackToTheLastDayOfShorterMonths() {
        XCTAssertTrue(isSameDay(TaskRecurrence.monthly.nextDate(after: day(2026, 1, 31)), day(2026, 2, 28)))
        XCTAssertTrue(isSameDay(TaskRecurrence.monthly.nextDate(after: day(2028, 1, 31)), day(2028, 2, 29)), "Schaltjahr")
        XCTAssertTrue(isSameDay(TaskRecurrence.monthly.nextDate(after: day(2026, 3, 31)), day(2026, 4, 30)))
        XCTAssertTrue(isSameDay(TaskRecurrence.monthly.nextDate(after: day(2026, 12, 31)), day(2027, 1, 31)), "Jahreswechsel")
    }

    func testUnknownRawValueReadsAsNoRule() {
        let task = AnkerTask(title: "Zukunft", priority: .b, order: 0)
        task.recurrenceRaw = "hourly"
        XCTAssertNil(task.recurrence, "Ein Fall einer neueren Version darf nichts brechen")
        XCTAssertEqual(task.recurrenceRaw, "hourly")
    }

    // MARK: - Abhaken erzeugt die Folgeinstanz

    @MainActor
    func testCompletingCreatesTheNextInstanceFromThePlannedDay() throws {
        let context = try makeContext()
        let monday = day(2026, 11, 23)
        let week = TaskActions.ensureWeek(containing: monday, weeks: [], modelContext: context)
        let task = try XCTUnwrap(TaskActions.create(
            title: "Wochenplanung", priority: .a, on: TaskActions.ensureDay(containing: monday, in: week),
            linkedGoal: nil, modelContext: context
        ))
        task.recurrence = .weekly

        // Abgehakt erst am Donnerstag — der nächste Termin rechnet trotzdem ab Montag.
        let next = try XCTUnwrap(TaskActions.toggleDone(task, now: day(2026, 11, 26), modelContext: context))

        XCTAssertEqual(next.title, "Wochenplanung")
        XCTAssertEqual(next.priority, .a)
        XCTAssertEqual(next.recurrence, .weekly)
        XCTAssertFalse(next.isDone)
        XCTAssertNil(next.recurrenceNextID)
        XCTAssertTrue(AnkerCalendar.storedDay(try XCTUnwrap(next.day).date, isOn: day(2026, 11, 30)))
        XCTAssertEqual(task.recurrence, .weekly, "Die erledigte Instanz behält ihre Regel")
        XCTAssertEqual(task.recurrenceNextID, next.id)
    }

    @MainActor
    func testSameWeekKeepsTheAnchor() throws {
        let context = try makeContext()
        let tuesday = day(2026, 11, 24)
        let week = TaskActions.ensureWeek(containing: tuesday, weeks: [], modelContext: context)
        let goal = addGoal("Fitness", to: week, context: context)
        let task = try XCTUnwrap(TaskActions.create(
            title: "Laufen", priority: .b, on: TaskActions.ensureDay(containing: tuesday, in: week),
            linkedGoal: goal, modelContext: context
        ))
        task.recurrence = .daily

        let next = try XCTUnwrap(TaskActions.toggleDone(task, modelContext: context))
        XCTAssertEqual(next.linkedGoal?.id, goal.id)
        XCTAssertTrue(AnkerCalendar.storedDay(try XCTUnwrap(next.day).date, isOn: day(2026, 11, 25)))
        XCTAssertTrue(next.day?.week === week)
    }

    @MainActor
    func testAnchorCarriesOverTheWeekBoundaryByTitle() throws {
        let context = try makeContext()
        let friday = day(2026, 11, 27)
        let week = TaskActions.ensureWeek(containing: friday, weeks: [], modelContext: context)
        let goal = addGoal("Fitness", to: week, context: context)
        let nextWeek = TaskActions.ensureWeek(containing: day(2026, 11, 30), weeks: [week], modelContext: context)
        let matching = addGoal(" fitness ", to: nextWeek, context: context)

        let task = try XCTUnwrap(TaskActions.create(
            title: "Dehnen", priority: .b, on: TaskActions.ensureDay(containing: friday, in: week),
            linkedGoal: goal, modelContext: context
        ))
        task.recurrence = .weekdays

        let next = try XCTUnwrap(TaskActions.toggleDone(task, modelContext: context))
        XCTAssertTrue(AnkerCalendar.storedDay(try XCTUnwrap(next.day).date, isOn: day(2026, 11, 30)),
                      "Werktags: vom Freitag auf den Montag")
        XCTAssertEqual(next.linkedGoal?.id, matching.id, "Gleichnamiger Anker der Folgewoche")

        // Ohne gleichnamigen Anker drüben steht die Folgeinstanz ohne Anker.
        let other = addGoal("Lesen", to: week, context: context)
        let reading = try XCTUnwrap(TaskActions.create(
            title: "Kapitel", priority: .b, on: TaskActions.ensureDay(containing: friday, in: week),
            linkedGoal: other, modelContext: context
        ))
        reading.recurrence = .weekly
        let nextReading = try XCTUnwrap(TaskActions.toggleDone(reading, modelContext: context))
        XCTAssertNil(nextReading.linkedGoal)
    }

    @MainActor
    func testYearBoundaryAcrossISOWeek53() throws {
        let context = try makeContext()
        XCTAssertEqual(AnkerCalendar.weeksInISOYear(2026), 53)

        // Donnerstag, 31.12.2026 liegt in KW 53/2026.
        let thursday = day(2026, 12, 31)
        let week = TaskActions.ensureWeek(containing: thursday, weeks: [], modelContext: context)
        XCTAssertEqual(week.isoWeek, 53)
        let weekly = try XCTUnwrap(TaskActions.create(
            title: "Wochenbericht", priority: .b, on: TaskActions.ensureDay(containing: thursday, in: week),
            linkedGoal: nil, modelContext: context
        ))
        weekly.recurrence = .weekly
        let nextWeekly = try XCTUnwrap(TaskActions.toggleDone(weekly, modelContext: context))
        XCTAssertTrue(AnkerCalendar.storedDay(try XCTUnwrap(nextWeekly.day).date, isOn: day(2027, 1, 7)))
        XCTAssertEqual(nextWeekly.day?.week?.isoYear, 2027)
        XCTAssertEqual(nextWeekly.day?.week?.isoWeek, 1)

        // Sonntag, 3.1.2027 ist noch KW 53/2026 — täglich führt in KW 1/2027.
        let sunday = day(2027, 1, 3)
        XCTAssertTrue(TaskActions.isSameISOWeek(TaskActions.ensureWeek(containing: sunday, weeks: [], modelContext: context), week))
        let daily = try XCTUnwrap(TaskActions.create(
            title: "Tagebuch", priority: .b, on: TaskActions.ensureDay(containing: sunday, in: week),
            linkedGoal: nil, modelContext: context
        ))
        daily.recurrence = .daily
        let nextDaily = try XCTUnwrap(TaskActions.toggleDone(daily, modelContext: context))
        XCTAssertTrue(AnkerCalendar.storedDay(try XCTUnwrap(nextDaily.day).date, isOn: day(2027, 1, 4)))
        XCTAssertEqual(nextDaily.day?.week?.isoWeek, 1)
        XCTAssertTrue(nextDaily.day?.week === nextWeekly.day?.week, "Dieselbe Woche, kein Duplikat")
    }

    /// Ein Tag, den ein Gerät in Tokio angelegt hat, ist hier ein anderer Zeitpunkt. Der nächste
    /// Termin rechnet ab dem gemeinten Kalendertag, nicht ab dem rohen Datum.
    @MainActor
    func testDayCreatedInTokyoCompletedHere() throws {
        let tokyoZone = try XCTUnwrap(TimeZone(identifier: "Asia/Tokyo"))
        let reference = day(2026, 11, 25)
        let difference = abs(tokyoZone.secondsFromGMT(for: reference) - TimeZone.current.secondsFromGMT(for: reference))
        guard difference > 0, difference < 12 * 60 * 60 else {
            throw XCTSkip("Braucht eine lokale Zone, die weniger als zwölf Stunden von Tokio abweicht und nicht Tokio ist")
        }

        var tokyo = Calendar(identifier: .iso8601)
        tokyo.timeZone = tokyoZone
        let tokyoMidnight = try XCTUnwrap(tokyo.date(from: DateComponents(year: 2026, month: 11, day: 25)))

        let context = try makeContext()
        let week = TaskActions.ensureWeek(containing: reference, weeks: [], modelContext: context)
        let storedDay = Day(date: tokyoMidnight, week: week)
        context.insert(storedDay)
        week.days = week.dayList + [storedDay]
        let task = try XCTUnwrap(TaskActions.create(title: "Standup", priority: .b, on: storedDay, linkedGoal: nil, modelContext: context))
        task.recurrence = .daily

        let next = try XCTUnwrap(TaskActions.toggleDone(task, modelContext: context))
        XCTAssertTrue(AnkerCalendar.storedDay(try XCTUnwrap(next.day).date, isOn: day(2026, 11, 26)),
                      "Mittwoch in Tokio, Donnerstag als nächster Termin — nicht derselbe Tag oder der übernächste")
    }

    // MARK: - Keine Dopplung

    @MainActor
    func testReopeningAndCompletingAgainCreatesNoSecondInstance() throws {
        let context = try makeContext()
        let task = try makeRecurringTask(.daily, on: day(2026, 11, 24), context: context)

        let first = try XCTUnwrap(TaskActions.toggleDone(task, modelContext: context))
        XCTAssertNil(TaskActions.toggleDone(task, modelContext: context), "Wieder offen erzeugt nichts")
        XCTAssertNil(TaskActions.toggleDone(task, modelContext: context), "Erneut abgehakt: keine zweite Folgeinstanz")

        XCTAssertEqual(task.recurrenceNextID, first.id)
        XCTAssertEqual(try context.fetch(FetchDescriptor<AnkerTask>()).count, 2)
    }

    @MainActor
    func testUnscheduledTaskWithRuleCreatesNothing() throws {
        let context = try makeContext()
        let task = try XCTUnwrap(TaskActions.createUnscheduled(title: "Irgendwann", goal: nil, modelContext: context))
        task.recurrence = .weekly

        XCTAssertNil(TaskActions.toggleDone(task, modelContext: context))
        XCTAssertNil(task.recurrenceNextID, "Die Regel wartet, bis die Aufgabe einen Tag hat")
        XCTAssertEqual(task.recurrence, .weekly)
        XCTAssertEqual(try context.fetch(FetchDescriptor<AnkerTask>()).count, 1)
    }

    // MARK: - Rückgängig

    @MainActor
    func testUndoOfCompletionRemovesTheNextInstance() throws {
        let context = try makeContext()
        let task = try makeRecurringTask(.weekly, on: day(2026, 11, 27), context: context)
        let weeks = try context.fetch(FetchDescriptor<Week>())

        let snapshot = TaskActions.snapshot(task)
        let next = try XCTUnwrap(TaskActions.toggleDone(task, modelContext: context))
        let nextID = next.id

        TaskActions.undo(TaskUndoNotice(message: "", snapshots: [snapshot]), weeks: weeks, modelContext: context)

        let remaining = try context.fetch(FetchDescriptor<AnkerTask>())
        XCTAssertEqual(remaining.map(\.id), [task.id])
        XCTAssertFalse(remaining.contains { $0.id == nextID })
        XCTAssertFalse(task.isDone)
        XCTAssertNil(task.recurrenceNextID, "Nach dem Undo darf erneutes Abhaken wieder eine Folgeinstanz erzeugen")
        XCTAssertEqual(task.recurrence, .weekly)

        XCTAssertNotNil(TaskActions.toggleDone(task, modelContext: context))
        XCTAssertEqual(try context.fetch(FetchDescriptor<AnkerTask>()).count, 2)
    }

    /// Die Sammelaktion „Erledigt" der Mehrfachauswahl: `setDone(save: false)` je Aufgabe, ein
    /// Schnappschuss pro Aufgabe — das Undo nimmt alle Folgeinstanzen zurück.
    @MainActor
    func testBulkCompletionIsUndoableIncludingNextInstances() throws {
        let context = try makeContext()
        let friday = day(2026, 11, 27)
        let a = try makeRecurringTask(.weekdays, on: friday, context: context, title: "A")
        let b = try makeRecurringTask(.weekly, on: friday, context: context, title: "B")
        let plain = try XCTUnwrap(TaskActions.create(
            title: "C", priority: .b, on: try XCTUnwrap(a.day), linkedGoal: nil, modelContext: context
        ))
        let weeks = try context.fetch(FetchDescriptor<Week>())

        let tasks = [a, b, plain]
        let snapshots = tasks.map(TaskActions.snapshot)
        for task in tasks { TaskActions.setDone(task, true, save: false, modelContext: context) }
        context.saveChanges()

        XCTAssertEqual(try context.fetch(FetchDescriptor<AnkerTask>()).count, 5)
        let nextKey = AnkerCalendar.weekKey(containing: day(2026, 11, 30))
        let nextWeeks = try context.fetch(FetchDescriptor<Week>()).filter { $0.isoYear == nextKey.isoYear && $0.isoWeek == nextKey.isoWeek }
        XCTAssertEqual(nextWeeks.count, 1, "Zwei Folgeinstanzen in eine neue Woche legen sie nur einmal an")

        TaskActions.undo(TaskUndoNotice(message: "", snapshots: snapshots), weeks: weeks, modelContext: context)
        let remaining = try context.fetch(FetchDescriptor<AnkerTask>())
        XCTAssertEqual(Set(remaining.map(\.title)), ["A", "B", "C"])
        XCTAssertEqual(remaining.count, 3)
        XCTAssertTrue(remaining.allSatisfy { !$0.isDone && $0.recurrenceNextID == nil })
    }

    @MainActor
    func testUndoKeepsANextInstanceThatWasAlreadyCompleted() throws {
        let context = try makeContext()
        let task = try makeRecurringTask(.daily, on: day(2026, 11, 24), context: context)
        let weeks = try context.fetch(FetchDescriptor<Week>())
        let snapshot = TaskActions.snapshot(task)
        let next = try XCTUnwrap(TaskActions.toggleDone(task, modelContext: context))
        TaskActions.setDone(next, true, modelContext: context)

        TaskActions.undo(TaskUndoNotice(message: "", snapshots: [snapshot]), weeks: weeks, modelContext: context)

        XCTAssertFalse(next.isDeleted, "Mit der Folgeinstanz wurde gearbeitet — sie bleibt")
        XCTAssertEqual(task.recurrenceNextID, next.id, "Sonst entstünde beim nächsten Abhaken eine zweite")
    }

    @MainActor
    func testUndoOfRuleChangeRestoresTheRule() throws {
        let context = try makeContext()
        let task = try makeRecurringTask(.weekly, on: day(2026, 11, 24), context: context)
        let weeks = try context.fetch(FetchDescriptor<Week>())
        let snapshot = TaskActions.snapshot(task)

        XCTAssertTrue(TaskActions.setRecurrence(task, to: .monthly, modelContext: context))
        XCTAssertFalse(TaskActions.setRecurrence(task, to: .monthly, modelContext: context), "Unverändert schreibt nichts")
        TaskActions.undo(TaskUndoNotice(message: "", snapshots: [snapshot]), weeks: weeks, modelContext: context)
        XCTAssertEqual(task.recurrence, .weekly)
    }

    @MainActor
    func testUndoOfDeleteRestoresRuleAndChain() throws {
        let context = try makeContext()
        let task = try makeRecurringTask(.daily, on: day(2026, 11, 24), context: context)
        let next = try XCTUnwrap(TaskActions.toggleDone(task, modelContext: context))
        let weeks = try context.fetch(FetchDescriptor<Week>())
        let id = task.id
        let snapshot = TaskActions.snapshot(task)

        TaskActions.delete(task, modelContext: context)
        TaskActions.undo(TaskUndoNotice(message: "", snapshots: [snapshot]), weeks: weeks, modelContext: context)

        let restored = try XCTUnwrap(try context.fetch(FetchDescriptor<AnkerTask>()).first { $0.id == id })
        XCTAssertEqual(restored.recurrence, .daily)
        XCTAssertEqual(restored.recurrenceNextID, next.id)
        XCTAssertFalse(next.isDeleted)
    }

    // MARK: - Rückblick

    /// Wieder geöffnet, nachdem die Folgeinstanz schon entstanden ist: „Mitnehmen" würde sie
    /// verdoppeln. Die Aufgabe bleibt in ihrer Woche.
    @MainActor
    func testCarryOverDoesNotDuplicateAnExistingNextInstance() throws {
        let context = try makeContext()
        let friday = day(2026, 11, 27)
        let task = try makeRecurringTask(.weekly, on: friday, context: context)
        let week = try XCTUnwrap(task.day?.week)
        let next = try XCTUnwrap(TaskActions.toggleDone(task, modelContext: context))
        TaskActions.toggleDone(task, modelContext: context)
        XCTAssertFalse(task.isDone)

        let weeks = try context.fetch(FetchDescriptor<Week>())
        let report = WeekActions.close(week, at: day(2026, 11, 29), weeks: weeks, modelContext: context)

        XCTAssertEqual(report.supersededTasks, 1)
        XCTAssertEqual(report.carriedOverTasks, 0)
        XCTAssertTrue(AnkerCalendar.storedDay(try XCTUnwrap(task.day).date, isOn: friday), "Bleibt in ihrer Woche")
        let nextFriday = day(2026, 12, 4)
        let onNextFriday = try context.fetch(FetchDescriptor<AnkerTask>()).filter {
            $0.day.map { AnkerCalendar.storedDay($0.date, isOn: nextFriday) } ?? false
        }
        XCTAssertEqual(onNextFriday.map(\.id), [next.id], "Genau eine Instanz am nächsten Freitag")
    }

    /// Eine offene tägliche Aufgabe vom Sonntag wird auf den Montag mitgenommen, nicht auf den
    /// nächsten Sonntag — und ohne Folgeinstanz gibt es nichts zu verdoppeln.
    @MainActor
    func testCarryOverMovesRecurringTaskToItsFirstOccurrenceNextWeek() throws {
        let context = try makeContext()
        let sunday = day(2026, 11, 29)
        let daily = try makeRecurringTask(.daily, on: sunday, context: context, title: "Täglich")
        let week = try XCTUnwrap(daily.day?.week)
        let biweekly = try XCTUnwrap(TaskActions.create(
            title: "Zweiwöchentlich", priority: .b, on: try XCTUnwrap(daily.day), linkedGoal: nil, modelContext: context
        ))
        biweekly.recurrence = .biweekly

        let weeks = try context.fetch(FetchDescriptor<Week>())
        let report = WeekActions.close(week, at: sunday, weeks: weeks, modelContext: context)

        XCTAssertEqual(report.carriedOverTasks, 2)
        XCTAssertTrue(AnkerCalendar.storedDay(try XCTUnwrap(daily.day).date, isOn: day(2026, 11, 30)))
        XCTAssertTrue(AnkerCalendar.storedDay(try XCTUnwrap(biweekly.day).date, isOn: day(2026, 12, 6)),
                      "Alle 2 Wochen trifft die Folgewoche nicht — derselbe Wochentag")
        XCTAssertEqual(try context.fetch(FetchDescriptor<AnkerTask>()).count, 2)
    }

    // MARK: - Hilfen

    private func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        AnkerCalendar.iso.startOfDay(for: AnkerCalendar.date(year: year, month: month, day: day))
    }

    private func isSameDay(_ lhs: Date, _ rhs: Date) -> Bool {
        AnkerCalendar.isSameDay(lhs, rhs)
    }

    @MainActor
    private func makeRecurringTask(_ rule: TaskRecurrence, on date: Date, context: ModelContext, title: String = "Wiederkehrend") throws -> AnkerTask {
        let week = TaskActions.ensureWeek(containing: date, weeks: [], modelContext: context)
        let day = TaskActions.ensureDay(containing: date, in: week)
        let task = try XCTUnwrap(TaskActions.create(title: title, priority: .b, on: day, linkedGoal: nil, modelContext: context))
        task.recurrence = rule
        return task
    }

    @MainActor
    private func addGoal(_ title: String, to week: Week, context: ModelContext) -> Goal {
        let goal = Goal(title: title, colorHex: "#000000", order: week.goalList.count, week: week)
        context.insert(goal)
        week.appendGoal(goal)
        return goal
    }

    @MainActor
    private func makeContext() throws -> ModelContext {
        let schema = Schema(AnkerSchema.models)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        containers.append(container)
        return container.mainContext
    }

    /// Der Container muss den Test überleben, sonst ist der Kontext tot.
    private var containers: [ModelContainer] = []
}
