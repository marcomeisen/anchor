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

nonisolated struct ImportedReminderDetails: Codable, Equatable, Sendable {
    let dueDate: DateComponents?
    let notes: String?
    let url: URL?
    var sourceIdentifier: String? = nil
    var sourceExternalIdentifier: String? = nil

    var isEmpty: Bool { dueDate == nil && notes?.isEmpty != false && url == nil }

    var isAllDay: Bool {
        dueDate?.hour == nil && dueDate?.minute == nil && dueDate?.second == nil
    }

    /// Ganztägige Angaben behalten ihren Kalendertag. Für Uhrzeiten gilt die Quellzeitzone,
    /// bei einer schwebenden Fälligkeit die für die Platzierung gewählte Zeitzone.
    func date(in timeZone: TimeZone) -> Date? {
        guard var components = dueDate else { return nil }
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = isAllDay ? timeZone : components.timeZone ?? timeZone
        components.calendar = nil
        components.timeZone = nil
        return gregorian.date(from: components)
    }
}

/// Eine Erinnerung, wie der Import sie braucht — ohne `EKReminder`, damit die Zuordnung ohne
/// EventKit testbar ist. Entsteht im Rückruf von `fetchReminders` (Hintergrund), deshalb
/// `nonisolated` und `Sendable`.
nonisolated struct ReminderSnapshot: Equatable, Sendable {
    let identifier: String
    let externalIdentifier: String?
    let listIdentifier: String
    let title: String
    let isCompleted: Bool
    let details: ImportedReminderDetails
    /// EventKit-Priorität: 0 keine, 1–4 hoch, 5 mittel, 6–9 niedrig.
    let priority: Int

    init(identifier: String, externalIdentifier: String? = nil, listIdentifier: String, title: String, isCompleted: Bool = false, details: ImportedReminderDetails, priority: Int = 0) {
        self.identifier = identifier
        self.externalIdentifier = externalIdentifier?.isEmpty == false ? externalIdentifier : nil
        self.listIdentifier = listIdentifier
        self.title = title
        self.isCompleted = isCompleted
        self.details = details
        self.priority = priority
    }

    init(reminder: EKReminder) {
        self.init(
            identifier: reminder.calendarItemIdentifier,
            externalIdentifier: reminder.calendarItemExternalIdentifier,
            listIdentifier: reminder.calendar?.calendarIdentifier ?? "",
            title: reminder.title ?? "",
            isCompleted: reminder.isCompleted,
            details: ImportedReminderDetails(dueDate: reminder.dueDateComponents, notes: reminder.notes, url: reminder.url),
            priority: reminder.priority
        )
    }
}

/// Sichtbare Listendaten vor dem Lesen der Erinnerungseinträge.
nonisolated struct ReminderListSummary: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
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
    case unmatchedUpdate
}

struct ReminderImportEntry: Equatable {
    let reminder: ReminderSnapshot
    let placement: ReminderImportPlacement
    let priority: Priority
    var updateTaskID: UUID? = nil
}

struct ReminderImportPlan: Equatable {
    var entries: [ReminderImportEntry] = []
    var skipped: [ReminderImportSkipReason: Int] = [:]

    var datedCount: Int { entries.filter { $0.updateTaskID == nil && $0.placement != .inbox }.count }
    var inboxCount: Int { entries.filter { $0.updateTaskID == nil && $0.placement == .inbox }.count }
    var updatedCount: Int { entries.filter { $0.updateTaskID != nil }.count }
    var skippedExisting: Int { (skipped[.alreadyImported] ?? 0) + (skipped[.duplicate] ?? 0) }
}

struct ExistingReminderTasks {
    var byTitleAndDay: [ExistingTaskKey: [UUID]] = [:]
    var bySourceIdentifier: [String: [UUID]] = [:]
    var byExternalIdentifier: [String: [UUID]] = [:]
}

