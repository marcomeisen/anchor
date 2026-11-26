import CloudKit
import Combine
import CoreData
import Foundation
import OSLog
import SwiftUI

/// Persistentes Log fuer CloudKit-Ereignisse.
///
/// TestFlight-Builds laufen ohne Debugger. Deshalb landen Sync-Ereignisse im System-Log und
/// sind in Console.app nachlesbar (Subsystem der Bundle-ID, Kategorie `CloudSync`).
/// Bewusst `notice` und `error`: `debug` und `info` werden nicht dauerhaft gespeichert und
/// sind nach dem Auftreten nicht mehr abrufbar.
let cloudSyncLog = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.marcomeisen.Anchor",
    category: "CloudSync"
)

@MainActor
final class CloudSyncStatusCenter: ObservableObject {
    static let shared = CloudSyncStatusCenter()

    /// Muss **vor** dem Erzeugen des `ModelContainer` aufgerufen werden.
    ///
    /// Die Beobachter entstehen erst mit der Instanz. Wurde `shared` zuerst von einer View
    /// angefasst, war der CloudKit-Container schon aufgebaut und `setup` sowie oft der erste
    /// Import waren durch — der Status blieb dann auf "iCloud startet" stehen.
    static func startObserving() {
        shared.startObserving()
    }

    enum Phase: Sendable {
        case starting
        case ready
        case pendingExport
        case syncing
        case synced
        case issue
        /// Vom Nutzer abgeschaltet — kein Fehler, deshalb eine eigene Phase statt `.issue`.
        case disabled

        var title: String {
            switch self {
            case .starting:
                String(localized: "iCloud startet")
            case .ready:
                String(localized: "iCloud bereit")
            case .pendingExport:
                String(localized: "Export ausstehend")
            case .syncing:
                String(localized: "Synchronisiert")
            case .synced:
                String(localized: "Aktuell")
            case .issue:
                String(localized: "Sync prüfen")
            case .disabled:
                String(localized: "Sync aus")
            }
        }

        var icon: AnkerIcon {
            switch self {
            case .starting, .ready:
                .cloud
            case .pendingExport:
                .cloudUploading
            case .syncing:
                .refresh
            case .synced:
                .cloudSynced
            case .issue, .disabled:
                .cloudOff
            }
        }

        var tint: Color {
            switch self {
            case .starting, .ready, .disabled:
                AnkerColor.inkSecond
            case .pendingExport:
                AnkerColor.inkTertiary
            case .syncing:
                AnkerColor.accentInk
            case .synced:
                AnkerColor.ink
            case .issue:
                AnkerColor.inkSecond
            }
        }
    }

    @Published private(set) var phase: Phase = .starting
    @Published private(set) var detail = String(localized: "CloudKit wird vorbereitet")
    @Published private(set) var tooltip = String(localized: "Anchorit verbindet sich mit iCloud.")

    /// Getrennt vom `phase`-Text, damit die Diagnose den Accountzustand auch dann zeigt,
    /// wenn der Status gerade einen Import oder Export meldet.
    @Published private(set) var accountSummary = String(localized: "Wird geprüft")
    @Published private(set) var remoteNotificationSummary = String(localized: "Nicht registriert")
    @Published private(set) var serverProbeSummary = String(localized: "Nicht geprüft")
    @Published private(set) var isCheckingServer = false

    /// Was `StoreMaintenance` in dieser Sitzung automatisch zusammengefuehrt hat.
    ///
    /// Das Aufraeumen loescht Datensaetze ohne Rueckfrage. Sichtbar zu machen, dass es
    /// stattgefunden hat, ist die einzige Gelegenheit fuer den Nutzer, einen Fehler in der
    /// Zusammenfuehrung ueberhaupt zu bemerken.
    @Published private(set) var maintenanceSummary: String?

    /// Zaehlt eingegangene CloudKit-Importe.
    ///
    /// Dient als Schluessel fuer das Zusammenfuehren doppelter Datensaetze: es soll nach jedem
    /// Import laufen, aber nicht bei jeder Neuberechnung einer View. Startwert 0, damit der
    /// erste `task(id:)` auch ohne Import einmal durchlaeuft — ein Store kann Duplikate aus
    /// einer frueheren Sitzung mitbringen.
    @Published private(set) var remoteChangeCount = 0

    /// Ist in dieser Sitzung schon ein Import erfolgreich zu Ende gelaufen?
    ///
    /// Vorher gilt der Bestand als unvollständig: `.starting` und `.ready` stehen noch **vor**
    /// dem ersten Import. `StoreMaintenance` wartet darauf, sonst sähe es nach einem
    /// abgebrochenen Import Tage ohne ihre Woche und hielte sie für Waisen.
    @Published private(set) var hasCompletedImportThisSession = false

    private var observers: [NSObjectProtocol] = []
    private var pendingExportWatchdog: Task<Void, Never>?
    /// Laeuft gerade eine per Geste angeforderte Pruefung?
    ///
    /// Steuert auf dem iPhone, ob die Statuszeile eingeblendet ist. Ohne das Flag muesste die
    /// Zeile dauerhaft stehen — auf einem Telefon ist das 40pt Hoehe fuer eine Aussage, die in
    /// 95 % der Faelle „alles gut" lautet.
    @Published private(set) var isShowingManualSync = false

    private var isSyncDisabled = false
    /// Der CloudKit-Store konnte nicht geoeffnet werden und dieser Prozess speichert nur
    /// lokal. Danach darf keine Meldung mehr „wartet auf Export" behaupten — es wird nie
    /// exportiert, solange der Prozess laeuft.
    private var isCloudUnavailable = false

