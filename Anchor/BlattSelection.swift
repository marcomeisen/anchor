import Combine
import SwiftData
import SwiftUI

/// Der Zustand einer Mehrfachauswahl — ein Objekt pro Liste, damit Kopfknopf, Zeilen und
/// Aktionsleiste dieselbe Auswahl sehen.
@MainActor
final class TaskSelectionModel: ObservableObject {
    @Published private(set) var isActive = false
    @Published private(set) var ids = Set<UUID>()

    func toggleMode() {
        if isActive { finish() } else { isActive = true }
    }

    func toggle(_ task: AnkerTask) {
        if ids.contains(task.id) { ids.remove(task.id) } else { ids.insert(task.id) }
    }

    /// Langes Drücken auf ein Kästchen: Auswahl beginnen, mit dieser Aufgabe.
    func start(with task: AnkerTask) {
        isActive = true
        ids.insert(task.id)
    }

    func contains(_ task: AnkerTask) -> Bool { ids.contains(task.id) }

    func selected(from tasks: [AnkerTask]) -> [AnkerTask] {
        tasks.filter { ids.contains($0.id) }
    }

    func selectAll(_ tasks: [AnkerTask]) {
        ids = Set(tasks.map(\.id))
    }

    func finish() {
        isActive = false
        ids.removeAll()
    }
}

/// Der Knopf „Auswählen" / „Fertig" neben einer Abschnittsbeschriftung.
struct BlattSelectButton: View {
    @ObservedObject var selection: TaskSelectionModel

    var body: some View {
        Button(selection.isActive ? "Fertig" : "Auswählen") {
            withAnimation(.easeOut(duration: 0.15)) { selection.toggleMode() }
        }
        .ankerType(AnkerType.label)
        .foregroundStyle(AnkerColor.accentInk)
        .buttonStyle(.plain)
        .keyboardShortcut("a", modifiers: [.command, .shift])
        .accessibilityHint(selection.isActive ? "Beendet die Auswahl" : "Mehrere Aufgaben auf einmal bearbeiten")
    }
}

/// Die Aktionsleiste unten, solange ausgewählt wird. Sie ersetzt die Erfassungszeile.
///
/// Jede Aktion lässt sich rückgängig machen; Löschen fragt ab drei Aufgaben nach.
struct BlattBulkActionBar: View {
    @Environment(\.modelContext) private var modelContext

    @ObservedObject var selection: TaskSelectionModel
    /// Die Aufgaben, aus denen gewählt wird — die Leiste löst die Auswahl darüber auf.
    let tasks: [AnkerTask]
    /// Die Anker, an die sich die Auswahl hängen lässt.
    let anchors: [Goal]
    @ObservedObject var undo: TaskUndoCoordinator

    @State private var showingMove = false
    @State private var confirmingDelete = false
    @State private var choosingAnchor = false

    private var selected: [AnkerTask] { selection.selected(from: tasks) }

