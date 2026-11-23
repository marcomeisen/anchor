import Combine
import CoreData
import Foundation
import OSLog
import SwiftData
import SwiftUI
import UserNotifications
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

private let ritualReminderLog = Logger(subsystem: "com.marcomeisen.Anchor", category: "RitualReminders")

// MARK: - Die zwei Erinnerungen

/// Die zwei Erinnerungen an das Ritual: Montag „Anker setzen", Sonntag „Rückblick".
nonisolated enum RitualReminderKind: String, CaseIterable, Sendable {
    case weekStart
    case review

    /// `Calendar.weekday`: 1 = Sonntag, 2 = Montag — unabhängig vom ersten Wochentag.
    var weekday: Int {
        switch self {
        case .weekStart: 2
        case .review: 1
        }
    }

    /// Minuten nach Mitternacht: 8:00 bzw. 18:00.
    var defaultMinutes: Int {
        switch self {
        case .weekStart: 8 * 60
        case .review: 18 * 60
        }
    }

    /// Feste Kennungen je Termin (`….0` bis `….3`). Neu planen heißt: alle mit diesem Präfix
    /// entfernen und neu anlegen — fremde Benachrichtigungen bleiben unberührt.
    var identifierPrefix: String { "anchorit.ritual.\(rawValue)." }

    /// Wohin ein Tippen auf die Benachrichtigung führt. Den Rückblick öffnet `AnkerRootView`
    /// für `anchorit://review` als Blatt; für das Setzen gibt es keinen eigenen Link, die Woche
    /// zeigt den Weg dorthin.
    var deepLink: String {
        switch self {
        case .weekStart: "anchorit://week"
        case .review: "anchorit://review"
        }
    }

    var enabledKey: String {
        switch self {
        case .weekStart: AppSettingsKey.reminderWeekStartEnabled
        case .review: AppSettingsKey.reminderReviewEnabled
        }
    }

    var minutesKey: String {
        switch self {
        case .weekStart: AppSettingsKey.reminderWeekStartMinutes
        case .review: AppSettingsKey.reminderReviewMinutes
        }
    }
}

/// Was eingeschaltet ist und wann. Standard: beide aus.
nonisolated struct RitualReminderSettings: Equatable, Sendable {
    var weekStartEnabled = false
    var weekStartMinutes = RitualReminderKind.weekStart.defaultMinutes
    var reviewEnabled = false
    var reviewMinutes = RitualReminderKind.review.defaultMinutes

    func isEnabled(_ kind: RitualReminderKind) -> Bool {
        switch kind {
        case .weekStart: weekStartEnabled
        case .review: reviewEnabled
        }
    }

    func minutes(_ kind: RitualReminderKind) -> Int {
        switch kind {
        case .weekStart: weekStartMinutes
        case .review: reviewMinutes
        }
    }

    var anyEnabled: Bool { weekStartEnabled || reviewEnabled }

    static func stored(in defaults: UserDefaults = .standard) -> RitualReminderSettings {
        func minutes(_ kind: RitualReminderKind) -> Int {
            guard let value = defaults.object(forKey: kind.minutesKey) as? Int,
                  (0..<(24 * 60)).contains(value) else { return kind.defaultMinutes }
            return value
        }
        return RitualReminderSettings(
            weekStartEnabled: defaults.bool(forKey: RitualReminderKind.weekStart.enabledKey),
            weekStartMinutes: minutes(.weekStart),
            reviewEnabled: defaults.bool(forKey: RitualReminderKind.review.enabledKey),
            reviewMinutes: minutes(.review)
        )
    }
}

// MARK: - Planung als reine Rechnung

/// Der Zustand einer Woche, so weit die Erinnerungen ihn brauchen — ein Abbild ohne SwiftData.
nonisolated struct RitualWeekState: Equatable, Sendable {
    let key: AnkerCalendar.WeekKey
    /// Mindestens ein echter Anker (kein Onboarding-Platzhalter).
    var hasAnchors: Bool
    /// „Woche schließen" ist erfolgt.
    var isReviewed: Bool
}

