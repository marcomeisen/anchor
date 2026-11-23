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

    // Nur Zählwerte — `fetchCount` statt vier `@Query`, die den ganzen Bestand laden.
    @State private var counts = RecordCounts()
    @State private var isDeleting = false

    @State private var exportDocument: DataExportDocument?
    @State private var showsExporter = false
    @State private var exportFileName = DataPortability.exportFileName()
    @State private var statusMessage: StatusMessage?
    @State private var showsDeleteConfirmation = false

    private struct RecordCounts {
        var weeks = 0, goals = 0, days = 0, tasks = 0, timeBlocks = 0
        var total: Int { weeks + goals + days + tasks + timeBlocks }
    }

    private struct StatusMessage: Identifiable {
        let id = UUID()
        let text: String
        let isError: Bool
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AnkerSpacing.s4) {
                storedDataSection
                exportSection
                deleteSection

                if let statusMessage {
                    Text(statusMessage.text)
                        .ankerType(AnkerType.caption)
                        .foregroundStyle(statusMessage.isError ? AnkerColor.accentMark : AnkerColor.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityAddTraits(.isStaticText)
                }
            }
            .padding(AnkerSpacing.screenPadding)
        }
        .background(AnkerColor.ground)
        .onAppear(perform: refreshCounts)
        .ankerSheetChrome("Daten und Datenschutz", cancel: AnkerSheetAction("Fertig") { dismiss() })
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
            sectionTitle("Was Anchorit speichert")

            Text("Wochen, Anker, Aufgaben, Zeitblöcke, Tagesfokus und Notizen — also nur das, "
                 + "was du selbst eingibst. Es gibt keine Analyse, keine Werbung und keine Weitergabe "
                 + "an Dritte.")
                .ankerType(AnkerType.body)
                .foregroundStyle(AnkerColor.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text("Gespeichert wird auf diesem Gerät und, wenn iCloud aktiv ist, in deiner privaten "
                 + "iCloud-Datenbank. Daran kommst nur du über deinen Apple-Account — der Entwickler von "
                 + "Anchorit hat keinen Zugriff.")
                .ankerType(AnkerType.caption)
                .foregroundStyle(AnkerColor.inkSecond)
                .fixedSize(horizontal: false, vertical: true)

            countRow

            Link(destination: AppLinks.privacyPolicy) {
                Label("Datenschutzerklärung", ankerIcon: AnkerIcon.privacy)
                    .ankerType(AnkerType.caption)
                    .foregroundStyle(AnkerColor.accentInk)
            }
            .accessibilityHint("Öffnet die Datenschutzerklärung im Browser")
        }
    }

    private var countRow: some View {
        HStack(spacing: AnkerSpacing.s4) {
            countItem(counts.weeks, "Wochen")
            countItem(counts.goals, "Anker")
            countItem(counts.tasks, "Aufgaben")
            countItem(counts.timeBlocks, "Zeitblöcke")
            Spacer(minLength: 0)
        }
        .padding(.top, AnkerSpacing.s1)
    }

    private func countItem(_ value: Int, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: AnkerSpacing.s1) {
            Text(verbatim: String(value))
                .ankerType(AnkerType.bodyStrong)
                .foregroundStyle(AnkerColor.ink)
            Text(label)
                .ankerType(AnkerType.caption)
                .foregroundStyle(AnkerColor.inkSecond)
        }
        .accessibilityElement(children: .combine)
    }

    private var exportSection: some View {
        card {
            sectionTitle("Daten exportieren")

            Text("Legt eine JSON-Datei mit allen gespeicherten Daten an — vollständig und "
                 + "maschinenlesbar, für ein eigenes Backup oder den Umzug in eine andere App.")
                .ankerType(AnkerType.body)
                .foregroundStyle(AnkerColor.ink)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                prepareExport()
            } label: {
                Label("Export sichern", ankerIcon: AnkerIcon.share)
                    .ankerType(AnkerType.caption)
            }
            .buttonStyle(AnkerButtonStyle.primary)
            .accessibilityLabel("Alle Daten als JSON-Datei exportieren")
        }
    }

    private var deleteSection: some View {
        card {
            sectionTitle("Alle Daten löschen")

            Text("Entfernt alle Wochen, Anker, Aufgaben, Zeitblöcke und Notizen — auf diesem Gerät "
                 + "und, wenn du bei iCloud angemeldet bist, auch in iCloud und damit auf deinen "
                 + "anderen Geräten.")
                .ankerType(AnkerType.body)
                .foregroundStyle(AnkerColor.ink)
                .fixedSize(horizontal: false, vertical: true)

            // Der wichtigste Satz des Bildschirms: das blosse Loeschen der App raeumt die
            // private CloudKit-Datenbank nicht auf, die Daten kaemen bei einer Neuinstallation
            // zurueck. Ohne diesen Hinweis haelt der Nutzer die App-Loeschung faelschlich
            // fuer eine Loeschung seiner Daten.
            Text("Die App zu löschen reicht dafür nicht: Deine Daten bleiben dann in iCloud liegen "
                 + "und werden bei einer Neuinstallation wiederhergestellt.")
                .ankerType(AnkerType.caption)
                .foregroundStyle(AnkerColor.inkSecond)
                .fixedSize(horizontal: false, vertical: true)

            Button(role: .destructive) {
                showsDeleteConfirmation = true
            } label: {
                Label(isDeleting ? "Wird gelöscht …" : "Alle Daten löschen", ankerIcon: AnkerIcon.delete)
                    .ankerType(AnkerType.caption)
            }
            .buttonStyle(AnkerButtonStyle.secondary)
            // Nicht an die lokale Zahl gebunden: auf einem frischen Gerät kann iCloud Daten
            // halten, die hier noch nicht angekommen sind.
            .disabled(isDeleting)
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
            // `saveChanges` hat den Fehler bereits gemeldet, die Löschung ist zurückgerollt.
            statusMessage = StatusMessage(
                text: "Die Daten konnten nicht gelöscht werden. Es wurde nichts entfernt.",
                isError: true
            )
            return
        }

        DataPortability.resetStoredPreferences()
        refreshCounts()
        isDeleting = true
        Task {
            let cloud = await DataPortability.deleteCloudData()
            isDeleting = false
            statusMessage = deletionMessage(local: report.total, cloud: cloud)
        }
    }

    private func deletionMessage(local: Int, cloud: DataPortability.CloudDeletionResult) -> StatusMessage {
        let localText = local == 1 ? "1 Datensatz wurde gelöscht." : "\(local) Datensätze wurden gelöscht."
        switch cloud {
        case .deleted:
            return StatusMessage(text: "\(localText) Auch die Daten in iCloud sind entfernt; deine anderen Geräte leeren sich beim nächsten Abgleich.", isError: false)
        case .noAccount, .notApplicable:
            return StatusMessage(text: "\(localText) Dieses Gerät ist nicht bei iCloud angemeldet. Liegen dort noch Daten, lösche sie von einem angemeldeten Gerät aus.", isError: false)
        case .failed:
            return StatusMessage(text: "\(localText) iCloud war nicht erreichbar, dort liegen eventuell noch Daten. Versuche es mit Internetverbindung erneut.", isError: true)
        }
    }

    private func refreshCounts() {
        counts = RecordCounts(
            weeks: (try? modelContext.fetchCount(FetchDescriptor<Week>())) ?? 0,
            goals: (try? modelContext.fetchCount(FetchDescriptor<Goal>())) ?? 0,
            days: (try? modelContext.fetchCount(FetchDescriptor<Day>())) ?? 0,
            tasks: (try? modelContext.fetchCount(FetchDescriptor<AnkerTask>())) ?? 0,
            timeBlocks: (try? modelContext.fetchCount(FetchDescriptor<TimeBlock>())) ?? 0
        )
    }

    // MARK: - Texte

    private var deleteConfirmationMessage: String {
        "\(counts.weeks) Wochen, \(counts.goals) Anker, \(counts.tasks) Aufgaben und "
            + "\(counts.timeBlocks) Zeitblöcke auf diesem Gerät werden dauerhaft entfernt. Bist du bei "
            + "iCloud angemeldet, wird auch dort alles gelöscht — auch, was hier noch nicht angekommen "
            + "ist — und deine anderen Geräte leeren sich. Das lässt sich nicht rückgängig machen. "
            + "Sichere vorher einen Export, wenn du die Daten behalten willst."
    }

    // MARK: - Bausteine

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .ankerType(AnkerType.metaStrong)
            .foregroundStyle(AnkerColor.ink)
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AnkerSpacing.s2) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AnkerSpacing.s4)
        .ankerCard()
    }
}

#Preview {
    NavigationStack {
        DataPrivacyView()
    }
    .modelContainer(PreviewContainer.shared)
}
