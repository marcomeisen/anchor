import SwiftData
import XCTest
@testable import Daivento

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
        let past = TaskActions.ensureWeek(containing: AnkerCalendar.date(year: 2026, month: 7, day: 27),
                                         weeks: [], modelContext: context)
        _ = GoalActions.create(title: "Vertragsprüfung", colorHex: "#DD2B0F", in: past, modelContext: context)
        let current = TaskActions.ensureWeek(containing: AnkerCalendar.date(year: 2026, month: 8, day: 3),
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
        let week = TaskActions.ensureWeek(containing: AnkerCalendar.date(year: 2026, month: 8, day: 3),
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
        let week = TaskActions.ensureWeek(containing: AnkerCalendar.date(year: 2026, month: 8, day: 3),
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
        let week = TaskActions.ensureWeek(containing: AnkerCalendar.date(year: 2026, month: 8, day: 3),
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
        let week = TaskActions.ensureWeek(containing: AnkerCalendar.date(year: 2026, month: 8, day: 3),
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

    // MARK: - D3: nach dem Zusammenführen entschied die UUID über die sichtbaren vier

    @MainActor
    func testMergingKeepsTheRicherWeekEvenWhenItsUUIDIsHigher() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let interval = AnkerCalendar.weekInterval(containing: AnkerCalendar.date(year: 2026, month: 8, day: 3))

        // Zwei Wochen für denselben Montag — genau das entsteht, wenn ein neu installiertes Gerät
        // eine Woche anlegt, während der iCloud-Erstimport dieselbe Woche noch bringt.
        //
        // Die UUIDs sind bewusst gesetzt: die **Onboarding**-Woche hat die kleinere. Die alte
        // Wahl nahm die kleinere UUID und hätte damit den echten Bestand zur Nebensache gemacht.
        let onboarding = Week(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                              isoYear: interval.isoYear, isoWeek: interval.isoWeek,
                              monday: interval.monday, sunday: interval.sunday)
        let synced = Week(id: UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")!,
                          isoYear: interval.isoYear, isoWeek: interval.isoWeek,
                          monday: interval.monday, sunday: interval.sunday)
        context.insert(onboarding)
        context.insert(synced)

        for (index, title) in ["Echt 1", "Echt 2", "Echt 3", "Echt 4"].enumerated() {
            let goal = Goal(title: title, colorHex: "#DD2B0F", order: index, week: synced)
            context.insert(goal)
            synced.appendGoal(goal)
        }
        let day = Day(date: interval.monday, week: synced)
        context.insert(day)
        synced.days = [day]
        let task = AnkerTask(title: "Aus iCloud", priority: .b, isDone: false, order: 0, day: day)
        context.insert(task)
        day.appendTask(task)

        for (index, title) in ["Onboarding 1", "Onboarding 2"].enumerated() {
            let goal = Goal(title: title, colorHex: "#2D2B2B", order: index, week: onboarding)
            context.insert(goal)
            onboarding.appendGoal(goal)
        }
        try context.save()

        StoreMaintenance.merge(weeks: [onboarding, synced], modelContext: context, reporter: nil)

        let survivor = try XCTUnwrap(try context.fetch(FetchDescriptor<Week>()).first { !$0.isDeleted })
        XCTAssertEqual(survivor.id, synced.id, "Die inhaltsreichere Woche muss überleben")
        XCTAssertEqual(survivor.goalList.count, 6, "Zusammenführen darf nichts verlieren")

        // Das ist die Aussage des gemeldeten Fehlers: die echten Anker bleiben die sichtbaren.
        XCTAssertEqual(GoalOrdering.anchors(in: survivor).map(\.title),
                       ["Echt 1", "Echt 2", "Echt 3", "Echt 4"])
        // Der Überschuss ist sichtbar benannt, nicht verschluckt.
        XCTAssertEqual(GoalOrdering.excess(in: survivor).map(\.title),
                       ["Onboarding 1", "Onboarding 2"])
        // Lückenlos, damit die Ankernummern stabil bleiben.
        XCTAssertEqual(GoalOrdering.sorted(survivor.goalList).map(\.order), Array(0..<6))
    }

    @MainActor
    func testElectionFallsBackToTheUUIDOnEqualContent() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let interval = AnkerCalendar.weekInterval(containing: AnkerCalendar.date(year: 2026, month: 8, day: 3))

        // Gleich viel Inhalt: dann muss die Wahl trotzdem eindeutig sein, sonst führen zwei
        // Geräte dieselben Duplikate verschieden zusammen und laufen auseinander.
        let low = Week(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                       isoYear: interval.isoYear, isoWeek: interval.isoWeek,
                       monday: interval.monday, sunday: interval.sunday)
        let high = Week(id: UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")!,
                        isoYear: interval.isoYear, isoWeek: interval.isoWeek,
                        monday: interval.monday, sunday: interval.sunday)
        context.insert(low)
        context.insert(high)
        try context.save()

        StoreMaintenance.merge(weeks: [high, low], modelContext: context, reporter: nil)

        let survivor = try XCTUnwrap(try context.fetch(FetchDescriptor<Week>()).first { !$0.isDeleted })
        XCTAssertEqual(survivor.id, low.id)
    }

    // MARK: - Hilfen

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(AnkerSchema.models)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
