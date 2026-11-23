import SwiftUI

/// Wer hinter Anchorit steht. **Eine** Stelle für Datenschutzerklärung, Hilfe und die
/// öffentlichen Seiten unter `docs/` — vor dem Release ausfüllen.
enum LegalInfo {
    static let name = "[Vor- und Nachname]"
    static let address = "[Straße Hausnummer, PLZ Ort, Land]"
    static let email = "[Kontakt-E-Mail]"
    /// Stand der Datenschutzerklärung.
    static let policyDate = AnkerCalendar.date(year: 2026, month: 11, day: 23)

    static var hasPlaceholders: Bool {
        [name, address, email].contains { $0.hasPrefix("[") }
    }

    static var mailURL: URL? {
        hasPlaceholders ? nil : URL(string: "mailto:\(email)")
    }
}

/// Die beiden Rechtstexte der App.
///
/// Bewusst nicht über den String-Katalog: Ein Rechtstext ist ein zusammenhängender Text, der
/// als Ganzes geprüft und freigegeben wird. In Einzelschlüssel zerlegt ginge die Übersicht
/// verloren, welche Fassung gilt. Deshalb zwei vollständige Fassungen, gewählt nach der
/// Sprache, in der die App läuft.
enum LegalDocument: Hashable {
    case privacy
    case support

    struct Section: Identifiable {
        let id = UUID()
        let heading: String?
        let paragraphs: [String]
    }

    var title: String {
        switch (self, AppLanguage.isGermanActive) {
        case (.privacy, true): "Datenschutzerklärung"
        case (.privacy, false): "Privacy Policy"
        case (.support, true): "Hilfe und Kontakt"
        case (.support, false): "Help & Contact"
        }
    }

    var summary: String {
        switch (self, AppLanguage.isGermanActive) {
        case (.privacy, true):
            "Anchorit speichert nur, was du selbst eingibst — auf deinem Gerät und, wenn du es erlaubst, in deiner privaten iCloud. Der Entwickler hat darauf keinen Zugriff. Keine Analyse, keine Werbung, kein Tracking, keine Weitergabe an Dritte."
        case (.privacy, false):
            "Anchorit stores only what you enter yourself — on your device and, if you allow it, in your private iCloud. The developer has no access to it. No analytics, no ads, no tracking, nothing shared with third parties."
        case (.support, true):
            "Fragen, Fehler oder Wünsche? Schreib eine E-Mail. Hilfreich sind Gerät, Systemversion und die App-Version (Einstellungen → iCloud-Sync → Status antippen)."
        case (.support, false):
            "Questions, bugs or ideas? Send an email. Device, system version and app version help (Settings → iCloud sync → tap the status)."
        }
    }

    var sections: [Section] {
        switch (self, AppLanguage.isGermanActive) {
        case (.privacy, true): Self.privacyGerman
        case (.privacy, false): Self.privacyEnglish
        case (.support, true): Self.supportGerman
        case (.support, false): Self.supportEnglish
        }
    }

    // MARK: - Datenschutz

    private static var controller: String {
        "\(LegalInfo.name)\n\(LegalInfo.address)\n\(LegalInfo.email)"
    }

