import SwiftData
import XCTest
@testable import Anchorit

/// Befunde aus dem Release-Review: Blatt-Partition, Rückblickzahl, Übertrag über Zeitzonen,
/// Archiv über den Jahreswechsel, Deep Links, Suche ohne Tag und Sync-Aufräumen.
final class ReleaseLogicTests: XCTestCase {

    // MARK: - WeekSheet

    @MainActor
    func testWeekSheetPartitionsEveryTaskExactlyOnce() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let monday = AnkerCalendar.date(year: 2026, month: 8, day: 3)
        let week = TaskActions.ensureWeek(containing: monday, weeks: [], modelContext: context)
        let day = TaskActions.ensureDay(containing: monday, in: week)
        let goals = (0..<5).map { index in
            let goal = Goal(title: "Anker \(index)", colorHex: "#000000", order: index, week: week)
            context.insert(goal)
            week.appendGoal(goal)
            return goal
        }
        var all: [AnkerTask] = []
        func task(_ title: String, day: Day?, goal: Goal?) {
            let task = AnkerTask(title: title, priority: .b, order: all.count, day: day, linkedGoal: goal)
            context.insert(task)
            day?.appendTask(task)
            all.append(task)
        }
        task("Anker mit Tag", day: day, goal: goals[0])
        task("Anker ohne Tag", day: nil, goal: goals[1])
        task("Lose mit Tag", day: day, goal: nil)
        task("Fünftes Ziel mit Tag", day: day, goal: goals[4])
        task("Fünftes Ziel ohne Tag", day: nil, goal: goals[4])
        task("Eingang", day: nil, goal: nil)
        try context.save()

