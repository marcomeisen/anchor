import SwiftData
import SwiftUI

/// Mutationen an Wochenzielen. Gegenstueck zu `TaskActions`; jede Aenderung an einem `Goal`
/// laeuft hierueber, damit Beziehungspflege und Speichern zusammenbleiben.
enum GoalActions {
    /// Loescht ein Wochenziel. Zugeordnete Aufgaben bleiben erhalten und stehen danach
    /// ohne Wochenziel da.
    static func delete(_ goal: Goal, in week: Week?, modelContext: ModelContext) {
        detachTasks(from: goal, in: week)

        if let owningWeek = goal.week ?? week {
            owningWeek.goals = owningWeek.goalList.filter { $0.id != goal.id }
        }

        modelContext.delete(goal)
        // Sonst bleibt eine Luecke (0, 1, 3) und `nextOrder` waechst unnoetig.
        if let owningWeek = goal.week ?? week {
            GoalOrdering.normalize(owningWeek)
        }
        modelContext.saveChanges()
    }

    /// Legt ein Wochenziel an und vergibt dabei die Ankerordnung.
    ///
    /// Bisher erzeugten `NewGoalSheet` und `WeekPlanning` selbst `Goal(...)` — damit lag die
    /// Vergabe von `order` an zwei Stellen und konnte vergessen werden.
    ///
    /// **Höchstens vier Anker pro Woche, hier zentral.** Gibt `nil` zurück, wenn die Woche schon
    /// vier vom Nutzer angelegte Anker hat. Der Onboarding-Platzhalter zählt nicht mit. Über
    /// zwei Geräte offline kann trotzdem ein fünftes entstehen; das fängt `GoalOrdering.excess` ab.
    @discardableResult
    static func create(
        title: String,
        colorHex: String? = nil,
        why: String? = nil,
        in week: Week,
        modelContext: ModelContext
    ) -> Goal? {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty, canAddAnchor(to: week) else { return nil }

        let goal = Goal(
            title: cleanTitle,
            colorHex: colorHex ?? WeekPlanning.defaultGoalColorHex,
            order: GoalOrdering.nextOrder(in: week),
            week: week
        )
        goal.why = cleanWhy(why)
        modelContext.insert(goal)
        week.appendGoal(goal)
        modelContext.saveChanges()
        return goal
    }

    /// Ist in dieser Woche noch Platz für einen Anker?
    static func canAddAnchor(to week: Week) -> Bool {
        week.goalList.filter { !$0.isDeleted && WeekPlanning.isUserCreated($0) }.count < GoalOrdering.maxAnchors
    }

    /// Titel und Warum-Satz ändern. `nil` heißt: dieses Feld nicht anfassen. Ein leerer Titel
    /// wird verworfen (wie bei `TaskActions.rename`), ein leerer Warum-Satz löscht ihn.
    /// Gibt zurück, ob sich etwas geändert hat; gespeichert wird nur dann.
    @discardableResult
    static func update(_ goal: Goal, title: String? = nil, why: String? = nil, modelContext: ModelContext) -> Bool {
        var didChange = false
        if let title {
            let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
            if !clean.isEmpty, clean != goal.title {
                goal.title = clean
                didChange = true
            }
        }
        if let why {
            let clean = cleanWhy(why)
            if clean != goal.why {
                goal.why = clean
                didChange = true
            }
        }
        if didChange { modelContext.saveChanges() }
        return didChange
    }

    private static func cleanWhy(_ why: String?) -> String? {
        why?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }

    /// Wie viele Aufgaben verlieren beim Loeschen ihre Zuordnung? Fuer den Bestaetigungstext,
    /// damit die Konsequenz benannt ist statt nur die Aktion.
    static func linkedTaskCount(for goal: Goal, in week: Week?) -> Int {
        linkedTasks(for: goal, in: week).count
    }

    private static func detachTasks(from goal: Goal, in week: Week?) {
        // Beide Seiten der Beziehung anfassen: die Delete-Rule ist zwar `.nullify`, der Bestand
        // pflegt Beziehungen aber durchgaengig explizit, und ueber CloudKit ist auf implizites
        // Aufraeumen kein Verlass.
        for task in linkedTasks(for: goal, in: week) {
            task.linkedGoal = nil
        }

        goal.tasks = []
    }

    /// Sowohl ueber die Beziehung als auch ueber die Woche suchen: nach einem Sync kann eine
    /// Seite der Beziehung noch nicht nachgezogen sein.
    private static func linkedTasks(for goal: Goal, in week: Week?) -> [AnkerTask] {
        var seen = Set<UUID>()
        var result: [AnkerTask] = []

        let candidates = goal.taskList + (week?.dayList.flatMap(\.taskList) ?? [])
        for task in candidates where task.linkedGoal?.id == goal.id {
            if seen.insert(task.id).inserted {
                result.append(task)
            }
        }

        return result
    }
}

extension View {
    /// Bestaetigungsdialog fuers Loeschen eines Wochenziels.
    ///
    /// Als Modifier, weil die Aktion laut Interaktionskonzept an mehreren Stellen erreichbar
    /// sein soll — Sidebar, Wochenuebersicht und Zieldetail teilen sich so Text und Verhalten.
    func goalDeleteConfirmation(
        goal: Binding<Goal?>,
        week: Week?,
        onDeleted: @escaping () -> Void = {}
    ) -> some View {
        modifier(GoalDeleteConfirmation(goal: goal, week: week, onDeleted: onDeleted))
    }
}

private struct GoalDeleteConfirmation: ViewModifier {
    @Environment(\.modelContext) private var modelContext

    @Binding var goal: Goal?
    let week: Week?
    let onDeleted: () -> Void

    func body(content: Content) -> some View {
        content.confirmationDialog(
            "Wochenziel löschen?",
            isPresented: Binding(
                get: { goal != nil },
                set: { isPresented in
                    if !isPresented { goal = nil }
                }
            ),
            titleVisibility: .visible,
            presenting: goal
        ) { pendingGoal in
            Button("Löschen", role: .destructive) {
                GoalActions.delete(pendingGoal, in: week, modelContext: modelContext)
                goal = nil
                onDeleted()
            }
            Button("Abbrechen", role: .cancel) {
                goal = nil
            }
        } message: { pendingGoal in
            Text(message(for: pendingGoal))
        }
    }

    private func message(for goal: Goal) -> String {
        let count = GoalActions.linkedTaskCount(for: goal, in: week)

        switch count {
        case 0:
            return "Das Wochenziel \(goal.title) wird dauerhaft entfernt."
        case 1:
            return "Das Wochenziel \(goal.title) wird dauerhaft entfernt. Die zugeordnete Aufgabe bleibt erhalten, hat danach aber kein Wochenziel mehr."
        default:
            return "Das Wochenziel \(goal.title) wird dauerhaft entfernt. Die \(count) zugeordneten Aufgaben bleiben erhalten, haben danach aber kein Wochenziel mehr."
        }
    }
}
