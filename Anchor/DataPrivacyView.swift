import OSLog
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Der Export als Dokument fuer `fileExporter`.
///
/// Ueber `fileExporter` statt eines eigenen Schreibvorgangs, weil die App auf dem Mac in der
/// Sandbox laeuft: nur ueber das Systemfenster bekommt sie Schreibrechte fuer den vom Nutzer
/// gewaehlten Ort.
struct DataExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

/// Auskunft, Export und Loeschung an einer Stelle — die Betroffenenrechte aus Art. 15, 17
/// und 20 DSGVO, erreichbar aus der Sidebar (Mac, iPad) und aus dem Tab Mehr (iPhone).
struct DataPrivacyView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var weeks: [Week]
    @Query private var goals: [Goal]
    @Query private var tasks: [AnkerTask]
    @Query private var timeBlocks: [TimeBlock]

    @State private var exportDocument: DataExportDocument?
    @State private var showsExporter = false
    @State private var exportFileName = DataPortability.exportFileName()
    @State private var statusMessage: StatusMessage?
    @State private var showsDeleteConfirmation = false

    private struct StatusMessage: Identifiable {
        let id = UUID()
        let text: String
        let isError: Bool
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                storedDataSection
                exportSection
                deleteSection

                if let statusMessage {
                    Text(statusMessage.text)
                        .font(.system(size: 12))
                        .foregroundStyle(statusMessage.isError ? AnkerColor.destructive : AnkerColor.success)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityAddTraits(.isStaticText)
                }
            }
            .padding(AnkerSpacing.screenPadding)
        }
        .background(AnkerColor.paper)
        .navigationTitle("Daten und Datenschutz")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Fertig") { dismiss() }
            }
        }
        .fileExporter(
            isPresented: $showsExporter,
            document: exportDocument,
            contentType: .json,
            defaultFilename: exportFileName
        ) { result in
            handleExportResult(result)
        }
        .confirmationDialog(
            "Alle Daten löschen?",
            isPresented: $showsDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Alle Daten löschen", role: .destructive) {
                deleteAllData()
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text(deleteConfirmationMessage)
        }
    }

    // MARK: - Abschnitte

    private var storedDataSection: some View {
        card {
            sectionTitle("Was Daivento speichert")

            Text("Wochen, Wochenziele, Aufgaben, Zeitblöcke, Tagesfokus und Notizen — also nur das, "
                 + "was du selbst eingibst. Es gibt keine Analyse, keine Werbung und keine Weitergabe "
                 + "an Dritte.")
                .font(.system(size: 12.5))
                .foregroundStyle(AnkerColor.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text("Gespeichert wird auf diesem Gerät und, wenn iCloud aktiv ist, in deiner privaten "
                 + "iCloud-Datenbank. Auf diese hat nur dein Apple-Account Zugriff.")
                .font(.system(size: 12))
                .foregroundStyle(AnkerColor.muted)
                .fixedSize(horizontal: false, vertical: true)

            countRow
        }
    }

    private var countRow: some View {
        HStack(spacing: 18) {
            countItem(weeks.count, "Wochen")
            countItem(goals.count, "Ziele")
            countItem(tasks.count, "Aufgaben")
            countItem(timeBlocks.count, "Zeitblöcke")
            Spacer(minLength: 0)
        }
        .padding(.top, 2)
    }

    private func countItem(_ value: Int, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(verbatim: String(value))
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(AnkerColor.ink)
            Text(label)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(AnkerColor.muted)
        }
        .accessibilityElement(children: .combine)
    }

    private var exportSection: some View {
        card {
            sectionTitle("Daten exportieren")

            Text("Legt eine JSON-Datei mit allen gespeicherten Daten an — vollständig und "
                 + "maschinenlesbar, für ein eigenes Backup oder den Umzug in eine andere App.")
                .font(.system(size: 12.5))
                .foregroundStyle(AnkerColor.ink)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                prepareExport()
            } label: {
                Label("Export sichern", systemImage: "square.and.arrow.up")
                    .font(.system(size: 12.5, weight: .semibold))
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel("Alle Daten als JSON-Datei exportieren")
        }
    }

    private var deleteSection: some View {
        card {
            sectionTitle("Alle Daten löschen")

            Text("Entfernt alle Wochen, Ziele, Aufgaben, Zeitblöcke und Notizen — auf diesem Gerät "
                 + "und in iCloud, damit sie nicht auf anderen Geräten zurückkommen.")
                .font(.system(size: 12.5))
                .foregroundStyle(AnkerColor.ink)
                .fixedSize(horizontal: false, vertical: true)

            // Der wichtigste Satz des Bildschirms: das blosse Loeschen der App raeumt die
            // private CloudKit-Datenbank nicht auf, die Daten kaemen bei einer Neuinstallation
            // zurueck. Ohne diesen Hinweis haelt der Nutzer die App-Loeschung faelschlich
            // fuer eine Loeschung seiner Daten.
            Text("Die App zu löschen reicht dafür nicht: Deine Daten bleiben dann in iCloud liegen "
                 + "und werden bei einer Neuinstallation wiederhergestellt.")
                .font(.system(size: 12))
                .foregroundStyle(AnkerColor.muted)
                .fixedSize(horizontal: false, vertical: true)

            Button(role: .destructive) {
                showsDeleteConfirmation = true
            } label: {
                Label("Alle Daten löschen", systemImage: "trash")
                    .font(.system(size: 12.5, weight: .semibold))
            }
            .buttonStyle(.bordered)
            .tint(AnkerColor.destructive)
            .disabled(totalRecordCount == 0)
            .accessibilityLabel("Alle Daten unwiderruflich löschen")
        }
    }

    // MARK: - Aktionen

    private func prepareExport() {
        do {
            let data = try DataPortability.encodedSnapshot(from: modelContext)
            exportDocument = DataExportDocument(data: data)
            exportFileName = DataPortability.exportFileName()
            showsExporter = true
        } catch {
            statusMessage = StatusMessage(
                text: "Der Export konnte nicht erstellt werden: \(error.localizedDescription)",
                isError: true
            )
            persistenceLog.error("Datenexport fehlgeschlagen — \((error as NSError).domain, privacy: .public) \((error as NSError).code, privacy: .public)")
        }
    }

    private func handleExportResult(_ result: Result<URL, Error>) {
        exportDocument = nil

        switch result {
        case .success(let url):
            statusMessage = StatusMessage(text: "Export gesichert unter \(url.lastPathComponent).", isError: false)
            persistenceLog.notice("Datenexport gesichert")
        case .failure(let error):
            // Abbrechen im Systemfenster kommt hier ebenfalls als Fehler an; ein Hinweis
            // waere in dem Fall irrefuehrend.
            if (error as NSError).code == NSUserCancelledError { return }
            statusMessage = StatusMessage(
                text: "Der Export konnte nicht gesichert werden: \(error.localizedDescription)",
                isError: true
            )
        }
    }

    private func deleteAllData() {
        let report = DataPortability.deleteAllData(in: modelContext)

        guard report.didSave else {
            // `saveChanges` hat den Fehler bereits gemeldet; hier nur klarstellen, dass
            // nichts geloescht wurde.
            statusMessage = StatusMessage(
                text: "Die Daten konnten nicht gelöscht werden. Es wurde nichts entfernt.",
                isError: true
            )
            return
        }

        DataPortability.resetStoredPreferences()
        statusMessage = StatusMessage(
            text: "\(report.total) Datensätze wurden gelöscht. Die Löschung wird an iCloud übertragen, sobald eine Verbindung besteht.",
            isError: false
        )
    }

    // MARK: - Texte

    private var totalRecordCount: Int {
        weeks.count + goals.count + tasks.count + timeBlocks.count
    }

    private var deleteConfirmationMessage: String {
        "\(weeks.count) Wochen, \(goals.count) Wochenziele, \(tasks.count) Aufgaben und "
            + "\(timeBlocks.count) Zeitblöcke werden dauerhaft entfernt — auch in iCloud und damit "
            + "auf allen Geräten. Das lässt sich nicht rückgängig machen. Sichere vorher einen Export, "
            + "wenn du die Daten behalten willst."
    }

    // MARK: - Bausteine

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13.5, weight: .bold))
            .foregroundStyle(AnkerColor.ink)
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AnkerColor.card)
        .overlay(RoundedRectangle(cornerRadius: AnkerRadius.card).stroke(AnkerColor.line))
        .clipShape(RoundedRectangle(cornerRadius: AnkerRadius.card))
    }
}

#Preview {
    NavigationStack {
        DataPrivacyView()
    }
    .modelContainer(PreviewContainer.shared)
}