    var body: some View {
        let count = selected.count
        HStack(spacing: AnkerSpacing.s1) {
            Text(verbatim: "\(count)")
                .ankerType(AnkerType.numeric)
                .foregroundStyle(AnkerColor.onAccent)
                .frame(minWidth: 32, minHeight: 32)
                .background(AnkerColor.accentFill, in: RoundedRectangle(cornerRadius: AnkerRadius.inlineButton, style: .continuous))
                .accessibilityLabel("\(count) ausgewählt")
                .padding(.trailing, AnkerSpacing.s1)

            action(.check, "Erledigt", disabled: count == 0, perform: markDone)
            action(.week, "Verschieben", disabled: count == 0) { showingMove = true }
            action(.goal, "Anker", disabled: count == 0) { choosingAnchor = true }
            action(.delete, "Löschen", disabled: count == 0) {
                if count >= 3 { confirmingDelete = true } else { delete() }
            }

            Spacer(minLength: 0)
            if count < tasks.count {
                Button("Alle") { selection.selectAll(tasks) }
                    .ankerType(AnkerType.label)
                    .foregroundStyle(AnkerColor.accentInk)
                    .buttonStyle(.plain)
                    .padding(.trailing, AnkerSpacing.s2)
            }
        }
        .padding(.horizontal, AnkerSpacing.s2)
        .frame(minHeight: 56)
        .ankerCard(radius: AnkerRadius.bar)
#if os(macOS)
        .onExitCommand { selection.finish() }
#endif
        .sheet(isPresented: $showingMove) {
            TaskMoveSheet(tasks: selected) { snapshots in
                undo.present(TaskUndoNotice(message: Self.tasksMessage(snapshots.count, "verschoben"), snapshots: snapshots))
                selection.finish()
            }
            .presentationDetents([.medium])
        }
        .confirmationDialog("Anker setzen", isPresented: $choosingAnchor, titleVisibility: .visible) {
            ForEach(Array(anchors.enumerated()), id: \.element.id) { index, goal in
                Button("Anker \(index + 1) · \(goal.title)") { link(to: goal) }
            }
            Button("Ohne Anker") { link(to: nil) }
            Button("Abbrechen", role: .cancel) {}
        }
        .confirmationDialog("Ausgewählte Aufgaben löschen?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("\(count) Aufgaben löschen", role: .destructive, action: delete)
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Das lässt sich direkt danach rückgängig machen.")
        }
    }

    private func action(_ icon: AnkerIcon, _ title: String, disabled: Bool, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            actionLabel(icon, title, disabled: disabled)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .accessibilityLabel(title)
    }

    private func actionLabel(_ icon: AnkerIcon, _ title: String, disabled: Bool) -> some View {
        VStack(spacing: AnkerSpacing.s0) {
            Image(icon).ankerIcon(AnkerIconSize.s)
            Text(title).ankerType(AnkerType.microLabel).lineLimit(1).fixedSize()
        }
        .foregroundStyle(disabled ? AnkerColor.inkTertiary : AnkerColor.ink)
        .frame(minWidth: 58, minHeight: 44)
        .padding(.horizontal, AnkerSpacing.s0)
        .contentShape(Rectangle())
    }

    // Jede Sammelaktion speichert **einmal** am Ende statt pro Aufgabe: bei 30 Aufgaben
    // waren das 30 Saves und 30 CloudKit-Exporte. Die Snapshots vor der Aktion, über eine
    // Closure statt `map(TaskActions.snapshot)` — die Funktionsreferenz eines
    // Hauptakteur-Typs warnt in Swift 6.

    private func markDone() {
        let tasks = selected
        let snapshots = tasks.map { TaskActions.snapshot($0) }
        for task in tasks { TaskActions.setDone(task, true, save: false, modelContext: modelContext) }
        modelContext.saveChanges()
        undo.present(TaskUndoNotice(message: Self.tasksMessage(tasks.count, "erledigt"), snapshots: snapshots))
        selection.finish()
    }

    /// Ein Anker gehört zu genau einer Woche. Aufgaben aus einer anderen Woche bleiben deshalb
    /// ohne ihn — `TaskActions.link` hängt sie trotzdem an, die Woche entscheidet die Ansicht.
    private func link(to goal: Goal?) {
        let tasks = selected
        let snapshots = tasks.map { TaskActions.snapshot($0) }
        for task in tasks { TaskActions.link(task, to: goal, save: false, modelContext: modelContext) }
        modelContext.saveChanges()
        undo.present(TaskUndoNotice(message: goal == nil ? "Anker gelöst" : "Anker gesetzt", snapshots: snapshots))
        selection.finish()
    }

    private func delete() {
        let tasks = selected
        let snapshots = tasks.map { TaskActions.snapshot($0) }
        for task in tasks { TaskActions.delete(task, save: false, modelContext: modelContext) }
        modelContext.saveChanges()
        undo.present(TaskUndoNotice(message: Self.tasksMessage(tasks.count, "gelöscht"), snapshots: snapshots))
        selection.finish()
    }

    /// „1 Aufgabe erledigt", „3 Aufgaben erledigt".
    static func tasksMessage(_ count: Int, _ verb: String) -> String {
        count == 1 ? "1 Aufgabe \(verb)" : "\(count) Aufgaben \(verb)"
    }
}
