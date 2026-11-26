import Foundation
import SwiftData

@Model
final class Goal {
    var id: UUID = UUID()
    var title: String = ""
    var colorHex: String = "#5B6EE8"
    /// Position des Ankers in der Woche, 0-basiert.
    ///
    /// CloudKit spiegelt To-many-Beziehungen **ungeordnet** — `Week.goalList` hat nach jedem
    /// Import eine andere Reihenfolge, und die Ankernummern 1 bis 4 wuerden auf jedem Geraet
    /// anders vergeben. Ohne dieses Feld ist „Anker 2" keine feste Aussage.
    var order: Int = 0
    var week: Week?

    /// Ein Satz, warum dieser Anker diese Woche zaehlt. Optional und additiv — aeltere
    /// Datensaetze und aeltere App-Versionen kommen ohne aus.
    var why: String?

    /// Die Antwort im Wochenrueckblick: `GoalVerdict.rawValue`. `nil` heisst noch nicht
    /// beantwortet. Als Text statt als Enum gespeichert, damit ein unbekannter Wert einer
    /// neueren Version auf einem aelteren Geraet nicht den Import bricht.
    var verdictRaw: String?

    var verdict: GoalVerdict? {
        get { verdictRaw.flatMap(GoalVerdict.init(rawValue:)) }
        set { verdictRaw = newValue?.rawValue }
    }

    @Relationship(deleteRule: .nullify, inverse: \AnkerTask.linkedGoal)
    var tasks: [AnkerTask]? = []

    var progress: Double {
        taskList.isEmpty ? 0 : Double(taskList.filter(\.isDone).count) / Double(taskList.count)
    }

    var taskList: [AnkerTask] { tasks ?? [] }

    init(id: UUID = UUID(), title: String, colorHex: String, order: Int = 0, week: Week? = nil) {
        self.id = id
        self.title = title
        self.colorHex = colorHex
        self.order = order
        self.week = week
    }
}

@Model
final class Week {
    var id: UUID = UUID()
    var isoYear: Int = 0
    var isoWeek: Int = 0
    var monday: Date = Date()
    var sunday: Date = Date()

    // `.nullify` statt `.cascade`, bewusst: eine Woche wird nur beim Zusammenfuehren von
    // Sync-Duplikaten und beim vollstaendigen Loeschen entfernt. Kommt die Loeschung eines
    // Duplikats von einem anderen Geraet an, bevor dieses Geraet die Kinder umgehaengt hat,
    // haette die Kaskade Tage, Ziele und Aufgaben mitgenommen — und die Loeschung danach
    // exportiert. Verwaiste Kinder sammelt `StoreMaintenance.adoptOrphans` wieder ein.
    @Relationship(deleteRule: .nullify, inverse: \Goal.week)
    var goals: [Goal]? = []

    @Relationship(deleteRule: .nullify, inverse: \Day.week)
    var days: [Day]? = []

    /// Antwort auf die eine Frage des Wochenrueckblicks.
    ///
    /// Stand bisher nur als `@State` in der Ansicht und war beim Bildschirmwechsel weg.
    var reflection: String?

    /// Gesetzt von „Woche schliessen". `nil` heisst offen.
    ///
    /// Optional statt `Bool`: der Zeitpunkt ist die eigentliche Information, und beim
    /// Zusammenfuehren zweier Kopien konvergiert nil/nicht-nil ohne Regel.
    var reviewedAt: Date?

    var goalList: [Goal] { goals ?? [] }
    var dayList: [Day] { days ?? [] }
    var isReviewed: Bool { reviewedAt != nil }

    func appendGoal(_ goal: Goal) {
        var existingGoals = goalList
        existingGoals.append(goal)
        goals = existingGoals
    }

    init(
        id: UUID = UUID(),
        isoYear: Int,
        isoWeek: Int,
        monday: Date,
        sunday: Date
    ) {
        self.id = id
        self.isoYear = isoYear
        self.isoWeek = isoWeek
        self.monday = monday
        self.sunday = sunday
    }
}

@Model
final class Day {
    var id: UUID = UUID()
    var date: Date = Date()
    var focusNote: String?
    var week: Week?

