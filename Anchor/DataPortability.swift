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
        var formatVersion = 1
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
        var goals: [ExportedGoal]
        var days: [ExportedDay]
    }

    struct ExportedGoal: Codable, Sendable {
        var id: UUID
        var title: String
        var colorHex: String
        var weekID: UUID?
    }

    struct ExportedDay: Codable, Sendable {
        var id: UUID
        var date: Date
        var focusNote: String?
        var notes: String?
        var weekID: UUID?
        var tasks: [ExportedTask]
        var timeBlocks: [ExportedTimeBlock]
    }

    struct ExportedTask: Codable, Sendable {
        var id: UUID
        var title: String
        var priority: String
        var isDone: Bool
        var order: Int
        var dayID: UUID?
        var linkedGoalID: UUID?
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
            application: "Daivento \(CloudSyncDiagnostics.appVersion)",
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
        return "Daivento-Export-\(day).json"
    }

    private static func exported(week: Week) -> ExportedWeek {
        ExportedWeek(
            id: week.id,
            isoYear: week.isoYear,
            isoWeek: week.isoWeek,
            monday: week.monday,
            sunday: week.sunday,
            goals: week.goalList.map(exported(goal:)),
            days: week.dayList.sorted { $0.date < $1.date }.map(exported(day:))
        )
    }

    private static func exported(goal: Goal) -> ExportedGoal {
        ExportedGoal(id: goal.id, title: goal.title, colorHex: goal.colorHex, weekID: goal.week?.id)
    }

    private static func exported(day: Day) -> ExportedDay {
        ExportedDay(
            id: day.id,
            date: day.date,
            focusNote: day.focusNote,
            notes: day.notes,
            weekID: day.week?.id,
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
            dayID: task.day?.id,
            linkedGoalID: task.linkedGoal?.id
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
        /// Falsch, wenn das Speichern fehlgeschlagen ist — dann ist nichts geloescht.
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
    static func deleteAllData(in context: ModelContext) -> DeletionReport {
        var report = DeletionReport()

        let tasks = (try? context.fetch(FetchDescriptor<AnkerTask>())) ?? []
        let blocks = (try? context.fetch(FetchDescriptor<TimeBlock>())) ?? []
        let goals = (try? context.fetch(FetchDescriptor<Goal>())) ?? []
        let days = (try? context.fetch(FetchDescriptor<Day>())) ?? []
        let weeks = (try? context.fetch(FetchDescriptor<Week>())) ?? []

        report.tasks = tasks.count
        report.timeBlocks = blocks.count
        report.goals = goals.count
        report.days = days.count
        report.weeks = weeks.count

        for task in tasks { context.delete(task) }
        for block in blocks { context.delete(block) }
        for goal in goals { context.delete(goal) }
        for day in days { context.delete(day) }
        for week in weeks { context.delete(week) }

        report.didSave = context.saveChanges()

        persistenceLog.notice(
            "Alle Daten geloescht: \(report.weeks, privacy: .public) Wochen, \(report.goals, privacy: .public) Ziele, \(report.days, privacy: .public) Tage, \(report.tasks, privacy: .public) Aufgaben, \(report.timeBlocks, privacy: .public) Zeitbloecke, gespeichert=\(report.didSave, privacy: .public)"
        )

        return report
    }

    /// Zum Datenbestand gehoerende Einstellungen. Ohne diesen Schritt bliebe nach einer
    /// Loeschung der Onboarding-Zustand stehen und der Nutzer landete in einer leeren App,
    /// die so tut, als sei sie schon eingerichtet.
    static func resetStoredPreferences(in defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: "hasCompletedOnboarding")
        defaults.removeObject(forKey: "onboardingVersion")
    }
}
