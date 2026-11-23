import SwiftData
import XCTest
@testable import Anchorit

/// Neuinstallation neben bestehendem iCloud-Bestand.
///
/// Der gemeldete Fehler: auf einem neuen Gerät liess sich das Onboarding nach dem Sync nicht
/// abbrechen, und der Bestand der anderen Geräte wurde mit den Onboarding-Inhalten überschrieben.
/// Dahinter stecken drei getrennte Defekte; jeder hat hier seinen Test.
final class OnboardingSyncTests: XCTestCase {

    // MARK: - D1: das Onboarding fragte nur die laufende Woche

    @MainActor
    func testNoOnboardingWhenEarlierWeeksAlreadyHaveAnchors() throws {
        let container = try makeContainer()
        let context = container.mainContext

        // Der Bestand eines echten Nutzers, gerade per iCloud angekommen: die Vorwoche ist
        // geplant, die laufende noch nicht — das ist am Montagmorgen der Normalfall.
        let past = TaskActions.ensureFullWeek(containing: AnkerCalendar.date(year: 2026, month: 7, day: 27),
                                         weeks: [], modelContext: context)
        _ = GoalActions.create(title: "Vertragsprüfung", colorHex: "#DD2B0F", in: past, modelContext: context)
        let current = TaskActions.ensureFullWeek(containing: AnkerCalendar.date(year: 2026, month: 8, day: 3),
                                             weeks: [past], modelContext: context)
        try context.save()

        XCTAssertTrue(current.goalList.filter(WeekPlanning.isUserCreated).isEmpty,
                      "Aufbau des Tests: die laufende Woche hat absichtlich keine Anker")

        // Vorher fuehrte genau das ins Onboarding — ohne Ausweg.
        XCTAssertFalse(
            WeekPlanning.needsOnboarding(in: [past, current], hasCompletedOnboarding: false,
                                         now: AnkerCalendar.date(year: 2026, month: 8, day: 3, hour: 9)),
            "Wer irgendwo Anker hat, ist kein neuer Nutzer"
        )
    }

    @MainActor
    func testNoOnboardingWhenOnlyTasksExist() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let week = TaskActions.ensureFullWeek(containing: AnkerCalendar.date(year: 2026, month: 8, day: 3),
                                          weeks: [], modelContext: context)
        let day = try XCTUnwrap(week.dayList.first)
        _ = TaskActions.create(title: "Ohne Anker erfasst", priority: .b, on: day,
                               linkedGoal: nil, modelContext: context)
        try context.save()

