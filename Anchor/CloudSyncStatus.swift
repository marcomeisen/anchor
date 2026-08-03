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
        _ = shared
        cloudSyncLog.notice("CloudSync-Beobachter registriert")
    }

    enum Phase: Sendable {
        case starting
        case ready
        case pendingExport
        case syncing
        case synced
        case issue

        var title: String {
            switch self {
            case .starting:
                "iCloud startet"
            case .ready:
                "iCloud bereit"
            case .pendingExport:
                "Export ausstehend"
            case .syncing:
                "Synchronisiert"
            case .synced:
                "Aktuell"
            case .issue:
                "Sync pruefen"
            }
        }

        var symbolName: String {
            switch self {
            case .starting, .ready:
                "icloud"
            case .pendingExport:
                "icloud.and.arrow.up"
            case .syncing:
                "arrow.triangle.2.circlepath"
            case .synced:
                "icloud.fill"
            case .issue:
                "icloud.slash"
            }
        }

        var tint: Color {
            switch self {
            case .starting, .ready:
                AnkerColor.muted
            case .pendingExport:
                AnkerColor.brass
            case .syncing:
                AnkerColor.indigoText
            case .synced:
                AnkerColor.success
            case .issue:
                AnkerColor.brass
            }
        }
    }

    @Published private(set) var phase: Phase = .starting
    @Published private(set) var detail = "CloudKit wird vorbereitet"
    @Published private(set) var tooltip = "Daivento verbindet sich mit iCloud."

    /// Getrennt vom `phase`-Text, damit die Diagnose den Accountzustand auch dann zeigt,
    /// wenn der Status gerade einen Import oder Export meldet.
    @Published private(set) var accountSummary = "Wird geprüft"

    private var observers: [NSObjectProtocol] = []
    private var pendingExportWatchdog: Task<Void, Never>?

    private init() {
        let cloudKitObserver = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey] as? NSPersistentCloudKitContainer.Event else {
                return
            }

            let update = CloudSyncEventUpdate(event: event)
            Task { @MainActor in
                CloudSyncStatusCenter.shared.apply(update)
            }
        }

        let localSaveObserver = NotificationCenter.default.addObserver(
            forName: NSManagedObjectContext.didSaveObjectsNotification,
            object: nil,
            queue: .main
        ) { notification in
            // CloudKit speichert seine Importe in eigenen Kontexten. Ohne diesen Filter
            // gilt jeder empfangene Datensatz als neue lokale Aenderung, der Status faellt
            // auf "Export ausstehend" zurueck und der Watchdog meldet faelschlich ein Problem.
            guard CloudSyncStatusCenter.isUserContext(notification.object) else { return }

            Task { @MainActor in
                CloudSyncStatusCenter.shared.markLocalChangeSaved()
            }
        }

        let remoteChangeObserver = NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                CloudSyncStatusCenter.shared.markRemoteChangeSeen()
            }
        }

        // Meldet sich, wenn der Nutzer sich bei iCloud an- oder abmeldet.
        let accountObserver = NotificationCenter.default.addObserver(
            forName: .CKAccountChanged,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                await CloudSyncStatusCenter.shared.refreshAccountStatus()
            }
        }

        observers = [cloudKitObserver, localSaveObserver, remoteChangeObserver, accountObserver]
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
        detail = "Wartet auf Änderungen"
        tooltip = "iCloud ist eingerichtet. Sobald CloudKit Import oder Export meldet, wird der Status hier aktualisiert."
    }

    /// Fragt den iCloud-Account direkt ab, statt das Problem aus einem Core-Data-Fehler
    /// abzuleiten. Ohne angemeldeten Account startet CloudKit gar nicht — das ist die
    /// haeufigste Ursache und soll auch so dastehen.
    func refreshAccountStatus() async {
        guard CloudSyncConfiguration.usesCloudKit else {
            accountSummary = "CloudKit in diesem Build abgeschaltet"
            return
        }

        let status: CKAccountStatus
        do {
            status = try await CKContainer(identifier: CloudSyncConfiguration.containerIdentifier).accountStatus()
        } catch {
            accountSummary = "Nicht abrufbar"
            cloudSyncLog.error("iCloud-Accountstatus nicht abrufbar — \(CloudSyncErrorFormatter.describe(error), privacy: .public)")
            return
        }

        accountSummary = Self.summary(for: status)

        cloudSyncLog.notice("iCloud-Accountstatus: \(String(describing: status), privacy: .public)")

        switch status {
        case .available:
            if phase == .issue, detail == Self.noAccountDetail {
                phase = .ready
                detail = "Wartet auf Änderungen"
                tooltip = "iCloud-Account ist angemeldet."
            }
        case .noAccount:
            phase = .issue
            detail = Self.noAccountDetail
            tooltip = "Auf diesem Gerät ist kein iCloud-Account angemeldet. Ohne Account kann CloudKit nicht starten und nichts synchronisieren. In den Systemeinstellungen bei iCloud anmelden."
        case .restricted:
            phase = .issue
            detail = "iCloud eingeschränkt"
            tooltip = "Der iCloud-Account ist eingeschränkt, etwa durch Bildschirmzeit oder eine Geräteverwaltung."
        case .temporarilyUnavailable:
            phase = .issue
            detail = "iCloud vorübergehend nicht verfügbar"
            tooltip = "Der iCloud-Account ist gerade nicht verfügbar. Das legt sich meist von selbst."
        case .couldNotDetermine:
            cloudSyncLog.error("iCloud-Accountstatus unbestimmt")
        @unknown default:
            break
        }
    }

    private static let noAccountDetail = "Kein iCloud-Account"

    private static func summary(for status: CKAccountStatus) -> String {
        switch status {
        case .available: "Angemeldet"
        case .noAccount: "Nicht angemeldet"
        case .restricted: "Eingeschränkt"
        case .temporarilyUnavailable: "Vorübergehend nicht verfügbar"
        case .couldNotDetermine: "Unbestimmt"
        @unknown default: "Unbekannt"
        }
    }

    /// Der Store laeuft ohne CloudKit weiter — sichtbar machen statt stillschweigend
    /// nur lokal zu speichern.
    func markCloudUnavailable(_ error: Error) {
        pendingExportWatchdog?.cancel()
        pendingExportWatchdog = nil
        phase = .issue
        detail = "Nur lokal gespeichert"
        tooltip = "\(CloudSyncErrorFormatter.describe(error)) — Daivento arbeitet lokal weiter; Änderungen werden nicht synchronisiert. Prüfe iCloud-Account, Entitlements und Provisioning."
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
        pendingExportWatchdog?.cancel()
        pendingExportWatchdog = nil
        phase = update.phase
        detail = update.detail
        tooltip = update.tooltip
    }

    private func markLocalChangeSaved() {
        guard phase != .syncing else { return }

        phase = .pendingExport
        detail = "Lokale Änderung gesichert"
        tooltip = "Daivento hat eine lokale Änderung gespeichert und wartet auf den CloudKit-Export."
        startPendingExportWatchdog()
    }

    private func markRemoteChangeSeen() {
        guard phase != .syncing else { return }

        pendingExportWatchdog?.cancel()
        pendingExportWatchdog = nil
        phase = .synced
        detail = "Remote-Änderung empfangen"
        tooltip = "iCloud hat eine Änderung aus einem anderen Gerät gemeldet."
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
                self.detail = "Export noch ausstehend"
                self.tooltip = "Die Änderung ist lokal gespeichert, aber CloudKit hat seit zwei Minuten keinen Export gemeldet. Das kann an fehlender Netzwerkverbindung liegen; sonst iCloud-Account, Provisioning und die CloudKit-Konsole prüfen."
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
        HStack(spacing: 8) {
            CloudSyncStatusIcon(phase: status.phase)

            VStack(alignment: .leading, spacing: 1) {
                Text(status.phase.title)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(AnkerColor.ink)
                    .lineLimit(1)

                Text(status.detail)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(AnkerColor.muted)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AnkerColor.card.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AnkerColor.line)
        )
        .help(status.tooltip)
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
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                CloudSyncStatusIcon(phase: status.phase)

                VStack(alignment: .leading, spacing: 2) {
                    Text(status.phase.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AnkerColor.ink)
                    Text(status.detail)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AnkerColor.muted)
                }

                Spacer(minLength: 0)
            }

            Text(status.tooltip)
                .font(.system(size: 12.5))
                .foregroundStyle(AnkerColor.ink)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(AnkerColor.card)
                .overlay(RoundedRectangle(cornerRadius: AnkerRadius.card).stroke(AnkerColor.line, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: AnkerRadius.card))

            VStack(spacing: 0) {
                diagnosticRow("iCloud-Account", status.accountSummary)
                Divider()
                diagnosticRow("Umgebung", CloudSyncDiagnostics.environmentName)
                Divider()
                diagnosticRow("Container", CloudSyncDiagnostics.containerIdentifier)
                Divider()
                diagnosticRow("App-Version", CloudSyncDiagnostics.appVersion)
            }
            .background(AnkerColor.card)
            .overlay(RoundedRectangle(cornerRadius: AnkerRadius.card).stroke(AnkerColor.line, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: AnkerRadius.card))

            Text("Geräte synchronisieren nur bei gleichem iCloud-Account und gleicher Umgebung. Development und Production sind getrennte Datenbestände.")
                .font(.system(size: 11.5))
                .foregroundStyle(AnkerColor.muted)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            Button("Fertig") { dismiss() }
                .font(.system(size: 13, weight: .semibold))
                .frame(maxWidth: .infinity)
        }
        .task {
            await status.refreshAccountStatus()
        }
        .padding(18)
        .background(AnkerColor.paper)
