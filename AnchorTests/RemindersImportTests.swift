import SwiftData
import XCTest
@testable import Anchorit

/// Import aus Apple Erinnerungen: Zuordnung (Tag, Eingang, Priorität, Doppelte) ohne EventKit,
/// Anlegen über `TaskActions` und Rückgängigmachen.
final class RemindersImportTests: XCTestCase {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, in calendar: Calendar? = nil) -> Date {
        (calendar ?? self.calendar).date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func reminder(
        _ id: String,
        _ title: String,
        due: Date? = nil,
        priority: Int = 0,
        done: Bool = false
    ) -> ReminderSnapshot {
        ReminderSnapshot(identifier: id, listIdentifier: "list", title: title, isCompleted: done, dueDate: due, priority: priority)
    }

    // MARK: - Priorität

    @MainActor
    func testHighEventKitPriorityBecomesImportant() {
        XCTAssertEqual(RemindersImportPlanner.priority(forEventKit: 0), .b)
        for high in 1...4 {
            XCTAssertEqual(RemindersImportPlanner.priority(forEventKit: high), .a)
        }
        for other in 5...9 {
            XCTAssertEqual(RemindersImportPlanner.priority(forEventKit: other), .b)
        }
    }

    // MARK: - Tag oder Eingang

    @MainActor
    func testPlacementThisAndNextWeekOnTheirDayOtherwiseInbox() {
        let now = date(2026, 11, 25, 10) // Mittwoch, KW 48

        XCTAssertEqual(RemindersImportPlanner.placement(for: nil, now: now, calendar: calendar), .inbox)
        XCTAssertEqual(RemindersImportPlanner.placement(for: date(2026, 11, 24, 9), now: now, calendar: calendar),
                       .day(date(2026, 11, 24)), "Vergangener Tag dieser Woche bleibt auf seinem Tag")
        XCTAssertEqual(RemindersImportPlanner.placement(for: date(2026, 11, 23), now: now, calendar: calendar),
                       .day(date(2026, 11, 23)), "Montag dieser Woche")
        XCTAssertEqual(RemindersImportPlanner.placement(for: date(2026, 12, 6, 23), now: now, calendar: calendar),
                       .day(date(2026, 12, 6)), "Sonntag nächster Woche")
        XCTAssertEqual(RemindersImportPlanner.placement(for: date(2026, 12, 7), now: now, calendar: calendar),
                       .inbox, "Übernächste Woche → Eingang")
        XCTAssertEqual(RemindersImportPlanner.placement(for: date(2026, 11, 22, 23), now: now, calendar: calendar),
                       .inbox, "Überfällig aus der Vorwoche → Eingang")
    }

    // MARK: - Plan

    @MainActor
    func testPlanSkipsCompletedEmptyImportedAndDuplicates() {
        let now = date(2026, 11, 25, 10)
        let reminders = [
            reminder("1", "Steuer abgeben", due: date(2026, 11, 26, 9), priority: 1),
            reminder("2", "Milch", done: true),
            reminder("3", "   "),
            reminder("4", "Schon da"),
            reminder("5", "Zahnarzt anrufen", due: date(2026, 11, 27)),
            reminder("6", "Buch lesen"),
            reminder("7", "Später", due: date(2027, 2, 1)),
        ]
        let existing: Set<ExistingTaskKey> = [
            // Gleicher Titel, anders geschrieben, am selben Tag.
            ExistingTaskKey(title: "zahnarzt Anrufen ", day: "2026-11-27"),
            // Gleicher Titel an einem anderen Tag zählt nicht als Doppel.
            ExistingTaskKey(title: "Buch lesen", day: "2026-11-25"),
        ]

        let plan = RemindersImportPlanner.plan(reminders, alreadyImported: ["4"], existing: existing, now: now, calendar: calendar)

        XCTAssertEqual(plan.entries.map(\.reminder.identifier), ["1", "6", "7"])
        XCTAssertEqual(plan.entries.first?.priority, .a)
        XCTAssertEqual(plan.entries.first?.placement, .day(date(2026, 11, 26)))
        XCTAssertEqual(plan.datedCount, 1)
        XCTAssertEqual(plan.inboxCount, 2)
        XCTAssertEqual(plan.skipped[.completed], 1)
        XCTAssertEqual(plan.skipped[.emptyTitle], 1)
        XCTAssertEqual(plan.skipped[.alreadyImported], 1)
        XCTAssertEqual(plan.skipped[.duplicate], 1)
        XCTAssertEqual(plan.skippedExisting, 2)
    }

