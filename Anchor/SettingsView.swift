import SwiftData
import SwiftUI

/// Einstellungen: Erscheinungsbild, iCloud-Sync und der Weg zu Daten und Datenschutz.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(AppSettingsKey.appearance) private var appearanceRaw = AppearanceMode.system.rawValue
    @AppStorage(AppSettingsKey.cloudSyncEnabled) private var cloudSyncEnabled = true

    @ObservedObject var cloudSyncStatus: CloudSyncStatusCenter = .shared
    @State private var showingDataPrivacy = false

    /// `showsDoneButton` false in der macOS-Einstellungen-Szene: die hat ihr eigenes Fenster
    /// mit Schließen-Knopf, ein zweites "Fertig" wäre dort verwirrend.
    var showsDoneButton = true

    private var appearance: AppearanceMode {
        AppearanceMode(rawValue: appearanceRaw) ?? .system
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                appearanceSection
                cloudSyncSection
                dataSection
            }
            .padding(AnkerSpacing.screenPadding)
        }
        .background(AnkerColor.paper)
        .navigationTitle("Einstellungen")
        .toolbar {
            if showsDoneButton {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showingDataPrivacy) {
            NavigationStack {
                DataPrivacyView()
            }
#if os(macOS)
            .frame(minWidth: 460, minHeight: 520)
#endif
        }
    }

    // MARK: - Erscheinungsbild

    private var appearanceSection: some View {
        card {
            sectionTitle("Erscheinungsbild")

            Picker("Erscheinungsbild", selection: $appearanceRaw) {
                ForEach(AppearanceMode.allCases) { mode in
                    Label(mode.title, systemImage: mode.symbolName)
                        .tag(mode.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .accessibilityLabel("Erscheinungsbild wählen")

            Text(appearance == .system
                 ? "Folgt der Systemeinstellung dieses Geräts."
                 : "Gilt nur für Daivento, unabhängig vom System.")
                .font(.system(size: 12))
                .foregroundStyle(AnkerColor.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        // Sofort anwenden: auf macOS hängen die Farbtokens und das Statusbar-Popover an
        // `NSApp.appearance`, nicht am Fenster.
        .onChange(of: appearanceRaw) { _, _ in
            appearance.apply()
        }
    }

    // MARK: - iCloud

    private var cloudSyncSection: some View {
        card {
            sectionTitle("iCloud-Sync")

            Toggle(isOn: Binding(
                get: { cloudSyncEnabled },
                set: { CloudSyncPreference.set($0) }
            )) {
                Text("Über iCloud synchronisieren")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(AnkerColor.ink)
            }
            .accessibilityLabel("iCloud-Sync ein- oder ausschalten")

            Text("Mit Sync sind Wochen, Ziele, Aufgaben und Notizen auf allen Geräten mit demselben Apple-Account gleich. Ohne Sync bleibt alles auf diesem Gerät.")
                .font(.system(size: 12))
                .foregroundStyle(AnkerColor.muted)
                .fixedSize(horizontal: false, vertical: true)

            if CloudSyncPreference.needsRestart {
                restartNotice
            } else {
                HStack(spacing: 6) {
                    Image(systemName: cloudSyncStatus.phase.symbolName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(cloudSyncStatus.phase.tint)
                    Text("\(cloudSyncStatus.phase.title) · \(cloudSyncStatus.detail)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AnkerColor.muted)
                        .lineLimit(1)
                }
                .accessibilityElement(children: .combine)
            }

            // Abschalten löscht nichts — das muss dastehen, sonst hält jemand den Schalter
            // für eine Löschfunktion. Der Weg dafür steht direkt darunter.
            Text("Der Schalter überträgt keine Löschung: bereits in iCloud gespeicherte Daten bleiben dort. Zum Entfernen die vollständige Löschung unter Daten und Datenschutz nutzen.")
                .font(.system(size: 11))
                .foregroundStyle(AnkerColor.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Der Store wird beim Start einmal geöffnet, mit oder ohne CloudKit. Ein Umschalten
    /// zur Laufzeit ist nicht möglich — derselbe Store zweimal mit CloudKit verbunden bricht
    /// mit Core Data 134422 ab. Deshalb der ehrliche Hinweis statt einer halben Umschaltung.
    private var restartNotice: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(
                CloudSyncPreference.isEnabled()
                    ? "Der Sync startet beim nächsten Start von Daivento."
                    : "Der Sync endet beim nächsten Start von Daivento.",
                systemImage: "arrow.clockwise"
            )
            .font(.system(size: 11.5, weight: .semibold))
            .foregroundStyle(AnkerColor.brass)
            .fixedSize(horizontal: false, vertical: true)

#if os(macOS)
            Button("Jetzt neu starten") {
                CloudSyncPreference.relaunch()
            }
            .font(.system(size: 11.5, weight: .semibold))
            .accessibilityLabel("Daivento jetzt neu starten, damit die Sync-Einstellung greift")
#endif
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(AnkerColor.brass.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Daten

    private var dataSection: some View {
        card {
            sectionTitle("Daten")

            Button {
                showingDataPrivacy = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AnkerColor.indigoText)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Daten und Datenschutz")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(AnkerColor.ink)
                        Text("Exportieren oder vollständig löschen")
                            .font(.system(size: 11))
                            .foregroundStyle(AnkerColor.muted)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AnkerColor.muted)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Daten und Datenschutz öffnen")
        }
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
        SettingsView()
    }
    .modelContainer(PreviewContainer.shared)
}
