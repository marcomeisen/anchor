import XCTest
@testable import Anchorit

/// Erinnerungen an das Ritual: nächster Termin, Bedingungen, Kennungen, gespeicherte Einstellung.
final class RitualReminderTests: XCTestCase {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    private func key(containing date: Date) -> AnkerCalendar.WeekKey {
        RitualReminderPlanner.weekKey(containing: date, calendar: calendar)
    }

    // MARK: - Nächster Termin

    @MainActor
    func testMondayOccurrencesFollowWeekByWeek() {
        // Mittwoch, 25.11.2026, 10:00
        let now = date(2026, 11, 25, 10)
        let dates = RitualReminderPlanner.occurrences(of: .weekStart, minutes: 8 * 60, after: now, calendar: calendar)

        XCTAssertEqual(dates, [
            date(2026, 11, 30, 8), date(2026, 12, 7, 8), date(2026, 12, 14, 8), date(2026, 12, 21, 8),
        ])
    }

    @MainActor
    func testSameDayBeforeTimeCountsAndExactTimeDoesNot() {
        let before = RitualReminderPlanner.occurrences(of: .review, minutes: 18 * 60, after: date(2026, 11, 29, 17, 59), count: 1, calendar: calendar)
        XCTAssertEqual(before, [date(2026, 11, 29, 18)])

        let exact = RitualReminderPlanner.occurrences(of: .review, minutes: 18 * 60, after: date(2026, 11, 29, 18), count: 1, calendar: calendar)
        XCTAssertEqual(exact, [date(2026, 12, 6, 18)])
    }

    @MainActor
    func testOccurrencesCrossTheYearBoundary() {
        // Sonntag, 3.1.2027, gehört zu KW 53/2026.
        let dates = RitualReminderPlanner.occurrences(of: .review, minutes: 18 * 60, after: date(2026, 12, 30, 12), count: 1, calendar: calendar)
        XCTAssertEqual(dates, [date(2027, 1, 3, 18)])
        XCTAssertEqual(key(containing: dates[0]), AnkerCalendar.WeekKey(isoYear: 2026, isoWeek: 53))
    }

    // MARK: - Bedingungen

    @MainActor
    func testConditions() {
        let week = AnkerCalendar.WeekKey(isoYear: 2026, isoWeek: 48)
        let empty = RitualWeekState(key: week, hasAnchors: false, isReviewed: false)
        let planned = RitualWeekState(key: week, hasAnchors: true, isReviewed: false)
        let closed = RitualWeekState(key: week, hasAnchors: true, isReviewed: true)

        XCTAssertTrue(RitualReminderPlanner.shouldRemind(.weekStart, week: nil), "Ohne gespeicherte Woche: erinnern")
        XCTAssertTrue(RitualReminderPlanner.shouldRemind(.weekStart, week: empty))
        XCTAssertFalse(RitualReminderPlanner.shouldRemind(.weekStart, week: planned), "Anker schon gesetzt")

        XCTAssertFalse(RitualReminderPlanner.shouldRemind(.review, week: nil))
        XCTAssertFalse(RitualReminderPlanner.shouldRemind(.review, week: empty), "Ohne Anker kein Rückblick")
        XCTAssertTrue(RitualReminderPlanner.shouldRemind(.review, week: planned))
        XCTAssertFalse(RitualReminderPlanner.shouldRemind(.review, week: closed), "Schon geschlossen")
    }

    // MARK: - Planung

    @MainActor
    func testNothingIsPlannedByDefault() {
        let plan = RitualReminderPlanner.plan(settings: RitualReminderSettings(), weeks: [], now: date(2026, 11, 25, 10), calendar: calendar)
        XCTAssertTrue(plan.isEmpty)
    }

