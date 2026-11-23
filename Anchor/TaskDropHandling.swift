import SwiftData
import SwiftUI
import UniformTypeIdentifiers

enum TaskDragEvents {
    static let didEnd = Notification.Name("AnchoritTaskDragDidEnd")

    static func end(taskID: UUID) {
        NotificationCenter.default.post(name: didEnd, object: taskID.uuidString)
    }
}

/// Gemeinsame Behandlung von Task-Drops. Aufgaben werden als reine UUID-Zeichenkette
/// gezogen (`conditionalTaskDrag` bzw. `draggable` am `TaskChip`), also braucht jedes Drop-Ziel dieselben drei Schritte:
/// ID laden, Aufgabe verschieben, Drag-Ende melden.
enum TaskDropHandling {
    static let draggedTypes = [UTType.plainText]

    /// Laedt die Task-ID aus dem Provider und ruft `completion` auf dem Main Actor auf.
    /// Ueber die Grenze geht bewusst nur die `UUID` — Modellobjekte sind nicht `Sendable`.
    static func loadTaskID(
        from providers: [NSItemProvider],
        completion: @escaping @MainActor (UUID) -> Void
    ) -> Bool {
        guard let provider = providers.first(where: { $0.canLoadObject(ofClass: NSString.self) }) else {
            return false
        }

        provider.loadObject(ofClass: NSString.self) { object, _ in
            guard let rawID = object as? String ?? (object as? NSString)?.description,
                  let taskID = UUID(uuidString: rawID) else { return }

            Task { @MainActor in
                completion(taskID)
            }
        }

        return true
    }

    /// Verschiebt die Aufgabe auf `date` und meldet in jedem Fall das Drag-Ende, damit die
    /// Ursprungszeile auf macOS ihre Transparenz verliert — auch wenn die Aufgabe
    /// inzwischen geloescht wurde.
    @MainActor
    @discardableResult
    static func moveTask(
        id: UUID,
        to date: Date,
        weeks: [Week],
        modelContext: ModelContext
    ) -> TaskSnapshot? {
        defer { TaskDragEvents.end(taskID: id) }

        guard let task = task(with: id, modelContext: modelContext) else { return nil }

        let snapshot = TaskActions.snapshot(task)
        TaskActions.move(task, to: date, weeks: weeks, modelContext: modelContext)
        return snapshot
    }

    /// Ueber eine Abfrage im Kontext, nicht ueber die Tage der Wochen: so kommen auch
    /// Aufgaben ohne Tag (Eingang, „noch ohne Tag") an.
    @MainActor
    private static func task(with id: UUID, modelContext: ModelContext) -> AnkerTask? {
        let descriptor = FetchDescriptor<AnkerTask>(predicate: #Predicate { $0.id == id })
        return (try? modelContext.fetch(descriptor))?.first { !$0.isDeleted }
    }
}
