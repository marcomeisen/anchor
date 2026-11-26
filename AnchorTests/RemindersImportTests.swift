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
        done: Bool = false,
        in calendar: Calendar? = nil
    ) -> ReminderSnapshot {
        let calendar = calendar ?? self.calendar
        let components = due.map {
            var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: $0)
            components.timeZone = calendar.timeZone
            return components
        }
        return ReminderSnapshot(
            identifier: id, listIdentifier: "list", title: title, isCompleted: done,
            details: ImportedReminderDetails(dueDate: components, notes: nil, url: nil),
            priority: priority
        )
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
        let existing = ExistingReminderTasks(byTitleAndDay: [
            // Gleicher Titel, anders geschrieben, am selben Tag.
            ExistingTaskKey(title: "zahnarzt Anrufen ", day: "2026-11-27"): [UUID()],
            // Gleicher Titel an einem anderen Tag zählt nicht als Doppel.
            ExistingTaskKey(title: "Buch lesen", day: "2026-11-25"): [UUID()],
        ])

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
            existing: ExistingReminderTasks(byTitleAndDay: [ExistingTaskKey(title: "Fahrrad reparieren", day: nil): [UUID()]]),
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
                reminder("a", "Steuer abgeben", due: date(2026, 11, 26, 9, in: local), priority: 2, in: local),
                reminder("b", "Buch lesen"),
            ],
            alreadyImported: [],
            existing: try RemindersImportPlanner.existingTasks(modelContext: context, calendar: local),
            now: now,
            calendar: local
        )
        XCTAssertEqual(plan.entries.count, 2)

        let created = try XCTUnwrap(RemindersImportPlanner.perform(plan, modelContext: context)).created
        XCTAssertEqual(created.count, 2)

        let tasks = try context.fetch(FetchDescriptor<AnkerTask>())
        let dated = try XCTUnwrap(tasks.first { $0.title == "Steuer abgeben" })
        XCTAssertEqual(dated.priority, .a)
        XCTAssertEqual(dated.importedReminder?.dueDate?.hour, 9)
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
            existing: try RemindersImportPlanner.existingTasks(modelContext: context, calendar: local),
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
    func testInboxPreservesOriginalDetailsThroughSaveAndUndo() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let details = ImportedReminderDetails(
            dueDate: DateComponents(timeZone: TimeZone(identifier: "America/New_York"), year: 2027, month: 2, day: 1, hour: 0, minute: 30),
            notes: "Unterlagen prüfen\nRückfragen aufschreiben",
            url: URL(string: "https://example.com/unterlagen")
        )
        let reminder = ReminderSnapshot(identifier: "1", listIdentifier: "list", title: "Abgabe", details: details)
        let plan = RemindersImportPlanner.plan(
            [reminder], alreadyImported: [], existing: ExistingReminderTasks(), now: date(2026, 11, 25), calendar: calendar
        )
        XCTAssertEqual(plan.entries.first?.placement, .inbox)
        XCTAssertEqual(details.date(in: calendar.timeZone), calendar.date(from: DateComponents(year: 2027, month: 2, day: 1, hour: 6, minute: 30)))
        XCTAssertFalse(details.isAllDay)

        let snapshots = try XCTUnwrap(RemindersImportPlanner.perform(plan, modelContext: context)).created
        let reader = ModelContext(container)
        let task = try XCTUnwrap(reader.fetch(FetchDescriptor<AnkerTask>()).first)
        XCTAssertNil(task.day)
        var expected = details
        expected.sourceIdentifier = reminder.identifier
        XCTAssertEqual(task.importedReminder, expected)
        XCTAssertEqual(try DataPortability.snapshot(from: reader).unassigned.tasks.first?.importedReminder, expected)

        let original = try XCTUnwrap(context.fetch(FetchDescriptor<AnkerTask>()).first)
        TaskActions.delete(original, modelContext: context)
        TaskActions.restore(snapshots, weeks: [], modelContext: context)
        XCTAssertEqual(try context.fetch(FetchDescriptor<AnkerTask>()).first?.importedReminder, expected)
    }

    @MainActor
    func testAllDayReminderStaysOnItsCalendarDay() {
        let details = ImportedReminderDetails(
            dueDate: DateComponents(timeZone: TimeZone(identifier: "Pacific/Tongatapu"), year: 2026, month: 11, day: 23),
            notes: nil,
            url: nil
        )
        XCTAssertTrue(details.isAllDay)
        XCTAssertEqual(details.date(in: calendar.timeZone), date(2026, 11, 23))
        XCTAssertNotNil(AnkerDateFormat.reminderDueDate(details))
    }

    @MainActor
    func testReimportUpdatesTheSameTaskAndUndoRestoresItsImportFields() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let local = RitualReminderPlanner.currentCalendar
        let now = date(2026, 11, 25, in: local)
        let original = reminder("original", "Abgabe", due: now, in: local)
        let firstPlan = RemindersImportPlanner.plan(
            [original], alreadyImported: [], existing: ExistingReminderTasks(), now: now, calendar: local
        )
        let first = try XCTUnwrap(RemindersImportPlanner.perform(firstPlan, modelContext: context))
        let originalID = try XCTUnwrap(first.created.first?.id)
        let task = try XCTUnwrap(context.fetch(FetchDescriptor<AnkerTask>()).first)
        let planningDay = task.day?.id
        TaskActions.toggleDone(task, modelContext: context)

        let updatedDetails = ImportedReminderDetails(dueDate: nil, notes: "Neue Angaben", url: nil)
        let changed = ReminderSnapshot(identifier: "original", listIdentifier: "list", title: "Neue Abgabe", details: updatedDetails, priority: 1)
        let added = reminder("new", "Unterlagen lesen")
        let existing = try RemindersImportPlanner.existingTasks(modelContext: context, calendar: local)
        let standard = RemindersImportPlanner.plan([changed], alreadyImported: [], existing: existing, now: now, calendar: local)
        XCTAssertEqual(standard.skipped[.alreadyImported], 1)
        let replace = RemindersImportPlanner.plan(
            [changed, added], alreadyImported: ["original"], existing: existing, overwritesExisting: true, now: now, calendar: local
        )
        XCTAssertEqual(replace.updatedCount, 1)
        XCTAssertEqual(replace.inboxCount, 1)
        let result = try XCTUnwrap(RemindersImportPlanner.perform(replace, modelContext: context))
        XCTAssertEqual(result.updated.map(\.id), [originalID])
        XCTAssertEqual(result.created.count, 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<AnkerTask>()), 2)
        XCTAssertEqual(task.title, "Neue Abgabe")
        XCTAssertEqual(task.priority, .a)
        XCTAssertNil(task.importedReminder?.dueDate)
        XCTAssertEqual(task.importedReminder?.notes, "Neue Angaben")
        XCTAssertEqual(task.day?.id, planningDay)
        XCTAssertTrue(task.isDone)

        XCTAssertTrue(RemindersImportPlanner.undo(result, modelContext: context))
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<AnkerTask>()), 1)
        XCTAssertEqual(task.title, "Abgabe")
        XCTAssertEqual(task.importedReminder?.dueDate, original.details.dueDate)
        XCTAssertEqual(task.day?.id, planningDay)
        XCTAssertTrue(task.isDone)
    }

    @MainActor
    func testOverwriteSkipsLegacyHistoryWithASingleSameTitleTask() {
        let key = ExistingTaskKey(title: "Buch lesen", day: nil)
        let id = UUID()
        let existing = ExistingReminderTasks(byTitleAndDay: [key: [id]])
        let source = reminder("legacy", "Buch lesen")
        let now = date(2026, 11, 25)
        let legacy = RemindersImportPlanner.plan(
            [source], alreadyImported: ["legacy"], existing: existing, overwritesExisting: true, now: now, calendar: calendar
        )
        XCTAssertTrue(legacy.entries.isEmpty)
        XCTAssertEqual(legacy.skipped[.unmatchedUpdate], 1)

        let unrelated = RemindersImportPlanner.plan(
            [source], alreadyImported: [], existing: existing, overwritesExisting: true, now: now, calendar: calendar
        )
        XCTAssertTrue(unrelated.entries.isEmpty)
        XCTAssertEqual(unrelated.skipped[.unmatchedUpdate], 1)
    }

    @MainActor
    func testOverwriteRequiresVerifiedExternalIdentifier() {
        let id = UUID()
        let existing = ExistingReminderTasks(byExternalIdentifier: ["sync-id": [id]])
        let source = ReminderSnapshot(
            identifier: "device-id", externalIdentifier: "sync-id", listIdentifier: "list", title: "Buch lesen",
            details: ImportedReminderDetails(dueDate: nil, notes: nil, url: nil)
        )
        let now = date(2026, 11, 25)
        let unverified = RemindersImportPlanner.plan(
            [source], alreadyImported: [], existing: existing, overwritesExisting: true, now: now, calendar: calendar
        )
        XCTAssertTrue(unverified.entries.isEmpty)
        XCTAssertEqual(unverified.skipped[.unmatchedUpdate], 1)

        let verified = RemindersImportPlanner.plan(
            [source], alreadyImported: [], existing: existing, overwritesExisting: true,
            verifiesExternalIdentifier: { $0.identifier == source.identifier }, now: now, calendar: calendar
        )
        XCTAssertEqual(verified.entries.first?.updateTaskID, id)
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