        let inbox = TaskActions.inboxTasks(modelContext: context)
        let current = WeekSheet(monday: monday, weeks: [week], inbox: inbox, now: monday)
        let ids = current.lanes.flatMap(\.tasks).map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "Keine Aufgabe doppelt")
        XCTAssertEqual(Set(ids), Set(all.map(\.id)), "Jede Aufgabe steht auf dem Blatt")

        // In einer anderen Woche steht der Eingang nicht.
        let later = AnkerCalendar.date(year: 2026, month: 9, day: 14)
        let past = WeekSheet(monday: monday, weeks: [week], inbox: inbox, now: later)
        XCTAssertFalse(past.lanes.flatMap(\.tasks).contains { $0.title == "Eingang" })
        XCTAssertEqual(past.lanes.flatMap(\.tasks).count, all.count - 1)
    }

    @MainActor
    func testReadinessCountMatchesReviewOpenList() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let monday = AnkerCalendar.date(year: 2026, month: 8, day: 3)
        let week = TaskActions.ensureWeek(containing: monday, weeks: [], modelContext: context)
        let day = TaskActions.ensureDay(containing: monday, in: week)
        let goal = Goal(title: "Laufen", colorHex: "#000000", order: 0, week: week)
        context.insert(goal)
        week.appendGoal(goal)
        _ = TaskActions.create(title: "Am Tag", priority: .b, on: day, linkedGoal: goal, modelContext: context)
        _ = TaskActions.createUnscheduled(title: "Ohne Tag", goal: goal, modelContext: context)
        _ = TaskActions.create(title: "Lose", priority: .b, on: day, linkedGoal: nil, modelContext: context)
        let done = try XCTUnwrap(TaskActions.create(title: "Erledigt", priority: .b, on: day, linkedGoal: goal, modelContext: context))
        TaskActions.setDone(done, true, modelContext: context)
        _ = TaskActions.createUnscheduled(title: "Eingang", goal: nil, modelContext: context)

        let sunday = AnkerCalendar.date(year: 2026, month: 8, day: 9, hour: 18)
        let sheet = WeekSheet(monday: monday, weeks: [week], inbox: TaskActions.inboxTasks(modelContext: context), now: monday)
        let open = WeekActions.openTasks(in: sheet)
        XCTAssertEqual(Set(open.map(\.title)), ["Am Tag", "Ohne Tag", "Lose"], "Eingang gehört zu keiner Woche")
        XCTAssertEqual(WeekActions.readiness(of: week, now: sunday), .armed(open: open.count))
    }

    // MARK: - Übertrag über Zeitzonen

    /// Ein Freitag, angelegt in einer Zone acht Stunden östlich (Tokio gegenüber Berlin), ist
    /// hier Donnerstag 16 Uhr. Mitgenommen bleibt er ein Freitag.
    @MainActor
    func testCarryOverKeepsNominalWeekdayAcrossTimeZones() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let friday = AnkerCalendar.date(year: 2026, month: 8, day: 7)
        let week = TaskActions.ensureWeek(containing: friday, weeks: [], modelContext: context)
        let stored = AnkerCalendar.iso.startOfDay(for: friday).addingTimeInterval(-8 * 60 * 60)
        let day = Day(date: stored, week: week)
        context.insert(day)
        week.days = [day]
        let task = AnkerTask(title: "Freitagsaufgabe", priority: .b, order: 0, day: day)
        context.insert(task)
        day.appendTask(task)
        try context.save()

        WeekActions.close(week, decisions: [task.id: .keep], fallback: nil, weeks: [week], modelContext: context)

        let target = try XCTUnwrap(task.day)
        XCTAssertTrue(AnkerCalendar.storedDay(target.date, isOn: AnkerCalendar.date(year: 2026, month: 8, day: 14)),
                      "Freitag bleibt Freitag")
        XCTAssertEqual(task.carryOverCount, 1)

        // Um einen Tag: ebenfalls ab dem gemeinten Tag.
        let other = AnkerTask(title: "Tokio", priority: .b, order: 1, day: day)
        context.insert(other)
        day.appendTask(other)
        TaskActions.move(other, byDays: 1, weeks: [week], modelContext: context)
        XCTAssertTrue(AnkerCalendar.storedDay(try XCTUnwrap(other.day).date, isOn: AnkerCalendar.date(year: 2026, month: 8, day: 8)))
        XCTAssertEqual(other.carryOverCount, 0, "Innerhalb der Woche kein Übertrag")
    }

    @MainActor
    func testKeepingReattachesToSameNamedAnchorInNextWeek() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let monday = AnkerCalendar.date(year: 2026, month: 8, day: 3)
        let week = TaskActions.ensureWeek(containing: monday, weeks: [], modelContext: context)
        let next = TaskActions.ensureWeek(containing: AnkerCalendar.date(year: 2026, month: 8, day: 10), weeks: [week], modelContext: context)
        let goal = Goal(title: "Laufen", colorHex: "#000000", order: 0, week: week)
        let twin = Goal(title: "  laufen ", colorHex: "#000000", order: 0, week: next)
        context.insert(goal)
        context.insert(twin)
        week.appendGoal(goal)
        next.appendGoal(twin)
        let day = TaskActions.ensureDay(containing: monday, in: week)
        let scheduled = try XCTUnwrap(TaskActions.create(title: "Runde", priority: .b, on: day, linkedGoal: goal, modelContext: context))
        let unscheduled = try XCTUnwrap(TaskActions.createUnscheduled(title: "Schuhe", goal: goal, modelContext: context))

        let report = WeekActions.close(week, weeks: [week, next], modelContext: context)

        XCTAssertEqual(report.carriedOverTasks, 2)
        XCTAssertEqual(scheduled.linkedGoal?.id, twin.id)
        XCTAssertEqual(unscheduled.linkedGoal?.id, twin.id)
        XCTAssertNil(unscheduled.day, "Ohne Tag bleibt ohne Tag")
    }

    // MARK: - Archiv

    @MainActor
    func testHeldStreakNeedsConsecutiveWeeksAcrossTheYearBoundary() throws {
        let container = try makeContainer()
        let context = container.mainContext
        var weeks: [Week] = []
        func week(_ year: Int, _ month: Int, _ day: Int, held: Bool?) {
            let week = TaskActions.ensureWeek(containing: AnkerCalendar.date(year: year, month: month, day: day),
                                              weeks: weeks, modelContext: context)
            if let held {
                let goal = Goal(title: "Anker", colorHex: "#000000", order: 0, week: week)
                goal.verdict = held ? .held : .missed
                context.insert(goal)
                week.appendGoal(goal)
            }
            weeks.append(week)
        }
        week(2026, 12, 21, held: true)   // KW 52
        week(2026, 12, 28, held: true)   // KW 53
        week(2027, 1, 4, held: true)     // KW 1
        // KW 2 fehlt
        week(2027, 1, 18, held: true)    // KW 3
        week(2027, 1, 25, held: true)    // KW 4
        week(2027, 2, 1, held: nil)      // KW 5 ohne Anker
        week(2027, 2, 8, held: true)     // KW 6

        XCTAssertEqual(AnkerCalendar.WeekKey(isoYear: 2026, isoWeek: 53).next, .init(isoYear: 2027, isoWeek: 1))
        XCTAssertEqual(AnkerCalendar.WeekKey(isoYear: 2027, isoWeek: 52).next, .init(isoYear: 2028, isoWeek: 1))
        XCTAssertEqual(ArchiveSummary.longestHeldStreak(weeks), 3)
        XCTAssertEqual(ArchiveSummary.weeksText(1), "1 Woche")
        XCTAssertEqual(ArchiveSummary.weeksText(3), "3 Wochen")
    }

    @MainActor
    func testRecurringMissIsDeterministic() throws {
        let container = try makeContainer()
        let context = container.mainContext
        var weeks: [Week] = []
        for offset in 0..<3 {
            let date = AnkerCalendar.date(year: 2026, month: 8, day: 3 + offset * 7)
            let week = TaskActions.ensureWeek(containing: date, weeks: weeks, modelContext: context)
            for (index, title) in ["Zeta", "Alpha"].enumerated() {
                let goal = Goal(title: title, colorHex: "#000000", order: index, week: week)
                goal.verdict = .missed
                context.insert(goal)
                week.appendGoal(goal)
            }
            weeks.append(week)
        }
        for _ in 0..<5 {
            XCTAssertEqual(ArchiveSummary.recurringMiss(weeks.shuffled())?.title, "Alpha")
        }
    }

    // MARK: - Deep Links

    @MainActor
    func testDeepLinkDatesAreStrict() {
        XCTAssertNil(AnkerNavigationState.date(from: "2026-13-45"))
        XCTAssertNil(AnkerNavigationState.date(from: "2026-02-30"))
        XCTAssertNil(AnkerNavigationState.date(from: "1999-01-01"))
        XCTAssertNil(AnkerNavigationState.date(from: "murks"))
        XCTAssertNil(AnkerNavigationState.date(from: "2026-8-+5"))
        XCTAssertNotNil(AnkerNavigationState.date(from: "2026-02-28"))
        XCTAssertNotNil(AnkerNavigationState.date(from: "2028-02-29"))
    }

    @MainActor
    func testDeepLinksRejectInvalidArgumentsWithoutTouchingState() throws {
        let now = AnkerCalendar.date(year: 2026, month: 8, day: 5)
        var state = AnkerNavigationState(now: now)
        let before = state

        XCTAssertFalse(state.apply(try XCTUnwrap(URL(string: "anchorit://day/2026-02-30"))))
        XCTAssertFalse(state.apply(try XCTUnwrap(URL(string: "anchorit://week/murks"))))
        XCTAssertFalse(state.apply(try XCTUnwrap(URL(string: "anchorit://day/2026-13-45"))))
        XCTAssertEqual(state, before)

        XCTAssertTrue(state.apply(try XCTUnwrap(URL(string: "ANCHORIT://Archive"))))
        XCTAssertEqual(state.destination, .archive)
        XCTAssertTrue(state.apply(try XCTUnwrap(URL(string: "anchorit://week"))))
        XCTAssertEqual(state.destination, .week)
        XCTAssertTrue(state.apply(try XCTUnwrap(URL(string: "anchorit://week/2026-08-12"))))
        XCTAssertEqual(state.weekStart, AnkerCalendar.weekInterval(containing: AnkerCalendar.date(year: 2026, month: 8, day: 10)).monday)
    }

    /// Die Erinnerungen schicken `review` und `week` ohne Datum — gemeint ist die Woche von heute,
    /// auch wenn zuletzt eine andere Woche offen war (Testbericht 2026-11-26, M4).
    @MainActor
    func testReminderLinksWithoutDateOpenTheCurrentWeek() throws {
        let sunday = AnkerCalendar.date(year: 2026, month: 11, day: 29, hour: 18, minute: 0)
        let currentMonday = AnkerCalendar.weekInterval(containing: sunday).monday
        var state = AnkerNavigationState(now: sunday)
        state.moveWeek(by: 1)
        XCTAssertNotEqual(state.weekStart, currentMonday)

        XCTAssertTrue(state.apply(try XCTUnwrap(URL(string: "anchorit://review")), now: sunday))
        XCTAssertEqual(state.destination, .review)
        XCTAssertEqual(state.weekStart, currentMonday)

        state.moveWeek(by: -3)
        let monday = AnkerCalendar.date(year: 2026, month: 11, day: 30, hour: 8, minute: 0)
        XCTAssertTrue(state.apply(try XCTUnwrap(URL(string: "anchorit://week")), now: monday))
        XCTAssertEqual(state.destination, .week)
        XCTAssertEqual(state.weekStart, AnkerCalendar.weekInterval(containing: monday).monday)
        XCTAssertTrue(AnkerCalendar.isSameDay(state.dayDate, monday))
    }

    // MARK: - Suche

    @MainActor
    func testSearchFindsTasksWithoutDayAndGoalWhy() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let monday = AnkerCalendar.date(year: 2026, month: 8, day: 3)
        let week = TaskActions.ensureWeek(containing: monday, weeks: [], modelContext: context)
        let goal = Goal(title: "Laufen", colorHex: "#000000", order: 0, week: week)
        goal.why = "Damit der Marathon klappt"
        context.insert(goal)
        week.appendGoal(goal)
        week.reflection = "Die Woche war ruhig"
        _ = TaskActions.createUnscheduled(title: "Laufschuhe kaufen", goal: goal, modelContext: context)
        _ = TaskActions.createUnscheduled(title: "Steuer Laufzettel", goal: nil, modelContext: context)
        try context.save()

        let results = AnkerSearch.results(for: "lauf", in: [week], modelContext: context)
        let anchored = try XCTUnwrap(results.first { $0.title == "Laufschuhe kaufen" })
        XCTAssertNil(anchored.dayID)
        XCTAssertEqual(anchored.goalID, goal.id)
        let inbox = try XCTUnwrap(results.first { $0.title == "Steuer Laufzettel" })
        XCTAssertNil(inbox.goalID)

        XCTAssertEqual(AnkerSearch.results(for: "marathon", in: [week], modelContext: context).first?.id, goal.id)

        // Jeder Treffer führt irgendwohin.
        var state = AnkerNavigationState(now: AnkerCalendar.date(year: 2026, month: 9, day: 1))
        state.open(anchored, dayDate: nil)
        XCTAssertEqual(state.destination, .goal(goal.id))
        XCTAssertEqual(state.weekStart, AnkerCalendar.weekInterval(containing: monday).monday)

        let reflection = try XCTUnwrap(AnkerSearch.results(for: "ruhig", in: [week], modelContext: context).first)
        state = AnkerNavigationState(now: AnkerCalendar.date(year: 2026, month: 9, day: 1))
        state.open(reflection, dayDate: nil)
        XCTAssertEqual(state.destination, .week)
        XCTAssertEqual(state.weekStart, AnkerCalendar.weekInterval(containing: monday).monday)

        state.open(inbox, dayDate: nil)
        XCTAssertEqual(state.destination, .week)
    }

    // MARK: - Sync-Aufräumen

    @MainActor
    func testOrphanDayWithoutExistingWeekIsLeftAlone() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let date = AnkerCalendar.date(year: 2026, month: 8, day: 4)
        let day = Day(date: AnkerCalendar.iso.startOfDay(for: date))
        context.insert(day)
        let block = TimeBlock(startTime: date, endTime: date.addingTimeInterval(3600), title: "Block")
        context.insert(block)
        try context.save()

        let report = StoreMaintenance.run(modelContext: context, reporter: nil)
        XCTAssertEqual(report.adoptedOrphans, 0)
        XCTAssertTrue(try context.fetch(FetchDescriptor<Week>()).isEmpty, "Kein Duplikat aus einem halben Import")
        XCTAssertNil(day.week)
        XCTAssertNil(block.day)
    }

    @MainActor
    func testUsageRankIgnoresLocallyVisibleTasks() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let placeholder = Goal(title: WeekPlanning.placeholderGoalTitle, colorHex: "#000000")
        context.insert(placeholder)
        let task = AnkerTask(title: "Sichtbar nur hier", priority: .b, order: 0, linkedGoal: placeholder)
        context.insert(task)
        XCTAssertEqual(StoreMaintenance.usageRank(placeholder), 0, "Aufgaben zählen nicht")
        placeholder.why = "Weil"
        XCTAssertEqual(StoreMaintenance.usageRank(placeholder), 2)
    }

    @MainActor
    func testOrphanGoalWithOnlyUnscheduledTasksReleasesThemToInbox() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let goal = Goal(title: "Verwaist", colorHex: "#000000")
        context.insert(goal)
        let task = AnkerTask(title: "Unsichtbar", priority: .b, order: 0, linkedGoal: goal)
        context.insert(task)
        try context.save()

        StoreMaintenance.run(modelContext: context, reporter: nil)
        // Erst nach der Karenzzeit: ein Ziel kann während eines Imports kurz ohne Woche sein.
        XCTAssertTrue(task.linkedGoal === goal)
        StoreMaintenance.adoptOrphans(weeks: [], modelContext: context,
                                      now: Date().addingTimeInterval(StoreMaintenance.strandedGrace + 1))
        XCTAssertNil(task.linkedGoal)
        XCTAssertEqual(TaskActions.inboxTasks(modelContext: context).map(\.title), ["Unsichtbar"])
        XCTAssertFalse(goal.isDeleted, "Das Ziel bleibt")
    }

    /// Zwei Kopien derselben ISO-Woche vor dem Zusammenführen: der Anker hängt an der einen,
    /// der Tag an der anderen. Verschieben innerhalb der Woche behält ihn.
    @MainActor
    func testMoveWithinDuplicateWeekKeepsAnchor() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let interval = AnkerCalendar.weekInterval(containing: AnkerCalendar.date(year: 2026, month: 8, day: 3))
        let low = Week(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                       isoYear: interval.isoYear, isoWeek: interval.isoWeek, monday: interval.monday, sunday: interval.sunday)
        let high = Week(id: UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")!,
                        isoYear: interval.isoYear, isoWeek: interval.isoWeek, monday: interval.monday, sunday: interval.sunday)
        context.insert(low)
        context.insert(high)
        let goal = Goal(title: "Anker", colorHex: "#000000", order: 0, week: high)
        context.insert(goal)
        high.appendGoal(goal)
        let day = TaskActions.ensureDay(containing: interval.monday, in: low)
        let task = try XCTUnwrap(TaskActions.create(title: "Aufgabe", priority: .b, on: day, linkedGoal: goal, modelContext: context))

        let tuesday = AnkerCalendar.date(year: 2026, month: 8, day: 4)
        TaskActions.move(task, to: tuesday, weeks: [low, high], modelContext: context)
        XCTAssertEqual(task.linkedGoal?.id, goal.id)

        TaskActions.place(task, on: AnkerCalendar.date(year: 2026, month: 8, day: 5), goalID: goal.id,
                          weeks: [low, high], modelContext: context)
        XCTAssertEqual(task.linkedGoal?.id, goal.id)
    }

    /// Wurde der Tag eines Snapshots inzwischen zusammengeführt, stellt das Rückgängig die
    /// Aufgabe am selben Kalendertag wieder her.
    @MainActor
    func testRestoreAfterDayMergeUsesSnapshotDate() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let date = AnkerCalendar.date(year: 2026, month: 8, day: 4)
        let week = TaskActions.ensureWeek(containing: date, weeks: [], modelContext: context)
        let start = AnkerCalendar.iso.startOfDay(for: date)
        let survivor = Day(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, date: start, week: week)
        let duplicate = Day(id: UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")!, date: start, week: week)
        context.insert(survivor)
        context.insert(duplicate)
        week.days = [survivor, duplicate]
        let task = try XCTUnwrap(TaskActions.create(title: "Zurück", priority: .b, on: duplicate, linkedGoal: nil, modelContext: context))
        let snapshot = TaskActions.snapshot(task)
        TaskActions.delete(task, modelContext: context)

        StoreMaintenance.merge(weeks: [week], modelContext: context, reporter: nil)
        XCTAssertEqual(week.dayList.count, 1)

        TaskActions.restore([snapshot], weeks: [week], modelContext: context)
        let restored = try XCTUnwrap(try context.fetch(FetchDescriptor<AnkerTask>()).first)
        XCTAssertEqual(restored.title, "Zurück")
        XCTAssertEqual(restored.day?.id, survivor.id)
    }

    // MARK: - Anker anlegen

    @MainActor
    func testGoalCreationIsLimitedToFourAnchors() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let week = TaskActions.ensureWeek(containing: AnkerCalendar.date(year: 2026, month: 8, day: 3), weeks: [], modelContext: context)
        for index in 0..<4 {
            XCTAssertNotNil(GoalActions.create(title: "Anker \(index)", colorHex: "#000000", in: week, modelContext: context))
        }
        XCTAssertNil(GoalActions.create(title: "Fünf", colorHex: "#000000", in: week, modelContext: context))
        XCTAssertEqual(week.goalList.count, 4)

        let goal = try XCTUnwrap(GoalOrdering.anchor(number: 1, in: week))
        XCTAssertTrue(GoalActions.update(goal, title: " Neu ", why: "  Weil  ", modelContext: context))
        XCTAssertEqual(goal.title, "Neu")
        XCTAssertEqual(goal.why, "Weil")
        XCTAssertFalse(GoalActions.update(goal, title: "   ", modelContext: context), "Leerer Titel wird verworfen")
        XCTAssertTrue(GoalActions.update(goal, why: "", modelContext: context))
        XCTAssertNil(goal.why)
    }

    @MainActor
    func testBulkMessagesUseSingular() {
        XCTAssertEqual(BlattBulkActionBar.tasksMessage(1, "erledigt"), "1 Aufgabe erledigt")
        XCTAssertEqual(BlattBulkActionBar.tasksMessage(3, "gelöscht"), "3 Aufgaben gelöscht")
    }

    // MARK: - Hilfen

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(AnkerSchema.models)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