/// Eine geplante Benachrichtigung.
nonisolated struct PlannedRitualReminder: Equatable, Sendable {
    let kind: RitualReminderKind
    let identifier: String
    let fireDate: Date
    let week: AnkerCalendar.WeekKey
}

/// Wann und ob erinnert wird — ohne `UserNotifications`, damit es testbar ist.
///
/// **Einmalige statt wiederholender Auslöser.** Lokale Benachrichtigungen sind fest geplant;
/// ein wöchentlich wiederholender Auslöser kann nicht fragen, ob die Woche schon Anker hat.
/// Deshalb plant die App die nächsten `horizonWeeks` Termine einzeln, jeden nur, wenn seine
/// Bedingung **jetzt** erfüllt ist, und plant neu bei jedem Start, bei jedem Wechsel in den
/// Vordergrund und nach jedem Speichern (`RitualReminderCenter`). Vier Wochen Vorrat, damit die
/// Montags-Erinnerung auch dann weiterkommt, wenn die App eine Weile nicht geöffnet wird.
///
/// - Montag: nur, solange die Woche dieses Montags keine Anker hat.
/// - Sonntag: nur, wenn die Woche Anker hat und noch nicht geschlossen ist. Künftige Wochen
///   haben in der Regel noch keine Anker — praktisch plant das nur den nächsten Sonntag. Das
///   genügt: Anker entstehen in der App, und jedes Speichern plant neu.
nonisolated enum RitualReminderPlanner {
    static let horizonWeeks = 4

    /// Die nächsten `count` Termine streng nach `now`, in der Ortszeit von `calendar`.
    static func occurrences(
        of kind: RitualReminderKind,
        minutes: Int,
        after now: Date,
        count: Int = horizonWeeks,
        calendar: Calendar
    ) -> [Date] {
        let clamped = min(max(minutes, 0), 24 * 60 - 1)
        let components = DateComponents(hour: clamped / 60, minute: clamped % 60, weekday: kind.weekday)
        var dates: [Date] = []
        var cursor = now
        while dates.count < count,
              let next = calendar.nextDate(after: cursor, matching: components, matchingPolicy: .nextTime) {
            dates.append(next)
            cursor = next
        }
        return dates
    }

    /// Soll für diese Woche erinnert werden?
    static func shouldRemind(_ kind: RitualReminderKind, week: RitualWeekState?) -> Bool {
        switch kind {
        case .weekStart:
            return !(week?.hasAnchors ?? false)
        case .review:
            guard let week else { return false }
            return week.hasAnchors && !week.isReviewed
        }
    }

    static func plan(
        settings: RitualReminderSettings,
        weeks: [RitualWeekState],
        now: Date,
        calendar: Calendar
    ) -> [PlannedRitualReminder] {
        let byKey = Dictionary(weeks.map { ($0.key, $0) }, uniquingKeysWith: merge)

        return RitualReminderKind.allCases.flatMap { kind -> [PlannedRitualReminder] in
            guard settings.isEnabled(kind) else { return [] }
            return occurrences(of: kind, minutes: settings.minutes(kind), after: now, calendar: calendar)
                .enumerated()
                .compactMap { index, date in
                    let key = weekKey(containing: date, calendar: calendar)
                    guard shouldRemind(kind, week: byKey[key]) else { return nil }
                    return PlannedRitualReminder(
                        kind: kind,
                        identifier: kind.identifierPrefix + String(index),
                        fireDate: date,
                        week: key
                    )
                }
        }
    }

    /// Alle Kennungen, die die App je vergeben kann — zum vollständigen Entfernen.
    static var allIdentifiers: [String] {
        RitualReminderKind.allCases.flatMap { kind in
            (0..<horizonWeeks).map { kind.identifierPrefix + String($0) }
        }
    }

    /// Zwei Kopien derselben Woche (Sync-Duplikat vor dem Aufräumen): Anker zählen, wenn eine
    /// Kopie sie hat, geschlossen ist sie, wenn eine Kopie geschlossen ist.
    static func merge(_ lhs: RitualWeekState, _ rhs: RitualWeekState) -> RitualWeekState {
        RitualWeekState(key: lhs.key, hasAnchors: lhs.hasAnchors || rhs.hasAnchors, isReviewed: lhs.isReviewed || rhs.isReviewed)
    }

    static func weekKey(containing date: Date, calendar: Calendar) -> AnkerCalendar.WeekKey {
        let interval = AnkerCalendar.weekInterval(containing: date, calendar: calendar)
        return AnkerCalendar.WeekKey(isoYear: interval.isoYear, isoWeek: interval.isoWeek)
    }

    /// Ein ISO-Kalender in der **aktuellen** Zone. Nicht `AnkerCalendar.iso`: dessen Zone ist beim
    /// Start festgeschrieben, und nach einer Reise läge die Erinnerung sonst um Stunden daneben.
    static var currentCalendar: Calendar {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .current
        calendar.locale = .current
        return calendar
    }

    static func minutes(from date: Date, calendar: Calendar) -> Int {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    static func date(fromMinutes minutes: Int, on day: Date, calendar: Calendar) -> Date {
        let start = calendar.startOfDay(for: day)
        return calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: start) ?? start
    }
}