    // Aus demselben Grund `.nullify`: eine Aufgabe ohne Tag ist kein Datenmuell, sondern
    // „noch nicht eingeplant" — sie gehoert ueber `linkedGoal` weiter zu ihrer Woche.
    @Relationship(deleteRule: .nullify, inverse: \AnkerTask.day)
    var tasks: [AnkerTask]? = []

    @Relationship(deleteRule: .nullify, inverse: \TimeBlock.day)
    var timeBlocks: [TimeBlock]? = []

    var notes: String?

    var taskList: [AnkerTask] { tasks ?? [] }
    var timeBlockList: [TimeBlock] { timeBlocks ?? [] }

    func appendTask(_ task: AnkerTask) {
        var existingTasks = taskList
        existingTasks.append(task)
        tasks = existingTasks
    }

    init(
        id: UUID = UUID(),
        date: Date,
        focusNote: String? = nil,
        week: Week? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.date = date
        self.focusNote = focusNote
        self.week = week
        self.notes = notes
    }
}

/// Die Antwort auf „Wie lief dieser Anker?" im Wochenrueckblick.
///
/// Bewusst vom Nutzer gegeben statt aus den Haken errechnet: „1 von 2 erledigt" kann trotzdem
/// gehalten sein. Die Zahl ist ein Hinweis, die Antwort ist die Aussage.
enum GoalVerdict: String, CaseIterable, Identifiable, Sendable {
    case held
    case partial
    case missed

    var id: String { rawValue }

    var label: String {
        switch self {
        case .held: String(localized: "Gehalten")
        case .partial: String(localized: "Teilweise")
        case .missed: String(localized: "Nicht")
        }
    }
}

enum Priority: String, Codable, CaseIterable, Identifiable {
    case a
    case b
    case c

    var id: String { rawValue }

    var label: String { rawValue.uppercased() }
}

/// Wie sich eine Aufgabe wiederholt — „nach Plan" wie das „every" von Things oder Todoist:
/// der naechste Termin rechnet ab dem **geplanten** Tag der erledigten Instanz, nicht ab heute.
///
/// Als Text in `AnkerTask.recurrenceRaw` gespeichert, nicht als `Codable`-Enum.
nonisolated enum TaskRecurrence: String, CaseIterable, Identifiable, Sendable {
    case daily
    case weekdays
    case weekly
    case biweekly
    case monthly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .daily: String(localized: "Täglich")
        case .weekdays: String(localized: "Werktags")
        case .weekly: String(localized: "Wöchentlich")
        case .biweekly: String(localized: "Alle 2 Wochen")
        case .monthly: String(localized: "Monatlich")
        }
    }

    /// Fuer das kleine Wiederhol-Symbol an Zeile und Chip.
    var accessibilityDescription: String {
        switch self {
        case .daily: String(localized: "wiederholt sich täglich")
        case .weekdays: String(localized: "wiederholt sich werktags")
        case .weekly: String(localized: "wiederholt sich wöchentlich")
        case .biweekly: String(localized: "wiederholt sich alle 2 Wochen")
        case .monthly: String(localized: "wiederholt sich monatlich")
        }
    }

    /// Der naechste Termin nach dem Kalendertag `date` (Mitternacht in `calendar`).
    ///
    /// Werktags ueberspringt Samstag und Sonntag. Monatlich nimmt denselben Tag im Folgemonat,
    /// in einem kuerzeren Monat dessen letzten Tag — `date(byAdding: .month)` klemmt genau so.
    /// Grenze: die Kette merkt sich den urspruenglichen Monatstag nicht; nach einem 31. Januar
    /// folgt der 28. Februar und danach der 28. Maerz. Ein Feld dafuer waere eine weitere
    /// Schemaaenderung fuer einen seltenen Fall.
    func nextDate(after date: Date, calendar: Calendar = AnkerCalendar.iso) -> Date {
        let start = calendar.startOfDay(for: date)
        let next: Date?
        switch self {
        case .daily:
            next = calendar.date(byAdding: .day, value: 1, to: start)
        case .weekdays:
            var candidate = calendar.date(byAdding: .day, value: 1, to: start)
            // `weekday` zaehlt auch im ISO-Kalender gregorianisch: 1 Sonntag, 7 Samstag.
            while let current = candidate, [1, 7].contains(calendar.component(.weekday, from: current)) {
                candidate = calendar.date(byAdding: .day, value: 1, to: current)
            }
            next = candidate
        case .weekly:
            next = calendar.date(byAdding: .day, value: 7, to: start)
        case .biweekly:
            next = calendar.date(byAdding: .day, value: 14, to: start)
        case .monthly:
            next = calendar.date(byAdding: .month, value: 1, to: start)
        }
        return calendar.startOfDay(for: next ?? start)
    }
}

