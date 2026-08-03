import SwiftData
import XCTest
@testable import Daivento

final class AnchorTests: XCTestCase {
    @MainActor
    func testGoalProgressCountsDoneLinkedTasks() throws {
        let container = try makeContainer()
        let week = SampleData.insertReferenceWeek(in: container.mainContext)
        let goal = try XCTUnwrap(week.goalList.first { $0.title == "Jahresplanung 2026" })

        XCTAssertEqual(goal.taskList.count, 5)
        XCTAssertEqual(goal.taskList.filter(\.isDone).count, 2)
        XCTAssertEqual(goal.progress, 0.4, accuracy: 0.001)

        goal.taskList.first { !$0.isDone }?.isDone = true
        XCTAssertEqual(goal.progress, 0.6, accuracy: 0.001)
    }

    func testISOWeekAcrossYearBoundary() {
        let date = AnkerCalendar.date(year: 2026, month: 1, day: 1)
        let interval = AnkerCalendar.weekInterval(containing: date)

        XCTAssertEqual(interval.isoYear, 2026)
        XCTAssertEqual(interval.isoWeek, 1)

        let monday = interval.monday.formatted(.dateTime.locale(Locale(identifier: "de_DE")).day(.twoDigits).month(.twoDigits).year())
        let sunday = interval.sunday.formatted(.dateTime.locale(Locale(identifier: "de_DE")).day(.twoDigits).month(.twoDigits).year())
        XCTAssertEqual(monday, "29.12.2025")
        XCTAssertEqual(sunday, "04.01.2026")
    }

    @MainActor
    func testTaskActionsToggleMoveAndDeleteTask() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let week = SampleData.insertReferenceWeek(in: context)
        try context.save()

        let task = try XCTUnwrap(week.dayList.flatMap(\.taskList).first { $0.isDone && $0.linkedGoal != nil })
        let sourceDay = try XCTUnwrap(task.day)

        XCTAssertTrue(task.isDone)

        TaskActions.toggleDone(task, modelContext: context)
        XCTAssertFalse(task.isDone)

        TaskActions.move(task, byDays: 7, weeks: [week], modelContext: context)

        let targetDay = try XCTUnwrap(task.day)
        let targetWeek = try XCTUnwrap(targetDay.week)
        XCTAssertEqual(targetWeek.isoWeek, 2)
        XCTAssertFalse(sourceDay.taskList.contains { $0.id == task.id })
        XCTAssertTrue(targetDay.taskList.contains { $0.id == task.id })
        XCTAssertNil(task.linkedGoal)

        TaskActions.delete(task, modelContext: context)

