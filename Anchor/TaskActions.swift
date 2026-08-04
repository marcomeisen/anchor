import SwiftData
import SwiftUI

import Combine
import SwiftData
import SwiftUI

struct TaskSnapshot: Identifiable {
    let id: UUID
    let title: String
    let priority: Priority
    let isDone: Bool
    let order: Int
    /// Muss mit: sonst laesst ein Undo den Erledigungszeitpunkt stehen und die Statistik
    /// zaehlt eine zurueckgenommene Erledigung weiter.
    let completedAt: Date?
    let carryOverCount: Int
    let dayID: UUID?
    let goalID: UUID?
}

struct TaskUndoNotice: Identifiable {
    let id = UUID()
    let message: String
    let snapshots: [TaskSnapshot]
    var operation: TaskUndoOperation = .restore
}

enum TaskUndoOperation {
    case restore
    case deleteCreated
}

/// Haelt den aktuell sichtbaren Rueckgaengig-Hinweis.
///
/// Laut Interaktionskonzept verdraengt ein neuer Toast den vorherigen sofort statt sich zu
/// stapeln, und er verschwindet nach vier Sekunden. Als eigener Typ, damit jede Ansicht mit
/// Aufgabenliste dieselbe Mechanik nutzt statt sie zu kopieren.
@MainActor
final class TaskUndoCoordinator: ObservableObject {
    @Published private(set) var notice: TaskUndoNotice?

    private var dismissTask: Task<Void, Never>?

    func present(_ notice: TaskUndoNotice) {
        guard !notice.snapshots.isEmpty else { return }

        dismissTask?.cancel()
        self.notice = notice

        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            self?.dismiss(noticeID: notice.id)
        }
    }

    func undo(weeks: [Week], modelContext: ModelContext) {
        guard let notice else { return }

        TaskActions.undo(notice, weeks: weeks, modelContext: modelContext)
        dismissTask?.cancel()
        self.notice = nil
    }

    private func dismiss(noticeID: UUID) {
        guard notice?.id == noticeID else { return }
        notice = nil
    }
}

enum TaskActions {
    static func toggleDone(_ task: AnkerTask, now: Date = Date(), modelContext: ModelContext) {
        setDone(task, !task.isDone, now: now, modelContext: modelContext)
    }

    /// Setzt den Zustand ausdruecklich — und fuehrt dabei `completedAt`.
    ///
    /// Es gab zwei Stellen, die `task.isDone` direkt zugewiesen haben (Mehrfachauswahl und
    /// Editorblatt). Die haetten den Zeitpunkt still ausgelassen und damit „staerkster
    /// Wochentag" verfaelscht.
    static func setDone(_ task: AnkerTask, _ isDone: Bool, now: Date = Date(), modelContext: ModelContext) {
        guard task.isDone != isDone else { return }
        task.isDone = isDone
        task.completedAt = isDone ? now : nil
        finishToggle(task, modelContext: modelContext)
    }

    /// Erledigtes wandert ans Ende des Tages — der Zustand ist zu dem Zeitpunkt schon gesetzt.
    private static func finishToggle(_ task: AnkerTask, modelContext: ModelContext) {
        if task.isDone, let day = task.day {
            task.order = (day.taskList.map(\.order).max() ?? task.order) + 1
            day.tasks = day.taskList.filter { $0.id != task.id } + [task]
            normalizeOrders(in: day)
        }

        modelContext.saveChanges()
    }

    static func delete(_ task: AnkerTask, modelContext: ModelContext) {
        if let day = task.day {
            day.tasks = day.taskList.filter { $0.id != task.id }
            normalizeOrders(in: day)
        }

        if let goal = task.linkedGoal {
            goal.tasks = goal.taskList.filter { $0.id != task.id }
        }

        modelContext.delete(task)
        modelContext.saveChanges()
    }

    @discardableResult
    static func duplicate(_ task: AnkerTask, modelContext: ModelContext) -> AnkerTask? {
        guard let day = task.day else { return nil }

        let copy = AnkerTask(
            title: task.title,
            priority: task.priority,
            isDone: false,
            order: day.taskList.count,
            day: day,
            linkedGoal: task.linkedGoal
        )
        modelContext.insert(copy)
        day.appendTask(copy)
        normalizeOrders(in: day)
        modelContext.saveChanges()
        return copy
    }