struct ReminderImportResult {
    var created: [TaskSnapshot] = []
    var updated: [TaskSnapshot] = []
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
/// - **Bereits vorhanden:** standardmäßig überspringen. Auf Wunsch einen eindeutig über
///   die Quellenkennung ermittelten Import aktualisieren. Titel und Tag dienen der
///   Duplikaterkennung.
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
        existing: ExistingReminderTasks,
        overwritesExisting: Bool = false,
        verifiesExternalIdentifier: (ReminderSnapshot) -> Bool = { _ in false },
        now: Date,
        calendar: Calendar
    ) -> ReminderImportPlan {
        var plan = ReminderImportPlan()
        let externalCounts = Dictionary(grouping: reminders.compactMap(\.externalIdentifier), by: { $0 }).mapValues(\.count)
        var seen = Set<String>()
        for reminder in reminders {
            guard seen.insert(reminder.identifier).inserted else { continue }
            let title = reminder.title.trimmingCharacters(in: .whitespacesAndNewlines)
            if reminder.isCompleted {
                plan.skipped[.completed, default: 0] += 1
                continue
            }
            if title.isEmpty {
                plan.skipped[.emptyTitle, default: 0] += 1
                continue
            }

            let placement = placement(for: reminder.details.date(in: calendar.timeZone), now: now, calendar: calendar)
            let key: ExistingTaskKey = {
                switch placement {
                case .day(let date): ExistingTaskKey(title: title, day: dayKey(date, calendar: calendar))
                case .inbox: ExistingTaskKey(title: title, day: nil)
                }
            }()

            let localMatches = existing.bySourceIdentifier[reminder.identifier] ?? []
            let externalMatches = reminder.externalIdentifier.flatMap { existing.byExternalIdentifier[$0] } ?? []
            let matchingTitle = existing.byTitleAndDay[key] ?? []
            let knownImport = alreadyImported.contains(reminder.identifier) || !localMatches.isEmpty || !externalMatches.isEmpty
            let entry = ReminderImportEntry(reminder: reminder, placement: placement, priority: priority(forEventKit: reminder.priority))
            guard knownImport || !matchingTitle.isEmpty else {
                plan.entries.append(entry)
                continue
            }
            guard overwritesExisting else {
                plan.skipped[knownImport ? .alreadyImported : .duplicate, default: 0] += 1
                continue
            }

            let candidates: [UUID]
            if !localMatches.isEmpty {
                candidates = localMatches
            } else if externalMatches.count == 1 {
                let externalCount = reminder.externalIdentifier.flatMap { externalCounts[$0] } ?? 0
                candidates = externalCount == 1 && verifiesExternalIdentifier(reminder) ? externalMatches : []
            } else {
                candidates = []
            }
            guard candidates.count == 1, let taskID = candidates.first else {
                plan.skipped[.unmatchedUpdate, default: 0] += 1
                continue
            }
            var update = entry
            update.updateTaskID = taskID
            plan.entries.append(update)
        }
        let updatesByTask = Dictionary(grouping: plan.entries.compactMap(\.updateTaskID), by: { $0 })
        let conflicts = Set(updatesByTask.filter { $0.value.count > 1 }.keys)
        if !conflicts.isEmpty {
            let before = plan.entries.count
            plan.entries.removeAll { $0.updateTaskID.map(conflicts.contains) == true }
            plan.skipped[.unmatchedUpdate, default: 0] += before - plan.entries.count
        }
        return plan
    }

    static func existingTasks(modelContext: ModelContext, calendar: Calendar) throws -> ExistingReminderTasks {
        let tasks = try modelContext.fetch(FetchDescriptor<AnkerTask>())
        var existing = ExistingReminderTasks()
        for task in tasks where !task.isDeleted {
            let day = task.day.map { stored -> String in
                let parts = AnkerCalendar.nominalDay(ofStored: stored.date, calendar: calendar)
                return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
            }
            let key = ExistingTaskKey(title: task.title, day: day)
            existing.byTitleAndDay[key, default: []].append(task.id)
            let source = task.importedReminder
            if let identifier = source?.sourceIdentifier {
                existing.bySourceIdentifier[identifier, default: []].append(task.id)
            }
            if let externalIdentifier = source?.sourceExternalIdentifier {
                existing.byExternalIdentifier[externalIdentifier, default: []].append(task.id)
            }
        }
        return existing
    }

    /// Schreibt den Import als einen Stapel und hält die vorherigen Werte für Undo fest.
    static func perform(_ plan: ReminderImportPlan, modelContext: ModelContext) -> ReminderImportResult? {
        let updateIDs = plan.entries.compactMap(\.updateTaskID)
        guard let tasks = fetchTasks(updateIDs, modelContext: modelContext),
              tasks.count == updateIDs.count else { return nil }
        let data: [Data]
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            data = try plan.entries.map { entry in
                var details = entry.reminder.details
                details.sourceIdentifier = entry.reminder.identifier
                details.sourceExternalIdentifier = entry.reminder.externalIdentifier
                return try encoder.encode(details)
            }
        } catch {
            PersistenceFailureCenter.shared.report(PersistenceFailure(operation: #function, error: error))
            return nil
        }

        // Einen früheren, noch offenen Schreibvorgang beim Rückrollen nicht verwerfen.
        guard modelContext.saveChanges() else { return nil }
        var weeks: [Week] = []
        var result = ReminderImportResult()

        for (entry, importedReminderData) in zip(plan.entries, data) {
            if let task = entry.updateTaskID.flatMap({ tasks[$0] }) {
                result.updated.append(TaskActions.snapshot(task))
                TaskActions.applyReminderImport(
                    to: task, title: entry.reminder.title, priority: entry.priority, data: importedReminderData
                )
                continue
            }
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
                    importedReminderData: importedReminderData,
                    save: false,
                    modelContext: modelContext
                )
            case .inbox:
                task = TaskActions.createUnscheduled(
                    title: entry.reminder.title,
                    priority: entry.priority,
                    goal: nil,
                    importedReminderData: importedReminderData,
                    save: false,
                    modelContext: modelContext
                )
            }
            if let task { result.created.append(TaskActions.snapshot(task)) }
        }
        guard modelContext.saveChanges() else {
            modelContext.rollback()
            return nil
        }
        return result
    }

    static func undo(_ result: ReminderImportResult, modelContext: ModelContext) -> Bool {
        let ids = result.created.map(\.id) + result.updated.map(\.id)
        guard let tasks = fetchTasks(ids, modelContext: modelContext),
              modelContext.saveChanges() else { return false }
        for snapshot in result.created {
            if let task = tasks[snapshot.id] { TaskActions.delete(task, save: false, modelContext: modelContext) }
        }
        for snapshot in result.updated {
            if let task = tasks[snapshot.id] {
                TaskActions.applyReminderImport(
                    to: task, title: snapshot.title, priority: snapshot.priority, data: snapshot.importedReminderData
                )
            }
        }
        guard modelContext.saveChanges() else {
            modelContext.rollback()
            return false
        }
        return true
    }

    private static func fetchTasks(_ ids: [UUID], modelContext: ModelContext) -> [UUID: AnkerTask]? {
        guard !ids.isEmpty else { return [:] }
        do {
            let tasks = try modelContext.fetch(FetchDescriptor<AnkerTask>(predicate: #Predicate { ids.contains($0.id) }))
            return Dictionary(tasks.filter { !$0.isDeleted }.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        } catch {
            PersistenceFailureCenter.shared.report(PersistenceFailure(operation: #function, error: error))
            return nil
        }
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
        case choosingLists
        case loadingPreview
        case previewFailed
        case ready
        case done(created: Int, updated: Int)
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var lists: [ReminderListSummary] = []
    @Published var selectedLists: Set<String> = []
    @Published var overwritesExisting = false
    @Published private(set) var reminders: [ReminderSnapshot] = []

    private var lastImport: ReminderImportResult?
    private var newlyRecordedIdentifiers: [String] = []

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
        chooseLists()
    }

    func loadPreview() async {
        guard phase == .choosingLists, !selectedLists.isEmpty else { return }
        guard EKEventStore.authorizationStatus(for: .reminder) == .fullAccess else {
            phase = .denied
            return
        }
        phase = .loadingPreview
        let calendars = store.calendars(for: .reminder).filter { selectedLists.contains($0.calendarIdentifier) }
        guard !calendars.isEmpty else {
            phase = .previewFailed
            return
        }
        let predicate = store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: calendars)
        guard let fetched = await Self.fetch(predicate: predicate, from: store) else {
            phase = .previewFailed
            return
        }
        reminders = fetched.filter { !$0.isCompleted && selectedLists.contains($0.listIdentifier) }
        phase = .ready
    }

    func chooseLists() {
        guard EKEventStore.authorizationStatus(for: .reminder) == .fullAccess else {
            reminders = []
            phase = .denied
            return
        }
        lists = store.calendars(for: .reminder)
            .map { ReminderListSummary(id: $0.calendarIdentifier, title: $0.title) }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        selectedLists.formIntersection(lists.map(\.id))
        reminders = []
        overwritesExisting = false
        phase = .choosingLists
    }

    func resumeAfterSettings() {
        guard phase == .denied, EKEventStore.authorizationStatus(for: .reminder) == .fullAccess else { return }
        chooseLists()
    }

    /// `fetchReminders` ruft auf einem Hintergrund-Thread zurück; dort wird sofort in das
    /// `Sendable`-Abbild übersetzt, `EKReminder` verlässt den Rückruf nicht.
    nonisolated private static func fetch(predicate: NSPredicate, from store: EKEventStore) async -> [ReminderSnapshot]? {
        await withCheckedContinuation { continuation in
            store.fetchReminders(matching: predicate) { result in
                let snapshots = result?.map(ReminderSnapshot.init(reminder:))
                continuation.resume(returning: snapshots)
            }
        }
    }

    func plan(modelContext: ModelContext, now: Date = Date()) -> ReminderImportPlan? {
        let calendar = RitualReminderPlanner.currentCalendar
        guard let existing = try? RemindersImportPlanner.existingTasks(modelContext: modelContext, calendar: calendar) else { return nil }
        return RemindersImportPlanner.plan(
            reminders,
            alreadyImported: RemindersImportLedger.load(),
            existing: existing,
            overwritesExisting: overwritesExisting,
            verifiesExternalIdentifier: verifiesExternalIdentifier,
            now: now,
            calendar: calendar
        )
    }

    private func verifiesExternalIdentifier(_ reminder: ReminderSnapshot) -> Bool {
        guard let externalIdentifier = reminder.externalIdentifier else { return false }
        // Dieselbe externe Kennung kann in mehreren Listen vorkommen. Für diese Prüfung
        // werden nur Kennungen verglichen, keine Inhalte anderer Listen ausgewertet.
        let matches = store.calendarItems(withExternalIdentifier: externalIdentifier).compactMap { $0 as? EKReminder }
        return matches.count == 1 && matches.first?.calendarItemIdentifier == reminder.identifier
    }

    func runImport(modelContext: ModelContext) {
        guard phase == .ready else { return }
        guard EKEventStore.authorizationStatus(for: .reminder) == .fullAccess else {
            reminders = []
            phase = .denied
            return
        }
        guard let plan = plan(modelContext: modelContext), !plan.entries.isEmpty,
              let result = RemindersImportPlanner.perform(plan, modelContext: modelContext) else { return }
        lastImport = result
        newlyRecordedIdentifiers = Array(Set(plan.entries.map(\.reminder.identifier)).subtracting(RemindersImportLedger.load()))
        RemindersImportLedger.add(newlyRecordedIdentifiers)
        remindersImportLog.notice("Import aus Erinnerungen: \(result.created.count, privacy: .public) neu, \(result.updated.count, privacy: .public) aktualisiert")
        phase = .done(created: result.created.count, updated: result.updated.count)
    }

    func undoImport(modelContext: ModelContext) -> Bool {
        guard let lastImport, RemindersImportPlanner.undo(lastImport, modelContext: modelContext) else { return false }
        RemindersImportLedger.remove(newlyRecordedIdentifiers)
        self.lastImport = nil
        newlyRecordedIdentifiers = []
        overwritesExisting = false
        phase = .ready
        return true
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
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var model = RemindersImportModel()
    @State private var undone = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AnkerSpacing.s4) {
                Text("Wähle Listen aus Apple Erinnerungen, um offene Einträge als Aufgaben zu übernehmen.")
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
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active { model.resumeAfterSettings() }
        }
    }

    private var isDone: Bool {
        if case .done = model.phase { return true }
        return undone
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .idle, .loading, .loadingPreview:
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
        case .choosingLists:
            listsCard
        case .previewFailed:
            previewFailure
            chooseListsButton
        case .ready:
            if model.reminders.isEmpty {
                Text("In den ausgewählten Listen gibt es keine offenen Erinnerungen.")
                    .ankerType(AnkerType.body)
                    .foregroundStyle(AnkerColor.inkSecond)
            } else if let plan = model.plan(modelContext: modelContext) {
                previewCard(plan)
            } else {
                previewFailure
            }
            chooseListsButton
        case .done(let created, let updated):
            doneCard(created: created, updated: updated)
        }
    }

    private var previewFailure: some View {
        Text("Die Importvorschau konnte nicht geladen werden.")
            .ankerType(AnkerType.body)
            .foregroundStyle(AnkerColor.inkSecond)
    }

    private var chooseListsButton: some View {
        Button(action: model.chooseLists) {
            Text("Listenauswahl ändern").frame(minHeight: 44)
        }
        .buttonStyle(AnkerButtonStyle.secondary)
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
                    Text(verbatim: list.title)
                        .ankerType(AnkerType.body)
                        .foregroundStyle(AnkerColor.ink)
                }
                .toggleStyle(AnkerToggleStyle())
                .frame(minHeight: 44)
            }
            if !model.lists.isEmpty {
                Button("Vorschau erstellen") { Task { await model.loadPreview() } }
                    .buttonStyle(AnkerButtonStyle.primaryBlock)
                    .disabled(model.selectedLists.isEmpty)
                    .opacity(model.selectedLists.isEmpty ? 0.5 : 1)
            }
        }
        .padding(AnkerSpacing.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ankerCard()
    }

    private func previewCard(_ plan: ReminderImportPlan) -> some View {
        let count = plan.entries.count
        return VStack(alignment: .leading, spacing: AnkerSpacing.s3) {
            Text("Vorschau")
                .ankerType(AnkerType.metaStrong)
                .foregroundStyle(AnkerColor.ink)

            Toggle("Vorhandene Importe aktualisieren", isOn: $model.overwritesExisting)
                .ankerType(AnkerType.body)
                .foregroundStyle(AnkerColor.ink)
                .toggleStyle(.switch)
                .frame(minHeight: 44)

            if model.overwritesExisting {
                Text("Aktualisiert Titel, Fälligkeit, Priorität, Notizen und Link bei eindeutig zugeordneten Aufgaben.")
                    .ankerType(AnkerType.caption)
                    .foregroundStyle(AnkerColor.inkSecond)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("Neu: \(plan.datedCount) im Wochenplan, \(plan.inboxCount) im Eingang")
                .ankerType(AnkerType.body)
                .foregroundStyle(AnkerColor.ink)
                .fixedSize(horizontal: false, vertical: true)

            if model.overwritesExisting {
                Text("Aktualisierungen: \(plan.updatedCount)")
                    .ankerType(AnkerType.body)
                    .foregroundStyle(AnkerColor.ink)
            }

            if plan.skippedExisting > 0 {
                Text("\(plan.skippedExisting) schon vorhanden, werden übersprungen")
                    .ankerType(AnkerType.caption)
                    .foregroundStyle(AnkerColor.inkSecond)
            }

            if let unmatched = plan.skipped[.unmatchedUpdate], unmatched > 0 {
                Text("Übersprungen wegen unklarer Zuordnung: \(unmatched)")
                    .ankerType(AnkerType.caption)
                    .foregroundStyle(AnkerColor.inkSecond)
            }

            Button {
                model.runImport(modelContext: modelContext)
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

    private func doneCard(created: Int, updated: Int) -> some View {
        VStack(alignment: .leading, spacing: AnkerSpacing.s3) {
            Text("\(created) neu · \(updated) aktualisiert")
                .ankerType(AnkerType.bodyStrong)
                .foregroundStyle(AnkerColor.ink)
            Text("Aufgaben für diese und nächste Woche stehen an ihrem Tag. Die übrigen findest du im Eingang. Fälligkeiten, Notizen und Links stehen im Aufgabeneditor.")
                .ankerType(AnkerType.caption)
                .foregroundStyle(AnkerColor.inkSecond)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                undone = model.undoImport(modelContext: modelContext)
            } label: {
                Label("Import rückgängig machen", ankerIcon: AnkerIcon.undo)
            }
            .buttonStyle(AnkerButtonStyle.secondary)
        }
        .padding(AnkerSpacing.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ankerCard()
    }
}
