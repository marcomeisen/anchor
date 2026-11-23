import Combine
import EventKit
import Foundation
import OSLog
import SwiftData
import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

private let remindersImportLog = Logger(subsystem: "com.marcomeisen.Anchor", category: "RemindersImport")

// MARK: - Abbild ohne EventKit

/// Eine Erinnerung, wie der Import sie braucht — ohne `EKReminder`, damit die Zuordnung ohne
/// EventKit testbar ist. Entsteht im Rückruf von `fetchReminders` (Hintergrund), deshalb
/// `nonisolated` und `Sendable`.
nonisolated struct ReminderSnapshot: Equatable, Sendable {
    let identifier: String
    let listIdentifier: String
    let title: String
    let isCompleted: Bool
    /// Fälligkeit als Zeitpunkt in der Ortszeit; `nil` heißt ohne Datum.
    let dueDate: Date?
    /// EventKit-Priorität: 0 keine, 1–4 hoch, 5 mittel, 6–9 niedrig.
    let priority: Int

    init(identifier: String, listIdentifier: String, title: String, isCompleted: Bool = false, dueDate: Date?, priority: Int = 0) {
        self.identifier = identifier
        self.listIdentifier = listIdentifier
        self.title = title
        self.isCompleted = isCompleted
        self.dueDate = dueDate
        self.priority = priority
    }

    init(reminder: EKReminder, calendar: Calendar) {
        let due: Date? = reminder.dueDateComponents.flatMap { components in
            // Ganztägige Erinnerungen tragen nur Jahr, Monat, Tag — und oft keinen Kalender.
            components.calendar != nil ? components.date : calendar.date(from: components)
        }
        self.init(
            identifier: reminder.calendarItemIdentifier,
            listIdentifier: reminder.calendar?.calendarIdentifier ?? "",
            title: reminder.title ?? "",
            isCompleted: reminder.isCompleted,
            dueDate: due,
            priority: reminder.priority
        )
    }
}

/// Eine Liste aus Apple Erinnerungen mit der Zahl ihrer offenen Einträge.
nonisolated struct ReminderListSummary: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let openCount: Int
}

/// Titel und Tag einer vorhandenen Aufgabe — der Abgleich gegen Doppelimporte.
nonisolated struct ExistingTaskKey: Hashable, Sendable {
    let title: String
    /// `JJJJ-MM-TT` oder `nil` für eine Aufgabe ohne Tag.
    let day: String?

    init(title: String, day: String?) {
        self.title = Self.normalized(title)
        self.day = day
    }

    static func normalized(_ title: String) -> String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
    }
}

/// Wohin eine Erinnerung kommt.
enum ReminderImportPlacement: Equatable {
    /// Auf diesen Tag (Tagesanfang in der Ortszeit).
    case day(Date)
    /// Eingang: ohne Tag, ohne Anker.
    case inbox
}

enum ReminderImportSkipReason: Hashable {
    case completed
    case emptyTitle
    /// Dieses Gerät hat die Erinnerung schon einmal übernommen.
    case alreadyImported
    /// Eine Aufgabe mit gleichem Titel am gleichen Ort gibt es schon.
    case duplicate
}

struct ReminderImportEntry: Equatable {
    let reminder: ReminderSnapshot
    let placement: ReminderImportPlacement
    let priority: Priority
}

struct ReminderImportPlan: Equatable {
    var entries: [ReminderImportEntry] = []
    var skipped: [ReminderImportSkipReason: Int] = [:]

    var datedCount: Int { entries.filter { $0.placement != .inbox }.count }
    var inboxCount: Int { entries.filter { $0.placement == .inbox }.count }
    var skippedExisting: Int { (skipped[.alreadyImported] ?? 0) + (skipped[.duplicate] ?? 0) }
}

// MARK: - Zuordnung als reine Rechnung