#if os(iOS)
        .presentationDetents([.large])
#endif
    }

    private func diagnosticRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AnkerColor.muted)
                .frame(width: 96, alignment: .leading)

            Text(value)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(AnkerColor.ink)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
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
            Image(systemName: phase.symbolName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(phase.tint)
                .frame(width: 17, height: 17)
        }
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
            parts.append("CKError \(ckError.errorCode) (\(name(for: ckError.code)))")

            if let hint = hint(for: ckError.code) {
                parts.append(hint)
            }

            if depth < 2, let partial = ckError.partialErrorsByItemID?.values.first {
                parts.append("Teilfehler: \(describe(partial, depth: depth + 1))")
            }
        } else if nsError.domain == NSCocoaErrorDomain, let name = coreDataCloudKitName(for: nsError.code) {
            // CoreData+CloudKit meldet fast alles hier statt als CKError.
            parts.append("Core Data \(nsError.code) (\(name))")
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
            parts.append("Ursache: \(describe(underlying, depth: depth + 1))")
        }

        if depth < 2,
           let encountered = nsError.userInfo["encounteredErrors"] as? [Error],
           let first = encountered.first {
            parts.append("Enthaltener Fehler: \(describe(first, depth: depth + 1))")
        }

        return parts.joined(separator: " · ")
    }

    private static func coreDataCloudKitName(for code: Int) -> String? {
        switch code {
        case 134_400: "CloudKit-Integration nicht moeglich"
        case 134_405: "Store nicht fuer CloudKit konfiguriert"
        case 134_406: "Anfrage abgebrochen, Setup nie erfolgreich"
        case 134_410: "Schema-Konflikt"
        case 134_422: "Store wird bereits synchronisiert"
        case 134_060: "Core-Data-Fehler"
        default: nil
        }
    }

    private static func coreDataCloudKitHint(for error: NSError) -> String? {
        guard error.domain == NSCocoaErrorDomain else { return nil }

        switch error.code {
        case 134_400 where error.localizedFailureReason?.contains("CKAccountStatusNoAccount") == true:
            return "Auf diesem Geraet ist kein iCloud-Account angemeldet. Ohne Account kann CloudKit nicht starten."
        case 134_422:
            return "Derselbe Store wird zweimal im Prozess mit CloudKit verbunden."
        default:
            return nil
        }
    }

    private static func name(for code: CKError.Code) -> String {
        switch code {
        case .networkUnavailable, .networkFailure: "Netzwerk nicht erreichbar"
        case .notAuthenticated: "Nicht bei iCloud angemeldet"
        case .permissionFailure: "Keine Berechtigung"
        case .quotaExceeded: "iCloud-Speicher voll"
        case .badContainer, .missingEntitlement: "Container oder Entitlement falsch"
        case .partialFailure: "Teilweise fehlgeschlagen"
        case .unknownItem: "Unbekannter Datensatz"
        case .invalidArguments: "Ungueltige Anfrage"
        case .serverRejectedRequest: "Server hat abgelehnt"
        case .zoneNotFound, .userDeletedZone: "Zone fehlt"
        case .managedAccountRestricted: "Verwalteter Account eingeschraenkt"
        case .serviceUnavailable, .requestRateLimited: "Dienst gerade nicht verfuegbar"
        default: "\(code)"
        }
    }

    /// Die haeufigsten Ursachen benennen, statt den Nutzer mit einem Code alleinzulassen.
    private static func hint(for code: CKError.Code) -> String? {
        switch code {
        case .unknownItem, .invalidArguments, .serverRejectedRequest:
            "Haeufigste Ursache in TestFlight: Das Schema ist nur in Development vorhanden. In der CloudKit-Konsole nach Production deployen."
        case .missingEntitlement, .badContainer:
            "Container-Identifier oder iCloud-Entitlements pruefen."
        case .notAuthenticated:
            "Auf dem Geraet bei iCloud anmelden und iCloud Drive aktivieren."
        default:
            nil
        }
    }
}