    /// Zaehlt jedes CloudKit-Ereignis. `requestSync` erkennt daran, ob waehrend des Wartens
    /// wirklich etwas passiert ist — eine Phase abzufragen reicht nicht, weil sie danach
    /// wieder auf demselben Wert stehen kann.
    private var syncEventCount = 0

    /// CloudKit-Ereignisse, die begonnen, aber noch nicht geendet haben — nach `identifier`.
    private var runningEvents: Set<UUID> = []

    /// Ohne Nebenwirkungen: die Beobachter entstehen erst in `startObserving()`.
    ///
    /// Vorher registrierte der Initialisierer sie selbst — damit war jede Instanz an den
    /// `NotificationCenter` gekoppelt und in Tests nicht als stiller Ersatz verwendbar.
    init() {}

    /// Mehrfachaufruf ist unschaedlich.
    func startObserving() {
        guard observers.isEmpty else { return }

        let cloudKitObserver = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey] as? NSPersistentCloudKitContainer.Event else {
                return
            }

            let update = CloudSyncEventUpdate(event: event)
            // `queue: .main`: der Block läuft schon auf dem Hauptthread. Synchron statt über
            // einen `Task`, der das schwache `self` in nebenläufigen Code mitnähme.
            MainActor.assumeIsolated {
                self?.apply(update)
            }
        }

        let localSaveObserver = NotificationCenter.default.addObserver(
            forName: NSManagedObjectContext.didSaveObjectsNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            // CloudKit speichert seine Importe in eigenen Kontexten. Ohne diesen Filter
            // gilt jeder empfangene Datensatz als neue lokale Aenderung, der Status faellt
            // auf "Export ausstehend" zurueck und der Watchdog meldet faelschlich ein Problem.
            guard CloudSyncStatusCenter.isUserContext(notification.object) else { return }

            // `queue: .main`: der Block läuft schon auf dem Hauptthread. Synchron statt über
            // einen `Task`, der das schwache `self` in nebenläufigen Code mitnähme.
            MainActor.assumeIsolated {
                self?.markLocalChangeSaved()
            }
        }

        let remoteChangeObserver = NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // `queue: .main`: der Block läuft schon auf dem Hauptthread. Synchron statt über
            // einen `Task`, der das schwache `self` in nebenläufigen Code mitnähme.
            MainActor.assumeIsolated {
                self?.markRemoteChangeSeen()
            }
        }

        // Meldet sich, wenn der Nutzer sich bei iCloud an- oder abmeldet.
        let accountObserver = NotificationCenter.default.addObserver(
            forName: .CKAccountChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshAccountStatus()
            }
        }

        observers = [cloudKitObserver, localSaveObserver, remoteChangeObserver, accountObserver]
        cloudSyncLog.notice("CloudSync-Beobachter registriert")
    }

    deinit {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
        pendingExportWatchdog?.cancel()
    }

    func markReady() {
        guard phase == .starting else { return }
        phase = .ready
        detail = String(localized: "Wartet auf Änderungen")
        tooltip = String(localized: "iCloud ist eingerichtet. Sobald CloudKit Import oder Export meldet, wird der Status hier aktualisiert.")
    }

    /// Der Sync wurde in diesem Prozess eingeschaltet (Onboarding auf einem frischen Gerät).
    func markCloudSyncEnabledAtRuntime() {
        runningEvents.removeAll()
        isSyncDisabled = false
        isCloudUnavailable = false
        phase = .starting
        accountSummary = String(localized: "Wird geprüft")
        remoteNotificationSummary = String(localized: "Nicht registriert")
        serverProbeSummary = String(localized: "Nicht geprüft")
        markReady()
        cloudSyncLog.notice("iCloud-Sync im Onboarding eingeschaltet")
    }

    /// Der Nutzer hat den Sync abgeschaltet.
    ///
    /// Setzt zusaetzlich einen Riegel vor alle weiteren Statuswechsel: die Beobachter fuer
    /// lokale Saves laufen weiter und wuerden den Status sonst auf "Export ausstehend" ziehen,
    /// obwohl gar nichts exportiert wird.
    func markCloudSyncDisabled() {
        pendingExportWatchdog?.cancel()
        pendingExportWatchdog = nil
        runningEvents.removeAll()
        isSyncDisabled = true
        phase = .disabled
        detail = String(localized: "Nur auf diesem Gerät")
        tooltip = String(localized: "Der iCloud-Sync ist in den Einstellungen abgeschaltet. Änderungen bleiben lokal und werden nicht auf andere Geräte übertragen.")
        accountSummary = String(localized: "Sync abgeschaltet")
        remoteNotificationSummary = String(localized: "Sync abgeschaltet")
        serverProbeSummary = String(localized: "Sync abgeschaltet")
        cloudSyncLog.notice("iCloud-Sync ist per Einstellung abgeschaltet")
    }

    func markRemoteNotificationsRegistered() {
        let registered = String(localized: "Registriert")
        guard !isSyncDisabled, remoteNotificationSummary != registered else { return }
        remoteNotificationSummary = registered
        cloudSyncLog.notice("Remote Notifications registriert")
    }

    func markRemoteNotificationsUnavailable(_ error: Error) {
        guard !isSyncDisabled else { return }
        remoteNotificationSummary = String(localized: "Fehler")
        cloudSyncLog.error("Remote-Notification-Registrierung fehlgeschlagen — \(CloudSyncErrorFormatter.describe(error), privacy: .public)")
    }

    func markRemoteNotificationReceived() {
        guard !isSyncDisabled else { return }
        remoteNotificationSummary = String(localized: "Empfangen")
        cloudSyncLog.notice("Remote Notification empfangen")
    }

    /// Direkte CloudKit-Probe, unabhaengig von SwiftData-Import-Events.
    ///
    /// Das ist absichtlich keine "Force Sync"-Funktion: Core Data/SwiftData bietet dafuer keine
    /// verlaessliche oeffentliche API. Die Probe beantwortet stattdessen die wichtigere Frage,
    /// ob dieses Geraet denselben privaten CloudKit-Bestand ueberhaupt sieht.
    func checkServerReachability() async {
        guard !isSyncDisabled else { return }

        guard CloudSyncConfiguration.usesCloudKit else {
            serverProbeSummary = String(localized: "CloudKit in diesem Build abgeschaltet")
            return
        }

        isCheckingServer = true
        defer { isCheckingServer = false }

        do {
            let result = try await CloudSyncServerProbe.run()
            serverProbeSummary = result.summary
            cloudSyncLog.notice("CloudKit-Serverprobe: \(result.logSummary, privacy: .public)")
        } catch {
            let description = CloudSyncErrorFormatter.describe(error)
            serverProbeSummary = String(localized: "Fehler")
            phase = .issue
            detail = String(localized: "Serverprüfung fehlgeschlagen")
            tooltip = String(localized: "Direkte CloudKit-Prüfung: \(description)")
            cloudSyncLog.error("CloudKit-Serverprobe fehlgeschlagen — \(description, privacy: .public)")
        }
    }

    /// Fragt den iCloud-Account direkt ab, statt das Problem aus einem Core-Data-Fehler
    /// abzuleiten. Ohne angemeldeten Account startet CloudKit gar nicht — das ist die
    /// haeufigste Ursache und soll auch so dastehen.
    ///
    /// Gibt zurück, ob der Account **nachweislich** angemeldet ist. Nur dann darf `requestSync`
    /// „Nichts zu übertragen" sagen — eine gescheiterte Abfrage ist kein erreichbarer Account.
    @discardableResult
    func refreshAccountStatus() async -> Bool {
        guard !isSyncDisabled else { return false }

        guard CloudSyncConfiguration.usesCloudKit else {
            accountSummary = String(localized: "CloudKit in diesem Build abgeschaltet")
            return false
        }

        let status: CKAccountStatus
        do {
            status = try await CKContainer(identifier: CloudSyncConfiguration.containerIdentifier).accountStatus()
        } catch {
            accountSummary = String(localized: "Nicht abrufbar")
            cloudSyncLog.error("iCloud-Accountstatus nicht abrufbar — \(CloudSyncErrorFormatter.describe(error), privacy: .public)")
            return false
        }

        accountSummary = Self.summary(for: status)

        cloudSyncLog.notice("iCloud-Accountstatus: \(String(describing: status), privacy: .public)")

        switch status {
        case .available:
            if phase == .issue, detail == Self.noAccountDetail {
                phase = .ready
                detail = String(localized: "Wartet auf Änderungen")
                tooltip = String(localized: "iCloud-Account ist angemeldet.")
            }
        case .noAccount:
            phase = .issue
            detail = Self.noAccountDetail
            tooltip = String(localized: "Auf diesem Gerät ist kein iCloud-Account angemeldet. Ohne Account kann CloudKit nicht starten und nichts synchronisieren. In den Systemeinstellungen bei iCloud anmelden.")
        case .restricted:
            phase = .issue
            detail = String(localized: "iCloud eingeschränkt")
            tooltip = String(localized: "Der iCloud-Account ist eingeschränkt, etwa durch Bildschirmzeit oder eine Geräteverwaltung.")
        case .temporarilyUnavailable:
            phase = .issue
            detail = String(localized: "iCloud vorübergehend nicht verfügbar")
            tooltip = String(localized: "Der iCloud-Account ist gerade nicht verfügbar. Das legt sich meist von selbst.")
        case .couldNotDetermine:
            cloudSyncLog.error("iCloud-Accountstatus unbestimmt")
        @unknown default:
            break
        }
        return status == .available
    }

    /// Vom Nutzer angeforderter Abgleich — auf dem iPhone die Geste „nach unten ziehen".
    ///
    /// **CloudKit kennt kein „jetzt synchronisieren".** `NSPersistentCloudKitContainer` plant
    /// Im- und Export selbst; weder SwiftData noch Core Data bieten dafür eine Schnittstelle, und
    /// `CKContainer` direkt anzusprechen ginge am Mirroring vorbei. Eine Geste, die den Abgleich
    /// *erzwingt*, lässt sich also nicht bauen — eine, die ihn sichtbar macht und den häufigsten
    /// Grund für „synct nicht" findet, schon. Drei Dinge passieren wirklich:
    ///
    /// 1. Der iCloud-Accountstatus wird neu abgefragt. Das ist echte Arbeit und fängt den mit
    ///    Abstand häufigsten Fall — kein Account, abgemeldet, eingeschränkt.
    /// 2. Danach wartet die Geste kurz auf ein CloudKit-Ereignis. Läuft gerade ein Import oder
    ///    Export, sieht der Nutzer ihn zu Ende laufen statt ins Leere zu ziehen.
    /// 3. Das Ergebnis landet in derselben Anzeige wie auf Mac und iPad.
    ///
    /// Wichtig ist, was die Geste **nicht** tut: „Nichts zu übertragen" behaupten, wo in
    /// Wahrheit nur nichts gemessen wurde. Bleibt der Account unerreichbar, steht das da.
    func requestSync() async {
        guard !isSyncDisabled, CloudSyncConfiguration.usesCloudKit else {
            markCloudSyncDisabled()
            return
        }

        let eventsBefore = syncEventCount
        isShowingManualSync = true
        phase = .syncing
        detail = String(localized: "Abgleich angefordert")
        tooltip = String(localized: "Anchorit prüft den iCloud-Account und wartet auf den nächsten Abgleich.")

        let isAccountAvailable = await refreshAccountStatus()

        // Nicht endlos warten: CloudKit meldet sich oft binnen Sekundenbruchteilen, manchmal
        // gar nicht — dann lag schlicht nichts an.
        let deadline = Date().addingTimeInterval(3)
        while syncEventCount == eventsBefore, phase == .syncing, Date() < deadline {
            try? await Task.sleep(for: .milliseconds(120))
        }

        // Ein Ereignis oder ein Accountproblem hat die Anzeige schon gesetzt — dann nicht
        // darüberschreiben.
        if syncEventCount == eventsBefore, phase == .syncing {
            if isAccountAvailable {
                phase = .synced
                detail = String(localized: "Nichts zu übertragen")
                tooltip = String(localized: "Der iCloud-Account ist erreichbar, und es lag keine Änderung zum Abgleich an.")
            } else {
                phase = .issue
                detail = String(localized: "iCloud-Account nicht erreichbar")
                tooltip = String(localized: "Der iCloud-Account ließ sich nicht abfragen. Ob etwas zu übertragen ist, ist deshalb unbekannt.")
            }
        }

        // Das Ergebnis kurz stehen lassen. `refreshable` haelt seinen Ladeindikator, bis diese
        // Funktion zurueckkehrt — Indikator und Statuszeile verschwinden dadurch gemeinsam,
        // statt dass das Ergebnis im selben Moment aufblitzt und weg ist.
        try? await Task.sleep(for: .seconds(1.5))
        isShowingManualSync = false
    }

    private static let noAccountDetail = String(localized: "Kein iCloud-Account")

    private static func summary(for status: CKAccountStatus) -> String {
        switch status {
        case .available: String(localized: "Angemeldet")
        case .noAccount: String(localized: "Nicht angemeldet")
        case .restricted: String(localized: "Eingeschränkt")
        case .temporarilyUnavailable: String(localized: "Vorübergehend nicht verfügbar")
        case .couldNotDetermine: String(localized: "Unbestimmt")
        @unknown default: "Unbekannt"
        }
    }

    /// Meldet eine automatische Zusammenfuehrung doppelter Datensaetze.
    ///
    /// Summiert ueber die Sitzung statt zu ueberschreiben: mehrere Importe koennen mehrfach
    /// aufraeumen, und fuer die Beurteilung zaehlt die Gesamtzahl.
    func noteMaintenance(_ report: StoreMaintenance.MergeReport) {
        guard !report.isEmpty else { return }

        var parts = [report.summary]
        if let existing = maintenanceSummary {
            parts.insert(existing, at: 0)
        }
        if !report.affectedWeeks.isEmpty {
            parts.append("(\(report.affectedWeeks.joined(separator: ", ")))")
        }
        maintenanceSummary = parts.joined(separator: " · ")
    }

    /// Der Store laeuft ohne CloudKit weiter — sichtbar machen statt stillschweigend
    /// nur lokal zu speichern.
    func markCloudUnavailable(_ error: Error) {
        pendingExportWatchdog?.cancel()
        pendingExportWatchdog = nil
        runningEvents.removeAll()
        isCloudUnavailable = true
        phase = .issue
        detail = String(localized: "Nur lokal gespeichert")
        tooltip = String(localized: "\(CloudSyncErrorFormatter.describe(error)) — Anchorit arbeitet lokal weiter; Änderungen werden nicht synchronisiert. Prüfe, ob du in den Systemeinstellungen bei iCloud angemeldet bist.")
        cloudSyncLog.error("CloudKit-Store nicht verfuegbar — \(CloudSyncErrorFormatter.describe(error), privacy: .public)")
    }

    /// Stammt der Save aus dem Kontext der Oberflaeche — also aus einer echten Nutzeraktion?
    ///
    /// Zwei Kriterien, weil keines allein tragfaehig ist: der Name der CloudKit-Kontexte ist
    /// nicht dokumentiert und kann leer sein, deshalb zaehlt zusaetzlich die Queue. Die
    /// SwiftData-Oberflaeche speichert im Main-Queue-Kontext, CloudKit importiert in
    /// Private-Queue-Kontexten.
    nonisolated static func isUserContext(_ object: Any?) -> Bool {
        guard let context = object as? NSManagedObjectContext else { return false }

        if context.name?.hasPrefix("NSCloudKitMirroringDelegate") ?? false {
            return false
        }

        return context.concurrencyType == .mainQueueConcurrencyType
    }

    private func apply(_ update: CloudSyncEventUpdate) {
        guard !isSyncDisabled, !isCloudUnavailable else { return }

        syncEventCount += 1
        pendingExportWatchdog?.cancel()
        pendingExportWatchdog = nil
        if update.completedImport && !hasCompletedImportThisSession {
            hasCompletedImportThisSession = true
        }

        // Laufende Ereignisse als Menge: endet ein Export, während ein Import noch läuft, bleibt
        // die Phase `.syncing`. Vorher sprang sie auf „Aktuell", und das Aufräumen startete
        // mitten im Import auf einem halben Bestand.
        if update.isRunning {
            runningEvents.insert(update.identifier)
        } else {
            runningEvents.remove(update.identifier)
            guard runningEvents.isEmpty else { return }
        }
        phase = update.phase
        detail = update.detail
        tooltip = update.tooltip
    }

    private func markLocalChangeSaved() {
        guard !isSyncDisabled, !isCloudUnavailable, phase != .syncing else { return }

        phase = .pendingExport
        detail = String(localized: "Lokale Änderung gesichert")
        tooltip = String(localized: "Anchorit hat eine lokale Änderung gespeichert und wartet auf den CloudKit-Export.")
        startPendingExportWatchdog()
    }

    private func markRemoteChangeSeen() {
        // Der Zaehler laeuft auch bei abgeschaltetem Sync und waehrend `.syncing` weiter:
        // er steuert das Aufraeumen, nicht die Anzeige.
        remoteChangeCount += 1
        syncEventCount += 1

        guard !isSyncDisabled, !isCloudUnavailable, phase != .syncing else { return }

        pendingExportWatchdog?.cancel()
        pendingExportWatchdog = nil
        phase = .synced
        detail = String(localized: "Remote-Änderung empfangen")
        tooltip = String(localized: "iCloud hat eine Änderung aus einem anderen Gerät gemeldet.")
    }

    func waitForRemoteChange(after baseline: Int, timeout: Duration = .seconds(25)) async -> Bool {
        if remoteChangeCount > baseline { return true }

        let updates = AsyncStream<Int> { continuation in
            let cancellable = $remoteChangeCount.sink { value in
                continuation.yield(value)
            }
            continuation.onTermination = { _ in
                cancellable.cancel()
            }
        }

        return await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                for await value in updates where value > baseline {
                    return true
                }
                return false
            }
            group.addTask {
                try? await Task.sleep(for: timeout)
                return false
            }

            let result = await group.next() ?? false
            group.cancelAll()
            return result
        }
    }

    private func startPendingExportWatchdog() {
        pendingExportWatchdog?.cancel()
        pendingExportWatchdog = Task { [weak self] in
            // CloudKit buendelt Exporte und verzoegert sie bei schlechter Verbindung deutlich.
            // 45 Sekunden waren zu knapp und haben regelmaessig einen Fehler gemeldet,
            // wo nur gewartet wurde.
            try? await Task.sleep(for: .seconds(120))

            await MainActor.run {
                guard let self, self.phase == .pendingExport else { return }
                self.phase = .issue
                self.detail = String(localized: "Export noch ausstehend")
                self.tooltip = String(localized: "Die Änderung ist lokal gespeichert, aber CloudKit hat seit zwei Minuten keinen Export gemeldet. Das kann an fehlender Netzwerkverbindung liegen; sonst in den Systemeinstellungen die iCloud-Anmeldung prüfen.")
            }
        }
    }
}

