import SwiftData
import SwiftUI

/// Einstellungen: Erscheinungsbild, iCloud-Sync und der Weg zu Daten und Datenschutz.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(AppSettingsKey.startupViewMode) private var startupViewRaw = StartupViewMode.lastView.rawValue
    @AppStorage(AppSettingsKey.appearance) private var appearanceRaw = AppearanceMode.system.rawValue
    @AppStorage(AppSettingsKey.cloudSyncEnabled) private var cloudSyncEnabled = true
    @AppStorage(AppSettingsKey.language) private var languageRaw = AppLanguage.system.rawValue

    @AppStorage(AppSettingsKey.reminderWeekStartEnabled) private var weekStartReminderOn = false
    @AppStorage(AppSettingsKey.reminderWeekStartMinutes) private var weekStartReminderMinutes = RitualReminderKind.weekStart.defaultMinutes
    @AppStorage(AppSettingsKey.reminderReviewEnabled) private var reviewReminderOn = false
    @AppStorage(AppSettingsKey.reminderReviewMinutes) private var reviewReminderMinutes = RitualReminderKind.review.defaultMinutes

    @ObservedObject var cloudSyncStatus: CloudSyncStatusCenter = .shared
    @ObservedObject private var reminderCenter: RitualReminderCenter = .shared
    @State private var showingDataPrivacy = false
    /// Gesetzt, wenn das Einschalten an einer verweigerten Berechtigung scheiterte.
    @State private var reminderPermissionDenied = false

    /// `showsDoneButton` false in der macOS-Einstellungen-Szene: die hat ihr eigenes Fenster
    /// mit Schließen-Knopf, ein zweites "Fertig" wäre dort verwirrend.
    var showsDoneButton = true

    private var appearance: AppearanceMode {
        AppearanceMode(rawValue: appearanceRaw) ?? .system
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AnkerSpacing.s5) {
                generalSection
                remindersSection
                dataSection
                helpSection
            }
            .padding(AnkerSpacing.screenPadding)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
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
        .task { await reminderCenter.refreshAuthorization() }
    }

    // MARK: - Allgemein

    private var generalSection: some View {
        section("Allgemein") {
            settingsPicker("Startansicht", selection: $startupViewRaw) {
                ForEach(StartupViewMode.allCases) { mode in
                    Label(verbatim: mode.title, ankerIcon: mode.icon).tag(mode.rawValue)
                }
            }
            rowDivider
            settingsPicker("Erscheinungsbild", selection: $appearanceRaw) {
                ForEach(AppearanceMode.allCases) { mode in
                    Label(verbatim: mode.title, ankerIcon: mode.icon).tag(mode.rawValue)
                }
            }
            rowDivider
            settingsPicker("Sprache", selection: Binding(
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
            if AppLanguage.needsRestart(for: AppLanguage(rawValue: languageRaw) ?? .system) {
                languageRestartNotice
                    .padding(.bottom, AnkerSpacing.s2)
            }
        }
        .onChange(of: appearanceRaw) { _, _ in appearance.apply() }
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

    private var cloudSyncControls: some View {
        VStack(alignment: .leading, spacing: AnkerSpacing.s2) {
            Toggle(isOn: Binding(
                // Über `CloudSyncPreference`, nicht über den Vorgabewert von `@AppStorage`: ein
                // frisches Gerät ist bis zur Wahl lokal. Das Lesen von `cloudSyncEnabled` hält die
                // Ansicht an Änderungen gebunden.
                get: { _ = cloudSyncEnabled; return CloudSyncPreference.isEnabled() },
                set: { CloudSyncPreference.set($0) }
            )) {
                Text("Über iCloud synchronisieren")
                    .ankerType(AnkerType.body)
                    .foregroundStyle(AnkerColor.ink)
            }
            .toggleStyle(.switch)
            .accessibilityLabel("iCloud-Sync ein- oder ausschalten")

            Text("Mit Sync sind Wochen, Anker, Aufgaben und Notizen auf allen Geräten mit demselben Apple-Account gleich. Ohne Sync bleibt alles auf diesem Gerät.")
                .ankerType(AnkerType.caption)
                .foregroundStyle(AnkerColor.inkSecond)
                .fixedSize(horizontal: false, vertical: true)

            if CloudSyncPreference.needsRestart {
                restartNotice
            } else {
                HStack(alignment: .top, spacing: AnkerSpacing.s2) {
                    Image(cloudSyncStatus.phase.icon)
                        .ankerIcon(AnkerIconSize.xs)
                        .foregroundStyle(cloudSyncStatus.phase.tint)
                    Text("\(cloudSyncStatus.phase.title) · \(cloudSyncStatus.detail)")
                        .ankerType(AnkerType.caption)
                        .foregroundStyle(AnkerColor.inkSecond)
                        .fixedSize(horizontal: false, vertical: true)
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
        .padding(.vertical, AnkerSpacing.s2)
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

    // MARK: - Erinnerungen

    private var remindersSection: some View {
        section("Mitteilungen") {
            reminderRow(.weekStart, title: "Montags: Anker setzen", isOn: $weekStartReminderOn, minutes: $weekStartReminderMinutes)
            rowDivider
            reminderRow(.review, title: "Sonntags: Rückblick", isOn: $reviewReminderOn, minutes: $reviewReminderMinutes)

            Text("Die Erinnerung am Montag kommt nur, solange die Woche noch keine Anker hat. Die am Sonntag nur, wenn die Woche Anker hat und noch offen ist.")
                .ankerType(AnkerType.caption)
                .foregroundStyle(AnkerColor.inkSecond)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, AnkerSpacing.s2)

            if showsReminderPermissionNotice {
                reminderPermissionNotice
                    .padding(.bottom, AnkerSpacing.s2)
            }
        }
        .disabled(RitualReminderCenter.isInactiveInThisProcess)
    }

    /// Verweigert, oder nachträglich in den Systemeinstellungen abgeschaltet, während hier noch
    /// eine Erinnerung eingeschaltet ist.
    private var showsReminderPermissionNotice: Bool {
        reminderPermissionDenied
            || (reminderCenter.isDenied && (weekStartReminderOn || reviewReminderOn))
    }

    private func reminderRow(
        _ kind: RitualReminderKind,
        title: LocalizedStringKey,
        isOn: Binding<Bool>,
        minutes: Binding<Int>
    ) -> some View {
        VStack(alignment: .leading, spacing: AnkerSpacing.s2) {
            Toggle(isOn: Binding(
                get: { isOn.wrappedValue },
                set: { newValue in setReminder(isOn: isOn, to: newValue) }
            )) {
                Text(title)
                    .ankerType(AnkerType.body)
                    .foregroundStyle(AnkerColor.ink)
            }
            .toggleStyle(.switch)
            .frame(minHeight: 44)

            if isOn.wrappedValue {
                HStack(spacing: AnkerSpacing.s3) {
                    Text("Uhrzeit")
                        .ankerType(AnkerType.caption)
                        .foregroundStyle(AnkerColor.inkSecond)
                    Spacer(minLength: 0)
                    DatePicker(
                        "Uhrzeit",
                        selection: Binding(
                            get: {
                                RitualReminderPlanner.date(
                                    fromMinutes: minutes.wrappedValue,
                                    on: Date(),
                                    calendar: RitualReminderPlanner.currentCalendar
                                )
                            },
                            set: { date in
                                minutes.wrappedValue = RitualReminderPlanner.minutes(
                                    from: date,
                                    calendar: RitualReminderPlanner.currentCalendar
                                )
                                reminderCenter.scheduleSoon()
                            }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                    .tint(AnkerColor.accentInk)
#if os(macOS)
                    .datePickerStyle(.stepperField)
#else
                    .datePickerStyle(.compact)
#endif
                }
            }
        }
    }

    /// Erst beim Einschalten nach der Berechtigung fragen. Wird sie verweigert, springt der
    /// Schalter zurück und der Hinweis zeigt den Weg in die Systemeinstellungen.
    private func setReminder(isOn: Binding<Bool>, to newValue: Bool) {
        guard newValue else {
            isOn.wrappedValue = false
            reminderCenter.scheduleSoon(delay: .zero)
            return
        }
        isOn.wrappedValue = true
        Task {
            let granted = await reminderCenter.requestAuthorizationIfNeeded()
            if granted {
                reminderPermissionDenied = false
                reminderCenter.scheduleSoon(delay: .zero)
            } else {
                isOn.wrappedValue = false
                reminderPermissionDenied = true
            }
        }
    }

    private var reminderPermissionNotice: some View {
        VStack(alignment: .leading, spacing: AnkerSpacing.s2) {
            Text("Mitteilungen für Anchorit sind ausgeschaltet. Erinnerungen kommen erst, wenn du sie in den Systemeinstellungen erlaubst.")
                .ankerType(AnkerType.caption)
                .foregroundStyle(AnkerColor.inkSecond)
                .fixedSize(horizontal: false, vertical: true)

            Button("Systemeinstellungen öffnen") {
                RitualReminderCenter.openSystemSettings()
            }
            .ankerType(AnkerType.caption)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AnkerSpacing.s3)
        .ankerCard(fill: AnkerColor.neutral[500].opacity(0.12), elevated: false)
    }

    // MARK: - Daten

    private var dataSection: some View {
        section("Daten") {
            cloudSyncControls
            rowDivider
            Button {
                showingDataPrivacy = true
            } label: {
                disclosureRow("Daten und Datenschutz", detail: "Exportieren oder vollständig löschen", icon: .note)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Daten und Datenschutz öffnen")
            .accessibilityHint("Exportieren oder vollständig löschen")
            rowDivider
            legalRow(.privacy, icon: .privacy, title: "Datenschutzerklärung", detail: "Was Anchorit speichert und warum")
        }
    }

    private var helpSection: some View {
        section("Hilfe") {
            legalRow(.support, icon: .share, title: "Hilfe und Kontakt", detail: "Fragen, Fehler, Wünsche")
        }
    }

    private func legalRow(_ document: LegalDocument, icon: AnkerIcon, title: LocalizedStringKey, detail: LocalizedStringKey) -> some View {
        NavigationLink(value: document) {
            disclosureRow(title, detail: detail, icon: icon)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Bausteine

    private func disclosureRow(_ title: LocalizedStringKey, detail: LocalizedStringKey, icon: AnkerIcon) -> some View {
        HStack(spacing: AnkerSpacing.s3) {
            Image(icon)
                .ankerIcon(AnkerIconSize.s)
                .foregroundStyle(AnkerColor.inkSecond)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: AnkerSpacing.s1) {
                Text(title)
                    .ankerType(AnkerType.body)
                    .foregroundStyle(AnkerColor.ink)
                Text(detail)
                    .ankerType(AnkerType.caption)
                    .foregroundStyle(AnkerColor.inkSecond)
            }
            Spacer(minLength: 0)
            Image(.chevronRight)
                .ankerIcon(AnkerIconSize.xs)
                .foregroundStyle(AnkerColor.inkSecond)
                .accessibilityHidden(true)
        }
        .frame(minHeight: 44)
        .padding(.vertical, AnkerSpacing.s1)
        .contentShape(Rectangle())
    }

    private func settingsPicker<Value: Hashable, Options: View>(
        _ title: LocalizedStringKey,
        selection: Binding<Value>,
        @ViewBuilder options: () -> Options
    ) -> some View {
        LabeledContent {
            Picker(title, selection: selection, content: options)
                .labelsHidden()
                .pickerStyle(.menu)
                .tint(AnkerColor.ink)
                .frame(minHeight: 44)
        } label: {
            Text(title)
                .ankerType(AnkerType.body)
                .foregroundStyle(AnkerColor.ink)
        }
    }

    private var rowDivider: some View {
        AnkerRule(color: AnkerColor.cardDivider, weight: .row)
    }

    private func section<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AnkerSpacing.s2) {
            Text(title)
                .ankerType(AnkerType.metaStrong)
                .foregroundStyle(AnkerColor.ink)
                .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AnkerSpacing.s4)
            .padding(.vertical, AnkerSpacing.s2)
            .ankerCard()
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .modelContainer(PreviewContainer.shared)
}