/// Die Zuordnung Erinnerung → Aufgabe.
///
/// - **Erledigte** werden nicht übernommen.
/// - **Mit Datum in dieser oder der nächsten ISO-Woche** → auf ihren Tag (auch ein schon
///   vergangener Tag dieser Woche). Alles andere — ohne Datum, überfällig aus früheren Wochen,
///   weiter als nächste Woche — kommt in den **Eingang**. So entstehen beim Import höchstens
///   zwei Wochen, und nichts landet unsichtbar in einer fernen Woche.
/// - **Priorität:** EventKit hoch (1–4) → `.a` (wichtig), alles andere → `.b` (Standard).
/// - **Doppelt:** übersprungen, wenn dieses Gerät die `calendarItemIdentifier` schon
///   übernommen hat, oder wenn eine Aufgabe mit gleichem Titel am gleichen Ort (Tag bzw.
///   „ohne Tag") schon existiert. Der zweite Abgleich fängt den Import auf einem zweiten Gerät
///   ab — die Liste der Kennungen ist nur lokal.
enum RemindersImportPlanner {
    static func priority(forEventKit value: Int) -> Priority {
        (1...4).contains(value) ? .a : .b
    }

    static func placement(for dueDate: Date?, now: Date, calendar: Calendar) -> ReminderImportPlacement {
        guard let dueDate else { return .inbox }
        let thisWeek = AnkerCalendar.weekInterval(containing: now, calendar: calendar).monday
        guard let end = calendar.date(byAdding: .day, value: 14, to: thisWeek) else { return .inbox }
        guard dueDate >= thisWeek && dueDate < end else { return .inbox }
        return .day(calendar.startOfDay(for: dueDate))
    }

    static func dayKey(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    static func plan(
        _ reminders: [ReminderSnapshot],
        alreadyImported: Set<String>,
        existing: Set<ExistingTaskKey>,
        now: Date,
        calendar: Calendar
    ) -> ReminderImportPlan {
        var plan = ReminderImportPlan()
        for reminder in reminders {
            let title = reminder.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let reason: ReminderImportSkipReason?
            let placement = placement(for: reminder.dueDate, now: now, calendar: calendar)
            let key: ExistingTaskKey = {
                switch placement {
                case .day(let date): ExistingTaskKey(title: title, day: dayKey(date, calendar: calendar))
                case .inbox: ExistingTaskKey(title: title, day: nil)
                }
            }()

            if reminder.isCompleted {
                reason = .completed
            } else if title.isEmpty {
                reason = .emptyTitle
            } else if alreadyImported.contains(reminder.identifier) {
                reason = .alreadyImported
            } else if existing.contains(key) {
                reason = .duplicate
            } else {
                reason = nil
            }

            if let reason {
                plan.skipped[reason, default: 0] += 1
            } else {
                plan.entries.append(ReminderImportEntry(
                    reminder: reminder,
                    placement: placement,
                    priority: priority(forEventKit: reminder.priority)
                ))
            }
        }
        return plan
    }

    /// Titel und Tag aller vorhandenen Aufgaben.
    static func existingKeys(modelContext: ModelContext, calendar: Calendar) -> Set<ExistingTaskKey> {
        let tasks = (try? modelContext.fetch(FetchDescriptor<AnkerTask>())) ?? []
        return Set(tasks.filter { !$0.isDeleted }.map { task in
            let day = task.day.map { stored -> String in
                let parts = AnkerCalendar.nominalDay(ofStored: stored.date, calendar: calendar)
                return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
            }
            return ExistingTaskKey(title: task.title, day: day)
        })
    }

    /// Legt die Aufgaben an — nur über `TaskActions`. Woche und Tag entstehen hier, beim
    /// Schreiben, und nur für Erinnerungen mit Datum. Gibt die Schnappschüsse der neuen
    /// Aufgaben für das Rückgängigmachen zurück.
    static func perform(_ plan: ReminderImportPlan, modelContext: ModelContext) -> [TaskSnapshot] {
        var weeks: [Week] = []
        var created: [TaskSnapshot] = []

        for entry in plan.entries {
            let task: AnkerTask?
            switch entry.placement {
            case .day(let date):
                let week = TaskActions.ensureWeek(containing: date, weeks: weeks, modelContext: modelContext)
                if !weeks.contains(where: { $0 === week }) { weeks.append(week) }
                let day = TaskActions.ensureDay(containing: date, in: week)
                task = TaskActions.create(
                    title: entry.reminder.title,
                    priority: entry.priority,
                    on: day,
                    linkedGoal: nil,
                    modelContext: modelContext
                )
            case .inbox:
                task = TaskActions.createUnscheduled(
                    title: entry.reminder.title,
                    priority: entry.priority,
                    goal: nil,
                    modelContext: modelContext
                )
            }
            if let task { created.append(TaskActions.snapshot(task)) }
        }
        return created
    }
}

// MARK: - Gemerkte Kennungen

/// Welche Erinnerungen dieses Gerät schon übernommen hat — in `UserDefaults`, nicht im Modell.
///
/// Kein neues Modellfeld: das Schema gehört dem Sync, und eine Kennung aus Apple Erinnerungen
/// ist nur auf dem Gerät aussagekräftig, auf dem sie gelesen wurde. Im UI-Testmodus wird nichts
/// geschrieben — der Testmodus hinterlässt nichts.
enum RemindersImportLedger {
    static func load(from defaults: UserDefaults = .standard) -> Set<String> {
        Set(defaults.stringArray(forKey: AppSettingsKey.remindersImportedIdentifiers) ?? [])
    }

