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
    func testDeletingGoalKeepsTasksAndClearsTheirLink() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let week = SampleData.insertReferenceWeek(in: context)
        try context.save()

        let goal = try XCTUnwrap(week.goalList.first { !$0.taskList.isEmpty })
        let goalID = goal.id
        let linkedTaskIDs = Set(
            week.dayList
                .flatMap(\.taskList)
                .filter { $0.linkedGoal?.id == goalID }
                .map(\.id)
        )
        XCTAssertFalse(linkedTaskIDs.isEmpty)

        let otherGoalIDs = Set(week.goalList.map(\.id)).subtracting([goalID])
        let taskCountBefore = try context.fetch(FetchDescriptor<AnkerTask>()).count

        GoalActions.delete(goal, in: week, modelContext: context)

        let remainingGoals = try context.fetch(FetchDescriptor<Goal>())
        XCTAssertFalse(remainingGoals.contains { $0.id == goalID })
        XCTAssertEqual(Set(remainingGoals.map(\.id)), otherGoalIDs, "Andere Wochenziele dürfen nicht mitgelöscht werden")
        XCTAssertFalse(week.goalList.contains { $0.id == goalID })

        // Kern der Anforderung: die Aufgaben bleiben, nur die Zuordnung faellt weg.
        let remainingTasks = try context.fetch(FetchDescriptor<AnkerTask>())
        XCTAssertEqual(remainingTasks.count, taskCountBefore)
        for id in linkedTaskIDs {
            let task = try XCTUnwrap(remainingTasks.first { $0.id == id })
            XCTAssertNil(task.linkedGoal)
        }
        XCTAssertFalse(remainingTasks.contains { $0.linkedGoal?.id == goalID })
    }

    @MainActor
    func testDeletingGoalWithoutTasksLeavesOtherLinksIntact() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let week = SampleData.insertReferenceWeek(in: context)
        try context.save()

        let goals = week.goalList
        let victim = try XCTUnwrap(goals.first)
        let survivor = try XCTUnwrap(goals.first { $0.id != victim.id })
        let survivorTaskIDs = Set(survivor.taskList.map(\.id))

        GoalActions.delete(victim, in: week, modelContext: context)

        XCTAssertEqual(Set(survivor.taskList.map(\.id)), survivorTaskIDs)
        for task in survivor.taskList {
            XCTAssertEqual(task.linkedGoal?.id, survivor.id)
        }
    }

    @MainActor
    func testNoDuplicatesFoundInCleanStore() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let week = makeWeek(in: context)
        try context.save()

        XCTAssertTrue(StoreMaintenance.duplicateWeekKeys(in: [week]).isEmpty)
        XCTAssertTrue(StoreMaintenance.duplicateDayKeys(in: week).isEmpty)
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
        XCTAssertFalse(StoreMaintenance.duplicateWeekKeys(in: weeks).isEmpty)

        // Eine doppelte Woche plus die sieben doppelten Tage darin.
        XCTAssertEqual(StoreMaintenance.normalize(weeks: weeks, modelContext: context), 8)

        let remainingWeeks = try context.fetch(FetchDescriptor<Week>())
        XCTAssertEqual(remainingWeeks.count, 1)

        let survivor = try XCTUnwrap(remainingWeeks.first)
        XCTAssertEqual(survivor.dayList.count, 7)
        XCTAssertTrue(StoreMaintenance.duplicateWeekKeys(in: remainingWeeks).isEmpty)

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
    func testMergeReportNamesRemovedRecordsAndCalendarWeeks() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let interval = AnkerCalendar.weekInterval(containing: AnkerCalendar.date(year: 2026, month: 8, day: 3))
        let first = insertFullWeek(interval: interval, in: context)
        let second = insertFullWeek(interval: interval, in: context)
        try context.save()

        let report = StoreMaintenance.merge(weeks: [first, second], modelContext: context)

        // Ohne Protokoll waere die automatische Loeschung nicht nachvollziehbar — genau das
        // ist der Punkt des Befunds.
        XCTAssertEqual(report.removedWeeks, 1)
        XCTAssertEqual(report.removedDays, 7)
        XCTAssertEqual(report.removedTotal, 8)
        XCTAssertEqual(report.affectedWeeks, ["\(interval.isoYear)-KW\(String(format: "%02d", interval.isoWeek))"])
        XCTAssertTrue(report.summary.contains("zusammengeführt"))
    }

    @MainActor
    func testMergeReportIsEmptyWithoutDuplicates() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let week = SampleData.insertReferenceWeek(in: context)
        try context.save()

        let report = StoreMaintenance.merge(weeks: [week], modelContext: context)

        XCTAssertTrue(report.isEmpty)
        XCTAssertTrue(report.affectedWeeks.isEmpty)
        XCTAssertEqual(report.summary, "Keine Duplikate")
    }

    // MARK: - Datenexport und Loeschung

    @MainActor
    func testExportContainsEveryStoredRecord() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let week = SampleData.insertReferenceWeek(in: context)
        try context.save()

        let snapshot = try decodedExport(from: context)

        // Version 2: der Export traegt jetzt Ankerordnung, Erledigungszeitpunkt,
        // Uebertragungszaehler, Rueckblicktext und Abschlusszeitpunkt mit.
        XCTAssertEqual(snapshot.formatVersion, 2)
        XCTAssertEqual(snapshot.weeks.count, 1)

        let exportedWeek = try XCTUnwrap(snapshot.weeks.first)
        XCTAssertEqual(exportedWeek.id, week.id)
        XCTAssertEqual(exportedWeek.isoWeek, week.isoWeek)
        XCTAssertEqual(exportedWeek.goals.count, week.goalList.count)
        XCTAssertEqual(exportedWeek.days.count, week.dayList.count)

        // Vollstaendigkeit ist der Kern von Art. 15 und 20: keine Aufgabe darf fehlen.
        let storedTasks = try context.fetch(FetchDescriptor<AnkerTask>())
        let exportedTasks = exportedWeek.days.flatMap(\.tasks)
        XCTAssertEqual(Set(exportedTasks.map(\.id)), Set(storedTasks.map(\.id)))

        // Die neuen Felder sind Nutzerdaten und muessen in der Auskunft auftauchen (Art. 15).
        XCTAssertEqual(exportedWeek.reflection, week.reflection)
        XCTAssertEqual(exportedWeek.reviewedAt, week.reviewedAt)
        XCTAssertEqual(exportedWeek.goals.map(\.order), Array(0..<exportedWeek.goals.count),
                       "Ziele muessen sortiert und lueckenlos numeriert exportiert werden")
        XCTAssertTrue(exportedTasks.contains { $0.completedAt != nil }, "Erledigungszeitpunkt fehlt")
        XCTAssertTrue(exportedTasks.contains { $0.carryOverCount > 0 }, "Uebertragungszaehler fehlt")

        let linkedTask = try XCTUnwrap(exportedTasks.first { $0.linkedGoalID != nil })
        let storedLinked = try XCTUnwrap(storedTasks.first { $0.id == linkedTask.id })
        XCTAssertEqual(linkedTask.linkedGoalID, storedLinked.linkedGoal?.id)
        XCTAssertEqual(linkedTask.title, storedLinked.title)
        XCTAssertEqual(linkedTask.priority, storedLinked.priority.rawValue)
    }

    @MainActor
    func testExportIncludesRecordsWithoutWeekOrDay() throws {
        let container = try makeContainer()
        let context = container.mainContext
        SampleData.insertReferenceWeek(in: context)

        // Ueber die Oberflaeche nicht erreichbar, im Store aber vorhanden — eine Auskunft
        // muss solche Reste trotzdem enthalten.
        let orphanGoal = Goal(title: "Ziel ohne Woche", colorHex: "#5B6EE8")
        let orphanTask = AnkerTask(title: "Aufgabe ohne Tag", priority: .c, order: 0)
        context.insert(orphanGoal)
        context.insert(orphanTask)
        try context.save()

        let snapshot = try decodedExport(from: context)

        XCTAssertFalse(snapshot.unassigned.isEmpty)
        XCTAssertEqual(snapshot.unassigned.goals.map(\.id), [orphanGoal.id])
        XCTAssertEqual(snapshot.unassigned.tasks.map(\.id), [orphanTask.id])
        XCTAssertFalse(snapshot.weeks.contains { $0.goals.contains { $0.id == orphanGoal.id } })
    }

    @MainActor
    func testDeleteAllDataRemovesEveryRecord() throws {
        let container = try makeContainer()
        let context = container.mainContext
        SampleData.insertReferenceWeek(in: context)
        context.insert(Goal(title: "Ziel ohne Woche", colorHex: "#5B6EE8"))
        try context.save()

        let report = DataPortability.deleteAllData(in: context)

        XCTAssertTrue(report.didSave)
        XCTAssertEqual(report.weeks, 1)
        XCTAssertGreaterThan(report.tasks, 0)
        XCTAssertGreaterThan(report.total, 0)

        XCTAssertTrue(try context.fetch(FetchDescriptor<Week>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<Goal>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<Day>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<AnkerTask>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<TimeBlock>()).isEmpty)

        // Nach der Loeschung muss auch ein zweiter Export leer sein — sonst haette
        // irgendwo noch ein Rest ueberlebt.
        let snapshot = try decodedExport(from: context)
        XCTAssertTrue(snapshot.weeks.isEmpty)
        XCTAssertTrue(snapshot.unassigned.isEmpty)
    }

    @MainActor
    func testResetStoredPreferencesClearsOnboardingState() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "AnchorTests.\(#function)"))
        defaults.set(true, forKey: "hasCompletedOnboarding")
        defaults.set(2, forKey: "onboardingVersion")

        DataPortability.resetStoredPreferences(in: defaults)

        XCTAssertNil(defaults.object(forKey: "hasCompletedOnboarding"))
        XCTAssertNil(defaults.object(forKey: "onboardingVersion"))
        defaults.removePersistentDomain(forName: "AnchorTests.\(#function)")
    }

    @MainActor
    func testSaveChangesPersistsAndReportsNoFailure() throws {
        let container = try makeContainer()
        let context = container.mainContext
        PersistenceFailureCenter.shared.clear()

        let week = makeWeek(in: context)
        XCTAssertTrue(context.saveChanges())

        XCTAssertFalse(context.hasChanges)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Week>()).map(\.id), [week.id])
        XCTAssertNil(PersistenceFailureCenter.shared.failure)
        // Ohne Aenderungen ist der Aufruf ein No-op und meldet trotzdem Erfolg.
        XCTAssertTrue(context.saveChanges())
    }

    // MARK: - Suche

    @MainActor
    func testSearchFindsTasksGoalsNotesFocusAndTimeBlocks() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let week = SampleData.insertReferenceWeek(in: context)
        let notedDay = try XCTUnwrap(week.dayList.min { $0.date < $1.date })
        notedDay.notes = "Absprache mit Revision zur Freigabe"
        try context.save()

        XCTAssertEqual(kinds(for: "Workshop", in: [week]), [.task, .goal])
        XCTAssertEqual(kinds(for: "Revision", in: [week]), [.note])
        XCTAssertEqual(kinds(for: "Team-Sync", in: [week]), [.timeBlock])

        // "Jahresplanung 2026" ist Zieltitel und Tagesfokus — beide muessen kommen.
        XCTAssertEqual(kinds(for: "Jahresplanung", in: [week]), [.goal, .focus])

        let taskHit = try XCTUnwrap(AnkerSearch.results(for: "Executive", in: [week]).first)
        XCTAssertEqual(taskHit.kind, .task)
        XCTAssertEqual(taskHit.title, "Executive Summary finalisieren")
        XCTAssertNotNil(taskHit.dayID)
        // Prioritaet und zugeordnetes Ziel gehoeren in die Zeile, sonst ist ein Treffer
        // ohne Kontext nicht einzuordnen.
        XCTAssertTrue(taskHit.context.contains("Prio A"))
        XCTAssertTrue(taskHit.context.contains("Jahresplanung 2026"))
    }

    @MainActor
    func testSearchIgnoresCaseDiacriticsAndTooShortQueries() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let week = SampleData.insertReferenceWeek(in: context)
        try context.save()

        // "Rückmeldung an R+V senden" — klein geschrieben und ohne Umlaut trotzdem finden.
        XCTAssertEqual(AnkerSearch.results(for: "ruckmeldung", in: [week]).first?.kind, .task)
        XCTAssertEqual(AnkerSearch.results(for: "RÜCKMELDUNG", in: [week]).first?.kind, .task)

        // Ein Zeichen liefert bewusst nichts: sonst waere praktisch jeder Datensatz ein Treffer.
        XCTAssertTrue(AnkerSearch.results(for: "R", in: [week]).isEmpty)
        XCTAssertTrue(AnkerSearch.results(for: "   ", in: [week]).isEmpty)
        XCTAssertTrue(AnkerSearch.results(for: "", in: [week]).isEmpty)
    }

    @MainActor
    func testSearchReturnsSeparateResultsForNoteAndFocusOnSameDay() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let week = makeWeek(in: context)
        let day = try XCTUnwrap(week.dayList.first)
        day.focusNote = "Angebot pruefen"
        day.notes = "Angebot liegt beim Einkauf"
        try context.save()

        let results = AnkerSearch.results(for: "Angebot", in: [week])

        // Gleiche Tages-ID auf beiden Treffern wuerde ein `ForEach` einen davon verschlucken.
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(Set(results.map(\.kind)), [.focus, .note])
        XCTAssertEqual(Set(results.map(\.id)).count, 2)
        XCTAssertEqual(Set(results.compactMap(\.dayID)), [day.id])
    }

    func testSearchSnippetShowsSurroundingsOfLongNote() {
        let filler = String(repeating: "x", count: 200)
        let note = "\(filler) Vertragsentwurf \(filler)"

        let snippet = AnkerSearch.snippet(of: note, around: "Vertragsentwurf")

        XCTAssertTrue(snippet.contains("Vertragsentwurf"))
        XCTAssertTrue(snippet.hasPrefix("… "))
        XCTAssertTrue(snippet.hasSuffix(" …"))
        XCTAssertLessThan(snippet.count, note.count)
    }

    // MARK: - Navigation

    func testNavigationJumpsMoveWeekAndDayTogether() {
        var state = AnkerNavigationState(now: AnkerCalendar.date(year: 2026, month: 8, day: 5))
        let startWeek = state.weekStart
        let startDay = state.dayDate

        state.moveWeek(by: 1)

        // Beide um denselben Betrag: sonst zeigte die Wochenansicht die neue Woche, waehrend
        // neue Aufgaben weiter im alten Tag landeten.
        XCTAssertEqual(state.weekStart, AnkerCalendar.iso.date(byAdding: .weekOfYear, value: 1, to: startWeek))
        XCTAssertEqual(state.dayDate, AnkerCalendar.iso.date(byAdding: .weekOfYear, value: 1, to: startDay))
        XCTAssertEqual(state.destination, .week)

        state.moveWeek(by: -1)
        XCTAssertEqual(state.weekStart, startWeek)
        XCTAssertEqual(state.dayDate, startDay)
    }

    func testNavigationRemembersTopLevelWhilePushed() {
        var state = AnkerNavigationState()
        state.select(.year)
        XCTAssertFalse(state.isPushed)

        state.openDay(on: AnkerCalendar.date(year: 2026, month: 8, day: 6))
        XCTAssertEqual(state.destination, .day)
        XCTAssertTrue(state.isPushed)
        // Der Tab bleibt stehen — nur so fuehrt ein Zurueck dorthin, wo geoeffnet wurde.
        XCTAssertEqual(state.topLevel, .year)

        state.popToTopLevel()
        XCTAssertEqual(state.destination, .year)
        XCTAssertFalse(state.isPushed)
    }

    func testNavigationFocusDoesNotChangeDestination() {
        var state = AnkerNavigationState()
        state.select(.week)

        // Nach einem Drag-and-Drop soll der Blick bleiben, wo gezogen wurde.
        state.focus(on: AnkerCalendar.date(year: 2026, month: 9, day: 2))

        XCTAssertEqual(state.destination, .week)
        XCTAssertEqual(state.weekStart, AnkerCalendar.weekInterval(containing: AnkerCalendar.date(year: 2026, month: 9, day: 2)).monday)
    }

    func testNavigationSurvivesEncodingRoundTrip() throws {
        var state = AnkerNavigationState(now: AnkerCalendar.date(year: 2026, month: 8, day: 5))
        let goalID = UUID()
        state.select(.week)
        state.openGoal(goalID, inWeekContaining: AnkerCalendar.date(year: 2026, month: 8, day: 5))

        let restored = try XCTUnwrap(AnkerNavigationState(encoded: state.encoded))

        XCTAssertEqual(restored, state)
        XCTAssertEqual(restored.destination, .goal(goalID))
        XCTAssertEqual(restored.topLevel, .week)
        XCTAssertNil(AnkerNavigationState(encoded: "kein JSON"))
        XCTAssertNil(AnkerNavigationState(encoded: nil))
    }

    func testDeepLinksSetDestinationAndDate() throws {
        var state = AnkerNavigationState()

        XCTAssertTrue(state.apply(try XCTUnwrap(URL(string: "daivento://day/2026-08-05"))))
        XCTAssertEqual(state.destination, .day)
        XCTAssertTrue(AnkerCalendar.isSameDay(state.dayDate, AnkerCalendar.date(year: 2026, month: 8, day: 5)))

        XCTAssertTrue(state.apply(try XCTUnwrap(URL(string: "daivento://week/2026-09-14"))))
        XCTAssertEqual(state.destination, .week)
        XCTAssertEqual(state.weekStart, AnkerCalendar.weekInterval(containing: AnkerCalendar.date(year: 2026, month: 9, day: 14)).monday)

        let goalID = UUID()
        XCTAssertTrue(state.apply(try XCTUnwrap(URL(string: "daivento://goal/\(goalID.uuidString)"))))
        XCTAssertEqual(state.destination, .goal(goalID))

        XCTAssertTrue(state.apply(try XCTUnwrap(URL(string: "daivento://year"))))
        XCTAssertEqual(state.destination, .year)
    }

    func testUnknownDeepLinkLeavesStateUntouched() throws {
        var state = AnkerNavigationState()
        state.select(.review)
        let before = state

        // Ein Tippfehler im Link darf den Nutzer nicht irgendwo hin befoerdern.
        for text in ["daivento://unbekannt", "daivento://day/kein-datum", "daivento://goal/abc",
                     "https://daivento.app/today"] {
            XCTAssertFalse(state.apply(try XCTUnwrap(URL(string: text))), text)
            XCTAssertEqual(state, before, text)
        }
    }

    // MARK: - Wochenplanung

    @MainActor
    func testWeekPlanningResolvesWeeksDaysAndSundayEdge() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let week = SampleData.insertReferenceWeek(in: context)
        try context.save()

        XCTAssertEqual(WeekPlanning.week(startingAt: week.monday, in: [week])?.id, week.id)
        XCTAssertEqual(WeekPlanning.week(containing: week.monday, in: [week])?.id, week.id)

        // `sunday` ist auf den Tagesanfang normalisiert — ein Sonntag um 23:00 muss trotzdem
        // in seiner eigenen Woche liegen.
        let sundayEvening = try XCTUnwrap(AnkerCalendar.iso.date(byAdding: .hour, value: 23, to: week.sunday))
        XCTAssertTrue(WeekPlanning.contains(sundayEvening, in: week))
        let nextMonday = try XCTUnwrap(AnkerCalendar.iso.date(byAdding: .day, value: 7, to: week.monday))
        XCTAssertFalse(WeekPlanning.contains(nextMonday, in: week))

        let day = try XCTUnwrap(WeekPlanning.day(on: week.monday, in: week))
        XCTAssertTrue(AnkerCalendar.isSameDay(day.date, week.monday))
        XCTAssertEqual(WeekPlanning.day(withID: day.id, in: [week])?.id, day.id)
        XCTAssertNil(WeekPlanning.day(withID: UUID(), in: [week]))

        // Rueckfall statt nil: nach dem Zusammenfuehren doppelter Tage kann der gewaehlte Tag
        // verschwunden sein, und ohne Tag zeigt die App nur einen Spinner.
        let farAway = AnkerCalendar.date(year: 2030, month: 1, day: 1)
        XCTAssertNotNil(WeekPlanning.day(on: farAway, in: week))
    }

    @MainActor
    func testOnboardingIsNeededWhileOnlyPlaceholderGoalExists() throws {
        let container = try makeContainer()
        let context = container.mainContext

        // Ohne laufende Woche entscheidet allein das Flag.
        XCTAssertTrue(WeekPlanning.needsOnboarding(in: [], hasCompletedOnboarding: false))
        XCTAssertFalse(WeekPlanning.needsOnboarding(in: [], hasCompletedOnboarding: true))

        let week = WeekPlanning.ensureWeek(containing: Date(), weeks: [], modelContext: context)
        try context.save()

        // Laufende Woche ohne echtes Ziel: Onboarding, auch wenn das Flag gesetzt ist. Sonst
        // waere die App nach einer vollstaendigen Loeschung eine Sackgasse.
        XCTAssertTrue(WeekPlanning.needsOnboarding(in: [week], hasCompletedOnboarding: true))

        let placeholder = WeekPlanning.upsertOnboardingGoal(
            title: WeekPlanning.placeholderGoalTitle, in: week, modelContext: context
        )
        XCTAssertTrue(WeekPlanning.isPlaceholder(placeholder))
        XCTAssertFalse(WeekPlanning.isUserCreated(placeholder))
        XCTAssertTrue(WeekPlanning.needsOnboarding(in: [week], hasCompletedOnboarding: true))

        // Zweiter Durchlauf benennt den Platzhalter um statt ein zweites Ziel anzulegen —
        // sonst waere eines der vier Wochenziele unnoetig verbraucht.
        let real = WeekPlanning.upsertOnboardingGoal(title: "Echtes Ziel", in: week, modelContext: context)
        XCTAssertEqual(real.id, placeholder.id)
        XCTAssertEqual(week.goalList.count, 1)
        XCTAssertTrue(WeekPlanning.isUserCreated(real))
        XCTAssertFalse(WeekPlanning.needsOnboarding(in: [week], hasCompletedOnboarding: true))
    }

    // MARK: - Einstellungen

    func testAppearanceModeDefaultsToSystemAndRoundTrips() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "AnchorTests.\(#function)"))
        defer { defaults.removePersistentDomain(forName: "AnchorTests.\(#function)") }

        XCTAssertEqual(AppearanceMode.stored(in: defaults), .system)

        defaults.set(AppearanceMode.dark.rawValue, forKey: AppSettingsKey.appearance)
        XCTAssertEqual(AppearanceMode.stored(in: defaults), .dark)

        // Unbekannter Wert darf nicht zu einem Absturz oder zu Dunkel fuehren.
        defaults.set("sepia", forKey: AppSettingsKey.appearance)
        XCTAssertEqual(AppearanceMode.stored(in: defaults), .system)
    }

    @MainActor
    func testCloudSyncPreferenceDefaultsToEnabledUntilChosen() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "AnchorTests.\(#function)"))
        defer { defaults.removePersistentDomain(forName: "AnchorTests.\(#function)") }

        // Standard eingeschaltet: bestehende Installationen synchronisieren bereits, ein
        // stiller Wechsel auf "aus" waere aus Nutzersicht Datenverlust.
        XCTAssertTrue(CloudSyncPreference.isEnabled(in: defaults))
        XCTAssertFalse(CloudSyncPreference.hasBeenChosen(in: defaults))

        CloudSyncPreference.set(false, in: defaults)
        XCTAssertFalse(CloudSyncPreference.isEnabled(in: defaults))
        XCTAssertTrue(CloudSyncPreference.hasBeenChosen(in: defaults))

        CloudSyncPreference.set(true, in: defaults)
        XCTAssertTrue(CloudSyncPreference.isEnabled(in: defaults))
        XCTAssertTrue(CloudSyncPreference.hasBeenChosen(in: defaults))
    }

    @MainActor
    private func kinds(for query: String, in weeks: [Week]) -> [AnkerSearch.Kind] {
        var seen: [AnkerSearch.Kind] = []
        for result in AnkerSearch.results(for: query, in: weeks) where !seen.contains(result.kind) {
            seen.append(result.kind)
        }
        return seen
    }

    @MainActor
    private func decodedExport(from context: ModelContext) throws -> DataPortability.Snapshot {
        let data = try DataPortability.encodedSnapshot(from: context)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(DataPortability.Snapshot.self, from: data)
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