/// Fakten, die eine Ferndiagnose braucht und die man am Gerät sonst nicht sieht.
enum CloudSyncDiagnostics {
    /// Die Umgebung folgt der Build-Konfiguration, weil `ICLOUD_CONTAINER_ENVIRONMENT` genau
    /// daran haengt: Debug auf `Development`, Release auf `Production`. Zur Laufzeit ist das
    /// Entitlement plattformuebergreifend nicht auslesbar — `SecTask` gibt es nur auf macOS.
    static var environmentName: String {
#if DEBUG
        "Development (Debug-Build)"
#else
        "Production (Release, TestFlight und App Store)"
#endif
    }

    static var containerIdentifier: String {
        CloudSyncConfiguration.containerIdentifier
    }

    /// Beantwortet die Frage "teste ich ueberhaupt den Build mit den Korrekturen?".
    static var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
}

/// Ausfuehrliche Statuszeile — genutzt im Sidebar-Fuss auf Mac und iPad.
struct CloudSyncStatusRow: View {
    @ObservedObject var status: CloudSyncStatusCenter

    var body: some View {
        HStack(spacing: AnkerSpacing.s2) {
            CloudSyncStatusIcon(phase: status.phase)

            VStack(alignment: .leading, spacing: AnkerSpacing.s1) {
                Text(status.phase.title)
                    .ankerType(AnkerType.caption)
                    .foregroundStyle(AnkerColor.ink)
                    .lineLimit(1)

                Text(status.detail)
                    .ankerType(AnkerType.caption)
                    .foregroundStyle(AnkerColor.inkSecond)
                    .lineLimit(1)

                // Nur sichtbar, wenn tatsaechlich aufgeraeumt wurde — im Normalfall
                // bleibt die Zeile weg und der Fuss so kompakt wie bisher.
                if let maintenanceSummary = status.maintenanceSummary {
                    Text(maintenanceSummary)
                        .ankerType(AnkerType.caption)
                        .foregroundStyle(AnkerColor.inkTertiary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, AnkerSpacing.s3)
        .padding(.vertical, AnkerSpacing.s2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ankerCard(fill: AnkerColor.surface.opacity(0.72), elevated: false)
        .help(status.maintenanceSummary.map { String(localized: "\(status.tooltip)\n\nAutomatisch aufgeräumt: \($0)") } ?? status.tooltip)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("iCloud: \(status.phase.title), \(status.detail)")
    }
}

/// Kompakter Indikator fuer die iPhone-Navigationsleiste. Antippen zeigt die Details —
/// auf dem iPhone gibt es keine Tooltips, und ohne die Fehlermeldung ist ein Sync-Problem
/// auf dem Geraet nicht diagnostizierbar.
struct CloudSyncStatusBadge: View {
    @ObservedObject var status: CloudSyncStatusCenter

    @State private var showsDetail = false

    var body: some View {
        Button {
            showsDetail = true
        } label: {
            CloudSyncStatusIcon(phase: status.phase)
        }
        .buttonStyle(.plain)
        .help(status.tooltip)
        .accessibilityLabel("iCloud-Status: \(status.phase.title), \(status.detail). Antippen für Details.")
        .sheet(isPresented: $showsDetail) {
            CloudSyncStatusDetail(status: status)
        }
    }
}

private struct CloudSyncStatusDetail: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var status: CloudSyncStatusCenter

    var body: some View {
        VStack(alignment: .leading, spacing: AnkerSpacing.s4) {
            HStack(spacing: AnkerSpacing.s3) {
                CloudSyncStatusIcon(phase: status.phase)

                VStack(alignment: .leading, spacing: AnkerSpacing.s1) {
                    Text(status.phase.title)
                        .ankerType(AnkerType.bodyStrong)
                        .foregroundStyle(AnkerColor.ink)
                    Text(status.detail)
                        .ankerType(AnkerType.caption)
                        .foregroundStyle(AnkerColor.inkSecond)
                }

                Spacer(minLength: 0)
            }

            Text(status.tooltip)
                .ankerType(AnkerType.body)
                .foregroundStyle(AnkerColor.ink)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AnkerSpacing.s3)
                .ankerCard(fill: AnkerColor.surface, elevated: false)

            VStack(spacing: 0) {
                diagnosticRow(String(localized: "iCloud-Account"), status.accountSummary)
                AnkerRule(color: AnkerColor.cardDivider, weight: .row)
                diagnosticRow(String(localized: "App-Version"), CloudSyncDiagnostics.appVersion)
                if let maintenanceSummary = status.maintenanceSummary {
                    AnkerRule(color: AnkerColor.cardDivider, weight: .row)
                    diagnosticRow(String(localized: "Aufgeräumt"), maintenanceSummary)
                }
            }
            .ankerCard()

            Text("Geräte gleichen sich nur ab, wenn sie mit demselben iCloud-Account angemeldet sind.")
                .ankerType(AnkerType.caption)
                .foregroundStyle(AnkerColor.inkSecond)
                .fixedSize(horizontal: false, vertical: true)

            // Für Rückfragen beim Support, nicht für den Alltag — deshalb eingeklappt.
            DisclosureGroup("Technische Details") {
                VStack(spacing: 0) {
                    diagnosticRow(String(localized: "Push"), status.remoteNotificationSummary)
                    AnkerRule(color: AnkerColor.cardDivider, weight: .row)
                    diagnosticRow(String(localized: "Server"), status.serverProbeSummary)
                    AnkerRule(color: AnkerColor.cardDivider, weight: .row)
                    // Die aussagekräftigste Zahl, wenn ein Gerät nichts vom anderen mitbekommt:
                    // Steht hier 0, während das andere Gerät exportiert, liegt das Problem beim
                    // **Import** auf diesem Gerät.
                    diagnosticRow(String(localized: "Fremdänderungen"), String(localized: "\(status.remoteChangeCount) seit Start"))
                    AnkerRule(color: AnkerColor.cardDivider, weight: .row)
                    diagnosticRow(String(localized: "Umgebung"), CloudSyncDiagnostics.environmentName)
                    AnkerRule(color: AnkerColor.cardDivider, weight: .row)
                    diagnosticRow(String(localized: "Container"), CloudSyncDiagnostics.containerIdentifier)
                }
                .ankerCard()
                .padding(.top, AnkerSpacing.s2)
            }
            .ankerType(AnkerType.caption)
            .foregroundStyle(AnkerColor.inkSecond)
            .tint(AnkerColor.inkSecond)

            Button {
                Task { await status.checkServerReachability() }
            } label: {
                Label(
                    verbatim: status.isCheckingServer ? String(localized: "Verbindung wird geprüft") : String(localized: "Verbindung zu iCloud prüfen"),
                    ankerIcon: AnkerIcon.refresh
                )
                .ankerType(AnkerType.caption)
            }
            .buttonStyle(AnkerButtonStyle.secondary)
            .disabled(status.isCheckingServer)

            Spacer(minLength: 0)

            Button("Fertig") { dismiss() }
                .ankerType(AnkerType.meta)
                .frame(maxWidth: .infinity)
        }
        .task {
            await status.refreshAccountStatus()
            await status.checkServerReachability()
        }
        .padding(AnkerSpacing.s4)
        .background(AnkerColor.ground)
#if os(iOS)
        .presentationDetents([.large])
#endif
    }

    private func diagnosticRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: AnkerSpacing.s3) {
            Text(label)
                .ankerType(AnkerType.caption)
                .foregroundStyle(AnkerColor.inkSecond)
                .frame(width: 96, alignment: .leading)

            Text(value)
                .ankerType(AnkerType.numericSmall)
                .foregroundStyle(AnkerColor.ink)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, AnkerSpacing.s3)
        .padding(.vertical, AnkerSpacing.s2)
        .accessibilityElement(children: .combine)
    }
}