    private static var privacyGerman: [Section] {
        [
            Section(heading: "1. Verantwortlicher", paragraphs: [controller]),
            Section(heading: "2. Welche Daten Anchorit verarbeitet", paragraphs: [
                "Ausschließlich Inhalte, die du in der App anlegst: Wochen, Anker samt Warum-Satz und Rückblickantwort, Aufgaben, Zeitblöcke, Tagesfokus, Notizen und Wochenreflexionen. Dazu kommen Einstellungen wie Erscheinungsbild, Sprache, Startansicht und ob iCloud verwendet wird.",
                "Anchorit erhebt keine Gerätekennungen, keinen Standort, keine Kontakte, keine Nutzungsstatistiken und keine Absturzberichte. Die App enthält keine Software von Drittanbietern zur Analyse oder Werbung und baut außer zu iCloud keine Netzwerkverbindung auf.",
                "Import aus Apple Erinnerungen (optional). Nur wenn du unter Einstellungen → Daten den Import startest und den Zugriff erlaubst, liest Anchorit einmalig die offenen Erinnerungen der Listen, die du auswählst — Titel, Fälligkeit und Priorität — und legt daraus Aufgaben an. Gelesen wird auf dem Gerät; an Apple Erinnerungen wird nichts geändert und nichts zurückgeschrieben. Damit eine Erinnerung nicht zweimal übernommen wird, merkt sich Anchorit auf diesem Gerät deren Kennung. Den Zugriff kannst du jederzeit in den Systemeinstellungen widerrufen.",
                "Erinnerungen an das Ritual (optional). Schaltest du sie ein, plant das Gerät selbst lokale Mitteilungen für Montag und Sonntag. Dafür wird nichts übertragen.",
            ]),
            Section(heading: "3. Wo die Daten liegen", paragraphs: [
                "Auf deinem Gerät. Alle Inhalte werden lokal in der App gespeichert.",
                "In deiner privaten iCloud (optional). Beim ersten Start fragt Anchorit, ob deine Daten zwischen deinen Geräten abgeglichen werden sollen; bis du dich entscheidest, bleibt alles auf dem Gerät. Wählst du iCloud, liegen die Inhalte in der privaten CloudKit-Datenbank deines Apple-Accounts. Sie gehört zu deinem Account, der Entwickler kann sie nicht einsehen. Die Verarbeitung in iCloud erfolgt durch Apple nach den Bedingungen, die du mit Apple vereinbart hast. Mit dem erweiterten Datenschutz für iCloud sind die Daten Ende-zu-Ende verschlüsselt.",
                "Den Abgleich kannst du jederzeit in den Einstellungen ausschalten.",
            ]),
            Section(heading: "4. Zweck und Rechtsgrundlage", paragraphs: [
                "Die Daten werden nur verarbeitet, damit die App ihre Funktion erfüllt: deine Woche zu planen und auf deinen Geräten gleich zu halten (Art. 6 Abs. 1 lit. b DSGVO). Der iCloud-Abgleich erfolgt nur mit deiner Einwilligung (Art. 6 Abs. 1 lit. a DSGVO), die du in den Einstellungen widerrufen kannst.",
            ]),
            Section(heading: "5. Speicherdauer und Löschung", paragraphs: [
                "Die Daten bleiben gespeichert, bis du sie löschst. Unter Einstellungen → Daten und Datenschutz → Alle Daten löschen entfernt Anchorit alle Inhalte auf dem Gerät und, wenn du bei iCloud angemeldet bist, auch in iCloud. Das Löschen der App allein entfernt die Daten in iCloud nicht.",
            ]),
            Section(heading: "6. Deine Rechte", paragraphs: [
                "Du hast das Recht auf Auskunft, Berichtigung, Löschung, Einschränkung der Verarbeitung, Datenübertragbarkeit und Widerspruch (Art. 15–21 DSGVO). Auskunft und Übertragbarkeit erfüllt die App selbst: Einstellungen → Daten und Datenschutz → Export sichern erzeugt eine Datei mit allen gespeicherten Inhalten. Da der Entwickler keinen Zugriff auf deine Daten hat, kann er selbst keine Auskunft über deine Inhalte geben.",
                "Du hast außerdem das Recht, dich bei einer Datenschutz-Aufsichtsbehörde zu beschweren.",
            ]),
            Section(heading: "7. Änderungen", paragraphs: [
                "Ändert sich, wie Anchorit mit Daten umgeht, wird diese Erklärung angepasst und das Datum aktualisiert.",
            ]),
        ]
    }