    static func add(_ identifiers: [String], to defaults: UserDefaults = .standard) {
        guard !isReadOnly, !identifiers.isEmpty else { return }
        let merged = load(from: defaults).union(identifiers)
        defaults.set(merged.sorted(), forKey: AppSettingsKey.remindersImportedIdentifiers)
    }

    static func remove(_ identifiers: [String], from defaults: UserDefaults = .standard) {
        guard !isReadOnly, !identifiers.isEmpty else { return }
        let remaining = load(from: defaults).subtracting(identifiers)
        defaults.set(remaining.sorted(), forKey: AppSettingsKey.remindersImportedIdentifiers)
    }

    private static var isReadOnly: Bool {
#if DEBUG
        return UITestMode.isActive
#else
        return false
#endif
    }
}

// MARK: - EventKit

/// Liest Apple Erinnerungen — **nur lesen**. Nichts wird dort geändert, abgehakt oder gelöscht.
@MainActor
final class RemindersImportModel: ObservableObject {
    enum Phase: Equatable {
        case idle
        case loading
        case denied
        case ready
        case done(created: Int)
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var lists: [ReminderListSummary] = []
    @Published var selectedLists: Set<String> = []
    @Published private(set) var reminders: [ReminderSnapshot] = []

    private(set) var createdSnapshots: [TaskSnapshot] = []
    private(set) var importedIdentifiers: [String] = []

    private let store = EKEventStore()

    static var isAvailable: Bool {
#if DEBUG
        if UITestMode.isActive { return false }
#endif
        return !CloudSyncConfiguration.isRunningTests
    }

    func start() async {
        guard Self.isAvailable, phase == .idle else { return }
        phase = .loading

        switch EKEventStore.authorizationStatus(for: .reminder) {
        case .fullAccess:
            break
        case .notDetermined:
            let granted = (try? await store.requestFullAccessToReminders()) ?? false
            guard granted else { phase = .denied; return }
        default:
            phase = .denied
            return
        }
        await load()
    }

    private func load() async {
        let calendars = store.calendars(for: .reminder)
        let predicate = store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: calendars)
        let fetched = await Self.fetch(predicate: predicate, from: store, calendar: RitualReminderPlanner.currentCalendar)
        reminders = fetched.filter { !$0.isCompleted }

        let counts = Dictionary(grouping: reminders, by: \.listIdentifier).mapValues(\.count)
        lists = calendars
            .map { ReminderListSummary(id: $0.calendarIdentifier, title: $0.title, openCount: counts[$0.calendarIdentifier] ?? 0) }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        selectedLists = Set(lists.filter { $0.openCount > 0 }.map(\.id))
        phase = .ready
    }

    /// `fetchReminders` ruft auf einem Hintergrund-Thread zurück; dort wird sofort in das
    /// `Sendable`-Abbild übersetzt, `EKReminder` verlässt den Rückruf nicht.
    nonisolated private static func fetch(predicate: NSPredicate, from store: EKEventStore, calendar: Calendar) async -> [ReminderSnapshot] {
        await withCheckedContinuation { continuation in
            store.fetchReminders(matching: predicate) { result in
                let snapshots = (result ?? []).map { ReminderSnapshot(reminder: $0, calendar: calendar) }
                continuation.resume(returning: snapshots)
            }
        }
    }

