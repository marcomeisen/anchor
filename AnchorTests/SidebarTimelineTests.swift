import SwiftData
import XCTest
@testable import Anchorit

/// Die vier gemeinsamen Festlegungen der zweiten Entwurfsrunde.
///
/// Alle vier sind Aussagen über Zustand, nicht über Aussehen — und damit prüfbar, ohne die
/// Oberfläche zu starten. Genau dafür liegen `SidebarTimeline` und `WeekActions` als reine
/// Typen ohne View-Bezug.
final class SidebarTimelineTests: XCTestCase {

    // MARK: - Die sieben Quadrate

    @MainActor
    func testDayMarksDistinguishNothingPlannedFromNothingDone() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let week = makeWeek(in: context)
        let days = week.dayList.sorted { $0.date < $1.date }

        // Montag: geplant und erledigt. Dienstag: geplant, offen. Mittwoch: nichts geplant.
        let monday = try XCTUnwrap(TaskActions.create(title: "Fertig", priority: .b, on: days[0],
                                                     linkedGoal: nil, modelContext: context))
        TaskActions.setDone(monday, true, modelContext: context)
        _ = TaskActions.create(title: "Offen", priority: .b, on: days[1],
                               linkedGoal: nil, modelContext: context)

        // „Heute" liegt bewusst am Sonntag: sonst überschriebe es einen der geprüften Tage.
        let now = AnkerCalendar.date(year: 2026, month: 8, day: 9, hour: 10)
        let row = SidebarTimeline.row(forWeekContaining: week.monday, in: [week], now: now)

