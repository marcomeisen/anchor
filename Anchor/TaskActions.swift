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
    /// Das gespeicherte Datum des Tages. Rückfall für `restore`, wenn der Tag inzwischen beim
    /// Zusammenführen von Sync-Duplikaten aufgegangen ist — dann gibt es seine ID nicht mehr,
    /// den Kalendertag aber schon. Additiv, damit ältere Aufrufer weiter kompilieren.
    var dayDate: Date? = nil
}

struct TaskUndoNotice: Identifiable {
    let id = UUID()
    /// Schon übersetzt — der Hinweis zeigt ihn wörtlich.
    let message: String
    let snapshots: [TaskSnapshot]
    var operation: TaskUndoOperation = .restore

    /// Ein Literal am Aufrufort wird übersetzt (`LocalizedStringResource`).
    init(message: LocalizedStringResource, snapshots: [TaskSnapshot], operation: TaskUndoOperation = .restore) {
        self.message = String(localized: message)
        self.snapshots = snapshots
        self.operation = operation
    }

    /// Für bereits übersetzte Texte (`String(localized:)`). Nachrangig, damit ein Literal die
    /// übersetzbare Variante trifft.
    @_disfavoredOverload
    init<Message: StringProtocol>(message: Message, snapshots: [TaskSnapshot], operation: TaskUndoOperation = .restore) {
        self.message = String(message)
        self.snapshots = snapshots
        self.operation = operation
    }
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
    ///
    /// `save: false` für Sammelaktionen: der Aufrufer speichert einmal am Ende, statt N-mal.
    static func setDone(_ task: AnkerTask, _ isDone: Bool, now: Date = Date(), save: Bool = true, modelContext: ModelContext) {
        guard task.isDone != isDone else { return }
        task.isDone = isDone
        task.completedAt = isDone ? now : nil
        finishToggle(task, save: save, modelContext: modelContext)
    }

    /// Erledigtes wandert ans Ende des Tages — der Zustand ist zu dem Zeitpunkt schon gesetzt.
    private static func finishToggle(_ task: AnkerTask, save: Bool = true, modelContext: ModelContext) {
        if task.isDone, let day = task.day {
            task.order = (day.taskList.map(\.order).max() ?? task.order) + 1
            day.tasks = day.taskList.filter { $0.id != task.id } + [task]
            normalizeOrders(in: day)
        }

        if save { modelContext.saveChanges() }
    }

    static func delete(_ task: AnkerTask, save: Bool = true, modelContext: ModelContext) {
        if let day = task.day {
            day.tasks = day.taskList.filter { $0.id != task.id }
            normalizeOrders(in: day)
        }

        if let goal = task.linkedGoal {
            goal.tasks = goal.taskList.filter { $0.id != task.id }
        }

        modelContext.delete(task)
        if save { modelContext.saveChanges() }
    }

