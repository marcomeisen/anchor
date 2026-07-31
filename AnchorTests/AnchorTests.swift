import SwiftData
import XCTest
@testable import Anchor

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
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(AnkerSchema.models)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