// MARK: - Die Verbindung zum System

/// Plant die Erinnerungen bei `UNUserNotificationCenter` und hält sie aktuell.
///
/// Neu geplant wird beim Start, beim Wechsel in den Vordergrund, nach jedem Speichern eines
/// Kontexts und nach Änderungen aus iCloud — gebündelt über eine kurze Pause. Die Texte werden
/// beim Planen in der laufenden Sprache festgeschrieben; ein Sprachwechsel braucht ohnehin
/// einen Neustart, und der plant neu.
///
/// Im Testlauf und im UI-Testmodus fragt sie nie nach der Berechtigung und plant nichts.
@MainActor
final class RitualReminderCenter: ObservableObject {
    static let shared = RitualReminderCenter()

    @Published private(set) var authorization: UNAuthorizationStatus = .notDetermined

    /// Ausdrücklich verweigert — der Hinweis in den Einstellungen hängt daran.
    var isDenied: Bool { authorization == .denied }

    private weak var container: ModelContainer?
    private var observers: [AnyCancellable] = []
    private var pending: Task<Void, Never>?

    private init() {}

    /// Unit-Test-Host und UI-Testmodus: keine Anfrage, keine Planung.
    static var isInactiveInThisProcess: Bool {
#if DEBUG
        if UITestMode.isActive { return true }
#endif
        return CloudSyncConfiguration.isRunningTests
    }

    private var center: UNUserNotificationCenter { UNUserNotificationCenter.current() }