private struct CloudSyncStatusIcon: View {
    let phase: CloudSyncStatusCenter.Phase

    var body: some View {
        if phase == .syncing {
            ProgressView()
                .controlSize(.small)
                .frame(width: 17, height: 17)
                .tint(phase.tint)
        } else {
            Image(phase.icon)
                .ankerIcon(AnkerIconSize.s)
                .foregroundStyle(phase.tint)
        }
    }
}

private enum CloudSyncServerProbe {
    /// Standard-Zone, die Core Data / SwiftData fuer CloudKit-Mirroring anlegt.
    private static let swiftDataZoneID = CKRecordZone.ID(
        zoneName: "com.apple.coredata.cloudkit.zone",
        ownerName: CKCurrentUserDefaultName
    )

    struct Outcome: Sendable {
        let changedRecords: Int
        let deletedRecords: Int
        let moreComing: Bool

        var summary: String {
            let total = changedRecords + deletedRecords
            if total == 0 { return String(localized: "Zone erreichbar, keine Datensätze") }

            var parts = [String(localized: "\(changedRecords) Datensätze")]
            if deletedRecords > 0 {
                parts.append(String(localized: "\(deletedRecords) Löschungen"))
            }
            if moreComing {
                parts.append(String(localized: "weitere vorhanden"))
            }
            return parts.joined(separator: ", ")
        }