    func plan(modelContext: ModelContext, now: Date = Date()) -> ReminderImportPlan {
        let calendar = RitualReminderPlanner.currentCalendar
        return RemindersImportPlanner.plan(
            reminders.filter { selectedLists.contains($0.listIdentifier) },
            alreadyImported: RemindersImportLedger.load(),
            existing: RemindersImportPlanner.existingKeys(modelContext: modelContext, calendar: calendar),
            now: now,
            calendar: calendar
        )
    }

    func runImport(_ plan: ReminderImportPlan, modelContext: ModelContext) {
        createdSnapshots = RemindersImportPlanner.perform(plan, modelContext: modelContext)
        importedIdentifiers = plan.entries.map(\.reminder.identifier)
        RemindersImportLedger.add(importedIdentifiers)
        remindersImportLog.notice("Import aus Erinnerungen: \(self.createdSnapshots.count, privacy: .public) Aufgaben")
        phase = .done(created: createdSnapshots.count)
    }

    /// Entfernt genau die angelegten Aufgaben wieder — über die vorhandene Undo-Mechanik.
    /// Angelegte Wochen und Tage bleiben leer stehen; das ist gültiger Bestand.
    func undoImport(modelContext: ModelContext) {
        guard !createdSnapshots.isEmpty else { return }
        let notice = TaskUndoNotice(
            message: String(localized: "Import rückgängig gemacht"),
            snapshots: createdSnapshots,
            operation: .deleteCreated
        )
        TaskActions.undo(notice, weeks: [], modelContext: modelContext)
        RemindersImportLedger.remove(importedIdentifiers)
        createdSnapshots = []
        importedIdentifiers = []
        phase = .idle
        Task { await start() }
    }

    static func openSystemSettings() {
#if os(iOS)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
#elseif os(macOS)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Reminders") {
            NSWorkspace.shared.open(url)
        }
#endif
    }
}

// MARK: - Blatt