    /// Einmal beim Start; ein neu aufgebauter Store ersetzt den alten.
    func start(container: ModelContainer) {
        guard !Self.isInactiveInThisProcess else { return }
        self.container = container
        center.delegate = RitualNotificationDelegate.shared

        if observers.isEmpty {
            let saves = NotificationCenter.default.publisher(for: ModelContext.didSave).map { _ in () }
            let remote = NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange).map { _ in () }
            let day = NotificationCenter.default.publisher(for: .NSCalendarDayChanged).map { _ in () }
            observers.append(
                saves.merge(with: remote, day)
                    .receive(on: RunLoop.main)
                    .sink { [weak self] in self?.scheduleSoon() }
            )
        }
        scheduleSoon(delay: .zero)
    }

    /// Bündelt Serien von Änderungen (ein Import speichert pro Aufgabe).
    func scheduleSoon(delay: Duration = .seconds(1)) {
        guard !Self.isInactiveInThisProcess else { return }
        pending?.cancel()
        pending = Task { [weak self] in
            if delay > .zero {
                try? await Task.sleep(for: delay)
            }
            guard !Task.isCancelled else { return }
            await self?.reschedule()
        }
    }

    func refreshAuthorization() async {
        guard !Self.isInactiveInThisProcess else { return }
        authorization = await center.notificationSettings().authorizationStatus
    }

    /// Fragt nur, wenn noch nie gefragt wurde. Gibt zurück, ob Benachrichtigungen erlaubt sind.
    func requestAuthorizationIfNeeded() async -> Bool {
        guard !Self.isInactiveInThisProcess else { return false }
        await refreshAuthorization()
        switch authorization {
        case .authorized, .provisional:
            return true
        case .notDetermined:
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
            await refreshAuthorization()
            return granted
        default:
            return false
        }
    }

    func reschedule() async {
        guard !Self.isInactiveInThisProcess else { return }
        let settings = RitualReminderSettings.stored()

        center.removePendingNotificationRequests(withIdentifiers: RitualReminderPlanner.allIdentifiers)
        guard settings.anyEnabled else { return }

        await refreshAuthorization()
        guard authorization == .authorized || authorization == .provisional else {
            return
        }

        let calendar = RitualReminderPlanner.currentCalendar
        let planned = RitualReminderPlanner.plan(
            settings: settings,
            weeks: weekStates(),
            now: Date(),
            calendar: calendar
        )

        for reminder in planned {
            let request = UNNotificationRequest(
                identifier: reminder.identifier,
                content: Self.content(for: reminder.kind),
                trigger: UNCalendarNotificationTrigger(
                    dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.fireDate),
                    repeats: false
                )
            )
            do {
                try await center.add(request)
            } catch {
                ritualReminderLog.error("Erinnerung nicht geplant: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Frischer Fetch statt `@Query`-Schnappschuss — der Planer läuft auch ohne sichtbare View.
    private func weekStates() -> [RitualWeekState] {
        guard let context = container?.mainContext,
              let weeks = try? context.fetch(FetchDescriptor<Week>()) else { return [] }
        return weeks.filter { !$0.isDeleted }.map { week in
            RitualWeekState(
                key: AnkerCalendar.WeekKey(isoYear: week.isoYear, isoWeek: week.isoWeek),
                hasAnchors: !GoalOrdering.countableAnchors(in: week).isEmpty,
                isReviewed: week.isReviewed
            )
        }
    }

    static func content(for kind: RitualReminderKind) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        switch kind {
        case .weekStart:
            content.title = String(localized: "Anker setzen")
            content.body = String(localized: "Was zählt diese Woche? Bis zu vier Anker, jeder mit einem Satz, warum.")
        case .review:
            content.title = String(localized: "Rückblick")
            content.body = String(localized: "Was hast du gehalten? Ein kurzer Blick auf deine Anker dieser Woche.")
        }
        content.sound = .default
        content.threadIdentifier = "anchorit.ritual"
        content.userInfo = ["url": kind.deepLink]
        return content
    }

    /// Der Weg zu den Mitteilungseinstellungen dieser App.
    static func openSystemSettings() {
#if os(iOS)
        if let url = URL(string: UIApplication.openNotificationSettingsURLString) ?? URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
#elseif os(macOS)
        if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
#endif
    }
}

/// Zeigt die Erinnerung auch, wenn die App vorn ist, und öffnet beim Tippen den passenden Ort.
///
/// Der Sprung läuft über den eigenen Deep Link — dieselbe Stelle (`onOpenURL` in
/// `AnkerRootView`), die auch Kurzbefehle und Links bedient. Auf dem Mac ausdrücklich an
/// **dieses** Programm adressiert, damit nicht eine zweite installierte Kopie den Link bekommt.
final class RitualNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = RitualNotificationDelegate()

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard let link = response.notification.request.content.userInfo["url"] as? String,
              let url = URL(string: link) else { return }
        await Self.open(url)
    }

    @MainActor
    private static func open(_ url: URL) {
#if os(iOS)
        UIApplication.shared.open(url)
#elseif os(macOS)
        NSWorkspace.shared.open(
            [url],
            withApplicationAt: Bundle.main.bundleURL,
            configuration: NSWorkspace.OpenConfiguration()
        )
#endif
    }
}
