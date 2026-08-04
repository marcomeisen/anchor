import SwiftData
import XCTest
@testable import Daivento

/// Die Zellenzuordnung der Matrix. Eigener Typ genau deshalb: welche Aufgabe in welche Zelle
/// gehoert, ist die Aussage der Ansicht und muss ohne View pruefbar sein.
final class AnkerMatrixTests: XCTestCase {

    // MARK: - Invariante

    @MainActor
    func testEveryTaskOfTheWeekAppearsInExactlyOneCell() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let week = SampleData.insertReferenceWeek(in: context)
        try context.save()

        let allTasks = Set(week.dayList.flatMap(\.taskList).map(\.id))
        XCTAssertFalse(allTasks.isEmpty)

        var seen: [UUID] = []
        for row in AnkerMatrix.rows(for: week) {
            for day in AnkerMatrix.orderedDays(in: week) {
                seen.append(contentsOf: AnkerMatrix.tasks(in: row, on: day).map(\.id))
            }
        }

        // Die wichtigste Eigenschaft der Matrix: nichts faellt heraus und nichts doppelt.
        XCTAssertEqual(Set(seen), allTasks, "Die Zellen decken nicht genau die Woche ab")
        XCTAssertEqual(seen.count, allTasks.count, "Eine Aufgabe erscheint mehrfach")
    }

    @MainActor
    func testTasksBeyondTheFourthAnchorStillHaveARow() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let week = SampleData.insertReferenceWeek(in: context)

        // Fuenftes Ziel: entsteht real, weil die Vier-Anker-Grenze pro Geraet geprueft wird und
        // zwei Geraete offline je eines anlegen koennen.
        let fifth = Goal(title: "Fünftes Ziel", colorHex: "#DD2B0F", week: week)
        context.insert(fifth)
        week.appendGoal(fifth)
        let day = try XCTUnwrap(week.dayList.first)
        let stray = try XCTUnwrap(TaskActions.create(
            title: "Aufgabe am fünften Anker", priority: .b, on: day,
            linkedGoal: fifth, modelContext: context
        ))
        try context.save()

        let rows = AnkerMatrix.rows(for: week)
        XCTAssertEqual(rows.filter(\.isExcess).count, 1, "Der fünfte Anker braucht eine eigene Zeile")

        // Ohne diese Zeile waere die Aufgabe unsichtbar — genau der Fehler, den `prefix(4)` macht.
        let visible = rows.flatMap { row in
            AnkerMatrix.orderedDays(in: week).flatMap { AnkerMatrix.tasks(in: row, on: $0) }
        }
        XCTAssertTrue(visible.contains { $0.id == stray.id })
    }

    @MainActor
    func testInboxRowHoldsOnlyUnanchoredTasks() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let week = SampleData.insertReferenceWeek(in: context)
        try context.save()

        let inbox = try XCTUnwrap(AnkerMatrix.rows(for: week).first(where: \.isInbox))
        XCTAssertNil(inbox.goalID)

        let inboxTasks = AnkerMatrix.orderedDays(in: week).flatMap { AnkerMatrix.tasks(in: inbox, on: $0) }
        XCTAssertFalse(inboxTasks.isEmpty, "Die Beispielwoche hat Aufgaben ohne Ziel")
        XCTAssertTrue(inboxTasks.allSatisfy { $0.linkedGoal == nil })
    }

    @MainActor
    func testAnchorOrderIsStableAcrossRelationshipShuffles() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let week = SampleData.insertReferenceWeek(in: context)
        try context.save()

        let before = AnkerMatrix.orderedGoals(in: week).map(\.id)

        // CloudKit spiegelt To-many-Beziehungen ungeordnet — nach einem Import steht die
        // Reihenfolge anders. Die Ankernummern duerfen dadurch nicht wandern.
        week.goals = week.goalList.reversed()
        XCTAssertEqual(AnkerMatrix.orderedGoals(in: week).map(\.id), before)

        week.goals = week.goalList.shuffled()
        XCTAssertEqual(AnkerMatrix.orderedGoals(in: week).map(\.id), before)
    }

    // MARK: - Zweidimensionaler Drop

    @MainActor
    func testPlaceSetsDayAndAnchorInOneStep() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let week = SampleData.insertReferenceWeek(in: context)
        try context.save()

        let goal = try XCTUnwrap(week.goalList.first)
        let task = try XCTUnwrap(week.dayList.flatMap(\.taskList).first { $0.linkedGoal == nil })
        let targetDay = try XCTUnwrap(week.dayList.sorted { $0.date < $1.date }.last)

        TaskActions.place(task, on: targetDay.date, goalID: goal.id, weeks: [week], modelContext: context)

        XCTAssertEqual(task.day?.id, targetDay.id)
        XCTAssertEqual(task.linkedGoal?.id, goal.id)
    }

    @MainActor
    func testPlaceKeepsTheAnchorWhenCrossingAWeekBoundary() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let week = SampleData.insertReferenceWeek(in: context)
        try context.save()

        let task = try XCTUnwrap(week.dayList.flatMap(\.taskList).first)
        let nextWeekDate = try XCTUnwrap(
            AnkerCalendar.iso.date(byAdding: .weekOfYear, value: 1, to: week.monday)
        )
        let nextWeek = TaskActions.ensureWeek(containing: nextWeekDate, weeks: [week], modelContext: context)
        let targetGoal = Goal(title: "Ziel der Folgewoche", colorHex: "#DD2B0F", week: nextWeek)
        context.insert(targetGoal)
        nextWeek.appendGoal(targetGoal)
        try context.save()

        TaskActions.place(task, on: nextWeekDate, goalID: targetGoal.id,
                          weeks: [week, nextWeek], modelContext: context)

        // `move` loest `linkedGoal` beim Wochenwechsel. Genau deshalb setzt `place` den Anker
        // **danach** — sonst gewaenne das Aufraeumen gegen die Absicht des Nutzers.
        XCTAssertEqual(task.linkedGoal?.id, targetGoal.id, "Der Anker aus dem Drop muss gewinnen")
        XCTAssertEqual(task.day?.week?.id, nextWeek.id)
    }

    @MainActor
    func testPlaceWithoutGoalMovesToTheInbox() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let week = SampleData.insertReferenceWeek(in: context)
        try context.save()

        let task = try XCTUnwrap(week.dayList.flatMap(\.taskList).first { $0.linkedGoal != nil })
        let day = try XCTUnwrap(task.day)

        TaskActions.place(task, on: day.date, goalID: nil, weeks: [week], modelContext: context)

        XCTAssertNil(task.linkedGoal)
        XCTAssertEqual(task.day?.id, day.id, "Ein Drop in dieselbe Spalte darf den Tag nicht ändern")
    }

    // MARK: - Texte und Maße

    func testMetaLineTexts() {
        XCTAssertEqual(AnkerMatrix.metaLine(kind: .anchor(number: 1), doneCount: 3, totalCount: 5),
                       "3 von 5 erledigt")
        XCTAssertEqual(AnkerMatrix.metaLine(kind: .anchor(number: 2), doneCount: 0, totalCount: 0),
                       "noch keine Aufgabe — hierher ziehen")
        XCTAssertEqual(AnkerMatrix.metaLine(kind: .inbox, doneCount: 0, totalCount: 2),
                       "2 ohne Bezug")
        XCTAssertEqual(AnkerMatrix.metaLine(kind: .inbox, doneCount: 0, totalCount: 0),
                       "Eingangskorb leer")
        XCTAssertEqual(AnkerMatrix.metaLine(kind: .excess(number: 5), doneCount: 0, totalCount: 1),
                       "überzähliger Anker · 1 Aufgaben")
    }

    func testDayColumnsShareTheWidthAndFallBackToScrolling() {
        let wide = AnkerMatrixMetrics.dayColumnWidth(containerWidth: 1200)
        XCTAssertFalse(wide.needsHorizontalScroll)
        XCTAssertEqual(wide.width, (1200 - AnkerMatrixMetrics.anchorColumnWidth) / 7, accuracy: 0.01)

        // Im schmalen iPad-Split wird eine Spalte sonst unlesbar.
        let narrow = AnkerMatrixMetrics.dayColumnWidth(containerWidth: 640)
        XCTAssertTrue(narrow.needsHorizontalScroll)
        XCTAssertEqual(narrow.width, AnkerMatrixMetrics.minDayColumnWidth)
    }

    @MainActor
    func testInMotionCountsAnchorsWithAtLeastOneDoneTask() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let week = SampleData.insertReferenceWeek(in: context)
        try context.save()

        let expected = AnkerMatrix.orderedGoals(in: week).prefix(4).filter { goal in
            week.dayList.flatMap(\.taskList).contains { $0.linkedGoal?.id == goal.id && $0.isDone }
        }.count

        XCTAssertEqual(AnkerMatrix.inMotionCount(in: week), expected)
    }

    // MARK: - Hilfen

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(AnkerSchema.models)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
