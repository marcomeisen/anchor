import CloudKit
import Foundation
import OSLog
import SwiftData

/// Export und vollstaendige Loeschung der Nutzerdaten.
///
/// Setzt die Betroffenenrechte aus Art. 15, 17 und 20 DSGVO um. Beides laeuft ueber den
/// `ModelContext` und damit ueber CloudKit: der Export sieht denselben Stand wie die
/// Oberflaeche, und geloeschte Datensaetze werden als Loeschung in die private
/// CloudKit-Datenbank exportiert statt nur lokal zu verschwinden.
@MainActor
enum DataPortability {

    // MARK: - Export

    /// Vollstaendiges Abbild des Datenbestands.
    ///
    /// Zusaetzlich zu den Wochen wird `unassigned` gefuellt: Datensaetze ohne Woche oder ohne
    /// Tag sind ueber die Oberflaeche nicht erreichbar, gehoeren dem Nutzer aber trotzdem und
    /// muessen in einer Auskunft nach Art. 15 auftauchen.
    struct Snapshot: Codable, Sendable {
        /// 3: Anker tragen ihren Warum-Satz (`why`) und die Rückblickantwort (`verdict`).
        /// 4: Aufgaben tragen ihre Wiederholregel (`recurrence`) und die ID ihrer
        /// Folgeinstanz (`recurrenceNextID`).
        /// 5: Aufgaben tragen die Originalangaben aus importierten Erinnerungen.
        var formatVersion = 5
        var exportedAt: Date
        var application: String
        var weeks: [ExportedWeek]
        var unassigned: Unassigned

        struct Unassigned: Codable, Sendable {
            var goals: [ExportedGoal]
            var days: [ExportedDay]
            var tasks: [ExportedTask]
            var timeBlocks: [ExportedTimeBlock]

            var isEmpty: Bool {
                goals.isEmpty && days.isEmpty && tasks.isEmpty && timeBlocks.isEmpty
            }
        }
    }

    struct ExportedWeek: Codable, Sendable {
        var id: UUID
        var isoYear: Int
        var isoWeek: Int
        var monday: Date
        var sunday: Date
        var reflection: String?
        var reviewedAt: Date?
        var goals: [ExportedGoal]
        var days: [ExportedDay]
    }

    struct ExportedGoal: Codable, Sendable {
        var id: UUID
        var title: String
        var colorHex: String
        var order: Int
        var weekID: UUID?
        var why: String?
        var verdict: String?
        var createdAt: Date? = nil
    }

    struct ExportedDay: Codable, Sendable {
        var id: UUID
        var date: Date
        var focusNote: String?
        var notes: String?
        var weekID: UUID?
        /// Der gemeinte Kalendertag, `2026-11-23`; fehlt bei Altbestand.
        var dayKey: String? = nil
        var tasks: [ExportedTask]
        var timeBlocks: [ExportedTimeBlock]
    }

    struct ExportedTask: Codable, Sendable {
        var id: UUID
        var title: String
        var priority: String
        var isDone: Bool
        var order: Int
        var completedAt: Date?
        var carryOverCount: Int
        var dayID: UUID?
        var linkedGoalID: UUID?
        /// Rohtext der Regel (`daily`, `weekdays`, `weekly`, `biweekly`, `monthly`), `nil` einmalig.
        var recurrence: String?
        var recurrenceNextID: UUID?
        var importedReminder: ImportedReminderDetails?
    }

    struct ExportedTimeBlock: Codable, Sendable {
        var id: UUID
        var title: String
        var startTime: Date
        var endTime: Date
        var dayID: UUID?
        var linkedEventIdentifier: String?
    }

    static func snapshot(from context: ModelContext, exportedAt: Date = Date()) throws -> Snapshot {
        let weeks = try context.fetch(FetchDescriptor<Week>(sortBy: [SortDescriptor(\.monday)]))
        let allGoals = try context.fetch(FetchDescriptor<Goal>())
        let allDays = try context.fetch(FetchDescriptor<Day>(sortBy: [SortDescriptor(\.date)]))
        let allTasks = try context.fetch(FetchDescriptor<AnkerTask>())
        let allBlocks = try context.fetch(FetchDescriptor<TimeBlock>())

        return Snapshot(
            exportedAt: exportedAt,
            application: "Anchorit \(CloudSyncDiagnostics.appVersion)",
            weeks: weeks.map(exported(week:)),
            unassigned: Snapshot.Unassigned(
                goals: allGoals.filter { $0.week == nil }.map(exported(goal:)),
                days: allDays.filter { $0.week == nil }.map(exported(day:)),
                tasks: allTasks.filter { $0.day == nil }.map(exported(task:)),
                timeBlocks: allBlocks.filter { $0.day == nil }.map(exported(timeBlock:))
            )
        )
    }

