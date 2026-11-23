import SwiftData
import XCTest
@testable import Anchorit

/// Befunde aus dem Release-Review an Erfassung, Ablegen und Icons.
final class ComponentReleaseTests: XCTestCase {

    // MARK: - Erfassungssyntax: Wochentage nur am Ende

    func testWeekdayWordInsideASentenceStaysInTheTitle() {
        for raw in ["Mach das so gut wie möglich", "Mo und Lea anrufen", "Das ist so", "fr Brief schreiben"] {
            let input = CaptureSyntax.parse(raw)
            if raw == "Das ist so" {
                // Als letztes Wort bleibt „so" der Sonntag — die Hinweiszeile zeigt es vorher.
                XCTAssertEqual(input.weekdayIndex, 7, raw)
                XCTAssertEqual(input.title, "Das ist", raw)
            } else {
                XCTAssertNil(input.weekdayIndex, raw)
                XCTAssertEqual(input.title, raw, raw)
            }
        }
    }

    func testWeekdayBeforeTrailingTokensCounts() {
        let input = CaptureSyntax.parse("Bericht mi #2 !a")
        XCTAssertEqual(input.weekdayIndex, 3)
        XCTAssertEqual(input.anchorNumber, 2)
        XCTAssertEqual(input.priority, .a)
        XCTAssertEqual(input.title, "Bericht")
    }

    func testOnlyTheTrailingWeekdayCountsWhenAnEarlierOneIsAWord() {
        let input = CaptureSyntax.parse("Mach es so gut fr")
        XCTAssertEqual(input.weekdayIndex, 5)
        XCTAssertEqual(input.title, "Mach es so gut")
    }

    func testAnchorTokenCountsAnywhere() {
        let input = CaptureSyntax.parse("#3 so gut wie möglich")
        XCTAssertEqual(input.anchorNumber, 3)
        XCTAssertNil(input.weekdayIndex)
        XCTAssertEqual(input.title, "so gut wie möglich")
    }

    func testHelpNamesTheRealAnchorSyntax() {
        XCTAssertTrue(CaptureSyntax.syntaxHelp.contains("#1–#4"), CaptureSyntax.syntaxHelp)
        XCTAssertFalse(CaptureSyntax.syntaxHelp.contains("Prio"), CaptureSyntax.syntaxHelp)
    }

    func testHintMentionsPriorityOnlyWhenTyped() {
        let monday = AnkerCalendar.date(year: 2026, month: 8, day: 3)
        let typed = CaptureSyntax.parse("Bericht !a")
        let hint = CaptureSyntax.hint(raw: "Bericht !a", target: CaptureSyntax.resolve(typed, weekStart: monday, fallbackDate: monday), anchorCount: 4)
        XCTAssertTrue(hint.contains("wichtig"), hint)
    }

    // MARK: - Ablegen mit Rückgängig

    @MainActor
    func testDropOnACellOffersUndoAndUndoRestoresTheUnscheduledTask() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let week = TaskActions.ensureWeek(containing: Date(), weeks: [], modelContext: context)
        let goal = Goal(title: "Anker", colorHex: "#000000", order: 0, week: week)
        context.insert(goal)
        week.appendGoal(goal)
        let task = try XCTUnwrap(TaskActions.createUnscheduled(title: "Ohne Tag", goal: nil, modelContext: context))

        var notice: TaskUndoNotice?
        let placed = BlattDrop.place([task.id.uuidString], on: week.monday, goal: goal, weeks: [week],
                                     modelContext: context) { notice = $0 }

        XCTAssertTrue(placed)
        XCTAssertNotNil(task.day)
        XCTAssertEqual(task.linkedGoal?.id, goal.id)
        let undo = try XCTUnwrap(notice, "Ein Drop muss einen Rückgängig-Hinweis anbieten")

        TaskActions.undo(undo, weeks: [week], modelContext: context)
        XCTAssertNil(task.day)
        XCTAssertNil(task.linkedGoal)
    }

    @MainActor
    func testDropThatChangesNothingOffersNoUndo() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let task = try XCTUnwrap(TaskActions.createUnscheduled(title: "Eingang", goal: nil, modelContext: context))

        var notice: TaskUndoNotice?
        BlattDrop.place([task.id.uuidString], on: nil, goal: nil, weeks: [], modelContext: context) { notice = $0 }
        XCTAssertNil(notice)
    }

    @MainActor
    func testDropHandlingFindsTasksWithoutADay() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let task = try XCTUnwrap(TaskActions.createUnscheduled(title: "Eingang", goal: nil, modelContext: context))

        let snapshot = TaskDropHandling.moveTask(id: task.id, to: Date(), weeks: [], modelContext: context)
        XCTAssertNotNil(snapshot, "Eine Aufgabe ohne Tag muss sich auf einen Tag ziehen lassen")
        XCTAssertNotNil(task.day)
    }

    // MARK: - Hilfen

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(AnkerSchema.models)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
