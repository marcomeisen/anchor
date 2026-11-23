import SwiftData
import XCTest
@testable import Anchorit

/// Die Mehrfachauswahl: Zustand und die gesammelten Aktionen samt Rückgängig.
final class SelectionTests: XCTestCase {
    @MainActor
    func testLongPressStartsSelectionWithThatTaskAndFinishClearsIt() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let week = TaskActions.ensureWeek(containing: Date(), weeks: [], modelContext: context)
        let day = TaskActions.ensureDay(containing: Date(), in: week)
        let a = try XCTUnwrap(TaskActions.create(title: "A", priority: .b, on: day, linkedGoal: nil, modelContext: context))
        let b = try XCTUnwrap(TaskActions.create(title: "B", priority: .b, on: day, linkedGoal: nil, modelContext: context))

        let selection = TaskSelectionModel()
        XCTAssertFalse(selection.isActive)
        selection.start(with: a)
        XCTAssertTrue(selection.isActive)
        XCTAssertEqual(selection.selected(from: [a, b]).map(\.title), ["A"])

        selection.toggle(b)
        selection.toggle(a)
        XCTAssertEqual(selection.selected(from: [a, b]).map(\.title), ["B"])

        selection.selectAll([a, b])
        XCTAssertEqual(selection.selected(from: [a, b]).count, 2)

        selection.finish()
        XCTAssertFalse(selection.isActive)
        XCTAssertTrue(selection.selected(from: [a, b]).isEmpty)
    }

    /// Mehrere Aufgaben auf einmal löschen und alle zurückholen — auch eine ohne Tag.
    @MainActor
    func testBulkDeleteOfMixedTasksIsUndoable() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let week = TaskActions.ensureWeek(containing: Date(), weeks: [], modelContext: context)
        let goal = Goal(title: "Anker", colorHex: "#000000", order: 0, week: week)
        context.insert(goal)
        week.appendGoal(goal)
        let day = TaskActions.ensureDay(containing: Date(), in: week)
        let planned = try XCTUnwrap(TaskActions.create(title: "Geplant", priority: .b, on: day, linkedGoal: goal, modelContext: context))
        let loose = try XCTUnwrap(TaskActions.createUnscheduled(title: "Ohne Tag", goal: goal, modelContext: context))

        let snapshots = [planned, loose].map(TaskActions.snapshot)
        for task in [planned, loose] { TaskActions.delete(task, modelContext: context) }
        XCTAssertTrue(try context.fetch(FetchDescriptor<AnkerTask>()).isEmpty)

        TaskActions.undo(TaskUndoNotice(message: "", snapshots: snapshots), weeks: [week], modelContext: context)
        let restored = try context.fetch(FetchDescriptor<AnkerTask>())
        XCTAssertEqual(Set(restored.map(\.title)), ["Geplant", "Ohne Tag"])
        XCTAssertEqual(restored.first { $0.title == "Geplant" }?.day?.id, day.id)
        XCTAssertNil(restored.first { $0.title == "Ohne Tag" }?.day)
        XCTAssertTrue(restored.allSatisfy { $0.linkedGoal?.id == goal.id })
    }

    /// Ziehen auf eine Woche in der Seitenleiste: derselbe Wochentag, Rückgängig stellt her.
    @MainActor
    func testMovingToAnotherWeekKeepsTheWeekdayAndIsUndoable() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let friday = AnkerCalendar.date(year: 2026, month: 11, day: 27)
        let week = TaskActions.ensureWeek(containing: friday, weeks: [], modelContext: context)
        let goal = Goal(title: "Launch", colorHex: "#000000", order: 0, week: week)
        context.insert(goal)
        week.appendGoal(goal)
        let day = TaskActions.ensureDay(containing: friday, in: week)
        let task = try XCTUnwrap(TaskActions.create(title: "Beta", priority: .b, on: day, linkedGoal: goal, modelContext: context))
        let snapshot = TaskActions.snapshot(task)

        let nextMonday = AnkerCalendar.date(year: 2026, month: 11, day: 30)
        TaskActions.move(task, toWeekStarting: nextMonday, weeks: [week], modelContext: context)
        let moved = try XCTUnwrap(task.day)
        XCTAssertTrue(AnkerCalendar.storedDay(moved.date, isOn: AnkerCalendar.date(year: 2026, month: 12, day: 4)),
                      "Freitag bleibt Freitag")
        XCTAssertNil(task.linkedGoal, "Ein Anker gehört zu genau einer Woche")
        XCTAssertEqual(task.carryOverCount, 1)

        let weeks = try context.fetch(FetchDescriptor<Week>())
        TaskActions.undo(TaskUndoNotice(message: "", snapshots: [snapshot]), weeks: weeks, modelContext: context)
        XCTAssertEqual(task.day?.id, day.id)
        XCTAssertEqual(task.linkedGoal?.id, goal.id)
    }

    /// Eine Aufgabe ohne Tag landet in der Zielwoche am Montag.
    @MainActor
    func testMovingAnUnscheduledTaskLandsOnMonday() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let task = try XCTUnwrap(TaskActions.createUnscheduled(title: "Eingang", goal: nil, modelContext: context))
        let target = TaskActions.move(task, toWeekStarting: AnkerCalendar.date(year: 2026, month: 12, day: 2), weeks: [], modelContext: context)
        XCTAssertTrue(AnkerCalendar.isSameDay(target, AnkerCalendar.date(year: 2026, month: 11, day: 30)))
        XCTAssertNotNil(task.day)
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(AnkerSchema.models)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
