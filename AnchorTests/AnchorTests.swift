import SwiftData
import XCTest
@testable import Fyndara

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
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(AnkerSchema.models)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
