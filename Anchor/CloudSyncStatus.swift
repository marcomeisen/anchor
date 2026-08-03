import Combine
import CoreData
import Foundation
import SwiftUI

@MainActor
final class CloudSyncStatusCenter: ObservableObject {
    static let shared = CloudSyncStatusCenter()

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
            guard !CloudSyncStatusCenter.isMirroringContext(notification.object) else { return }

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

        observers = [cloudKitObserver, localSaveObserver, remoteChangeObserver]
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

    /// Der Store laeuft ohne CloudKit weiter — sichtbar machen statt stillschweigend
    /// nur lokal zu speichern.
    func markCloudUnavailable(_ error: Error) {
        pendingExportWatchdog?.cancel()
        pendingExportWatchdog = nil
        phase = .issue
        detail = "Nur lokal gespeichert"
        tooltip = "\(error.localizedDescription) Daivento arbeitet lokal weiter; Änderungen werden nicht synchronisiert. Prüfe iCloud-Account, Entitlements und Provisioning."
    }

    nonisolated static func isMirroringContext(_ object: Any?) -> Bool {
        guard let context = object as? NSManagedObjectContext else { return false }
        return context.name?.hasPrefix("NSCloudKitMirroringDelegate") ?? false
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
        } else {
            phase = .issue
            detail = event.type.issueTitle
            tooltip = event.error?.localizedDescription ?? "\(event.type.detailTitle) konnte nicht abgeschlossen werden."
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