        XCTAssertEqual(row.marks[0], .done)
        XCTAssertEqual(row.marks[1], .open)
        // Der Kern der Aussage: nichts geplant ist nicht dasselbe wie nichts geschafft.
        XCTAssertEqual(row.marks[2], .empty)
        XCTAssertEqual(row.marks[6], .today)
        XCTAssertEqual(row.openCount, 1)
    }

    @MainActor
    func testEveryRowHasSevenMarksEvenWithMissingDays() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let week = makeWeek(in: context)

        // Nach einem Sync kann eine Woche mit weniger als sieben Tagen ankommen.
        week.days = Array(week.dayList.prefix(3))

        let row = SidebarTimeline.row(forWeekContaining: week.monday, in: [week],
                                      now: AnkerCalendar.date(year: 2026, month: 8, day: 4))
        // Die Zeile ist ein Raster, keine Liste: eine kurze Woche darf nicht kürzer aussehen.
        XCTAssertEqual(row.marks.count, 7)
    }

    @MainActor
    func testRowForAWeekWithoutRecordIsStillAValidTarget() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let week = makeWeek(in: context)

        let nextMonday = try XCTUnwrap(AnkerCalendar.iso.date(byAdding: .weekOfYear, value: 1, to: week.monday))
        let row = SidebarTimeline.row(forWeekContaining: nextMonday, in: [week],
                                      now: AnkerCalendar.date(year: 2026, month: 8, day: 4))

        XCTAssertFalse(row.exists)
        XCTAssertEqual(row.marks, Array(repeating: .empty, count: 7))
        XCTAssertEqual(row.openCount, 0)
    }

    @MainActor
    func testWindowIsCenteredOnTheShownWeek() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let week = makeWeek(in: context)

        let rows = SidebarTimeline.rows(around: week.monday, in: [week],
                                        now: AnkerCalendar.date(year: 2026, month: 8, day: 4))
        XCTAssertEqual(rows.count, 5)
        XCTAssertEqual(rows.map(\.isoWeek), [30, 31, 32, 33, 34])
        XCTAssertEqual(rows.filter(\.exists).map(\.isoWeek), [32])
    }

    // MARK: - Der Rückblick ist scharf, nicht laut

    @MainActor
    func testReviewStaysQuietUntilSunday() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let week = makeWeek(in: context)
        let day = try XCTUnwrap(week.dayList.first)
        _ = TaskActions.create(title: "Offen", priority: .b, on: day, linkedGoal: nil, modelContext: context)

        // Dienstag: erreichbar, aber ohne Zähler. Der Zähler mitten in der Woche wäre eine
        // Mahnung für etwas, das noch gar nicht fällig ist.
        let tuesday = AnkerCalendar.date(year: 2026, month: 8, day: 4, hour: 9)
        XCTAssertEqual(WeekActions.readiness(of: week, now: tuesday), .quiet)
        XCTAssertEqual(WeekActions.readiness(of: week, now: tuesday).meta, "ab So")

        // Sonntag: scharf, und die Zahl steht dran.
        let sunday = AnkerCalendar.date(year: 2026, month: 8, day: 9, hour: 9)
        XCTAssertEqual(WeekActions.readiness(of: week, now: sunday), .armed(open: 1))
        XCTAssertEqual(WeekActions.readiness(of: week, now: sunday).meta, "1 offen")
        XCTAssertTrue(WeekActions.readiness(of: week, now: sunday).isArmed)
    }

    @MainActor
    func testAClosedWeekIsNeverArmedAgain() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let week = makeWeek(in: context)
        let closedAt = AnkerCalendar.date(year: 2026, month: 8, day: 5, hour: 18)
        week.reviewedAt = closedAt

        let sunday = AnkerCalendar.date(year: 2026, month: 8, day: 9, hour: 9)
        XCTAssertEqual(WeekActions.readiness(of: week, now: sunday), .closed(at: closedAt))
        XCTAssertFalse(WeekActions.readiness(of: week, now: sunday).isArmed)
    }

    // MARK: - Übertrag pro Aufgabe

    @MainActor
    func testCloseAppliesADecisionPerTask() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let week = makeWeek(in: context)
        let day = try XCTUnwrap(week.dayList.first)

        let keep = try XCTUnwrap(TaskActions.create(title: "Behalten", priority: .b, on: day,
                                                   linkedGoal: nil, modelContext: context))
        let drop = try XCTUnwrap(TaskActions.create(title: "Streichen", priority: .b, on: day,
                                                   linkedGoal: nil, modelContext: context))
        let untouched = try XCTUnwrap(TaskActions.create(title: "Nicht angefasst", priority: .b, on: day,
                                                        linkedGoal: nil, modelContext: context))
        let keepID = keep.id, dropID = drop.id, untouchedID = untouched.id
        try context.save()

        let report = WeekActions.close(
            week,
            at: AnkerCalendar.date(year: 2026, month: 8, day: 9, hour: 20),
            decisions: [keepID: .keep, dropID: .drop],
            weeks: [week],
            modelContext: context
        )

        XCTAssertEqual(report.droppedTasks, 1)
        // Zwei: die behaltene und die nicht angefasste. Wer nichts anfasst, überträgt.
        XCTAssertEqual(report.carriedOverTasks, 2)
        XCTAssertTrue(week.isReviewed)

        let remaining = week.dayList.flatMap(\.taskList).map(\.id)
        XCTAssertFalse(remaining.contains(keepID), "Die behaltene Aufgabe muss die Woche verlassen")
        XCTAssertFalse(remaining.contains(untouchedID))
        XCTAssertFalse(remaining.contains(dropID), "Die gestrichene Aufgabe ist gelöscht")

        let all = try context.fetch(FetchDescriptor<AnkerTask>()).map(\.id)
        XCTAssertFalse(all.contains(dropID), "Streichen heisst löschen, nicht verschieben")
        XCTAssertTrue(all.contains(keepID))
    }

    @MainActor
    func testCarriedTaskKeepsItsWeekdayAndCountsAsCarryOver() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let week = makeWeek(in: context)
        let friday = try XCTUnwrap(week.dayList.sorted { $0.date < $1.date }[4])
        let task = try XCTUnwrap(TaskActions.create(title: "Freitagssache", priority: .b, on: friday,
                                                   linkedGoal: nil, modelContext: context))

        WeekActions.close(week, decisions: [:], weeks: [week], modelContext: context)

        // Eine Aufgabe, die für den Freitag gedacht war, bleibt eine Freitagsaufgabe.
        let target = try XCTUnwrap(task.day?.date)
        XCTAssertEqual(AnkerCalendar.iso.component(.weekday, from: target),
                       AnkerCalendar.iso.component(.weekday, from: friday.date))
        XCTAssertEqual(task.carryOverCount, 1)
    }

    @MainActor
    func testReanchorLinksToAnAnchorOfTheTargetWeek() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let week = makeWeek(in: context)
        let day = try XCTUnwrap(week.dayList.first)
        let oldGoal = try XCTUnwrap(GoalActions.create(title: "Alt", colorHex: "#DD2B0F",
                                                      in: week, modelContext: context))
        let task = try XCTUnwrap(TaskActions.create(title: "Wandert", priority: .b, on: day,
                                                   linkedGoal: oldGoal, modelContext: context))

        // Die Folgewoche mit einem eigenen Anker — ein Anker gehört genau einer Woche.
        let nextMonday = try XCTUnwrap(AnkerCalendar.iso.date(byAdding: .weekOfYear, value: 1, to: week.monday))
        let nextWeek = TaskActions.ensureFullWeek(containing: nextMonday, weeks: [week], modelContext: context)
        let newGoal = try XCTUnwrap(GoalActions.create(title: "Neu", colorHex: "#2D2B2B",
                                                      in: nextWeek, modelContext: context))
        try context.save()

        let report = WeekActions.close(
            week,
            decisions: [task.id: .reanchor(goalID: newGoal.id)],
            weeks: [week, nextWeek],
            modelContext: context
        )

        XCTAssertEqual(report.reanchoredTasks, 1)
        XCTAssertEqual(report.carriedOverTasks, 1)
        XCTAssertEqual(task.linkedGoal?.id, newGoal.id)
    }

    @MainActor
    func testCloseWithoutCarryOverLeavesTasksWhereTheyAre() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let week = makeWeek(in: context)
        let day = try XCTUnwrap(week.dayList.first)
        let task = try XCTUnwrap(TaskActions.create(title: "Bleibt", priority: .b, on: day,
                                                   linkedGoal: nil, modelContext: context))

        // Bestandsverhalten: „Nur schließen" liess die Aufgaben stehen. Es darf nicht löschen.
        WeekActions.close(week, carryOverOpenTasks: false, weeks: [week], modelContext: context)

        XCTAssertEqual(task.day?.id, day.id)
        XCTAssertEqual(task.carryOverCount, 0)
        XCTAssertTrue(week.isReviewed)
    }

    // MARK: - Archiv als Ort

    // MARK: - Der Streifen zeigt den Überschuss

    // MARK: - Titel umbenennen

    @MainActor
    func testRenameTrimsAndIgnoresNoOps() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let week = makeWeek(in: context)
        let day = try XCTUnwrap(week.dayList.first)
        let task = try XCTUnwrap(TaskActions.create(title: "Alt", priority: .b, on: day,
                                                   linkedGoal: nil, modelContext: context))

        XCTAssertTrue(TaskActions.rename(task, to: "  Neu  ", modelContext: context))
        XCTAssertEqual(task.title, "Neu")

        // Derselbe Titel ist keine Änderung — sonst meldete jedes Verlassen des Feldes ein Undo.
        XCTAssertFalse(TaskActions.rename(task, to: "Neu", modelContext: context))
        XCTAssertFalse(TaskActions.rename(task, to: "  Neu  ", modelContext: context))
    }

    @MainActor
    func testEmptyTitleIsDiscardedInsteadOfDeleting() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let week = makeWeek(in: context)
        let day = try XCTUnwrap(week.dayList.first)
        let task = try XCTUnwrap(TaskActions.create(title: "Bleibt", priority: .b, on: day,
                                                   linkedGoal: nil, modelContext: context))

        // Text wegzuwischen darf keine Löschung sein.
        XCTAssertFalse(TaskActions.rename(task, to: "", modelContext: context))
        XCTAssertFalse(TaskActions.rename(task, to: "   \n ", modelContext: context))
        XCTAssertEqual(task.title, "Bleibt")
        XCTAssertEqual(try context.fetch(FetchDescriptor<AnkerTask>()).count, 1)
    }

    @MainActor
    func testUndoRestoresThePreviousTitle() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let week = makeWeek(in: context)
        let day = try XCTUnwrap(week.dayList.first)
        let task = try XCTUnwrap(TaskActions.create(title: "Vorher", priority: .b, on: day,
                                                   linkedGoal: nil, modelContext: context))

        // Genau die Kette der Zeile: Schnappschuss vor dem Umbenennen, Undo darüber.
        let snapshot = TaskActions.snapshot(task)
        XCTAssertTrue(TaskActions.rename(task, to: "Nachher", modelContext: context))
        TaskActions.restore([snapshot], weeks: [week], modelContext: context)

        XCTAssertEqual(task.title, "Vorher")
    }

    // MARK: - Deep Link

    func testArchiveHasADeepLinkAndStaysTopLevel() throws {
        var state = AnkerNavigationState(now: AnkerCalendar.date(year: 2026, month: 8, day: 4))
        XCTAssertTrue(state.apply(URL(string: "anchorit://archive")!))
        XCTAssertEqual(state.destination, .archive)
        XCTAssertTrue(AppDestination.archive.isTopLevel)
    }

    // MARK: - Hilfen

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(AnkerSchema.models)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    @MainActor
    private func makeWeek(in context: ModelContext) -> Week {
        TaskActions.ensureFullWeek(
            containing: AnkerCalendar.date(year: 2026, month: 8, day: 3),
            weeks: [],
            modelContext: context
        )
    }
}