/// „Aus Erinnerungen importieren": Berechtigung, Listen wählen, Vorschau, Import, Undo.
struct RemindersImportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var model = RemindersImportModel()
    @State private var undone = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AnkerSpacing.s4) {
                Text("Übernimmt offene Erinnerungen einmalig als Aufgaben. Apple Erinnerungen bleibt dabei unverändert, und es wird nichts abgeglichen.")
                    .ankerType(AnkerType.caption)
                    .foregroundStyle(AnkerColor.inkSecond)
                    .fixedSize(horizontal: false, vertical: true)

                content
            }
            .padding(AnkerSpacing.screenPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(AnkerColor.ground)
        .ankerSheetChrome(
            "Aus Erinnerungen importieren",
            cancel: AnkerSheetAction(isDone ? "Fertig" : "Abbrechen") { dismiss() }
        )
        .task { await model.start() }
    }

    private var isDone: Bool {
        if case .done = model.phase { return true }
        return undone
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .idle, .loading:
            HStack(spacing: AnkerSpacing.s2) {
                ProgressView().controlSize(.small)
                Text("Erinnerungen werden gelesen …")
                    .ankerType(AnkerType.caption)
                    .foregroundStyle(AnkerColor.inkSecond)
            }
            .padding(AnkerSpacing.s4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .ankerCard()
        case .denied:
            deniedCard
        case .ready:
            listsCard
            previewCard
        case .done(let created):
            doneCard(created: created)
        }
    }

    private var deniedCard: some View {
        VStack(alignment: .leading, spacing: AnkerSpacing.s3) {
            Text("Anchorit hat keinen Zugriff auf deine Erinnerungen.")
                .ankerType(AnkerType.bodyStrong)
                .foregroundStyle(AnkerColor.ink)
            Text("Der Zugriff lässt sich in den Systemeinstellungen unter Datenschutz → Erinnerungen erlauben. Anchorit liest nur und ändert dort nichts.")
                .ankerType(AnkerType.caption)
                .foregroundStyle(AnkerColor.inkSecond)
                .fixedSize(horizontal: false, vertical: true)
            Button("Systemeinstellungen öffnen") { RemindersImportModel.openSystemSettings() }
                .buttonStyle(AnkerButtonStyle.secondary)
        }
        .padding(AnkerSpacing.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ankerCard()
    }

    private var listsCard: some View {
        VStack(alignment: .leading, spacing: AnkerSpacing.s2) {
            Text("Listen")
                .ankerType(AnkerType.metaStrong)
                .foregroundStyle(AnkerColor.ink)

            if model.lists.isEmpty {
                Text("Keine Listen gefunden.")
                    .ankerType(AnkerType.caption)
                    .foregroundStyle(AnkerColor.inkSecond)
            }

            ForEach(Array(model.lists.enumerated()), id: \.element.id) { index, list in
                if index > 0 {
                    AnkerRule(color: AnkerColor.cardDivider, weight: .row)
                }
                Toggle(isOn: Binding(
                    get: { model.selectedLists.contains(list.id) },
                    set: { isOn in
                        if isOn { model.selectedLists.insert(list.id) } else { model.selectedLists.remove(list.id) }
                    }
                )) {
                    VStack(alignment: .leading, spacing: AnkerSpacing.s1) {
                        Text(verbatim: list.title)
                            .ankerType(AnkerType.caption)
                            .foregroundStyle(AnkerColor.ink)
                        Text("\(list.openCount) offen")
                            .ankerType(AnkerType.caption)
                            .foregroundStyle(AnkerColor.inkSecond)
                    }
                }
                .toggleStyle(AnkerToggleStyle())
                .frame(minHeight: 44)
            }
        }
        .padding(AnkerSpacing.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ankerCard()
    }

    private var previewCard: some View {
        let plan = model.plan(modelContext: modelContext)
        let count = plan.entries.count
        return VStack(alignment: .leading, spacing: AnkerSpacing.s3) {
            Text("Vorschau")
                .ankerType(AnkerType.metaStrong)
                .foregroundStyle(AnkerColor.ink)

            Text("\(count) Aufgaben: \(plan.datedCount) mit Datum in dieser oder nächster Woche, \(plan.inboxCount) in den Eingang")
                .ankerType(AnkerType.body)
                .foregroundStyle(AnkerColor.ink)
                .fixedSize(horizontal: false, vertical: true)

            if plan.skippedExisting > 0 {
                Text("\(plan.skippedExisting) schon vorhanden, werden übersprungen")
                    .ankerType(AnkerType.caption)
                    .foregroundStyle(AnkerColor.inkSecond)
            }

            Text("Erledigte Erinnerungen werden nicht übernommen. Hohe Priorität wird zu „wichtig“, ein Datum außerhalb dieser und der nächsten Woche landet im Eingang.")
                .ankerType(AnkerType.caption)
                .foregroundStyle(AnkerColor.inkSecond)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                model.runImport(plan, modelContext: modelContext)
            } label: {
                Text("\(count) Aufgaben importieren")
            }
            .buttonStyle(AnkerButtonStyle.primaryBlock)
            .disabled(count == 0)
            .opacity(count == 0 ? 0.5 : 1)
        }
        .padding(AnkerSpacing.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ankerCard()
    }

    private func doneCard(created: Int) -> some View {
        VStack(alignment: .leading, spacing: AnkerSpacing.s3) {
            Text("\(created) Aufgaben übernommen")
                .ankerType(AnkerType.bodyStrong)
                .foregroundStyle(AnkerColor.ink)
            Text("Aufgaben mit Datum stehen an ihrem Tag, die übrigen im Eingang unter „noch ohne Tag“. Deine Erinnerungen in Apple Erinnerungen sind unverändert.")
                .ankerType(AnkerType.caption)
                .foregroundStyle(AnkerColor.inkSecond)
                .fixedSize(horizontal: false, vertical: true)

            if created > 0 {
                Button {
                    model.undoImport(modelContext: modelContext)
                    undone = true
                } label: {
                    Label("Import rückgängig machen", ankerIcon: AnkerIcon.undo)
                }
                .buttonStyle(AnkerButtonStyle.secondary)
            }
        }
        .padding(AnkerSpacing.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ankerCard()
    }
}
