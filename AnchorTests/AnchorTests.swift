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
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(AnkerSchema.models)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
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
