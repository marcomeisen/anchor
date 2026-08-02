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
        case syncing
        case synced
        case issue

        var title: String {
            switch self {
            case .starting:
                "iCloud startet"
            case .ready:
                "iCloud bereit"
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
    @Published private(set) var tooltip = "Fyndara verbindet sich mit iCloud."

    private var observer: NSObjectProtocol?

    private init() {
        observer = NotificationCenter.default.addObserver(
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
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func markReady() {
        guard phase == .starting else { return }
        phase = .ready
        detail = "Wartet auf Aenderungen"
        tooltip = "iCloud ist eingerichtet. Sobald CloudKit Import oder Export meldet, wird der Status hier aktualisiert."
    }

    private func apply(_ update: CloudSyncEventUpdate) {
        phase = update.phase
        detail = update.detail
        tooltip = update.tooltip
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