    @MainActor
    func testInboxDuplicateMatchesTasksWithoutDay() {
        let plan = RemindersImportPlanner.plan(
            [reminder("1", "Fahrrad reparieren")],
            alreadyImported: [],
            existing: [ExistingTaskKey(title: "Fahrrad reparieren", day: nil)],
            now: date(2026, 11, 25, 10),
            calendar: calendar
        )
        XCTAssertTrue(plan.entries.isEmpty)
        XCTAssertEqual(plan.skipped[.duplicate], 1)
    }

    // MARK: - Anlegen und Rückgängig

    @MainActor
    func testPerformCreatesDayTasksAndInboxAndUndoRemovesThem() throws {
        let container = try makeContainer()
        let context = container.mainContext
        // Die App rechnet in der Ortszeit; hier ebenso, damit `ensureDay` denselben Tag trifft.
        let local = RitualReminderPlanner.currentCalendar
        let now = date(2026, 11, 25, 10, in: local)

        let plan = RemindersImportPlanner.plan(
            [
                reminder("a", "Steuer abgeben", due: date(2026, 11, 26, 9, in: local), priority: 2),
                reminder("b", "Buch lesen"),
            ],
            alreadyImported: [],
            existing: RemindersImportPlanner.existingKeys(modelContext: context, calendar: local),
            now: now,
            calendar: local
        )
        XCTAssertEqual(plan.entries.count, 2)

        let created = RemindersImportPlanner.perform(plan, modelContext: context)
        XCTAssertEqual(created.count, 2)

        let tasks = try context.fetch(FetchDescriptor<AnkerTask>())
        let dated = try XCTUnwrap(tasks.first { $0.title == "Steuer abgeben" })
        XCTAssertEqual(dated.priority, .a)
        XCTAssertNil(dated.linkedGoal)
        XCTAssertTrue(AnkerCalendar.storedDay(try XCTUnwrap(dated.day?.date), isOn: date(2026, 11, 26, 12, in: local)))

        let inbox = try XCTUnwrap(tasks.first { $0.title == "Buch lesen" })
        XCTAssertNil(inbox.day)
        XCTAssertNil(inbox.linkedGoal)
        XCTAssertEqual(inbox.priority, .b)

        // Genau eine Woche, mit genau einem Tag — nur dort, wo geschrieben wurde.
        let weeks = try context.fetch(FetchDescriptor<Week>())
        XCTAssertEqual(weeks.count, 1)
        XCTAssertEqual(weeks.first?.dayList.count, 1)

        // Ein zweiter Durchlauf findet beides als vorhanden.
        let again = RemindersImportPlanner.plan(
            [reminder("x", "Steuer abgeben", due: date(2026, 11, 26, 9, in: local)), reminder("y", "Buch lesen")],
            alreadyImported: [],
            existing: RemindersImportPlanner.existingKeys(modelContext: context, calendar: local),
            now: now,
            calendar: local
        )
        XCTAssertTrue(again.entries.isEmpty)
        XCTAssertEqual(again.skipped[.duplicate], 2)

        TaskActions.undo(
            TaskUndoNotice(message: "Import rückgängig gemacht", snapshots: created, operation: .deleteCreated),
            weeks: weeks,
            modelContext: context
        )
        XCTAssertTrue(try context.fetch(FetchDescriptor<AnkerTask>()).isEmpty)
    }

    @MainActor
    func testLedgerIsAvailableOnlyOutsideTests() {
        XCTAssertFalse(RemindersImportModel.isAvailable, "Im Testlauf keine Berechtigungsanfrage")
    }

    // MARK: - Hilfen

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(AnkerSchema.models)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