    @discardableResult
    static func duplicate(_ task: AnkerTask, modelContext: ModelContext) -> AnkerTask? {
        guard let day = task.day else {
            // Ohne Tag: die Kopie bleibt ebenfalls uneingeplant, beim selben Anker.
            let copy = AnkerTask(
                title: task.title,
                priority: task.priority,
                isDone: false,
                order: (task.linkedGoal?.taskList.count ?? 0),
                linkedGoal: task.linkedGoal
            )
            modelContext.insert(copy)
            modelContext.saveChanges()
            return copy
        }

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

    static func link(_ task: AnkerTask, to goal: Goal?, save: Bool = true, modelContext: ModelContext) {
        task.linkedGoal = goal
        if save { modelContext.saveChanges() }
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
            goalID: task.linkedGoal?.id,
            dayDate: task.day?.date
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
        guard !snapshots.isEmpty else { return }

        // Nachschlagen über Wörterbücher statt `first(where:)` pro Snapshot: eine Sammelaktion
        // über 30 Aufgaben lief sonst 30-mal über den ganzen Bestand.
        let daysByID = Dictionary(weeks.flatMap(\.dayList).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let goalsByID = Dictionary(weeks.flatMap(\.goalList).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        // Aus dem Store statt aus den Tagen: Aufgaben ohne Tag haengen an keinem Tag.
        let ids = snapshots.map(\.id)
        let fetched = (try? modelContext.fetch(FetchDescriptor<AnkerTask>(predicate: #Predicate { ids.contains($0.id) })))
            ?? weeks.flatMap(\.dayList).flatMap(\.taskList).filter { ids.contains($0.id) }
        let existingTasks = Dictionary(fetched.filter { !$0.isDeleted }.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        var knownWeeks = weeks
        var targetDaysByID: [UUID: Day] = [:]
        var touchedOldDays: [UUID: Day] = [:]
        var restoredTasksByID: [UUID: AnkerTask] = [:]
        var snapshotsByTaskID: [UUID: TaskSnapshot] = [:]
        var targetDayIDByTaskID: [UUID: UUID] = [:]

        for snapshot in snapshots {
            // `dayID == nil` heisst „ohne Tag" — das ist ein gueltiger Zustand, kein Fehlerfall.
            var day = snapshot.dayID.flatMap { daysByID[$0] }
            if snapshot.dayID != nil && day == nil {
                // Der Tag ist inzwischen in einem Duplikat aufgegangen. Sein Kalendertag gibt es
                // weiter: dort wiederherstellen. Das ist ein Schreibvorgang, Anlegen ist erlaubt.
                guard let stored = snapshot.dayDate else { continue }
                let date = AnkerCalendar.nominalDate(ofStored: stored)
                let week = ensureWeek(containing: date, weeks: knownWeeks, modelContext: modelContext)
                if !knownWeeks.contains(where: { $0 === week }) { knownWeeks.append(week) }
                day = ensureDay(containing: date, in: week)
            }
            let goal = snapshot.goalID.flatMap { goalsByID[$0] ?? fetchGoal(id: $0, modelContext: modelContext) }
            snapshotsByTaskID[snapshot.id] = snapshot
            if let day {
                targetDaysByID[day.id] = day
                targetDayIDByTaskID[snapshot.id] = day.id
            }

            if let existingTask = existingTasks[snapshot.id] {
                existingTask.title = snapshot.title
                existingTask.priority = snapshot.priority
                existingTask.isDone = snapshot.isDone
                existingTask.order = snapshot.order
                existingTask.completedAt = snapshot.completedAt
                existingTask.carryOverCount = snapshot.carryOverCount
                existingTask.linkedGoal = goal

                if existingTask.day?.id != day?.id {
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
                snapshots: snapshotsByTaskID.filter { targetDayIDByTaskID[$0.key] == day.id }
            )
        }

        modelContext.saveChanges()
    }

    private static func fetchGoal(id: UUID, modelContext: ModelContext) -> Goal? {
        var descriptor = FetchDescriptor<Goal>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return (try? modelContext.fetch(descriptor))?.first { !$0.isDeleted }
    }

    private static func deleteCreatedTasks(_ snapshots: [TaskSnapshot], weeks: [Week], modelContext: ModelContext) {
        let createdIDs = Set(snapshots.map(\.id))
        let allTasks = (try? modelContext.fetch(FetchDescriptor<AnkerTask>()))
            ?? weeks.flatMap(\.dayList).flatMap(\.taskList)
        let tasks = allTasks.filter { createdIDs.contains($0.id) }

        for task in tasks {
            delete(task, save: false, modelContext: modelContext)
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

        // Der Aufrufer reicht nur die Snapshots dieses Tages — auch die, deren ursprünglicher Tag
        // inzwischen zusammengeführt wurde und deshalb eine andere ID trug.
        let daySnapshots = snapshots.values
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

    static func move(_ task: AnkerTask, to targetDate: Date, weeks: [Week], save: Bool = true, modelContext: ModelContext) {
        let targetWeek = ensureWeek(containing: targetDate, weeks: weeks, modelContext: modelContext)
        let targetDay = ensureDay(containing: targetDate, in: targetWeek)

        if let currentDay = task.day, currentDay.id == targetDay.id {
            if save { modelContext.saveChanges() }
            return
        }

        // Über den gemeinten Kalendertag: ein Sonntag aus einer westlicheren Zone ist hier schon
        // Montag früh und läge sonst in der falschen Woche.
        let source = task.day.map { AnkerCalendar.nominalDate(ofStored: $0.date) }
        if isCarryOver(from: source, to: targetDate, isDone: task.isDone) {
            task.carryOverCount += 1
        }

        if let oldDay = task.day {
            oldDay.tasks = oldDay.taskList.filter { $0.id != task.id }
            normalizeOrders(in: oldDay)
        }

        // Über den ISO-Schlüssel, nicht über die Wochen-ID: vor dem Zusammenführen kann es zwei
        // Kopien derselben Woche geben, und der Anker hängt vielleicht an der anderen.
        if !isSameISOWeek(task.linkedGoal?.week, targetWeek) {
            task.linkedGoal = nil
        }

        task.day = targetDay
        task.order = targetDay.taskList.count
        targetDay.tasks = targetDay.taskList.filter { $0.id != task.id } + [task]
        normalizeOrders(in: targetDay)
        if save { modelContext.saveChanges() }
    }

    /// Dieselbe Kalenderwoche — über ISO-Jahr und -Woche, damit Sync-Duplikate gleich zählen.
    static func isSameISOWeek(_ lhs: Week?, _ rhs: Week?) -> Bool {
        guard let lhs, let rhs, !lhs.isDeleted, !rhs.isDeleted else { return false }
        return lhs.isoYear == rhs.isoYear && lhs.isoWeek == rhs.isoWeek
    }

    // MARK: - In eine andere Woche

    /// Derselbe Wochentag in der Woche, die an `monday` beginnt — eine Freitagsaufgabe bleibt
    /// eine Freitagsaufgabe. Ohne Tag landet die Aufgabe am Montag. Ihr Anker gehört zur alten
    /// Woche und wird dabei gelöst, das erledigt `move`.
    @discardableResult
    static func move(_ task: AnkerTask, toWeekStarting monday: Date, weeks: [Week], modelContext: ModelContext) -> Date {
        var weekday = 0
        if let stored = task.day?.date {
            let date = AnkerCalendar.nominalDate(ofStored: stored)
            let sourceMonday = AnkerCalendar.weekInterval(containing: date).monday
            weekday = AnkerCalendar.iso.dateComponents([.day], from: sourceMonday, to: date).day ?? 0
        }
        let targetMonday = AnkerCalendar.weekInterval(containing: monday).monday
        let target = AnkerCalendar.iso.date(byAdding: .day, value: max(0, min(6, weekday)), to: targetMonday) ?? targetMonday
        move(task, to: target, weeks: weeks, modelContext: modelContext)
        return target
    }

    // MARK: - Ohne Tag

    /// Legt eine Aufgabe ohne Tag an: mit Anker „noch nicht eingeplant" (sie gehoert ueber den
    /// Anker zu dessen Woche), ohne Anker im Eingang.
    @discardableResult
    static func createUnscheduled(
        title: String,
        priority: Priority = .b,
        goal: Goal?,
        modelContext: ModelContext
    ) -> AnkerTask? {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return nil }

        let task = AnkerTask(
            title: cleanTitle,
            priority: priority,
            order: goal?.taskList.count ?? 0,
            linkedGoal: goal
        )
        modelContext.insert(task)
        modelContext.saveChanges()
        return task
    }

    /// Nimmt eine Aufgabe aus ihrem Tag heraus, der Anker bleibt.
    static func unschedule(_ task: AnkerTask, modelContext: ModelContext) {
        guard let day = task.day else { return }
        day.tasks = day.taskList.filter { $0.id != task.id }
        normalizeOrders(in: day)
        task.day = nil
        modelContext.saveChanges()
    }

    /// Aufgaben einer Woche, die keinen Tag haben — ueber ihren Anker.
    static func unscheduledTasks(in week: Week) -> [AnkerTask] {
        GoalOrdering.sorted(week.goalList)
            .flatMap { goal in goal.taskList.filter { $0.day == nil && !$0.isDeleted } }
    }

    /// Der Eingang: Aufgaben ohne Tag und ohne Anker.
    static func inboxTasks(modelContext: ModelContext) -> [AnkerTask] {
        let descriptor = FetchDescriptor<AnkerTask>(
            predicate: #Predicate { $0.day == nil && $0.linkedGoal == nil },
            sortBy: [SortDescriptor(\.order)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
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
        save: Bool = true,
        modelContext: ModelContext
    ) {
        move(task, to: targetDate, weeks: weeks, save: false, modelContext: modelContext)

        // Erst in der Zielwoche, dann im Store — der Anker kann an einer Sync-Kopie derselben
        // ISO-Woche hängen. Ein Anker einer anderen Woche wird nicht gesetzt.
        let targetWeek = task.day?.week
        let goal = goalID.flatMap { id in
            targetWeek?.goalList.first { $0.id == id }
                ?? fetchGoal(id: id, modelContext: modelContext).flatMap { isSameISOWeek($0.week, targetWeek) ? $0 : nil }
        }
        if task.linkedGoal?.id != goal?.id {
            task.linkedGoal = goal
        }
        if save { modelContext.saveChanges() }
    }

    /// Um `offset` Tage — ab dem **gemeinten** Kalendertag, nicht ab dem rohen `Day.date`,
    /// das Mitternacht in der Zone des anlegenden Geräts ist.
    static func move(_ task: AnkerTask, byDays offset: Int, weeks: [Week], modelContext: ModelContext) {
        guard let stored = task.day?.date else { return }
        let sourceDate = AnkerCalendar.nominalDate(ofStored: stored)
        guard let targetDate = AnkerCalendar.iso.date(byAdding: .day, value: offset, to: sourceDate) else { return }
        move(task, to: targetDate, weeks: weeks, modelContext: modelContext)
    }

    /// Die Woche zu `date` — vorhanden oder neu angelegt.
    ///
    /// **Nur aufrufen, wenn wirklich etwas geschrieben wird.** Früher legte schon das Blättern
    /// und jeder Start eine Woche mit sieben Tagen an. Auf einem frisch eingerichteten Gerät
    /// entstand so die laufende Woche, bevor der iCloud-Import sie brachte — jedes Mal ein
    /// Duplikat, das danach zusammengeführt werden musste.
    ///
    /// Gesucht wird über ISO-Jahr und -Woche, nicht über das Montagsdatum: das ist Mitternacht
    /// in der Zeitzone des anlegenden Geräts und auf anderen Geräten ein anderer Zeitpunkt.
    /// Tage legt die Funktion **nicht** an; das macht `ensureDay` für genau den einen Tag.
    @discardableResult
    static func ensureWeek(containing date: Date, weeks: [Week], modelContext: ModelContext) -> Week {
        let interval = AnkerCalendar.weekInterval(containing: date)

        if let existingWeek = WeekPlanning.week(startingAt: interval.monday, in: weeks) {
            return existingWeek
        }

        if let fetchedWeek = fetchWeek(isoYear: interval.isoYear, isoWeek: interval.isoWeek, modelContext: modelContext) {
            return fetchedWeek
        }

        let week = Week(
            isoYear: interval.isoYear,
            isoWeek: interval.isoWeek,
            monday: interval.monday,
            sunday: interval.sunday
        )
        modelContext.insert(week)
        return week
    }

    /// Die vorhandene Woche zu `date`, ohne etwas anzulegen — für Lesepfade.
    static func existingWeek(containing date: Date, weeks: [Week], modelContext: ModelContext) -> Week? {
        let interval = AnkerCalendar.weekInterval(containing: date)
        return WeekPlanning.week(startingAt: interval.monday, in: weeks)
            ?? fetchWeek(isoYear: interval.isoYear, isoWeek: interval.isoWeek, modelContext: modelContext)
    }

    private static func fetchWeek(isoYear: Int, isoWeek: Int, modelContext: ModelContext) -> Week? {
        let descriptor = FetchDescriptor<Week>(
            predicate: #Predicate { $0.isoYear == isoYear && $0.isoWeek == isoWeek }
        )
        return (try? modelContext.fetch(descriptor))?
            .filter { !$0.isDeleted }
            .min { $0.id.uuidString < $1.id.uuidString }
    }

    /// Alle sieben Tage anlegen. Nur noch für Altbestand und Tests — die Oberfläche rechnet
    /// die sieben Daten aus dem Kalender und legt Tage erst beim Schreiben an.
    static func ensureWeekDays(in week: Week) {
        for date in AnkerCalendar.daysInWeek(starting: week.monday) {
            _ = ensureDay(containing: date, in: week)
        }
    }

    static func ensureDay(containing date: Date, in week: Week) -> Day {
        if let day = WeekPlanning.existingDay(on: date, in: week) {
            return day
        }

        let day = Day(date: AnkerCalendar.iso.startOfDay(for: date), week: week)
        week.days = week.dayList + [day]
        return day
    }

    /// Vergibt `order` lückenlos ab 0. Schreibt **nur, was sich ändert** — jede Zuweisung
    /// markiert den Datensatz als geändert und wird über CloudKit exportiert, auch wenn der
    /// Wert gleich bleibt. Gibt zurück, ob sich etwas geändert hat.
    @discardableResult
    static func normalizeOrders(in day: Day) -> Bool {
        let current = day.taskList
        let orderedTasks = current.sorted {
            if $0.order == $1.order {
                return $0.title.localizedStandardCompare($1.title) == .orderedAscending
            }
            return $0.order < $1.order
        }

        var didChange = false
        for (index, task) in orderedTasks.enumerated() where task.order != index {
            task.order = index
            didChange = true
        }

        if didChange || !current.elementsEqual(orderedTasks, by: { $0 === $1 }) {
            day.tasks = orderedTasks
            didChange = true
        }
        return didChange
    }
}