    private static var privacyEnglish: [Section] {
        [
            Section(heading: "1. Controller", paragraphs: [controller]),
            Section(heading: "2. What data Anchorit processes", paragraphs: [
                "Only content you create in the app: weeks, anchors with their why-sentence and review answer, tasks, time blocks, daily focus, notes and weekly reflections. Plus settings such as appearance, language, start view and whether iCloud is used.",
                "Anchorit collects no device identifiers, no location, no contacts, no usage statistics and no crash reports. The app contains no third-party analytics or advertising software and makes no network connections other than to iCloud.",
                "Import from Apple Reminders (optional). Only if you start the import under Settings → Data and allow access, Anchorit reads the open reminders of the lists you choose once — title, due date and priority — and creates tasks from them. Reading happens on the device; nothing in Apple Reminders is changed or written back. So that a reminder isn’t imported twice, Anchorit remembers its identifier on this device. You can revoke access at any time in the system settings.",
                "Ritual reminders (optional). If you turn them on, the device itself schedules local notifications for Monday and Sunday. Nothing is transmitted for this.",
            ]),
            Section(heading: "3. Where the data lives", paragraphs: [
                "On your device. All content is stored locally in the app.",
                "In your private iCloud (optional). On first launch, Anchorit asks whether your data should sync between your devices; until you decide, everything stays on the device. If you choose iCloud, the content is stored in the private CloudKit database of your Apple Account. It belongs to your account; the developer cannot see it. Processing in iCloud is done by Apple under the terms you have agreed with Apple. With Advanced Data Protection for iCloud, the data is end-to-end encrypted.",
                "You can turn syncing off at any time in Settings.",
            ]),
            Section(heading: "4. Purpose and legal basis", paragraphs: [
                "Data is processed only so the app can do its job: plan your week and keep it the same on your devices (Art. 6(1)(b) GDPR). iCloud syncing happens only with your consent (Art. 6(1)(a) GDPR), which you can withdraw in Settings.",
            ]),
            Section(heading: "5. Retention and deletion", paragraphs: [
                "Your data is kept until you delete it. Settings → Data & Privacy → Delete all data removes all content on the device and, if you’re signed in to iCloud, in iCloud too. Deleting the app alone does not remove the data in iCloud.",
            ]),
            Section(heading: "6. Your rights", paragraphs: [
                "You have the right of access, rectification, erasure, restriction of processing, data portability and objection (Art. 15–21 GDPR). The app covers access and portability itself: Settings → Data & Privacy → Save export creates a file with all stored content. Because the developer has no access to your data, they cannot provide information about your content themselves.",
                "You also have the right to lodge a complaint with a data protection supervisory authority.",
            ]),
            Section(heading: "7. Changes", paragraphs: [
                "If the way Anchorit handles data changes, this policy will be updated along with its date.",
            ]),
        ]
    }

    // MARK: - Hilfe

    private static var supportGerman: [Section] {
        [
            Section(heading: "Wie funktioniert Anchorit?", paragraphs: [
                "Am Montag setzt du bis zu vier Anker — Dinge, die diese Woche zählen, jedes mit einem Satz, warum. Aufgaben hängst du an einen Anker oder lässt sie bewusst ohne. Am Sonntag beantwortest du pro Anker: gehalten, teilweise oder nicht. Offenes nimmst du mit oder lässt es los.",
            ]),
            Section(heading: "Wie lege ich eine Aufgabe schnell an?", paragraphs: [
                "In der Erfassungszeile tippen und Enter drücken. #1 bis #4 hängt die Aufgabe an einen Anker, mo bis so am Ende legt sie auf einen Wochentag.",
            ]),
            Section(heading: "Wie verschiebe ich eine Aufgabe?", paragraphs: [
                "Lange auf die Aufgabe drücken (Mac: Rechtsklick) und „Verschieben …“ oder „In die nächste Woche“ wählen. Auf Mac und iPad lässt sie sich auch auf einen Tag im Raster oder auf eine Woche in der Seitenleiste ziehen.",
            ]),
            Section(heading: "Meine Geräte zeigen nicht dasselbe", paragraphs: [
                "Alle Geräte müssen mit demselben Apple-Account bei iCloud angemeldet sein, und auf jedem muss in Anchorit der iCloud-Sync eingeschaltet sein. Der erste Abgleich kann einige Minuten dauern; den Stand zeigt das Wolkensymbol.",
            ]),
            Section(heading: "Wie lösche ich alle meine Daten?", paragraphs: [
                "Einstellungen → Daten und Datenschutz → Alle Daten löschen. Das entfernt die Inhalte auf dem Gerät und in iCloud. Die App zu löschen reicht dafür nicht. Vorher kannst du dort einen Export sichern.",
            ]),
        ]
    }