    /// Legt eine Aufgabe an.
    ///
    /// Bisher erzeugten `NewTaskSheet`, `QuickCapturePopover` und `WeeklyReviewView` selbst
    /// `AnkerTask(...)` — entgegen der Projektregel, dass Aufgaben nur ueber diese Schicht
    /// entstehen. Damit lag die Reihenfolge-Vergabe dreimal im Code und die Blaetter mussten
    /// selbst speichern.
    @discardableResult
    static func create(
        title: String,
        priority: Priority,
        on day: Day,
        linkedGoal: Goal?,
        modelContext: ModelContext
    ) -> AnkerTask? {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return nil }

        let task = AnkerTask(
            title: cleanTitle,
            priority: priority,
            order: day.taskList.count,
            day: day,
            linkedGoal: linkedGoal
        )
        modelContext.insert(task)
        day.appendTask(task)
        normalizeOrders(in: day)
        modelContext.saveChanges()
        return task
    }

    /// Legt eine Aufgabe aus einer Erfassungszeile an und erzeugt dabei Zielwoche und Zieltag,
    /// falls sie fehlen — ein Wochentagskuerzel kann in eine Woche zeigen, die es noch nicht gibt.
    @discardableResult
    static func create(
        _ input: CaptureInput,
        weekStart: Date,
        fallbackDate: Date,
        weeks: [Week],
        modelContext: ModelContext
    ) -> AnkerTask? {
        guard !input.isEmpty else { return nil }

        let target = CaptureSyntax.resolve(input, weekStart: weekStart, fallbackDate: fallbackDate)
        let week = ensureWeek(containing: target.date, weeks: weeks, modelContext: modelContext)
        let day = ensureDay(containing: target.date, in: week)
        // Ueber `GoalOrdering`, nicht ueber `week.goalList`: die Beziehung kommt nach einem
        // CloudKit-Sync ungeordnet zurueck, und ein ueberzaehliges fuenftes Ziel ist kein Anker.
        // Sonst zeigt `#1` auf jedem Geraet auf ein anderes Ziel.
        let goal = target.anchorNumber.flatMap { number -> Goal? in
            let anchors = GoalOrdering.anchors(in: week)
            guard anchors.indices.contains(number - 1) else { return nil }
            return anchors[number - 1]
        }

        return create(
            title: input.title,
            priority: target.priority,
            on: day,
            linkedGoal: goal,
            modelContext: modelContext
        )
    }

    /// Benennt eine Aufgabe um. Gibt zurück, ob sich etwas geändert hat — der Aufrufer haengt
    /// daran seinen Undo-Hinweis.
    ///
    /// Ein leerer Titel loescht die Aufgabe **nicht**: das waere eine unbeabsichtigte Loeschung
    /// durch Wegwischen von Text. Er wird verworfen, der alte Titel bleibt stehen.
    @discardableResult
    static func rename(_ task: AnkerTask, to title: String, modelContext: ModelContext) -> Bool {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, clean != task.title else { return false }
        task.title = clean
        modelContext.saveChanges()
        return true
    }

    static func setPriority(_ task: AnkerTask, to priority: Priority, modelContext: ModelContext) {
        task.priority = priority
        modelContext.saveChanges()
    }

    static func link(_ task: AnkerTask, to goal: Goal?, modelContext: ModelContext) {
        task.linkedGoal = goal
        modelContext.saveChanges()
    }

    static func snapshot(_ task: AnkerTask) -> TaskSnapshot {
        TaskSnapshot(
            id: task.id,
            title: task.title,
            priority: task.priority,
            isDone: task.isDone,
            order: task.order,
            completedAt: task.completedAt,
            carryOverCount: task.carryOverCount,
            dayID: task.day?.id,
            goalID: task.linkedGoal?.id
        )
    }

    static func undo(_ notice: TaskUndoNotice, weeks: [Week], modelContext: ModelContext) {
        switch notice.operation {
        case .restore:
            restore(notice.snapshots, weeks: weeks, modelContext: modelContext)
        case .deleteCreated:
            deleteCreatedTasks(notice.snapshots, weeks: weeks, modelContext: modelContext)
        }
    }

    static func restore(_ snapshots: [TaskSnapshot], weeks: [Week], modelContext: ModelContext) {
        let allDays = weeks.flatMap(\.dayList)
        let allGoals = weeks.flatMap(\.goalList)
        let existingTasks = allDays.flatMap(\.taskList)
        var targetDaysByID: [UUID: Day] = [:]
        var touchedOldDays: [UUID: Day] = [:]
        var restoredTasksByID: [UUID: AnkerTask] = [:]
        var snapshotsByTaskID: [UUID: TaskSnapshot] = [:]

        for snapshot in snapshots {
            guard let dayID = snapshot.dayID,
                  let day = allDays.first(where: { $0.id == dayID }) else { continue }
            let goal = snapshot.goalID.flatMap { goalID in allGoals.first { $0.id == goalID } }
            snapshotsByTaskID[snapshot.id] = snapshot
            targetDaysByID[day.id] = day

            if let existingTask = existingTasks.first(where: { $0.id == snapshot.id }) {
                existingTask.title = snapshot.title
                existingTask.priority = snapshot.priority
                existingTask.isDone = snapshot.isDone
                existingTask.order = snapshot.order
                existingTask.completedAt = snapshot.completedAt
                existingTask.carryOverCount = snapshot.carryOverCount
                existingTask.linkedGoal = goal

                if existingTask.day?.id != day.id {
                    if let oldDay = existingTask.day {
                        oldDay.tasks = oldDay.taskList.filter { $0.id != existingTask.id }
                        touchedOldDays[oldDay.id] = oldDay
                    }
                    existingTask.day = day
                }
                restoredTasksByID[existingTask.id] = existingTask
            } else {
                let task = AnkerTask(
                    id: snapshot.id,
                    title: snapshot.title,
                    priority: snapshot.priority,
                    isDone: snapshot.isDone,
                    order: snapshot.order,
                    completedAt: snapshot.completedAt,
                    carryOverCount: snapshot.carryOverCount,
                    day: day,
                    linkedGoal: goal
                )
                modelContext.insert(task)
                restoredTasksByID[task.id] = task
            }
        }

        for day in touchedOldDays.values where targetDaysByID[day.id] == nil {
            normalizeOrders(in: day)
        }

        for day in targetDaysByID.values {
            restoreTaskOrder(
                in: day,
                restoredTasks: restoredTasksByID,
                snapshots: snapshotsByTaskID
            )
        }

        modelContext.saveChanges()
    }

    private static func deleteCreatedTasks(_ snapshots: [TaskSnapshot], weeks: [Week], modelContext: ModelContext) {
        let createdIDs = Set(snapshots.map(\.id))
        let allDays = weeks.flatMap(\.dayList)
        let tasks = allDays.flatMap(\.taskList).filter { createdIDs.contains($0.id) }

        for task in tasks {
            delete(task, modelContext: modelContext)
        }

        modelContext.saveChanges()
    }

    private static func restoreTaskOrder(
        in day: Day,
        restoredTasks: [UUID: AnkerTask],
        snapshots: [UUID: TaskSnapshot]
    ) {
        var orderedTasks = day.taskList
            .filter { restoredTasks[$0.id] == nil }
            .sorted {
                if $0.order == $1.order {
                    return $0.title.localizedStandardCompare($1.title) == .orderedAscending
                }
                return $0.order < $1.order
            }

        let daySnapshots = snapshots.values
            .filter { $0.dayID == day.id }
            .sorted {
                if $0.order == $1.order {
                    return $0.title.localizedStandardCompare($1.title) == .orderedAscending
                }
                return $0.order < $1.order
            }

        for snapshot in daySnapshots {
            guard let task = restoredTasks[snapshot.id] else { continue }
            let insertionIndex = min(max(snapshot.order, 0), orderedTasks.count)
            orderedTasks.insert(task, at: insertionIndex)
        }

        for (index, task) in orderedTasks.enumerated() {
            task.order = index
            task.day = day
        }

        day.tasks = orderedTasks
    }

    /// Zaehlt ein Verschieben als Uebertragung?
    ///
    /// Nur wenn eine **offene** Aufgabe ueber eine Wochengrenze **nach vorn** wandert.
    /// „Uebernommen" heisst unfertige Arbeit weitergeschoben — eine erledigte Aufgabe zu
    /// verschieben oder etwas in die Vergangenheit zu planen ist keine Uebernahme.
    ///
    /// Vergleich ueber die ISO-Felder, nicht ueber `Date`: derselbe Montag ist in zwei
    /// Zeitzonen ein anderer `Date`-Wert.
    nonisolated static func isCarryOver(from source: Date?, to target: Date, isDone: Bool) -> Bool {
        guard !isDone, let source else { return false }

        let from = AnkerCalendar.weekInterval(containing: source)
        let to = AnkerCalendar.weekInterval(containing: target)
        guard (from.isoYear, from.isoWeek) != (to.isoYear, to.isoWeek) else { return false }
        return (to.isoYear, to.isoWeek) > (from.isoYear, from.isoWeek)
    }

    static func move(_ task: AnkerTask, to targetDate: Date, weeks: [Week], modelContext: ModelContext) {
        let targetWeek = ensureWeek(containing: targetDate, weeks: weeks, modelContext: modelContext)
        let targetDay = ensureDay(containing: targetDate, in: targetWeek)

        if let currentDay = task.day, currentDay.id == targetDay.id {
            modelContext.saveChanges()
            return
        }

        if isCarryOver(from: task.day?.date, to: targetDate, isDone: task.isDone) {
            task.carryOverCount += 1
        }

        if let oldDay = task.day {
            oldDay.tasks = oldDay.taskList.filter { $0.id != task.id }
            normalizeOrders(in: oldDay)
        }

        if task.linkedGoal?.week?.id != targetWeek.id {
            task.linkedGoal = nil
        }

        task.day = targetDay
        task.order = targetDay.taskList.count
        targetDay.tasks = targetDay.taskList.filter { $0.id != task.id } + [task]
        normalizeOrders(in: targetDay)
        modelContext.saveChanges()
    }

    /// Setzt Tag **und** Anker in einem Schritt — der Drop in der Matrix.
    ///
    /// Reihenfolge ist wesentlich: `move` loest bei einem Wochenwechsel `linkedGoal`, weil ein
    /// Ziel zu genau einer Woche gehoert. Der Anker wird deshalb **danach** gesetzt, sonst
    /// gewaenne das Aufraeumen gegen die Absicht des Nutzers.
    static func place(
        _ task: AnkerTask,
        on targetDate: Date,
        goalID: UUID?,
        weeks: [Week],
        modelContext: ModelContext
    ) {
        move(task, to: targetDate, weeks: weeks, modelContext: modelContext)

        let goal = goalID.flatMap { id in
            task.day?.week?.goalList.first { $0.id == id }
        }
        if task.linkedGoal?.id != goal?.id {
            task.linkedGoal = goal
            modelContext.saveChanges()
        }
    }

    static func move(_ task: AnkerTask, byDays offset: Int, weeks: [Week], modelContext: ModelContext) {
        guard let sourceDate = task.day?.date,
              let targetDate = AnkerCalendar.iso.date(byAdding: .day, value: offset, to: sourceDate) else { return }
        move(task, to: targetDate, weeks: weeks, modelContext: modelContext)
    }

    @discardableResult
    static func ensureWeek(containing date: Date, weeks: [Week], modelContext: ModelContext) -> Week {
        let interval = AnkerCalendar.weekInterval(containing: date)

        if let existingWeek = weeks.first(where: { AnkerCalendar.isSameDay($0.monday, interval.monday) }) {
            ensureWeekDays(in: existingWeek)
            return existingWeek
        }

        if let fetchedWeek = fetchWeek(starting: interval.monday, modelContext: modelContext) {
            ensureWeekDays(in: fetchedWeek)
            return fetchedWeek
        }

        let week = Week(
            isoYear: interval.isoYear,
            isoWeek: interval.isoWeek,
            monday: interval.monday,
            sunday: interval.sunday
        )
        week.days = AnkerCalendar.daysInWeek(starting: interval.monday).map { date in
            Day(date: date, week: week)
        }
        modelContext.insert(week)
        return week
    }

    private static func fetchWeek(starting monday: Date, modelContext: ModelContext) -> Week? {
        let descriptor = FetchDescriptor<Week>(sortBy: [SortDescriptor(\.monday)])
        return (try? modelContext.fetch(descriptor))?.first {
            AnkerCalendar.isSameDay($0.monday, monday)
        }
    }

    static func ensureWeekDays(in week: Week) {
        if week.dayList.isEmpty {
            week.days = AnkerCalendar.daysInWeek(starting: week.monday).map { date in
                Day(date: date, week: week)
            }
        }
    }

    static func ensureDay(containing date: Date, in week: Week) -> Day {
        ensureWeekDays(in: week)

        if let day = week.dayList.first(where: { AnkerCalendar.isSameDay($0.date, date) }) {
            return day
        }

        let day = Day(date: date, week: week)
        week.days = (week.days ?? []) + [day]
        return day
    }

    static func normalizeOrders(in day: Day) {
        let orderedTasks = day.taskList.sorted {
            if $0.order == $1.order {
                return $0.title.localizedStandardCompare($1.title) == .orderedAscending
            }
            return $0.order < $1.order
        }

        for (index, task) in orderedTasks.enumerated() {
            task.order = index
        }

        day.tasks = orderedTasks
    }
}
