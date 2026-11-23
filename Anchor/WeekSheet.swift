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
    /// Ob der Eingang in der losen Bahn steht.
    let includesInbox: Bool

    /// - Parameters:
    ///   - inbox: Aufgaben ohne Tag und ohne Anker. Sie gehören zu **keiner** Woche.
    ///   - now: Bestimmt die laufende Woche.
    ///   - includesInbox: `nil` (Standard) heißt: nur in der laufenden Woche.
    ///
    /// **Der Eingang steht nur auf dem Blatt der laufenden Woche.** Vorher stand er in der
    /// losen Bahn jeder Woche — in der Vorwoche, im Archiv, in einer Woche in drei Monaten —,
    /// und der Rückblick einer vergangenen Woche zählte ihn als „offen geblieben", obwohl er
    /// nie zu ihr gehörte. Der Eingang ist das, was *jetzt* noch keinen Platz hat; also steht
    /// er dort, wo jetzt geplant wird. Wer ihn anderswo braucht, gibt `includesInbox: true`.
    init(monday: Date, weeks: [Week], inbox: [AnkerTask], now: Date = Date(), includesInbox: Bool? = nil) {
        let interval = AnkerCalendar.weekInterval(containing: monday)
        self.monday = interval.monday
        self.dates = AnkerCalendar.daysInWeek(starting: interval.monday)
        let week = WeekPlanning.week(startingAt: interval.monday, in: weeks)
        self.week = week
        let showsInbox = includesInbox
            ?? (AnkerCalendar.weekKey(containing: now) == AnkerCalendar.weekKey(containing: interval.monday))
        self.includesInbox = showsInbox
        let inbox = showsInbox ? inbox.filter { !$0.isDeleted && $0.day == nil && $0.linkedGoal == nil } : []

        guard let week else {
            lanes = [Lane(goal: nil, number: nil, tasks: Self.sorted(inbox))]
            return
        }

        let anchors = GoalOrdering.anchors(in: week)
        var anchorLanes = anchors.enumerated().map { index, goal in
            Lane(goal: goal, number: index + 1, tasks: Self.sorted(goal.taskList.filter { !$0.isDeleted }))
        }

        // Ohne Anker: was an einem Tag dieser Woche liegt und keinen der vier Anker hat —
        // auch Aufgaben eines fünften Ziels, das über das Limit gerutscht ist — plus der Eingang.
        // Jede Aufgabe steht genau einmal auf dem Blatt; doppelte Kanten aus dem Sync (eine
        // Aufgabe in zwei Tageslisten) dürfen sie nicht zweimal zählen.
        let anchorIDs = Set(anchors.map(\.id))
        var seen = Set(anchorLanes.flatMap(\.tasks).map(\.id))
        let looseScheduled = week.dayList
            .filter { !$0.isDeleted }
            .flatMap(\.taskList)
            .filter { task in !task.isDeleted && !(task.linkedGoal.map { anchorIDs.contains($0.id) } ?? false) }
        let looseUnscheduled = GoalOrdering.excess(in: week).flatMap { $0.taskList.filter { !$0.isDeleted && $0.day == nil } }
        let loose = (looseScheduled + looseUnscheduled + inbox).filter { seen.insert($0.id).inserted }
        anchorLanes.append(Lane(goal: nil, number: nil, tasks: Self.sorted(loose)))
        lanes = anchorLanes
    }

    /// Das Blatt einer gespeicherten Woche, über ihren gemeinten Montag — `week.monday` ist
    /// Mitternacht in der Zone des anlegenden Geräts und läge westlich davon in der Vorwoche.
    init(week: Week, inbox: [AnkerTask] = [], now: Date = Date(), includesInbox: Bool? = nil) {
        self.init(
            monday: AnkerCalendar.nominalDate(ofStored: week.monday),
            weeks: [week],
            inbox: inbox,
            now: now,
            includesInbox: includesInbox
        )
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
