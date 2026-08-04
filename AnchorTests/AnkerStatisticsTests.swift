import SwiftData
import XCTest
@testable import Daivento

/// Ankerordnung, Wochenaktionen und Kennzahlen.
///
/// Der Entwurf macht Aussagen — „5 Wochen Serie", „Bei diesem Tempo schaffst du 6 von 7". Eine
/// Aussage muss nachgerechnet sein, sonst behauptet die App etwas Ungeprüftes.
final class AnkerStatisticsTests: XCTestCase {

    // MARK: - Ankerordnung

    @MainActor
    func testAnchorNumbersFollowOrderNotRelationshipSequence() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let week = SampleData.insertReferenceWeek(in: context)
        try context.save()

        let expected = week.goalList.sorted { $0.order < $1.order }.map(\.id)

        // CloudKit spiegelt To-many-Beziehungen ungeordnet.
        week.goals = week.goalList.reversed()
        XCTAssertEqual(GoalOrdering.sorted(week.goalList).map(\.id), expected)

        for (index, goal) in GoalOrdering.anchors(in: week).enumerated() {
            XCTAssertEqual(GoalOrdering.anchorNumber(of: goal, in: week), index + 1)
        }
    }

    @MainActor
    func testOrderTieBreaksDeterministicallyByID() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let week = makeWeek(in: context)

        // Zwei Geraete offline: beide vergeben dieselbe Ordnungszahl.
        let a = Goal(title: "A", colorHex: "#DD2B0F", order: 3, week: week)
        let b = Goal(title: "B", colorHex: "#2D2B2B", order: 3, week: week)
        context.insert(a)
        context.insert(b)
        week.goals = [a, b]
        let first = GoalOrdering.sorted(week.goalList).map(\.id)

        week.goals = [b, a]
        XCTAssertEqual(GoalOrdering.sorted(week.goalList).map(\.id), first,
                       "Der Gleichstandsentscheid muss geraeteunabhaengig sein")
    }

    @MainActor
    func testFifthGoalBecomesExcessAndNextOrderKeepsCounting() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let week = SampleData.insertReferenceWeek(in: context)
        try context.save()

        XCTAssertEqual(GoalOrdering.nextOrder(in: week), 4, "max(order) + 1, nicht count")

        let fifth = Goal(title: "Fünftes", colorHex: "#DD2B0F", order: GoalOrdering.nextOrder(in: week), week: week)
        context.insert(fifth)
        week.appendGoal(fifth)

        XCTAssertEqual(GoalOrdering.anchors(in: week).count, 4)
        XCTAssertEqual(GoalOrdering.excess(in: week).map(\.id), [fifth.id])
        XCTAssertNil(GoalOrdering.anchorNumber(of: fifth, in: week))
    }

    @MainActor
    func testNormalizeClosesGapsAndReportsOnlyRealChanges() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let week = SampleData.insertReferenceWeek(in: context)
        try context.save()

        XCTAssertFalse(GoalOrdering.normalize(week), "Auf sauberem Bestand darf nichts gemeldet werden")

        let goal = try XCTUnwrap(week.goalList.first { $0.order == 1 })
        GoalActions.delete(goal, in: week, modelContext: context)

        XCTAssertEqual(GoalOrdering.sorted(week.goalList).map(\.order), [0, 1, 2],
                       "Nach dem Loeschen muss die Ordnung lueckenlos sein")
    }

    @MainActor
    func testPlaceholderGoalIsNotACountableAnchor() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let week = makeWeek(in: context)
        WeekPlanning.upsertOnboardingGoal(title: WeekPlanning.placeholderGoalTitle, in: week, modelContext: context)

        XCTAssertEqual(GoalOrdering.anchors(in: week).count, 1)
        // Sonst waere die Woche unerreichbar: ein Anker, der nie eine Aufgabe bekommt.
        XCTAssertTrue(GoalOrdering.countableAnchors(in: week).isEmpty)
    }

    // MARK: - Erledigungszeitpunkt und Übertragungen

    @MainActor
    func testToggleDoneSetsAndClearsCompletedAt() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let week = makeWeek(in: context)
        let day = try XCTUnwrap(week.dayList.first)
        let task = try XCTUnwrap(TaskActions.create(title: "Bericht", priority: .b, on: day,
                                                   linkedGoal: nil, modelContext: context))
        let now = AnkerCalendar.date(year: 2026, month: 8, day: 5, hour: 14)

        TaskActions.toggleDone(task, now: now, modelContext: context)
        XCTAssertTrue(task.isDone)
        XCTAssertEqual(task.completedAt, now)
        XCTAssertEqual(task.completionDate, now)

        TaskActions.toggleDone(task, now: now, modelContext: context)
        XCTAssertFalse(task.isDone)
        XCTAssertNil(task.completedAt)
        XCTAssertNil(task.completionDate)
    }

    @MainActor
    func testCompletionDateFallsBackToPlannedDayForLegacyTasks() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let week = makeWeek(in: context)
        let day = try XCTUnwrap(week.dayList.first)

        // Altbestand: erledigt, aber ohne Zeitpunkt — das Feld gab es damals nicht.
        let legacy = AnkerTask(title: "Alt", priority: .b, isDone: true, order: 0, day: day)
        context.insert(legacy)
        day.appendTask(legacy)

        XCTAssertNil(legacy.completedAt)
        XCTAssertEqual(legacy.completionDate, day.date)
    }

    func testCarryOverRuleIsPure() {
        let monday = AnkerCalendar.date(year: 2026, month: 8, day: 3)
        let nextMonday = AnkerCalendar.date(year: 2026, month: 8, day: 10)
        let sameWeek = AnkerCalendar.date(year: 2026, month: 8, day: 6)
        let previous = AnkerCalendar.date(year: 2026, month: 7, day: 27)

        // Offen und nach vorn ueber die Wochengrenze: das ist eine Uebernahme.
        XCTAssertTrue(TaskActions.isCarryOver(from: monday, to: nextMonday, isDone: false))
        // Erledigtes verschieben ist keine.
        XCTAssertFalse(TaskActions.isCarryOver(from: monday, to: nextMonday, isDone: true))
        // Innerhalb der Woche ist keine.
        XCTAssertFalse(TaskActions.isCarryOver(from: monday, to: sameWeek, isDone: false))
        // Zurueck in die Vergangenheit planen ist keine.
        XCTAssertFalse(TaskActions.isCarryOver(from: monday, to: previous, isDone: false))
        XCTAssertFalse(TaskActions.isCarryOver(from: nil, to: nextMonday, isDone: false))
    }

    @MainActor
    func testMoveAcrossWeekCountsCarryOverOnlyForOpenTasks() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let week = makeWeek(in: context)
        let day = try XCTUnwrap(week.dayList.first)
        let open = try XCTUnwrap(TaskActions.create(title: "Offen", priority: .b, on: day,
                                                   linkedGoal: nil, modelContext: context))
        let done = try XCTUnwrap(TaskActions.create(title: "Fertig", priority: .b, on: day,
                                                   linkedGoal: nil, modelContext: context))
        TaskActions.setDone(done, true, modelContext: context)

        let nextWeekDate = try XCTUnwrap(AnkerCalendar.iso.date(byAdding: .weekOfYear, value: 1, to: day.date))
        TaskActions.move(open, to: nextWeekDate, weeks: [week], modelContext: context)
        TaskActions.move(done, to: nextWeekDate, weeks: [week], modelContext: context)

        XCTAssertEqual(open.carryOverCount, 1)
        XCTAssertEqual(done.carryOverCount, 0)
    }

    @MainActor
    func testUndoRestoresCompletedAtAndCarryOverCount() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let week = makeWeek(in: context)
        let day = try XCTUnwrap(week.dayList.first)
        let task = try XCTUnwrap(TaskActions.create(title: "Bericht", priority: .b, on: day,
                                                   linkedGoal: nil, modelContext: context))
        task.carryOverCount = 2
        let snapshot = TaskActions.snapshot(task)

        TaskActions.setDone(task, true, modelContext: context)
        XCTAssertNotNil(task.completedAt)

        TaskActions.restore([snapshot], weeks: [week], modelContext: context)

        // Ohne das zaehlte die Statistik eine zurueckgenommene Erledigung weiter.
        XCTAssertNil(task.completedAt)
        XCTAssertEqual(task.carryOverCount, 2)
    }

    // MARK: - Wochenaktionen

    @MainActor
    func testReflectionPersistsAndEmptyTextBecomesNil() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let week = makeWeek(in: context)

        WeekActions.setReflection("  Reviews früher legen.  ", in: week, modelContext: context)
        XCTAssertEqual(week.reflection, "Reviews früher legen.")

        WeekActions.setReflection("   ", in: week, modelContext: context)
        XCTAssertNil(week.reflection)
    }

    @MainActor
    func testClosingAWeekMovesOpenTasksAndSetsReviewedAt() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let week = SampleData.insertReferenceWeek(in: context)
        try context.save()

        let openBefore = WeekActions.openTaskCount(in: week)
        XCTAssertGreaterThan(openBefore, 0)
        let now = AnkerCalendar.date(year: 2026, month: 1, day: 4, hour: 20)

        let report = WeekActions.close(week, at: now, weeks: [week], modelContext: context)

        XCTAssertEqual(report.carriedOverTasks, openBefore)
        XCTAssertEqual(week.reviewedAt, now)
        XCTAssertTrue(week.isReviewed)
        XCTAssertEqual(WeekActions.openTaskCount(in: week), 0, "Offene Aufgaben sind gewandert")

        WeekActions.reopen(week, modelContext: context)
        XCTAssertNil(week.reviewedAt)
    }

    @MainActor
    func testClosingWithoutCarryOverKeepsTasks() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let week = SampleData.insertReferenceWeek(in: context)
        try context.save()
        let openBefore = WeekActions.openTaskCount(in: week)

        let report = WeekActions.close(week, carryOverOpenTasks: false, weeks: [week], modelContext: context)

        XCTAssertEqual(report.carriedOverTasks, 0)
        XCTAssertEqual(WeekActions.openTaskCount(in: week), openBefore)
    }

    // MARK: - Kennzahlen

    @MainActor
    func testAnchorsInMotionCountsAnchorsWithAtLeastOneDoneTask() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let week = SampleData.insertReferenceWeek(in: context)
        try context.save()

        let report = AnkerStatistics.week(week, now: AnkerCalendar.date(year: 2026, month: 1, day: 1))
        XCTAssertEqual(report.anchorCount, 4)
        XCTAssertEqual(report.inMotionCount, report.anchors.filter { $0.doneCount > 0 }.count)
        XCTAssertGreaterThan(report.inMotionCount, 0)
    }

    @MainActor
    func testAnchorWithoutTasksCountsInDenominatorButNotInMotion() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let week = makeWeek(in: context)
        GoalActions.create(title: "Leerer Anker", colorHex: "#DD2B0F", in: week, modelContext: context)
        try context.save()

        let report = AnkerStatistics.week(week)
        XCTAssertEqual(report.anchorCount, 1, "Ein erklaerter Anker zaehlt im Nenner")
        XCTAssertEqual(report.inMotionCount, 0, "…aber er hat sich nicht bewegt")
    }

    @MainActor
    func testWeekWithoutAnchorsIsUnplannedAndBreaksTheStreak() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = AnkerCalendar.date(year: 2026, month: 8, day: 5)

        // Eine Woche in der Vergangenheit ohne Anker.
        let past = TaskActions.ensureWeek(
            containing: AnkerCalendar.date(year: 2026, month: 7, day: 20),
            weeks: [], modelContext: context
        )
        try context.save()

        XCTAssertEqual(AnkerStatistics.standing(of: past, now: now), .unplanned)
        XCTAssertEqual(AnkerStatistics.standing(of: nil, now: now), .unplanned)
        XCTAssertEqual(AnkerStatistics.streak(in: [past], now: now).weeks, 0)
    }

    @MainActor
    func testRunningWeekCountsInStreakOnlyWhenAlreadyHeld() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = AnkerCalendar.date(year: 2026, month: 8, day: 5)
        let week = TaskActions.ensureWeek(containing: now, weeks: [], modelContext: context)
        let goal = try XCTUnwrap(GoalActions.create(title: "Anker", colorHex: "#DD2B0F", in: week, modelContext: context))
        let day = try XCTUnwrap(week.dayList.first)
        let task = try XCTUnwrap(TaskActions.create(title: "Sache", priority: .b, on: day,
                                                   linkedGoal: goal, modelContext: context))
        try context.save()

        // Noch nichts erledigt: die Serie darf mittwochs nicht auf 0 fallen, aber sie zaehlt
        // die laufende Woche auch nicht mit.
        XCTAssertEqual(AnkerStatistics.standing(of: week, now: now), .running)
        XCTAssertEqual(AnkerStatistics.streak(in: [week], now: now).weeks, 0)

        TaskActions.setDone(task, true, now: now, modelContext: context)
        let streak = AnkerStatistics.streak(in: [week], now: now)
        XCTAssertEqual(streak.weeks, 1)
        XCTAssertTrue(streak.isRunning)
    }

    @MainActor
    func testStrongestWeekdayUsesCompletionDateAndBreaksTiesEarlier() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let week = makeWeek(in: context)
        let day = try XCTUnwrap(week.dayList.first)

        func task(_ title: String, doneAt: Date?) throws -> AnkerTask {
            let created = try XCTUnwrap(TaskActions.create(title: title, priority: .b, on: day,
                                                          linkedGoal: nil, modelContext: context))
            if let doneAt { TaskActions.setDone(created, true, now: doneAt, modelContext: context) }
            return created
        }

        // Zwei am Dienstag, eine am Donnerstag.
        _ = try task("A", doneAt: AnkerCalendar.date(year: 2026, month: 8, day: 4, hour: 10))
        _ = try task("B", doneAt: AnkerCalendar.date(year: 2026, month: 8, day: 4, hour: 12))
        _ = try task("C", doneAt: AnkerCalendar.date(year: 2026, month: 8, day: 6, hour: 9))
        _ = try task("D", doneAt: nil)

        let strongest = try XCTUnwrap(AnkerStatistics.strongestWeekday(in: day.taskList))
        XCTAssertEqual(strongest.index, 2, "Dienstag")
        XCTAssertEqual(strongest.doneCount, 2)

        // Gleichstand: der fruehere Wochentag gewinnt, damit das Ergebnis nicht schwankt.
        _ = try task("E", doneAt: AnkerCalendar.date(year: 2026, month: 8, day: 6, hour: 11))
        XCTAssertEqual(try XCTUnwrap(AnkerStatistics.strongestWeekday(in: day.taskList)).index, 2)
    }

    @MainActor
    func testStrongestWeekdayIsNilWithoutCompletedTasks() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let week = makeWeek(in: context)
        XCTAssertNil(AnkerStatistics.strongestWeekday(in: week.dayList.flatMap(\.taskList)))
    }

    @MainActor
    func testCarriedInTasksAreCountedInTheTargetWeek() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let week = makeWeek(in: context)
        let day = try XCTUnwrap(week.dayList.first)
        let task = try XCTUnwrap(TaskActions.create(title: "Wandert", priority: .b, on: day,
                                                   linkedGoal: nil, modelContext: context))
        let nextWeekDate = try XCTUnwrap(AnkerCalendar.iso.date(byAdding: .weekOfYear, value: 1, to: day.date))
        TaskActions.move(task, to: nextWeekDate, weeks: [week], modelContext: context)
        let target = try XCTUnwrap(task.day?.week)

        // Zielseitig gezaehlt: quellseitig ist die Aufgabe nach dem Verschieben nicht mehr Teil
        // der alten Woche.
        XCTAssertEqual(AnkerStatistics.week(target).carriedInTaskCount, 1)
        XCTAssertEqual(AnkerStatistics.week(week).carriedInTaskCount, 0)
    }

    @MainActor
    func testForecastNamesTheDeficitAndTheNextWeek() throws {
        let container = try makeContainer()
        let context = container.mainContext
        // Mittwoch der Woche: vier Tage übrig, drei verstrichen.
        let wednesday = AnkerCalendar.date(year: 2026, month: 8, day: 5, hour: 10)
        let week = TaskActions.ensureWeek(containing: wednesday, weeks: [], modelContext: context)
        let day = try XCTUnwrap(week.dayList.first)

        for index in 0..<7 {
            let task = try XCTUnwrap(TaskActions.create(title: "Sache \(index)", priority: .b, on: day,
                                                        linkedGoal: nil, modelContext: context))
            if index < 3 { TaskActions.setDone(task, true, now: wednesday, modelContext: context) }
        }
        try context.save()

        let forecast = AnkerStatistics.forecast(for: week, now: wednesday)
        XCTAssertEqual(forecast.kind, .running)
        XCTAssertEqual(forecast.doneCount, 3)
        XCTAssertEqual(forecast.totalCount, 7)
        XCTAssertTrue(forecast.sentence.hasPrefix("Bei diesem Tempo schaffst du "), forecast.sentence)
        if forecast.deficit > 0 {
            XCTAssertTrue(forecast.sentence.contains("KW"), forecast.sentence)
        }
    }

    @MainActor
    func testForecastIsEmptyWithoutTasksAndPastAfterTheWeek() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let week = SampleData.insertReferenceWeek(in: context)
        try context.save()

        let empty = AnkerStatistics.forecast(
            for: TaskActions.ensureWeek(containing: AnkerCalendar.date(year: 2026, month: 9, day: 1),
                                        weeks: [], modelContext: context)
        )
        XCTAssertEqual(empty.kind, .empty)
        XCTAssertEqual(empty.sentence, "Noch keine Aufgabe in dieser Woche.")

        let later = AnkerCalendar.date(year: 2026, month: 6, day: 1)
        let past = AnkerStatistics.forecast(for: week, now: later)
        XCTAssertEqual(past.kind, .finished)
        XCTAssertTrue(past.sentence.hasPrefix("Du hast "), past.sentence)
    }

    @MainActor
    func testYearBandHasOneBarPerISOWeekIncludingGaps() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let week = SampleData.insertReferenceWeek(in: context)
        try context.save()

        let report = AnkerStatistics.year(isoYear: 2026, in: [week], now: AnkerCalendar.date(year: 2026, month: 1, day: 1))
        XCTAssertEqual(report.bars.count, AnkerCalendar.weeksInISOYear(2026))
        XCTAssertEqual(report.bars.map(\.isoWeek), Array(1...report.bars.count))

        // Genau eine Woche hat Daten, alle anderen sind Luecken — und die sind die Aussage.
        XCTAssertEqual(report.bars.filter { $0.anchorCount > 0 }.count, 1)
        XCTAssertEqual(report.bars.filter { $0.standing == .unplanned }.count, report.bars.count - 1)
    }

    @MainActor
    func testHeldPercentageIgnoresWeeksWithoutAnchors() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = AnkerCalendar.date(year: 2026, month: 8, day: 5)

        // Eine gehaltene Vorwoche.
        let past = TaskActions.ensureWeek(containing: AnkerCalendar.date(year: 2026, month: 7, day: 29),
                                          weeks: [], modelContext: context)
        let goal = try XCTUnwrap(GoalActions.create(title: "Anker", colorHex: "#DD2B0F", in: past, modelContext: context))
        let day = try XCTUnwrap(past.dayList.first)
        let task = try XCTUnwrap(TaskActions.create(title: "Sache", priority: .b, on: day,
                                                   linkedGoal: goal, modelContext: context))
        TaskActions.setDone(task, true, now: day.date, modelContext: context)

        // Und eine leere Woche, die die Quote nicht verwaessern darf.
        _ = TaskActions.ensureWeek(containing: AnkerCalendar.date(year: 2026, month: 7, day: 20),
                                   weeks: [past], modelContext: context)
        let all = try context.fetch(FetchDescriptor<Week>())
        try context.save()

        let report = AnkerStatistics.year(isoYear: 2026, in: all, now: now)
        XCTAssertEqual(report.plannedWeekCount, 1)
        XCTAssertEqual(report.heldAnchorPercentage, 100)
    }

    @MainActor
    func testRemainingDaysCountsTodayAndStopsAfterSunday() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let week = TaskActions.ensureWeek(containing: AnkerCalendar.date(year: 2026, month: 8, day: 3),
                                          weeks: [], modelContext: context)

        XCTAssertEqual(AnkerStatistics.remainingDays(in: week, now: AnkerCalendar.date(year: 2026, month: 8, day: 3)), 7)
        XCTAssertEqual(AnkerStatistics.remainingDays(in: week, now: AnkerCalendar.date(year: 2026, month: 8, day: 5)), 5)
        XCTAssertEqual(AnkerStatistics.remainingDays(in: week, now: AnkerCalendar.date(year: 2026, month: 8, day: 9)), 1)
        XCTAssertEqual(AnkerStatistics.remainingDays(in: week, now: AnkerCalendar.date(year: 2026, month: 8, day: 10)), 0)
        // Vor der Woche zaehlen alle sieben.
        XCTAssertEqual(AnkerStatistics.remainingDays(in: week, now: AnkerCalendar.date(year: 2026, month: 7, day: 1)), 7)
    }

    func testISOWeekdayIndexStartsOnMonday() {
        // Montag, 03.08.2026 bis Sonntag, 09.08.2026.
        for (offset, expected) in zip(0..<7, 1...7) {
            let date = AnkerCalendar.date(year: 2026, month: 8, day: 3 + offset)
            XCTAssertEqual(AnkerStatistics.isoWeekdayIndex(of: date), expected)
        }
    }

    func testWeeksInISOYear() {
        // 2026 hat 53 ISO-Wochen, 2027 hat 52.
        XCTAssertEqual(AnkerCalendar.weeksInISOYear(2026), 53)
        XCTAssertEqual(AnkerCalendar.weeksInISOYear(2027), 52)
    }

    @MainActor
    func testAnchorReportReflectsAToggleImmediately() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let week = makeWeek(in: context)
        let goal = try XCTUnwrap(GoalActions.create(title: "Vertragsprüfung", colorHex: "#DD2B0F",
                                                   in: week, modelContext: context))
        let day = try XCTUnwrap(week.dayList.first)
        let task = try XCTUnwrap(TaskActions.create(title: "Vertrag lesen", priority: .b, on: day,
                                                   linkedGoal: goal, modelContext: context))
        try context.save()

        func report() throws -> AnkerStatistics.AnchorReport {
            try XCTUnwrap(AnkerStatistics.week(week).anchors.first { $0.id == goal.id })
        }

        XCTAssertEqual(try report().totalCount, 1)
        XCTAssertEqual(try report().doneCount, 0)

        TaskActions.toggleDone(task, modelContext: context)

        // Genau die Kette, die das Zieldetail zeigt.
        XCTAssertEqual(try report().doneCount, 1)
        XCTAssertEqual(goal.progress, 1, accuracy: 0.001)
    }

    @MainActor
    func testCaptureLineCreatesTaskOnTheFirstAnchor() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let week = makeWeek(in: context)
        let goal = try XCTUnwrap(GoalActions.create(title: "Vertragsprüfung", colorHex: "#DD2B0F",
                                                   in: week, modelContext: context))
        try context.save()

        let input = CaptureSyntax.parse("Vertrag prüfen !a #1")
        let task = TaskActions.create(input, weekStart: week.monday,
                                      fallbackDate: week.monday, weeks: [week],
                                      modelContext: context)

        let created = try XCTUnwrap(task, "Die Erfassungszeile hat nichts angelegt")
        XCTAssertEqual(created.title, "Vertrag prüfen")
        XCTAssertEqual(created.priority, .a)
        XCTAssertEqual(created.linkedGoal?.id, goal.id, "#1 muss auf den ersten Anker zeigen")
        XCTAssertEqual(AnkerStatistics.week(week).anchors.first?.totalCount, 1)
    }

    // MARK: - Hilfen

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(AnkerSchema.models)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    @MainActor
    private func makeWeek(in context: ModelContext) -> Week {
        TaskActions.ensureWeek(
            containing: AnkerCalendar.date(year: 2026, month: 8, day: 3),
            weeks: [],
            modelContext: context
        )
    }
}