@Model
final class AnkerTask {
    var id: UUID = UUID()
    var title: String = ""
    var priority: Priority = Priority.b
    var isDone: Bool = false
    var order: Int = 0
    /// Wann die Aufgabe erledigt wurde. `nil` heisst offen — oder erledigt, bevor es dieses
    /// Feld gab; dafuer gibt es `completionDate`.
    ///
    /// Der geplante Tag ist **nicht** der Erledigungstag, und `TaskActions.move` aendert `day`
    /// nachtraeglich. Ohne dieses Feld waere „staerkster Wochentag" eine Aussage ueber die
    /// Planung, nicht ueber das Verhalten.
    var completedAt: Date?

    /// Wie oft die Aufgabe ueber eine Wochengrenze nach vorn geschoben wurde.
    var carryOverCount: Int = 0

    var day: Day?
    var linkedGoal: Goal?

    /// Die Wiederholregel: `TaskRecurrence.rawValue`, `nil` heisst einmalig.
    ///
    /// Bewusst **nicht** wie `priority` als `Codable`-Enum gespeichert: ein Fall, den eine neuere
    /// Version hinzufuegt, braeche auf einem aelteren Geraet den Import. Als Text bleibt er
    /// stehen und wird dort nur nicht verstanden. Optional und additiv — aeltere Datensaetze
    /// und App-Versionen kommen ohne aus.
    var recurrenceRaw: String?

    /// Die ID der Folgeinstanz, sobald das Abhaken sie erzeugt hat.
    ///
    /// Haelt die Kette eindeutig: nur die **neueste** Instanz traegt die Regel weiter. Wird eine
    /// erledigte Aufgabe wieder geoeffnet und erneut abgehakt, steht hier schon eine ID — es
    /// entsteht keine zweite Folgeinstanz. Die ID statt eines `Bool`, damit Undo und der
    /// Rueckblick die Folgeinstanz finden.
    var recurrenceNextID: UUID?

    /// Originalangaben aus Apple Erinnerungen, unabhängig vom geplanten Tag.
    var importedReminderData: Data?

    var importedReminder: ImportedReminderDetails? {
        importedReminderData.flatMap { try? JSONDecoder().decode(ImportedReminderDetails.self, from: $0) }
    }

    var recurrence: TaskRecurrence? {
        get { recurrenceRaw.flatMap(TaskRecurrence.init(rawValue:)) }
        set { recurrenceRaw = newValue?.rawValue }
    }

    /// Bestbekannter Erledigungstag, mit Rueckfall auf den geplanten Tag fuer Altbestand.
    var completionDate: Date? {
        isDone ? (completedAt ?? day?.date) : nil
    }

    init(
        id: UUID = UUID(),
        title: String,
        priority: Priority,
        isDone: Bool = false,
        order: Int,
        completedAt: Date? = nil,
        carryOverCount: Int = 0,
        day: Day? = nil,
        linkedGoal: Goal? = nil
    ) {
        self.id = id
        self.title = title
        self.priority = priority
        self.isDone = isDone
        self.order = order
        self.completedAt = completedAt
        self.carryOverCount = carryOverCount
        self.day = day
        self.linkedGoal = linkedGoal
    }
}

@Model
final class TimeBlock {
    var id: UUID = UUID()
    var startTime: Date = Date()
    var endTime: Date = Date()
    var title: String = ""
    var day: Day?
    var linkedEventIdentifier: String?

    init(
        id: UUID = UUID(),
        startTime: Date,
        endTime: Date,
        title: String,
        day: Day? = nil,
        linkedEventIdentifier: String? = nil
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.title = title
        self.day = day
        self.linkedEventIdentifier = linkedEventIdentifier
    }
}