    /// JSON, weil es ohne Zusatzsoftware lesbar und maschinell weiterverarbeitbar ist —
    /// beides verlangt Art. 20 ("gaengiges, maschinenlesbares Format").
    static func encodedSnapshot(from context: ModelContext, exportedAt: Date = Date()) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(snapshot(from: context, exportedAt: exportedAt))
    }

    static func exportFileName(for date: Date = Date()) -> String {
        // Bewusst ISO statt lokalem Format: der Name soll sortierbar sein und keine
        // Zeichen enthalten, die ein Dateisystem nicht mag.
        let day = date.formatted(.iso8601.year().month().day().dateSeparator(.dash))
        return "Anchorit-Export-\(day).json"
    }

    private static func exported(week: Week) -> ExportedWeek {
        ExportedWeek(
            id: week.id,
            isoYear: week.isoYear,
            isoWeek: week.isoWeek,
            monday: week.monday,
            sunday: week.sunday,
            reflection: week.reflection,
            reviewedAt: week.reviewedAt,
            // Sortiert exportieren: eine Auskunft muss zweimal gleich aussehen.
            goals: GoalOrdering.sorted(week.goalList).map(exported(goal:)),
            days: week.dayList.sorted { $0.date < $1.date }.map(exported(day:))
        )
    }

    private static func exported(goal: Goal) -> ExportedGoal {
        ExportedGoal(
            id: goal.id,
            title: goal.title,
            colorHex: goal.colorHex,
            order: goal.order,
            weekID: goal.week?.id,
            why: goal.why,
            verdict: goal.verdictRaw,
            createdAt: goal.createdAt
        )
    }

    private static func exported(day: Day) -> ExportedDay {
        ExportedDay(
            id: day.id,
            date: day.date,
            focusNote: day.focusNote,
            notes: day.notes,
            weekID: day.week?.id,
            dayKey: day.dayKey,
            tasks: day.taskList.sorted { $0.order < $1.order }.map(exported(task:)),
            timeBlocks: day.timeBlockList.sorted { $0.startTime < $1.startTime }.map(exported(timeBlock:))
        )
    }

    private static func exported(task: AnkerTask) -> ExportedTask {
        ExportedTask(
            id: task.id,
            title: task.title,
            priority: task.priority.rawValue,
            isDone: task.isDone,
            order: task.order,
            completedAt: task.completedAt,
            carryOverCount: task.carryOverCount,
            dayID: task.day?.id,
            linkedGoalID: task.linkedGoal?.id,
            recurrence: task.recurrenceRaw,
            recurrenceNextID: task.recurrenceNextID,
            importedReminder: task.importedReminder
        )
    }

    private static func exported(timeBlock: TimeBlock) -> ExportedTimeBlock {
        ExportedTimeBlock(
            id: timeBlock.id,
            title: timeBlock.title,
            startTime: timeBlock.startTime,
            endTime: timeBlock.endTime,
            dayID: timeBlock.day?.id,
            linkedEventIdentifier: timeBlock.linkedEventIdentifier
        )
    }

    // MARK: - Loeschung

    struct DeletionReport: Sendable {
        var weeks = 0
        var goals = 0
        var days = 0
        var tasks = 0
        var timeBlocks = 0
        /// Falsch, wenn der Bestand nicht vollständig gelesen oder gelöscht werden konnte.
        var didSave = true

        var total: Int { weeks + goals + days + tasks + timeBlocks }
    }

    /// Loescht alle Nutzerdaten und meldet, was entfernt wurde.
    ///
    /// Jedes Objekt wird einzeln geloescht statt den Store wegzuwerfen: nur so entsteht pro
    /// Datensatz eine Loeschung, die CloudKit in die private Datenbank exportiert. Ein
    /// geloeschter lokaler Store wuerde beim naechsten Sync aus iCloud wiederhergestellt —
    /// genau der Fall, den Art. 17 ausschliesst.
    ///
    /// Reihenfolge von innen nach aussen, damit keine Cascade-Regel ein Objekt entfernt,
    /// das gleich noch gezaehlt werden soll.
    @discardableResult
    static func deleteAllData(in context: ModelContext, defaults: UserDefaults = .standard) -> DeletionReport {
        do {
            // Alle Typen vor der ersten Löschung laden. Ein Fetch-Fehler darf keinen Typ auslassen.
            let tasks = try context.fetch(FetchDescriptor<AnkerTask>())
            let blocks = try context.fetch(FetchDescriptor<TimeBlock>())
            let goals = try context.fetch(FetchDescriptor<Goal>())
            let days = try context.fetch(FetchDescriptor<Day>())
            let weeks = try context.fetch(FetchDescriptor<Week>())

            // Vor dem Löschstapel offene Änderungen sichern. Bei einem Fehler im Löschstapel
            // rollt rollback() damit nur die Löschung zurück.
            guard context.saveChanges() else { return DeletionReport(didSave: false) }
            for task in tasks { context.delete(task) }
            for block in blocks { context.delete(block) }
            for goal in goals { context.delete(goal) }
            for day in days { context.delete(day) }
            for week in weeks { context.delete(week) }

            guard context.saveChanges() else {
                context.rollback()
                return DeletionReport(didSave: false)
            }
            resetStoredPreferences(in: defaults)
            let report = DeletionReport(weeks: weeks.count, goals: goals.count, days: days.count, tasks: tasks.count, timeBlocks: blocks.count)
            persistenceLog.notice("Lokale Löschung abgeschlossen: \(report.total, privacy: .public) Datensätze")
            return report
        } catch {
            let failure = PersistenceFailure(operation: #function, error: error)
            persistenceLog.error("Datenbestand für Löschung nicht lesbar — \(failure.code, privacy: .public)")
            return DeletionReport(didSave: false)
        }
    }

    /// Löscht die CloudKit-Zone, in der SwiftData den Bestand spiegelt.
    ///
    /// Die lokale Löschung erreicht nur, was dieses Gerät kennt. Was noch nicht importiert ist
    /// (frisches Gerät, laufender Import) oder bei abgeschaltetem Sync, bliebe in iCloud liegen.
    /// Das Löschen der Zone räumt den ganzen Bestand ab; die anderen Geräte erfahren davon und
    /// leeren ihre gespiegelten Daten. **Erst nach** der lokalen Löschung aufrufen, sonst würde
    /// der laufende Container die lokalen Daten in eine neue Zone zurückexportieren.
    ///
    /// - Returns: `true`, wenn die Zone gelöscht wurde oder gar nicht existierte.
    static func deleteCloudData() async -> CloudDeletionResult {
#if DEBUG
        if UITestMode.isActive { return .notApplicable }
#endif
        guard !CloudSyncConfiguration.isRunningTests, CloudSyncConfiguration.hasCloudKitEntitlement else {
            return .notApplicable
        }
        let container = CKContainer(identifier: CloudSyncConfiguration.containerIdentifier)
        do {
            let status = try await container.accountStatus()
            if status == .noAccount { return .noAccount }
            guard status == .available else { return .unavailable }
            let zone = CKRecordZone.ID(zoneName: "com.apple.coredata.cloudkit.zone", ownerName: CKCurrentUserDefaultName)
            _ = try await container.privateCloudDatabase.deleteRecordZone(withID: zone)
            persistenceLog.notice("CloudKit-Zone gelöscht")
            return .deleted
        } catch let error as CKError where error.code == .zoneNotFound || error.code == .userDeletedZone {
            return .deleted
        } catch let error as CKError where error.code == .notAuthenticated {
            return .noAccount
        } catch {
            persistenceLog.error("CloudKit-Zone nicht gelöscht — \((error as NSError).domain, privacy: .public) \((error as NSError).code, privacy: .public)")
            return .failed
        }
    }

    enum CloudDeletionResult: Sendable {
        case deleted, noAccount, notApplicable, unavailable, failed
    }

    /// Zum Datenbestand gehoerende Einstellungen. Ohne diesen Schritt bliebe nach einer
    /// Loeschung der Onboarding-Zustand stehen und der Nutzer landete in einer leeren App,
    /// die so tut, als sei sie schon eingerichtet.
    static func resetStoredPreferences(in defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: "hasCompletedOnboarding")
        defaults.removeObject(forKey: "onboardingVersion")
        defaults.removeObject(forKey: AppSettingsKey.remindersImportedIdentifiers)
    }
}