        let remainingTasks = try context.fetch(FetchDescriptor<AnkerTask>())
        XCTAssertFalse(remainingTasks.contains { $0.id == task.id })
        XCTAssertFalse(targetDay.taskList.contains { $0.id == task.id })
    }

    @MainActor
    func testEnsureWeekReusesPersistedWeekWhenQueryListIsStale() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let existingWeek = makeWeek(in: context)
        try context.save()

        let ensuredWeek = TaskActions.ensureWeek(
            containing: existingWeek.monday,
            weeks: [],
            modelContext: context
        )

        let storedWeeks = try context.fetch(FetchDescriptor<Week>())
        XCTAssertEqual(ensuredWeek.id, existingWeek.id)
        XCTAssertEqual(storedWeeks.count, 1)
    }

    @MainActor
    func testCompletingTaskMovesItToEndOfDayOrder() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let week = makeWeek(in: context)
        let day = try XCTUnwrap(week.dayList.first)

        let first = AnkerTask(title: "Erste Aufgabe", priority: .a, order: 0, day: day)
        let second = AnkerTask(title: "Zweite Aufgabe", priority: .a, order: 1, day: day)
        let third = AnkerTask(title: "Dritte Aufgabe", priority: .a, order: 2, day: day)
        context.insert(first)
        context.insert(second)
        context.insert(third)
        day.tasks = [first, second, third]

        TaskActions.toggleDone(first, modelContext: context)

        let orderedTitles = day.taskList.sorted { $0.order < $1.order }.map(\.title)
        XCTAssertEqual(orderedTitles, ["Zweite Aufgabe", "Dritte Aufgabe", "Erste Aufgabe"])
        XCTAssertTrue(first.isDone)
    }

    @MainActor
    func testTaskUndoRestoresDeletedTaskAtOriginalPosition() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let week = makeWeek(in: context)
        let day = try XCTUnwrap(week.dayList.first)

        let first = AnkerTask(title: "Erste Aufgabe", priority: .a, order: 0, day: day)
        let second = AnkerTask(title: "Zweite Aufgabe", priority: .b, order: 1, day: day)
        let third = AnkerTask(title: "Dritte Aufgabe", priority: .c, order: 2, day: day)
        context.insert(first)
        context.insert(second)
        context.insert(third)
        day.tasks = [first, second, third]

        let snapshot = TaskActions.snapshot(second)
        TaskActions.delete(second, modelContext: context)

        TaskActions.restore([snapshot], weeks: [week], modelContext: context)

        let restoredTitles = day.taskList.sorted { $0.order < $1.order }.map(\.title)
        XCTAssertEqual(restoredTitles, ["Erste Aufgabe", "Zweite Aufgabe", "Dritte Aufgabe"])
    }

    @MainActor
    func testDuplicateUndoDeletesCreatedCopy() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let week = makeWeek(in: context)
        let day = try XCTUnwrap(week.dayList.first)

        let original = AnkerTask(title: "Original", priority: .b, order: 0, day: day)
        context.insert(original)
        day.tasks = [original]

        let copy = try XCTUnwrap(TaskActions.duplicate(original, modelContext: context))
        let notice = TaskUndoNotice(
            message: "Aufgabe dupliziert",
            snapshots: [TaskActions.snapshot(copy)],
            operation: .deleteCreated
        )

        TaskActions.undo(notice, weeks: [week], modelContext: context)

        let remainingTasks = try context.fetch(FetchDescriptor<AnkerTask>())
        XCTAssertTrue(remainingTasks.contains { $0.id == original.id })
        XCTAssertFalse(remainingTasks.contains { $0.id == copy.id })
    }

    @MainActor
    func testDuplicateSignatureIsEmptyForCleanStore() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let week = makeWeek(in: context)
        try context.save()

        XCTAssertTrue(StoreMaintenance.duplicateSignature(for: [week]).isEmpty)
        XCTAssertEqual(StoreMaintenance.normalize(weeks: [week], modelContext: context), 0)
    }

    @MainActor
    func testNormalizeMergesWeeksDuplicatedByCloudSync() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let interval = AnkerCalendar.weekInterval(containing: AnkerCalendar.date(year: 2026, month: 8, day: 3))

        let fromDeviceA = insertFullWeek(interval: interval, in: context)
        let fromDeviceB = insertFullWeek(interval: interval, in: context)

        let mondayA = try XCTUnwrap(fromDeviceA.dayList.min { $0.date < $1.date })
        let mondayB = try XCTUnwrap(fromDeviceB.dayList.min { $0.date < $1.date })

        let taskA = AnkerTask(title: "Aufgabe A", priority: .a, order: 0, day: mondayA)
        let taskB = AnkerTask(title: "Aufgabe B", priority: .b, order: 0, day: mondayB)
        context.insert(taskA)
        context.insert(taskB)
        mondayA.tasks = [taskA]
        mondayB.tasks = [taskB]
        mondayA.notes = "Notiz vom Mac"
        mondayB.notes = "Notiz vom iPhone"
        try context.save()

        let weeks = try context.fetch(FetchDescriptor<Week>())
        XCTAssertEqual(weeks.count, 2)
        XCTAssertFalse(StoreMaintenance.duplicateSignature(for: weeks).isEmpty)

        // Eine doppelte Woche plus die sieben doppelten Tage darin.
        XCTAssertEqual(StoreMaintenance.normalize(weeks: weeks, modelContext: context), 8)

        let remainingWeeks = try context.fetch(FetchDescriptor<Week>())
        XCTAssertEqual(remainingWeeks.count, 1)

        let survivor = try XCTUnwrap(remainingWeeks.first)
        XCTAssertEqual(survivor.dayList.count, 7)
        XCTAssertTrue(StoreMaintenance.duplicateSignature(for: remainingWeeks).isEmpty)

        // Keine Aufgabe darf beim Aufraeumen verloren gehen.
        let remainingTasks = try context.fetch(FetchDescriptor<AnkerTask>())
        XCTAssertEqual(Set(remainingTasks.map(\.title)), ["Aufgabe A", "Aufgabe B"])

        let mergedMonday = try XCTUnwrap(survivor.dayList.min { $0.date < $1.date })
        XCTAssertEqual(mergedMonday.taskList.count, 2)
        XCTAssertEqual(mergedMonday.taskList.sorted { $0.order < $1.order }.map(\.order), [0, 1])

        let mergedNotes = try XCTUnwrap(mergedMonday.notes)
        XCTAssertTrue(mergedNotes.contains("Notiz vom Mac"))
        XCTAssertTrue(mergedNotes.contains("Notiz vom iPhone"))
    }

    @MainActor
    func testNormalizeKeepsSameWeekRegardlessOfOrder() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let interval = AnkerCalendar.weekInterval(containing: AnkerCalendar.date(year: 2026, month: 8, day: 3))

        let first = insertFullWeek(interval: interval, in: context)
        let second = insertFullWeek(interval: interval, in: context)
        try context.save()

        // Beide Geraete raeumen unabhaengig voneinander auf und sehen die Wochen in
        // beliebiger Reihenfolge. Der Gewinner muss trotzdem derselbe sein, sonst
        // loeschen sich die Geraete gegenseitig die jeweils behaltene Woche.
        let expectedID = min(first.id.uuidString, second.id.uuidString)

        StoreMaintenance.normalize(weeks: [second, first], modelContext: context)

        let remaining = try context.fetch(FetchDescriptor<Week>())
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(try XCTUnwrap(remaining.first).id.uuidString, expectedID)
    }

    @MainActor
    func testNormalizeMergesDuplicateDaysWithinOneWeek() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let week = insertFullWeek(
            interval: AnkerCalendar.weekInterval(containing: AnkerCalendar.date(year: 2026, month: 8, day: 3)),
            in: context
        )

        let monday = try XCTUnwrap(week.dayList.min { $0.date < $1.date })
        let duplicateMonday = Day(date: monday.date, week: week)
        context.insert(duplicateMonday)
        week.days = week.dayList + [duplicateMonday]

        let strayTask = AnkerTask(title: "Verirrte Aufgabe", priority: .c, order: 0, day: duplicateMonday)
        context.insert(strayTask)
        duplicateMonday.tasks = [strayTask]
        try context.save()

        XCTAssertEqual(week.dayList.count, 8)
        XCTAssertEqual(StoreMaintenance.normalize(weeks: [week], modelContext: context), 1)

        XCTAssertEqual(week.dayList.count, 7)
        let mergedMonday = try XCTUnwrap(week.dayList.min { $0.date < $1.date })
        XCTAssertEqual(mergedMonday.taskList.map(\.title), ["Verirrte Aufgabe"])
    }

    @MainActor
    private func insertFullWeek(
        interval: (monday: Date, sunday: Date, isoYear: Int, isoWeek: Int),
        in context: ModelContext
    ) -> Week {
        let week = Week(
            isoYear: interval.isoYear,
            isoWeek: interval.isoWeek,
            monday: interval.monday,
            sunday: interval.sunday
        )
        week.days = AnkerCalendar.daysInWeek(starting: interval.monday).map { date in
            Day(date: date, week: week)
        }
        context.insert(week)
        return week
    }

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(AnkerSchema.models)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    @MainActor
    private func makeWeek(in context: ModelContext) -> Week {
        let interval = AnkerCalendar.weekInterval(containing: AnkerCalendar.date(year: 2026, month: 8, day: 3))
        let week = Week(
            isoYear: interval.isoYear,
            isoWeek: interval.isoWeek,
            monday: interval.monday,
            sunday: interval.sunday
        )
        let day = Day(date: interval.monday, week: week)
        week.days = [day]
        context.insert(week)
        return week
    }
}