    private static var supportEnglish: [Section] {
        [
            Section(heading: "How does Anchorit work?", paragraphs: [
                "On Monday you set up to four anchors — things that matter this week, each with one sentence on why. You hang tasks on an anchor or deliberately leave them without one. On Sunday you answer for each anchor: held, partly or missed. Whatever is still open, you carry over or let go.",
            ]),
            Section(heading: "How do I add a task quickly?", paragraphs: [
                "Type into the capture bar and press Return. #1 to #4 links the task to an anchor; mo to su at the end puts it on a weekday.",
            ]),
            Section(heading: "How do I move a task?", paragraphs: [
                "Long-press the task (Mac: right-click) and choose “Move…” or “To next week”. On Mac and iPad you can also drag it onto a day in the grid or onto a week in the sidebar.",
            ]),
            Section(heading: "My devices don’t show the same thing", paragraphs: [
                "All devices need to be signed in to iCloud with the same Apple Account, and iCloud sync must be turned on in Anchorit on each of them. The first sync can take a few minutes; the cloud icon shows its status.",
            ]),
            Section(heading: "How do I delete all my data?", paragraphs: [
                "Settings → Data & Privacy → Delete all data. This removes the content on the device and in iCloud. Deleting the app is not enough. You can save an export there first.",
            ]),
        ]
    }
}

/// Ein Rechtstext als ruhige Leseseite: Kopf, Zusammenfassung als Karte, dann die Abschnitte.
struct LegalDocumentView: View {
    @Environment(\.dismiss) private var dismiss
    let document: LegalDocument

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AnkerSpacing.s4) {
                if document == .privacy {
                    Text(verbatim: AppLanguage.isGermanActive
                         ? "Stand: \(LegalInfo.policyDate.formatted(date: .long, time: .omitted))"
                         : "Last updated: \(LegalInfo.policyDate.formatted(date: .long, time: .omitted))")
                        .ankerType(AnkerType.caption)
                        .foregroundStyle(AnkerColor.inkSecond)
                }

                Text(verbatim: document.summary)
                    .ankerType(AnkerType.body)
                    .foregroundStyle(AnkerColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(AnkerSpacing.s4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .ankerCard()

                if document == .support {
                    contactCard
                }

                ForEach(document.sections) { section in
                    VStack(alignment: .leading, spacing: AnkerSpacing.s2) {
                        if let heading = section.heading {
                            Text(verbatim: heading)
                                .ankerType(AnkerType.bodyStrong)
                                .foregroundStyle(AnkerColor.ink)
                                .accessibilityAddTraits(.isHeader)
                        }
                        ForEach(Array(section.paragraphs.enumerated()), id: \.offset) { _, paragraph in
                            Text(verbatim: paragraph)
                                .ankerType(AnkerType.body)
                                .foregroundStyle(AnkerColor.inkSecond)
                                .fixedSize(horizontal: false, vertical: true)
                                .textSelection(.enabled)
                        }
                    }
                }
            }
            .padding(AnkerSpacing.screenPadding)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(AnkerColor.ground)
        .ankerSheetChrome(LocalizedStringKey(document.title), cancel: AnkerSheetAction("Zurück") { dismiss() })
    }

    private var contactCard: some View {
        VStack(alignment: .leading, spacing: AnkerSpacing.s2) {
            Text(verbatim: LegalInfo.name)
                .ankerType(AnkerType.bodyStrong)
                .foregroundStyle(AnkerColor.ink)
            if let mail = LegalInfo.mailURL {
                Link(destination: mail) {
                    Label(verbatim: LegalInfo.email, ankerIcon: AnkerIcon.share)
                        .ankerType(AnkerType.body)
                        .foregroundStyle(AnkerColor.accentInk)
                }
            } else {
                Text(verbatim: LegalInfo.email)
                    .ankerType(AnkerType.body)
                    .foregroundStyle(AnkerColor.inkSecond)
            }
        }
        .padding(AnkerSpacing.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ankerCard()
    }
}