    @MainActor
    func testPlanRespectsWeekState() {
        let now = date(2026, 11, 25, 10) // KW 48
        let thisWeek = key(containing: now)
        let nextWeek = thisWeek.next
        let settings = RitualReminderSettings(weekStartEnabled: true, weekStartMinutes: 8 * 60, reviewEnabled: true, reviewMinutes: 18 * 60)
        let weeks = [
            RitualWeekState(key: thisWeek, hasAnchors: true, isReviewed: false),
            // Die nächste Woche ist schon geplant: kein Montag dafür.
            RitualWeekState(key: nextWeek, hasAnchors: true, isReviewed: false),
        ]

        let plan = RitualReminderPlanner.plan(settings: settings, weeks: weeks, now: now, calendar: calendar)
        let mondays = plan.filter { $0.kind == .weekStart }
        let sundays = plan.filter { $0.kind == .review }

        XCTAssertEqual(mondays.map(\.fireDate), [date(2026, 12, 7, 8), date(2026, 12, 14, 8), date(2026, 12, 21, 8)])
        XCTAssertEqual(sundays.map(\.fireDate), [date(2026, 11, 29, 18), date(2026, 12, 6, 18)])
        XCTAssertEqual(sundays.first?.week, thisWeek)
    }

    @MainActor
    func testReviewedWeekGetsNoSundayAndDuplicatesMerge() {
        let now = date(2026, 11, 25, 10)
        let thisWeek = key(containing: now)
        let settings = RitualReminderSettings(reviewEnabled: true)
        // Sync-Duplikat: eine Kopie geschlossen, eine offen — geschlossen gewinnt.
        let weeks = [
            RitualWeekState(key: thisWeek, hasAnchors: true, isReviewed: false),
            RitualWeekState(key: thisWeek, hasAnchors: false, isReviewed: true),
        ]
        let plan = RitualReminderPlanner.plan(settings: settings, weeks: weeks, now: now, calendar: calendar)
        XCTAssertTrue(plan.isEmpty)
    }

    @MainActor
    func testIdentifiersAreFixedAndCovered() {
        let settings = RitualReminderSettings(weekStartEnabled: true, reviewEnabled: false)
        let plan = RitualReminderPlanner.plan(settings: settings, weeks: [], now: date(2026, 11, 25, 10), calendar: calendar)

        XCTAssertEqual(plan.map(\.identifier), (0..<4).map { "anchorit.ritual.weekStart.\($0)" })
        XCTAssertTrue(Set(plan.map(\.identifier)).isSubset(of: Set(RitualReminderPlanner.allIdentifiers)))
        XCTAssertEqual(RitualReminderPlanner.allIdentifiers.count, 8)
    }

    // MARK: - Einstellungen

    @MainActor
    func testStoredSettingsDefaultToOffAndRejectBadTimes() throws {
        let suite = "RitualReminderTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        XCTAssertEqual(RitualReminderSettings.stored(in: defaults), RitualReminderSettings())
        XCTAssertEqual(RitualReminderSettings().weekStartMinutes, 8 * 60)
        XCTAssertEqual(RitualReminderSettings().reviewMinutes, 18 * 60)

        defaults.set(true, forKey: AppSettingsKey.reminderReviewEnabled)
        defaults.set(19 * 60 + 30, forKey: AppSettingsKey.reminderReviewMinutes)
        defaults.set(5000, forKey: AppSettingsKey.reminderWeekStartMinutes)
        let stored = RitualReminderSettings.stored(in: defaults)
        XCTAssertTrue(stored.reviewEnabled)
        XCTAssertEqual(stored.reviewMinutes, 19 * 60 + 30)
        XCTAssertFalse(stored.weekStartEnabled)
        XCTAssertEqual(stored.weekStartMinutes, 8 * 60, "Ungültige Uhrzeit fällt auf den Standard zurück")
    }

    @MainActor
    func testMinutesRoundTrip() {
        let day = date(2026, 11, 25)
        let picked = RitualReminderPlanner.date(fromMinutes: 7 * 60 + 45, on: day, calendar: calendar)
        XCTAssertEqual(picked, date(2026, 11, 25, 7, 45))
        XCTAssertEqual(RitualReminderPlanner.minutes(from: picked, calendar: calendar), 7 * 60 + 45)
    }

    @MainActor
    func testTestHostNeverSchedules() {
        XCTAssertTrue(RitualReminderCenter.isInactiveInThisProcess)
    }
}
