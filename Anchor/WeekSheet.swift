import Foundation
import SwiftData

/// Die Woche als **Blatt**: bis zu vier Anker mal sieben Tage, dazu „ohne Anker" und
/// „ohne Tag" — ohne View, deshalb testbar.
///
/// Die Woche selbst darf fehlen. Seit Wochen erst beim Schreiben entstehen, ist eine Woche, an
/// der noch nichts geplant ist, schlicht nicht im Store; die sieben Daten kommen dann aus dem
/// Kalender, und jede Ansicht zeigt ein leeres Blatt statt einen Ladekreisel.
@MainActor
struct WeekSheet {
    /// Eine Zeile (Mac-Raster) bzw. Spalte (nach Anker): ein Anker oder „ohne Anker".
    struct Lane: Identifiable {
        let goal: Goal?
        /// 1–4, `nil` für „ohne Anker".
        let number: Int?
        let tasks: [AnkerTask]

        var id: String { goal.map { $0.id.uuidString } ?? "loose" }
        var isLoose: Bool { goal == nil }
        var title: String { goal?.title ?? "Ohne Anker" }
        var why: String? { goal?.why?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank }
        var doneCount: Int { tasks.filter(\.isDone).count }
        var numberLabel: String { number.map(String.init) ?? "–" }
    }

    let monday: Date
    let week: Week?
    let dates: [Date]
    let lanes: [Lane]

    init(monday: Date, weeks: [Week], inbox: [AnkerTask]) {
        let interval = AnkerCalendar.weekInterval(containing: monday)
        self.monday = interval.monday
        self.dates = AnkerCalendar.daysInWeek(starting: interval.monday)
        let week = WeekPlanning.week(startingAt: interval.monday, in: weeks)
        self.week = week

        guard let week else {
            lanes = [Lane(goal: nil, number: nil, tasks: inbox)]
            return
        }

        let anchors = GoalOrdering.anchors(in: week)
        var anchorLanes = anchors.enumerated().map { index, goal in
            Lane(goal: goal, number: index + 1, tasks: Self.sorted(goal.taskList.filter { !$0.isDeleted }))
        }

        // Ohne Anker: was an einem Tag dieser Woche liegt und keinen der vier Anker hat —
        // auch Aufgaben eines fünften Ziels, das über das Limit gerutscht ist — plus der Eingang.
        let anchorIDs = Set(anchors.map(\.id))
        let looseScheduled = week.dayList
            .flatMap(\.taskList)
            .filter { task in !task.isDeleted && !(task.linkedGoal.map { anchorIDs.contains($0.id) } ?? false) }
        let looseUnscheduled = GoalOrdering.excess(in: week).flatMap { $0.taskList.filter { $0.day == nil } }
        anchorLanes.append(Lane(goal: nil, number: nil, tasks: Self.sorted(looseScheduled + looseUnscheduled + inbox)))
        lanes = anchorLanes
    }

    var anchorLanes: [Lane] { lanes.filter { !$0.isLoose } }
    var looseLane: Lane? { lanes.first(where: \.isLoose) }

    var isoWeek: Int { AnkerCalendar.weekInterval(containing: monday).isoWeek }
    var isoYear: Int { AnkerCalendar.weekInterval(containing: monday).isoYear }
    var sunday: Date { dates.last ?? monday }

    /// Aufgaben einer Bahn an einem Tag; `date == nil` heißt „ohne Tag".
    func tasks(in lane: Lane, on date: Date?) -> [AnkerTask] {
        lane.tasks.filter { task in
            guard let date else { return task.day == nil }
            guard let day = task.day else { return false }
            return AnkerCalendar.storedDay(day.date, isOn: date)
        }
    }

    /// Alle Aufgaben eines Tages, nach Ankernummer sortiert.
    func tasks(on date: Date) -> [AnkerTask] {
        lanes.flatMap { tasks(in: $0, on: date) }
    }

    /// Was zu dieser Woche gehört, aber noch keinen Tag hat. Erledigtes ohne Tag braucht keinen
    /// mehr und steht deshalb nicht im Vorrat.
    var unplanned: [AnkerTask] {
        lanes.flatMap { tasks(in: $0, on: nil) }.filter { !$0.isDone }
    }

    func anchorNumber(of task: AnkerTask) -> Int? {
        guard let goal = task.linkedGoal else { return nil }
        return anchorLanes.first { $0.goal?.id == goal.id }?.number
    }

    /// Erledigt von geplant, über die vier Anker. „Ohne Anker" zählt nicht zur Woche.
    var anchorProgress: (done: Int, total: Int) {
        let tasks = anchorLanes.flatMap(\.tasks)
        return (tasks.filter(\.isDone).count, tasks.count)
    }

    private static func sorted(_ tasks: [AnkerTask]) -> [AnkerTask] {
        tasks.sorted { left, right in
            switch (left.day?.date, right.day?.date) {
            case let (l?, r?) where l != r: return l < r
            case (nil, _?): return false
            case (_?, nil): return true
            default: return left.order < right.order
            }
        }
    }
}

extension String {
    var nilIfBlank: String? {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
    }
}