        var logSummary: String {
            "Zone erreichbar, changed=\(changedRecords), deleted=\(deletedRecords), moreComing=\(moreComing)"
        }
    }

    static func run() async throws -> Outcome {
        let database = CKContainer(identifier: CloudSyncConfiguration.containerIdentifier).privateCloudDatabase

        let zones = try await database.recordZones(for: [swiftDataZoneID])
        switch zones[swiftDataZoneID] {
        case .success:
            break
        case .failure(let error):
            throw error
        case .none:
            throw CKError(.zoneNotFound)
        }

        let changes = try await database.recordZoneChanges(
            inZoneWith: swiftDataZoneID,
            since: nil,
            desiredKeys: [],
            resultsLimit: 100
        )

        var changedRecords = 0
        for result in changes.modificationResultsByID.values {
            switch result {
            case .success:
                changedRecords += 1
            case .failure(let error):
                throw error
            }
        }

        return Outcome(
            changedRecords: changedRecords,
            deletedRecords: changes.deletions.count,
            moreComing: changes.moreComing
        )
    }
}

/// Macht CloudKit-Fehler lesbar.
///
/// `localizedDescription` liefert bei `CKError` meist nur "The operation couldn't be completed"
/// — die eigentliche Information steckt im Fehlercode und bei `partialFailure` in den
/// Teilfehlern. Ohne die ist ein Sync-Problem im TestFlight-Build nicht eingrenzbar.
enum CloudSyncErrorFormatter {
    static func describe(_ error: Error, depth: Int = 0) -> String {
        var parts: [String] = []
        let nsError = error as NSError

        if let ckError = error as? CKError {
            parts.append(String(localized: "CKError \(ckError.errorCode) (\(name(for: ckError.code)))"))

            if let hint = hint(for: ckError.code) {
                parts.append(hint)
            }

            if depth < 2, let partial = ckError.partialErrorsByItemID?.values.first {
                parts.append(String(localized: "Teilfehler: \(describe(partial, depth: depth + 1))"))
            }
        } else if nsError.domain == NSCocoaErrorDomain, let name = coreDataCloudKitName(for: nsError.code) {
            // CoreData+CloudKit meldet fast alles hier statt als CKError.
            parts.append(String(localized: "Core Data \(nsError.code) (\(name))"))
        } else {
            parts.append(error.localizedDescription)
        }

        // Traegt bei CoreData+CloudKit die eigentliche Aussage, etwa
        // "Unable to initialize without an iCloud account (CKAccountStatusNoAccount)".
        if let reason = nsError.localizedFailureReason {
            parts.append(reason)
        }

        if let hint = coreDataCloudKitHint(for: nsError) {
            parts.append(hint)
        }

        if depth < 2, let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
            parts.append(String(localized: "Ursache: \(describe(underlying, depth: depth + 1))"))
        }

