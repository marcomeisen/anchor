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
            VStack(alignment: .leading, spacing: AnkerSpacing.s4) {
                appearanceSection
                cloudSyncSection
                dataSection
            }
            .padding(AnkerSpacing.screenPadding)
        }
        .background(AnkerColor.ground)
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
                    Label(verbatim: mode.title, ankerIcon: mode.icon)
                        .tag(mode.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .accessibilityLabel("Erscheinungsbild wählen")

            Text(appearance == .system
                 ? "Folgt der Systemeinstellung dieses Geräts."
                 : "Gilt nur für Daivento, unabhängig vom System.")
                .ankerType(AnkerType.caption)
                .foregroundStyle(AnkerColor.inkSecond)
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
                    .ankerType(AnkerType.caption)
                    .foregroundStyle(AnkerColor.ink)
            }
            .accessibilityLabel("iCloud-Sync ein- oder ausschalten")

            Text("Mit Sync sind Wochen, Ziele, Aufgaben und Notizen auf allen Geräten mit demselben Apple-Account gleich. Ohne Sync bleibt alles auf diesem Gerät.")
                .ankerType(AnkerType.caption)
                .foregroundStyle(AnkerColor.inkSecond)
                .fixedSize(horizontal: false, vertical: true)

            if CloudSyncPreference.needsRestart {
                restartNotice
            } else {
                HStack(spacing: AnkerSpacing.s2) {
                    Image(cloudSyncStatus.phase.icon)
                        .ankerIcon(AnkerIconSize.xs)
                        .foregroundStyle(cloudSyncStatus.phase.tint)
                    Text("\(cloudSyncStatus.phase.title) · \(cloudSyncStatus.detail)")
                        .ankerType(AnkerType.caption)
                        .foregroundStyle(AnkerColor.inkSecond)
                        .lineLimit(1)
                }
                .accessibilityElement(children: .combine)
            }

            // Abschalten löscht nichts — das muss dastehen, sonst hält jemand den Schalter
            // für eine Löschfunktion. Der Weg dafür steht direkt darunter.
            Text("Der Schalter überträgt keine Löschung: bereits in iCloud gespeicherte Daten bleiben dort. Zum Entfernen die vollständige Löschung unter Daten und Datenschutz nutzen.")
                .ankerType(AnkerType.caption)
                .foregroundStyle(AnkerColor.inkSecond)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Der Store wird beim Start einmal geöffnet, mit oder ohne CloudKit. Ein Umschalten
    /// zur Laufzeit ist nicht möglich — derselbe Store zweimal mit CloudKit verbunden bricht
    /// mit Core Data 134422 ab. Deshalb der ehrliche Hinweis statt einer halben Umschaltung.
    private var restartNotice: some View {
        VStack(alignment: .leading, spacing: AnkerSpacing.s2) {
            Label(
                CloudSyncPreference.isEnabled()
                    ? "Der Sync startet beim nächsten Start von Daivento."
                    : "Der Sync endet beim nächsten Start von Daivento.",
                ankerIcon: AnkerIcon.refresh
            )
            .ankerType(AnkerType.caption)
            .foregroundStyle(AnkerColor.neutral[500])
            .fixedSize(horizontal: false, vertical: true)

#if os(macOS)
            Button("Jetzt neu starten") {
                CloudSyncPreference.relaunch()
            }
            .ankerType(AnkerType.caption)
            .accessibilityLabel("Daivento jetzt neu starten, damit die Sync-Einstellung greift")
#endif
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AnkerSpacing.s3)
        .background(AnkerColor.neutral[500].opacity(0.12), in: Rectangle())
    }

    // MARK: - Daten

    private var dataSection: some View {
        card {
            sectionTitle("Daten")

            Button {
                showingDataPrivacy = true
            } label: {
                HStack(spacing: AnkerSpacing.s3) {
                    Image(.privacy)
                        .ankerType(AnkerType.meta)
                        .foregroundStyle(AnkerColor.accentInk)
                    VStack(alignment: .leading, spacing: AnkerSpacing.s1) {
                        Text("Daten und Datenschutz")
                            .ankerType(AnkerType.caption)
                            .foregroundStyle(AnkerColor.ink)
                        Text("Exportieren oder vollständig löschen")
                            .ankerType(AnkerType.caption)
                            .foregroundStyle(AnkerColor.inkSecond)
                    }
                    Spacer(minLength: 0)
                    Image(.chevronRight)
                        .ankerType(AnkerType.caption)
                        .foregroundStyle(AnkerColor.inkSecond)
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
            .ankerType(AnkerType.metaStrong)
            .foregroundStyle(AnkerColor.ink)
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AnkerSpacing.s2) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AnkerSpacing.s4)
        .background(AnkerColor.surface)
        .overlay(Rectangle().stroke(AnkerColor.divider, lineWidth: AnkerBorder.rule))
        .clipShape(Rectangle())
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .modelContainer(PreviewContainer.shared)
}
