import Combine
import Foundation
import OSLog
import SwiftData
import SwiftUI

/// Log fuer Speichervorgaenge, getrennt von `cloudSyncLog`.
///
/// `notice`/`error`, damit die Eintraege auch ohne Debugger in Console.app nachlesbar sind.
let persistenceLog = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.marcomeisen.Anchor",
    category: "Persistence"
)

/// Ein fehlgeschlagener Speichervorgang, aufbereitet fuer die Anzeige.
///
/// Bewusst ein Wertetyp aus fertigen Strings statt des `Error`: der Fehler entsteht dort, wo
/// gespeichert wird, gemeldet wird er auf dem Main-Actor.
struct PersistenceFailure: Identifiable, Sendable {
    let id = UUID()
    /// Die aufrufende Funktion — sagt, welche Aktion verloren gegangen ist.
    let operation: String
    /// Kurzform fuer das Log: Domain und Code, keine Nutzerinhalte.
    let code: String
    /// Ausformulierter Text fuer den Dialog.
    let message: String

    init(operation: String, error: Error) {
        let nsError = error as NSError
        self.operation = operation
        self.code = "\(nsError.domain) \(nsError.code)"

        var parts = [error.localizedDescription]
        if let reason = nsError.localizedFailureReason {
            parts.append(reason)
        }
        self.message = parts.joined(separator: " · ")
    }
}

/// Sammelstelle fuer fehlgeschlagene Speichervorgaenge.
///
/// Vorher liefen alle Speichervorgaenge ueber `try?`: schlug einer fehl — voller Datentraeger,
/// Migrationskonflikt, beschaedigter Store —, bemerkte weder App noch Nutzer etwas, und die
/// Aenderung war beim naechsten Start weg. Fehler landen jetzt hier und werden im Dialog
/// gezeigt, damit der Nutzer mindestens weiss, dass seine Eingabe nicht gesichert ist.
@MainActor
final class PersistenceFailureCenter: ObservableObject {
    static let shared = PersistenceFailureCenter()

    @Published private(set) var failure: PersistenceFailure?

    /// Zaehlt alle Fehlschlaege der Sitzung, auch die, die waehrend eines offenen Dialogs
    /// dazukommen. Ein einzelner Dialog waere sonst irrefuehrend, wenn im Hintergrund
    /// weitere Speichervorgaenge scheitern.
    @Published private(set) var failureCount = 0

    private init() {}

    func report(_ failure: PersistenceFailure) {
        failureCount += 1
        // Den ersten Fehler stehen lassen: er benennt die Ursache, die Folgefehler sind
        // meist nur Wiederholungen desselben Problems.
        if self.failure == nil {
            self.failure = failure
        }
    }

    func clear() {
        failure = nil
        failureCount = 0
    }
}

extension ModelContext {
    /// Speichert und meldet Fehler, statt sie zu verschlucken.
    ///
    /// Ersetzt `try? save()` im gesamten Produktivcode. Gibt zurueck, ob gespeichert wurde —
    /// Aufrufer, die daran haengen (etwa Export oder Loeschung), koennen darauf reagieren;
    /// alle anderen ignorieren das Ergebnis, weil der Dialog die Meldung schon uebernimmt.
    @discardableResult
    func saveChanges(_ operation: String = #function) -> Bool {
        guard hasChanges else { return true }

        do {
            try save()
            return true
        } catch {
            let failure = PersistenceFailure(operation: operation, error: error)
            // Nur Operation und Fehlercode `.public`: der freie Text kann Feldinhalte
            // enthalten und unterliegt deshalb der Standardredaktion des Unified Log.
            persistenceLog.error(
                "Speichern fehlgeschlagen in \(failure.operation, privacy: .public) — \(failure.code, privacy: .public): \(failure.message)"
            )
            PersistenceFailureCenter.shared.report(failure)
            return false
        }
    }
}

extension View {
    /// Zeigt fehlgeschlagene Speichervorgaenge an. Gehoert genau einmal an die Wurzel.
    func persistenceFailureAlert() -> some View {
        modifier(PersistenceFailureAlert())
    }
}

private struct PersistenceFailureAlert: ViewModifier {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var center = PersistenceFailureCenter.shared

    func body(content: Content) -> some View {
        content.alert(
            "Änderung nicht gespeichert",
            isPresented: Binding(
                get: { center.failure != nil },
                set: { if !$0 { center.clear() } }
            ),
            presenting: center.failure
        ) { _ in
            Button("Erneut sichern") {
                center.clear()
                modelContext.saveChanges()
            }
            Button("Schließen", role: .cancel) {
                center.clear()
            }
        } message: { failure in
            Text(message(for: failure))
        }
    }

    private func message(for failure: PersistenceFailure) -> String {
        var text = "Daivento konnte die letzte Änderung nicht auf diesem Gerät sichern. "
            + "Sie geht verloren, wenn die App beendet wird.\n\n\(failure.message)"

        if center.failureCount > 1 {
            text += "\n\nSeit dem Start sind \(center.failureCount) Speichervorgänge fehlgeschlagen."
        }

        text += "\n\nPrüfe den freien Speicherplatz. Bleibt der Fehler, sichere deine Daten über "
            + "Daten und Datenschutz als Export, bevor du die App beendest."

        return text
    }
}