        if depth < 2,
           let encountered = nsError.userInfo["encounteredErrors"] as? [Error],
           let first = encountered.first {
            parts.append(String(localized: "Enthaltener Fehler: \(describe(first, depth: depth + 1))"))
        }

        return parts.joined(separator: " · ")
    }

    private static func coreDataCloudKitName(for code: Int) -> String? {
        switch code {
        case 134_400: String(localized: "CloudKit-Integration nicht möglich")
        case 134_405: String(localized: "Store nicht für CloudKit konfiguriert")
        case 134_406: String(localized: "Anfrage abgebrochen, Setup nie erfolgreich")
        case 134_410: String(localized: "Schema-Konflikt")
        case 134_422: String(localized: "Store wird bereits synchronisiert")
        case 134_060: String(localized: "Core-Data-Fehler")
        default: nil
        }
    }

    private static func coreDataCloudKitHint(for error: NSError) -> String? {
        guard error.domain == NSCocoaErrorDomain else { return nil }

        switch error.code {
        case 134_400 where error.localizedFailureReason?.contains("CKAccountStatusNoAccount") == true:
            return String(localized: "Auf diesem Gerät ist kein iCloud-Account angemeldet. Ohne Account kann CloudKit nicht starten.")
        case 134_422:
            return String(localized: "Derselbe Store wird zweimal im Prozess mit CloudKit verbunden.")
        default:
            return nil
        }
    }

    private static func name(for code: CKError.Code) -> String {
        switch code {
        case .networkUnavailable, .networkFailure: String(localized: "Netzwerk nicht erreichbar")
        case .notAuthenticated: String(localized: "Nicht bei iCloud angemeldet")
        case .permissionFailure: String(localized: "Keine Berechtigung")
        case .quotaExceeded: String(localized: "iCloud-Speicher voll")
        case .badContainer, .missingEntitlement: String(localized: "Container oder Entitlement falsch")
        case .partialFailure: String(localized: "Teilweise fehlgeschlagen")
        case .unknownItem: String(localized: "Unbekannter Datensatz")
        case .invalidArguments: String(localized: "Ungültige Anfrage")
        case .serverRejectedRequest: String(localized: "Server hat abgelehnt")
        case .zoneNotFound, .userDeletedZone: String(localized: "Zone fehlt")
        case .managedAccountRestricted: String(localized: "Verwalteter Account eingeschränkt")
        case .serviceUnavailable, .requestRateLimited: String(localized: "Dienst gerade nicht verfügbar")
        default: "\(code)"
        }
    }

    /// Die haeufigsten Ursachen benennen, statt den Nutzer mit einem Code alleinzulassen.
    private static func hint(for code: CKError.Code) -> String? {
        switch code {
        case .unknownItem, .invalidArguments, .serverRejectedRequest:
            String(localized: "Ein Teil der Änderungen wurde von iCloud abgewiesen. Anchorit versucht es später erneut; bleibt der Hinweis, bitte an den Support melden.")
        case .missingEntitlement, .badContainer:
            String(localized: "Diese App-Version kann iCloud nicht erreichen. Bitte die App aktualisieren oder den Support kontaktieren.")
        case .notAuthenticated:
            String(localized: "Auf dem Gerät bei iCloud anmelden und iCloud Drive aktivieren.")
        default:
            nil
        }
    }
}