        // Wer Aufgaben ohne Anker führt, benutzt die App — auch ohne ein einziges Wochenziel.
        XCTAssertFalse(WeekPlanning.needsOnboarding(in: [week], hasCompletedOnboarding: false,
                                                    now: AnkerCalendar.date(year: 2026, month: 8, day: 3, hour: 9)))
    }

    @MainActor
    func testOnboardingStillShowsForATrulyEmptyStore() throws {
        let container = try makeContainer()
        let context = container.mainContext

        // Ganz leer: das ist der Fall, für den das Onboarding gedacht ist.
        XCTAssertTrue(WeekPlanning.needsOnboarding(in: [], hasCompletedOnboarding: false))

        // Eine leere Woche allein macht daraus keinen Bestand.
        let week = TaskActions.ensureFullWeek(containing: AnkerCalendar.date(year: 2026, month: 8, day: 3),
                                          weeks: [], modelContext: context)
        try context.save()
        XCTAssertTrue(WeekPlanning.needsOnboarding(in: [week], hasCompletedOnboarding: false,
                                                   now: AnkerCalendar.date(year: 2026, month: 8, day: 3, hour: 9)))

        // Wer bewusst übersprungen hat, wird nicht bei jedem Start erneut gefragt.
        XCTAssertFalse(WeekPlanning.needsOnboarding(in: [week], hasCompletedOnboarding: true,
                                                    now: AnkerCalendar.date(year: 2026, month: 8, day: 3, hour: 9)))
    }

    @MainActor
    func testPlaceholderAloneDoesNotCountAsContent() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let week = TaskActions.ensureFullWeek(containing: AnkerCalendar.date(year: 2026, month: 8, day: 3),
                                          weeks: [], modelContext: context)
        WeekPlanning.upsertOnboardingGoal(title: WeekPlanning.placeholderGoalTitle, in: week, modelContext: context)
        try context.save()

        XCTAssertTrue(WeekPlanning.needsOnboarding(in: [week], hasCompletedOnboarding: false,
                                                   now: AnkerCalendar.date(year: 2026, month: 8, day: 3, hour: 9)),
                      "Der Platzhalter ist kein Bestand")
    }

    // MARK: - D2: das Onboarding lief in einen laufenden Erstimport hinein

    @MainActor
    func testOnboardingAnchorsAreNotAddedOnTopOfSyncedOnes() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let week = TaskActions.ensureFullWeek(containing: AnkerCalendar.date(year: 2026, month: 8, day: 3),
                                          weeks: [], modelContext: context)
        let existing = try XCTUnwrap(GoalActions.create(title: "Aus iCloud", colorHex: "#DD2B0F",
                                                       in: week, modelContext: context))
        try context.save()

        // Das Rennen: das Onboarding stand offen, waehrenddessen kam der Import an, dann tippte
        // der Nutzer auf „Weiter". Ohne Gegenpruefung entstuenden fuenf Anker aus vier Eingaben.
        let created = WeekPlanning.createOnboardingAnchors(
            ["Neu 1", "Neu 2", "Neu 3", "Neu 4"], in: week, modelContext: context
        )

        XCTAssertTrue(created.isEmpty, "Bei vorhandenen Ankern darf das Onboarding nichts anlegen")
        XCTAssertEqual(week.goalList.map(\.id), [existing.id])
    }

    // MARK: - D3: Zusammenführen muss auf allen Geräten dasselbe Ergebnis haben

    /// Die kleinste UUID überlebt — **auch** wenn die andere Kopie mehr Inhalt hat.
    ///
    /// Vorher gewann die inhaltsreichere Kopie. Inhalt wird aber lokal gezählt, und mitten in
    /// einem Import sehen zwei Geräte dieselben Kopien verschieden schwer: jedes löschte die
    /// andere. Die Aussage dieses Tests ist deshalb zweiteilig: die UUID entscheidet, und die
    /// benutzten Anker bleiben trotzdem die sichtbaren vier.
    @MainActor
    func testMergingKeepsSmallestUUIDAndUsedAnchorsStayVisible() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let interval = AnkerCalendar.weekInterval(containing: AnkerCalendar.date(year: 2026, month: 8, day: 3))

        let onboarding = Week(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                              isoYear: interval.isoYear, isoWeek: interval.isoWeek,
                              monday: interval.monday, sunday: interval.sunday)
        let synced = Week(id: UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")!,
                          isoYear: interval.isoYear, isoWeek: interval.isoWeek,
                          monday: interval.monday, sunday: interval.sunday)
        context.insert(onboarding)
        context.insert(synced)

        let day = Day(date: interval.monday, week: synced)
        context.insert(day)
        synced.days = [day]
        for (index, title) in ["Echt 1", "Echt 2", "Echt 3", "Echt 4"].enumerated() {
            let goal = Goal(title: title, colorHex: "#DD2B0F", order: index, week: synced)
            // Benutzt heißt: Felder des Datensatzes selbst (hier das Warum), nicht seine
            // lokal sichtbaren Aufgaben — siehe `StoreMaintenance.usageRank`.
            goal.why = "Weil \(title) zählt"
            context.insert(goal)
            synced.appendGoal(goal)
            let task = AnkerTask(title: "Aufgabe \(index)", priority: .b, order: index, day: day, linkedGoal: goal)
            context.insert(task)
            day.appendTask(task)
        }

        for (index, title) in ["Onboarding 1", "Onboarding 2"].enumerated() {
            let goal = Goal(title: title, colorHex: "#2D2B2B", order: index, week: onboarding)
            context.insert(goal)
            onboarding.appendGoal(goal)
        }
        try context.save()

        StoreMaintenance.merge(weeks: [synced, onboarding], modelContext: context, reporter: nil)

        let survivor = try XCTUnwrap(try context.fetch(FetchDescriptor<Week>()).first { !$0.isDeleted })
        XCTAssertEqual(survivor.id, onboarding.id, "Die kleinste UUID muss überleben, unabhängig vom Inhalt")
        XCTAssertEqual(survivor.goalList.count, 6, "Zusammenführen darf nichts verlieren")
        XCTAssertEqual(survivor.dayList.flatMap(\.taskList).count, 4)
        XCTAssertEqual(GoalOrdering.anchors(in: survivor).map(\.title),
                       ["Echt 1", "Echt 2", "Echt 3", "Echt 4"])
        XCTAssertEqual(GoalOrdering.excess(in: survivor).map(\.title),
                       ["Onboarding 1", "Onboarding 2"])
        XCTAssertEqual(GoalOrdering.sorted(survivor.goalList).map(\.order), Array(0..<6))
    }

    /// Zwei Geräte, die dieselben Kopien in verschiedenem Importzustand sehen, wählen
    /// denselben Gewinner.
    @MainActor
    func testElectionIgnoresLocallyVisibleContent() throws {
        let interval = AnkerCalendar.weekInterval(containing: AnkerCalendar.date(year: 2026, month: 8, day: 3))
        let lowID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let highID = UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")!

        var survivors: [UUID] = []
        for fullCopy in [lowID, highID] {
            let container = try makeContainer()
            let context = container.mainContext
            let low = Week(id: lowID, isoYear: interval.isoYear, isoWeek: interval.isoWeek,
                           monday: interval.monday, sunday: interval.sunday)
            let high = Week(id: highID, isoYear: interval.isoYear, isoWeek: interval.isoWeek,
                            monday: interval.monday, sunday: interval.sunday)
            context.insert(low)
            context.insert(high)
            // Auf diesem „Gerät" ist nur eine der beiden Kopien schon vollständig importiert.
            let full = fullCopy == lowID ? low : high
            let day = Day(date: interval.monday, week: full)
            context.insert(day)
            full.days = [day]
            let task = AnkerTask(title: "Inhalt", priority: .b, order: 0, day: day)
            context.insert(task)
            day.appendTask(task)
            try context.save()

            StoreMaintenance.merge(weeks: [low, high], modelContext: context, reporter: nil)
            let survivor = try XCTUnwrap(try context.fetch(FetchDescriptor<Week>()).first { !$0.isDeleted })
            survivors.append(survivor.id)
            XCTAssertEqual(try context.fetch(FetchDescriptor<AnkerTask>()).count, 1, "Nichts darf verloren gehen")
        }

        XCTAssertEqual(survivors, [lowID, lowID], "Beide Geräte müssen dieselbe Kopie behalten")
    }

    /// Kommt die Löschung der doppelten Woche an, bevor dieses Gerät ihre Tage umgehängt hat,
    /// bleiben die Tage als Waisen stehen — und werden wieder eingehängt, sobald es die Woche
    /// (in ihrer überlebenden Kopie) gibt. Angelegt wird sie dafür **nicht**: ein abgebrochener
    /// Import brächte sonst neben der noch kommenden echten Woche ein Duplikat hervor.
    @MainActor
    func testDeletingAWeekKeepsItsDaysAndMaintenanceAdoptsThem() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let date = AnkerCalendar.date(year: 2026, month: 8, day: 4)
        let week = TaskActions.ensureWeek(containing: date, weeks: [], modelContext: context)
        let day = TaskActions.ensureDay(containing: date, in: week)
        let task = AnkerTask(title: "Überlebt", priority: .b, order: 0, day: day)
        context.insert(task)
        day.appendTask(task)
        try context.save()

        // So wirkt eine Löschung, die von einem anderen Gerät kommt.
        context.delete(week)
        try context.save()

        let orphan = try XCTUnwrap(try context.fetch(FetchDescriptor<Day>()).first)
        XCTAssertNil(orphan.week, "Mit `.nullify` bleibt der Tag als Waise erhalten")
        XCTAssertEqual(orphan.taskList.map(\.title), ["Überlebt"])

        let waiting = StoreMaintenance.run(modelContext: context, reporter: nil)
        XCTAssertEqual(waiting.adoptedOrphans, 0)
        XCTAssertTrue(try context.fetch(FetchDescriptor<Week>()).isEmpty, "Keine Woche anlegen, nur um eine Waise einzuhängen")

        // Die überlebende Kopie kommt an.
        _ = TaskActions.ensureWeek(containing: date, weeks: [], modelContext: context)
        try context.save()
        let report = StoreMaintenance.run(modelContext: context, reporter: nil)
        XCTAssertEqual(report.adoptedOrphans, 1)
        let adopted = try XCTUnwrap(try context.fetch(FetchDescriptor<Day>()).first)
        let home = try XCTUnwrap(adopted.week)
        XCTAssertEqual(home.isoWeek, AnkerCalendar.weekKey(containing: date).isoWeek)
        XCTAssertEqual(adopted.taskList.map(\.title), ["Überlebt"])
    }

    /// Ein Tag, den ein Gerät eine Stunde östlich angelegt hat, gehört trotzdem zu seinem Tag.
    func testStoredDayFromAnEasternZoneMapsToTheSameDay() throws {
        var berlin = Calendar(identifier: .iso8601)
        berlin.timeZone = try XCTUnwrap(TimeZone(identifier: "Europe/Berlin"))
        var london = Calendar(identifier: .iso8601)
        london.timeZone = try XCTUnwrap(TimeZone(identifier: "Europe/London"))

        let berlinMonday = try XCTUnwrap(berlin.date(from: DateComponents(year: 2026, month: 8, day: 3)))
        // In London ist das noch Sonntag 23 Uhr.
        XCTAssertFalse(london.isDate(berlinMonday, inSameDayAs: london.date(from: DateComponents(year: 2026, month: 8, day: 3))!))

        let nominal = AnkerCalendar.nominalDay(ofStored: berlinMonday, calendar: london)
        XCTAssertEqual([nominal.year, nominal.month, nominal.day], [2026, 8, 3])
    }

    /// Wochen entstehen erst beim Schreiben — und dann ohne die sieben Tage.
    @MainActor
    func testEnsureWeekCreatesNoDaysAndEnsureDayCreatesExactlyOne() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let date = AnkerCalendar.date(year: 2026, month: 8, day: 5)
        let week = TaskActions.ensureWeek(containing: date, weeks: [], modelContext: context)
        XCTAssertTrue(week.dayList.isEmpty)

        let day = TaskActions.ensureDay(containing: date, in: week)
        XCTAssertEqual(week.dayList.count, 1)
        XCTAssertTrue(TaskActions.ensureDay(containing: date, in: week) === day, "Kein zweiter Tag für dasselbe Datum")
    }

    /// Aufgaben ohne Tag: einplanen, ausplanen, rückgängig machen.
    @MainActor
    func testUnscheduledTasksRoundTrip() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let date = AnkerCalendar.date(year: 2026, month: 8, day: 5)
        let week = TaskActions.ensureWeek(containing: date, weeks: [], modelContext: context)
        let goal = Goal(title: "Laufen", colorHex: "#000000", order: 0, week: week)
        context.insert(goal)
        week.appendGoal(goal)

        let task = try XCTUnwrap(TaskActions.createUnscheduled(title: "Schuhe kaufen", goal: goal, modelContext: context))
        XCTAssertNil(task.day)
        XCTAssertEqual(TaskActions.unscheduledTasks(in: week).map(\.id), [task.id])
        XCTAssertTrue(TaskActions.inboxTasks(modelContext: context).isEmpty)

        TaskActions.move(task, to: date, weeks: [week], modelContext: context)
        XCTAssertNotNil(task.day)
        XCTAssertEqual(task.linkedGoal?.id, goal.id, "Einplanen in derselben Woche behält den Anker")

        TaskActions.unschedule(task, modelContext: context)
        XCTAssertNil(task.day)

        let inbox = try XCTUnwrap(TaskActions.createUnscheduled(title: "Arzttermin", goal: nil, modelContext: context))
        XCTAssertEqual(TaskActions.inboxTasks(modelContext: context).map(\.id), [inbox.id])
        let inboxSnapshot = TaskActions.snapshot(inbox)
        TaskActions.delete(inbox, modelContext: context)
        TaskActions.restore([inboxSnapshot], weeks: [week], modelContext: context)
        XCTAssertEqual(TaskActions.inboxTasks(modelContext: context).map(\.title), ["Arzttermin"],
                       "Löschen einer Aufgabe ohne Tag muss rückgängig zu machen sein")
    }

    // MARK: - Hilfen

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(AnkerSchema.models)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
