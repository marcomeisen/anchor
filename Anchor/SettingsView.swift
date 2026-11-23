import SwiftData
import SwiftUI

/// Einstellungen: Erscheinungsbild, iCloud-Sync und der Weg zu Daten und Datenschutz.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(AppSettingsKey.startupViewMode) private var startupViewRaw = StartupViewMode.lastView.rawValue
    @AppStorage(AppSettingsKey.appearance) private var appearanceRaw = AppearanceMode.system.rawValue
    @AppStorage(AppSettingsKey.cloudSyncEnabled) private var cloudSyncEnabled = true
    @AppStorage(AppSettingsKey.language) private var languageRaw = AppLanguage.system.rawValue

    @ObservedObject var cloudSyncStatus: CloudSyncStatusCenter = .shared
    @State private var showingDataPrivacy = false

    /// `showsDoneButton` false in der macOS-Einstellungen-Szene: die hat ihr eigenes Fenster
    /// mit Schließen-Knopf, ein zweites "Fertig" wäre dort verwirrend.
    var showsDoneButton = true

    private var appearance: AppearanceMode {
        AppearanceMode(rawValue: appearanceRaw) ?? .system
    }

    private var startupViewMode: StartupViewMode {
        StartupViewMode(rawValue: startupViewRaw) ?? .lastView
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AnkerSpacing.s4) {
                startupSection
                appearanceSection
                languageSection
                cloudSyncSection
                dataSection
            }
            .padding(AnkerSpacing.screenPadding)
        }
        .background(AnkerColor.ground)
        .ankerSheetChrome(
            "Einstellungen",
            // In der macOS-Einstellungen-Szene bleibt der Platz leer: das Fenster hat seinen
            // eigenen Schliessen-Knopf, ein zweites „Fertig" waere dort verwirrend.
            cancel: showsDoneButton ? AnkerSheetAction("Fertig") { dismiss() } : nil
        )
        .navigationDestination(for: LegalDocument.self) { LegalDocumentView(document: $0) }
        .sheet(isPresented: $showingDataPrivacy) {
            NavigationStack {
                DataPrivacyView()
            }
#if os(macOS)
            .frame(minWidth: 460, minHeight: 520)
#endif
        }
    }

    // MARK: - Start

    private var startupSection: some View {
        card {
            sectionTitle("Start")

            Picker("Startansicht", selection: $startupViewRaw) {
                ForEach(StartupViewMode.allCases) { mode in
                    Label(verbatim: mode.title, ankerIcon: mode.icon)
                        .tag(mode.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .accessibilityLabel("Startansicht wählen")

            Text(startupViewMode.explanation)
                .ankerType(AnkerType.caption)
                .foregroundStyle(AnkerColor.inkSecond)
                .fixedSize(horizontal: false, vertical: true)
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
                 ? String(localized: "Folgt der Systemeinstellung dieses Geräts.")
                 : String(localized: "Gilt nur für Anchorit, unabhängig vom System."))
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

    // MARK: - Sprache

    private var languageSection: some View {
        card {
            sectionTitle("Sprache")

            Picker("Sprache", selection: Binding(
                get: { languageRaw },
                set: { raw in
                    languageRaw = raw
                    AppLanguage.select(AppLanguage(rawValue: raw) ?? .system)
                }
            )) {
                ForEach(AppLanguage.allCases) { language in
                    Text(verbatim: language.title).tag(language.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .accessibilityLabel("Sprache wählen")

            Text("Wie das System: Deutsch, wenn dein Gerät Deutsch spricht, sonst Englisch.")
                .ankerType(AnkerType.caption)
                .foregroundStyle(AnkerColor.inkSecond)
                .fixedSize(horizontal: false, vertical: true)

            if AppLanguage.needsRestart(for: AppLanguage(rawValue: languageRaw) ?? .system) {
                languageRestartNotice
            }
        }
    }

    /// Texte, Datumsformate und Systemdialoge wechseln gemeinsam — deshalb beim Neustart und
    /// nicht halb im laufenden Fenster. Die Ansage steht in der **gewählten** Sprache, damit
    /// sie auch versteht, wer die aktuelle nicht liest.
    private var languageRestartNotice: some View {
        let chosen = AppLanguage(rawValue: languageRaw) ?? .system
        let english = AppLanguage.expectedCode(for: chosen) == "en"
        return VStack(alignment: .leading, spacing: AnkerSpacing.s2) {
#if os(macOS)
            Label {
                Text(verbatim: english
                     ? "The new language applies after a restart."
                     : "Die neue Sprache gilt nach einem Neustart.")
            } icon: {
                Image(.refresh).ankerIcon(AnkerIconSize.xs)
            }
            .ankerType(AnkerType.caption)
            .foregroundStyle(AnkerColor.inkSecond)

            Button {
                CloudSyncPreference.relaunch()
            } label: {
                Text(verbatim: english ? "Restart now" : "Jetzt neu starten")
            }
            .ankerType(AnkerType.caption)
#else
            Label {
                Text(verbatim: english
                     ? "The new language applies the next time you open Anchorit. Close the app in the app switcher and open it again."
                     : "Die neue Sprache gilt beim nächsten Öffnen. Schließe Anchorit im App-Umschalter und öffne die App erneut.")
            } icon: {
                Image(.refresh).ankerIcon(AnkerIconSize.xs)
            }
            .ankerType(AnkerType.caption)
            .foregroundStyle(AnkerColor.inkSecond)
            .fixedSize(horizontal: false, vertical: true)
#endif
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AnkerSpacing.s3)
        .ankerCard(fill: AnkerColor.neutral[500].opacity(0.12), elevated: false)
    }

    // MARK: - iCloud

    private var cloudSyncSection: some View {
        card {
            sectionTitle("iCloud-Sync")

            Toggle(isOn: Binding(
                // Über `CloudSyncPreference`, nicht über den Vorgabewert von `@AppStorage`: ein
                // frisches Gerät ist bis zur Wahl lokal. Das Lesen von `cloudSyncEnabled` hält die
                // Ansicht an Änderungen gebunden.
                get: { _ = cloudSyncEnabled; return CloudSyncPreference.isEnabled() },
                set: { CloudSyncPreference.set($0) }
            )) {
                Text("Über iCloud synchronisieren")
                    .ankerType(AnkerType.caption)
                    .foregroundStyle(AnkerColor.ink)
            }
            .accessibilityLabel("iCloud-Sync ein- oder ausschalten")

            Text("Mit Sync sind Wochen, Anker, Aufgaben und Notizen auf allen Geräten mit demselben Apple-Account gleich. Ohne Sync bleibt alles auf diesem Gerät.")
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
                verbatim: CloudSyncPreference.isEnabled()
                    ? String(localized: "Der Sync startet beim nächsten Start von Anchorit.")
                    : String(localized: "Der Sync endet beim nächsten Start von Anchorit."),
                ankerIcon: AnkerIcon.refresh
            )
            .ankerType(AnkerType.caption)
            .foregroundStyle(AnkerColor.inkSecond)
            .fixedSize(horizontal: false, vertical: true)

#if os(macOS)
            Button("Jetzt neu starten") {
                CloudSyncPreference.relaunch()
            }
            .ankerType(AnkerType.caption)
            .accessibilityLabel("Anchorit jetzt neu starten, damit die Sync-Einstellung greift")
#endif
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AnkerSpacing.s3)
        .ankerCard(fill: AnkerColor.neutral[500].opacity(0.12), elevated: false)
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

            AnkerRule(color: AnkerColor.cardDivider, weight: .row)
            legalRow(.privacy, icon: .privacy, title: "Datenschutzerklärung", detail: "Was Anchorit speichert und warum")
            AnkerRule(color: AnkerColor.cardDivider, weight: .row)
            legalRow(.support, icon: .share, title: "Hilfe und Kontakt", detail: "Fragen, Fehler, Wünsche")
        }
    }

    /// Öffnet den Text in der App, von rechts hereingeschoben — nicht im Browser.
    private func legalRow(_ document: LegalDocument, icon: AnkerIcon, title: LocalizedStringKey, detail: LocalizedStringKey) -> some View {
        NavigationLink(value: document) {
            HStack(spacing: AnkerSpacing.s3) {
                Image(icon)
                    .ankerType(AnkerType.meta)
                    .foregroundStyle(AnkerColor.accentInk)
                VStack(alignment: .leading, spacing: AnkerSpacing.s1) {
                    Text(title)
                        .ankerType(AnkerType.caption)
                        .foregroundStyle(AnkerColor.ink)
                    Text(detail)
                        .ankerType(AnkerType.caption)
                        .foregroundStyle(AnkerColor.inkSecond)
                }
                Spacer(minLength: 0)
                Image(.chevronRight)
                    .ankerType(AnkerType.caption)
                    .foregroundStyle(AnkerColor.inkSecond)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Bausteine

    private func sectionTitle(_ text: LocalizedStringKey) -> some View {
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
        SettingsView()
    }
    .modelContainer(PreviewContainer.shared)
}