private struct CloudSyncEventUpdate: Sendable {
    let phase: CloudSyncStatusCenter.Phase
    let detail: String
    let tooltip: String
    let completedImport: Bool
    let identifier: UUID
    let isRunning: Bool

    init(event: NSPersistentCloudKitContainer.Event) {
        identifier = event.identifier
        isRunning = event.endDate == nil
        completedImport = event.type == .import && event.endDate != nil && event.succeeded
        if event.endDate == nil {
            phase = .syncing
            detail = event.type.inProgressTitle
            tooltip = String(localized: "\(event.type.detailTitle) läuft seit \(AnkerDateFormat.clock(event.startDate)).")
            return
        }

        if event.succeeded {
            let endDate = event.endDate ?? Date()
            phase = .synced
            detail = String(localized: "Zuletzt \(AnkerDateFormat.clock(endDate))")

            // **Erfolgreich heisst nicht: alles durch.** `succeeded` sagt nur, dass die
            // Aktivitaet durchgelaufen ist — einzelne Records koennen dabei abgewiesen worden
            // sein, und dann haengt ein Fehler am Ereignis. Genau diese Lage sah bisher wie ein
            // sauberer Export aus: die Zeile „iCloud-Export erfolgreich" stand im Log, waehrend
            // die Aenderung das andere Geraet nie erreichte. Der haeufigste Grund steht in
            // `CloudSyncErrorFormatter.hint(for:)` — in Production ist das Schema
            // schreibgeschuetzt, ein dort unbekanntes Feld laesst den Record auflaufen.
            if let error = event.error {
                let description = CloudSyncErrorFormatter.describe(error)
                tooltip = String(localized: "\(event.type.detailTitle) abgeschlossen um \(AnkerDateFormat.clock(endDate)), aber nicht vollständig: \(description)")
                cloudSyncLog.warning("\(event.type.detailTitle, privacy: .public) abgeschlossen, aber mit Fehler — \(description, privacy: .public)")
            } else {
                tooltip = String(localized: "\(event.type.detailTitle) erfolgreich abgeschlossen um \(AnkerDateFormat.clock(endDate)).")
                cloudSyncLog.notice("\(event.type.detailTitle, privacy: .public) erfolgreich")
            }
        } else {
            phase = .issue
            detail = event.type.issueTitle

            if let error = event.error {
                let description = CloudSyncErrorFormatter.describe(error)
                tooltip = String(localized: "\(event.type.detailTitle): \(description)")
                cloudSyncLog.error("\(event.type.detailTitle, privacy: .public) fehlgeschlagen — \(description, privacy: .public)")
            } else {
                tooltip = String(localized: "\(event.type.detailTitle) konnte nicht abgeschlossen werden.")
                cloudSyncLog.error("\(event.type.detailTitle, privacy: .public) fehlgeschlagen ohne Fehlerobjekt")
            }
        }
    }
}

private extension NSPersistentCloudKitContainer.EventType {
    var inProgressTitle: String {
        switch self {
        case .setup:
            String(localized: "iCloud wird eingerichtet")
        case .import:
            String(localized: "Empfängt Änderungen")
        case .export:
            String(localized: "Sendet Änderungen")
        @unknown default:
            String(localized: "Synchronisiert")
        }
    }

    var detailTitle: String {
        switch self {
        case .setup:
            String(localized: "CloudKit-Setup")
        case .import:
            String(localized: "iCloud-Import")
        case .export:
            String(localized: "iCloud-Export")
        @unknown default:
            String(localized: "iCloud-Sync")
        }
    }

    var issueTitle: String {
        switch self {
        case .setup:
            String(localized: "Setup fehlgeschlagen")
        case .import:
            String(localized: "Import fehlgeschlagen")
        case .export:
            String(localized: "Export fehlgeschlagen")
        @unknown default:
            String(localized: "Sync fehlgeschlagen")
        }
    }
}
