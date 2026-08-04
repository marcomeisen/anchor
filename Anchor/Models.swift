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

    @Relationship(deleteRule: .cascade, inverse: \Goal.week)
    var goals: [Goal]? = []

    @Relationship(deleteRule: .cascade, inverse: \Day.week)
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

    @Relationship(deleteRule: .cascade, inverse: \AnkerTask.day)
    var tasks: [AnkerTask]? = []

    @Relationship(deleteRule: .cascade, inverse: \TimeBlock.day)
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

enum Priority: String, Codable, CaseIterable, Identifiable {
    case a
    case b
    case c

    var id: String { rawValue }

    var label: String { rawValue.uppercased() }
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