private struct CloudSyncEventUpdate: Sendable {
    let phase: CloudSyncStatusCenter.Phase
    let detail: String
    let tooltip: String

    init(event: NSPersistentCloudKitContainer.Event) {
        if event.endDate == nil {
            phase = .syncing
            detail = event.type.inProgressTitle
            tooltip = "\(event.type.detailTitle) laeuft seit \(event.startDate.formatted(.dateTime.hour().minute()))."
            return
        }

        if event.succeeded {
            let endDate = event.endDate ?? Date()
            phase = .synced
            detail = "Zuletzt \(endDate.formatted(.dateTime.hour().minute()))"
            tooltip = "\(event.type.detailTitle) erfolgreich abgeschlossen um \(endDate.formatted(.dateTime.hour().minute()))."
            cloudSyncLog.notice("\(event.type.detailTitle, privacy: .public) erfolgreich")
        } else {
            phase = .issue
            detail = event.type.issueTitle

            if let error = event.error {
                let description = CloudSyncErrorFormatter.describe(error)
                tooltip = "\(event.type.detailTitle): \(description)"
                cloudSyncLog.error("\(event.type.detailTitle, privacy: .public) fehlgeschlagen — \(description, privacy: .public)")
            } else {
                tooltip = "\(event.type.detailTitle) konnte nicht abgeschlossen werden."
                cloudSyncLog.error("\(event.type.detailTitle, privacy: .public) fehlgeschlagen ohne Fehlerobjekt")
            }
        }
    }
}

private extension NSPersistentCloudKitContainer.EventType {
    var inProgressTitle: String {
        switch self {
        case .setup:
            "iCloud wird eingerichtet"
        case .import:
            "Empfaengt Aenderungen"
        case .export:
            "Sendet Aenderungen"
        @unknown default:
            "Synchronisiert"
        }
    }

    var detailTitle: String {
        switch self {
        case .setup:
            "CloudKit-Setup"
        case .import:
            "iCloud-Import"
        case .export:
            "iCloud-Export"
        @unknown default:
            "iCloud-Sync"
        }
    }

    var issueTitle: String {
        switch self {
        case .setup:
            "Setup fehlgeschlagen"
        case .import:
            "Import fehlgeschlagen"
        case .export:
            "Export fehlgeschlagen"
        @unknown default:
            "Sync fehlgeschlagen"
        }
    }
}
