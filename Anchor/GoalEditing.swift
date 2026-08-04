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
        modelContext.saveChanges()
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
