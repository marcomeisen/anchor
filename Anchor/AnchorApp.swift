//
//  AnchorApp.swift
//  Daivento
//
//  Created by Marco Meisen on 31.07.26.
//

import SwiftUI
import SwiftData
import CoreData
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

private enum CloudSyncConfiguration {
    enum SyncError: LocalizedError {
        case managedObjectModelUnavailable
        case cloudKitStoreUnavailable

        var errorDescription: String? {
            switch self {
            case .managedObjectModelUnavailable:
                "Das Datenmodell konnte nicht fuer CloudKit aufgebaut werden."
            case .cloudKitStoreUnavailable:
                "Der iCloud-Container konnte nicht geoeffnet werden."
            }
        }
    }

    static let containerIdentifier = "iCloud.com.marcomeisen.Anchor"

    /// Im Testlauf ohne CloudKit starten.
    ///
    /// Unit-Tests arbeiten mit eigenen In-Memory-Containern und brauchen keinen Sync. Wichtiger:
    /// CloudKit richtet sich nach `ModelContainer.init` asynchron auf einem Hintergrund-Queue
    /// ein und bricht den Prozess ab, wenn der Container nicht in den Entitlements steht —
    /// das ist per `do`/`catch` nicht abfangbar. Ein Testhost ohne Signatur bzw. ohne
    /// iCloud-Entitlements wuerde deshalb sofort abstuerzen.
    static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    static func modelConfiguration(schema: Schema) -> ModelConfiguration {
        guard !isRunningTests else {
            return ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        }

        return ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .private(containerIdentifier)
        )
    }

    @MainActor
    static func registerForRemoteNotifications() {
#if os(macOS)
        NSApplication.shared.registerForRemoteNotifications()
#elseif os(iOS)
        UIApplication.shared.registerForRemoteNotifications()
#endif
    }

#if DEBUG
    /// Das CloudKit-Entwicklungsschema muss nur nach Modelaenderungen einmal hochgeladen werden.
    /// Bei jedem Start ausgefuehrt legt `initializeCloudKitSchema` fuer jede Entity Beispielrecords
    /// an und wieder loescht sie, blockiert den Start und oeffnet einen zweiten CloudKit-Container
    /// auf derselben Store-Datei. Deshalb laeuft es nur noch auf Anforderung:
    /// Scheme > Run > Arguments > `-DaiventoInitializeCloudKitSchema` setzen.
    static let schemaInitializationArgument = "-DaiventoInitializeCloudKitSchema"

    static var shouldInitializeDevelopmentSchema: Bool {
        ProcessInfo.processInfo.arguments.contains(schemaInitializationArgument)
    }

    static func initializeDevelopmentSchema(for configuration: ModelConfiguration) throws {
        guard let managedObjectModel = NSManagedObjectModel.makeManagedObjectModel(for: AnkerSchema.models) else {
            throw SyncError.managedObjectModelUnavailable
        }

        let persistentContainer = NSPersistentCloudKitContainer(
            name: "Daivento",
            managedObjectModel: managedObjectModel
        )

        let storeDescription = NSPersistentStoreDescription(url: configuration.url)
        storeDescription.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
            containerIdentifier: containerIdentifier
        )
        storeDescription.shouldAddStoreAsynchronously = false
        storeDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        storeDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        persistentContainer.persistentStoreDescriptions = [storeDescription]

        var storeLoadError: Error?
        persistentContainer.loadPersistentStores { _, error in
            storeLoadError = error
        }

        if let storeLoadError {
            throw storeLoadError
        }

        try persistentContainer.initializeCloudKitSchema(options: [])

        // Store wieder freigeben, damit SwiftData die Datei danach exklusiv oeffnet.
        // Zwei Coordinators auf derselben SQLite-Datei koennen sich sonst gegenseitig blockieren.
        let coordinator = persistentContainer.persistentStoreCoordinator
        for store in coordinator.persistentStores {
            try coordinator.remove(store)
        }
    }
#endif
}

/// Der SwiftData-Store samt Information, ob CloudKit angebunden werden konnte.
///
/// Vorher endete jeder Fehler beim Oeffnen des Stores in `fatalError` — die App startete dann
/// gar nicht mehr. Das trifft realistisch beim Umstellen der CloudKit-Konfiguration waehrend
/// der Entwicklung zu, weil die vorhandene Store-Datei dann inkompatible Metadaten hat.
/// Stattdessen wird derselbe Store ohne CloudKit geoeffnet (gleiche Datei, kein Datenverlust)
/// und der Zustand in der Sync-Anzeige sichtbar gemacht.
///
/// Nicht abgedeckt: fehlende iCloud-Entitlements. CloudKit trappt in diesem Fall erst spaeter
/// asynchron im eigenen Setup, ausserhalb jedes `catch`.
struct AnkerStore {
    let container: ModelContainer
    let cloudKitError: Error?

    static func make() -> AnkerStore {
        let schema = Schema(AnkerSchema.models)
        let cloudConfiguration = CloudSyncConfiguration.modelConfiguration(schema: schema)

#if DEBUG
        if CloudSyncConfiguration.shouldInitializeDevelopmentSchema {
            do {
                try CloudSyncConfiguration.initializeDevelopmentSchema(for: cloudConfiguration)
                print("CloudKit schema initialized.")
            } catch {
                print("CloudKit schema initialization failed: \(error)")
            }
        }
#endif

        do {
            let container = try ModelContainer(for: schema, configurations: [cloudConfiguration])
            return AnkerStore(container: container, cloudKitError: nil)
        } catch {
            print("CloudKit store unavailable, falling back to local store: \(error)")
        }

        do {
            let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema)])
            return AnkerStore(container: container, cloudKitError: CloudSyncConfiguration.SyncError.cloudKitStoreUnavailable)
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }
}

@main
struct AnchorApp: App {
#if os(macOS)
    @NSApplicationDelegateAdaptor(AnchorAppDelegate.self) private var appDelegate
#endif

    private let store = AnkerStore.make()

    private var sharedModelContainer: ModelContainer { store.container }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    CloudSyncConfiguration.registerForRemoteNotifications()

                    if let cloudKitError = store.cloudKitError {
                        CloudSyncStatusCenter.shared.markCloudUnavailable(cloudKitError)
                    } else {
                        CloudSyncStatusCenter.shared.markReady()
                    }
                }
#if os(macOS)
                .onAppear {
                    appDelegate.configure(modelContainer: sharedModelContainer)
                }
#endif
        }
        .modelContainer(sharedModelContainer)
    }
}

#if os(macOS)
@MainActor
final class AnchorAppDelegate: NSObject, NSApplicationDelegate {
    private var statusItemController: AnchorStatusItemController?

    func configure(modelContainer: ModelContainer) {
        guard statusItemController == nil else { return }
        statusItemController = AnchorStatusItemController(modelContainer: modelContainer)
    }
}

@MainActor
private final class AnchorStatusItemController: NSObject {
    private let statusItem: NSStatusItem
    private let popover: NSPopover

    init(modelContainer: ModelContainer) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        popover = NSPopover()
        super.init()

        if let button = statusItem.button {
            if let image = NSImage(named: "FokusringBMenu") {
                image.size = NSSize(width: 18, height: 18)
                image.isTemplate = true
                image.accessibilityDescription = "Daivento"
                button.image = image
                button.imagePosition = .imageOnly
            } else {
                button.title = "F"
            }
            button.action = #selector(togglePopover(_:))
            button.target = self
        }

        let rootView = QuickCapturePopover()
            .modelContainer(modelContainer)
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 300, height: 252)
        popover.contentViewController = NSHostingController(rootView: rootView)
    }

    @objc
    private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
#endif

enum AnkerSchema {
    static let models: [any PersistentModel.Type] = [
        Goal.self,
        Week.self,
        Day.self,
        AnkerTask.self,
        TimeBlock.self
    ]
}

enum SampleDataPreview {
    @MainActor
    static var week: Week {
        let container = PreviewContainer.shared
        let descriptor = FetchDescriptor<Week>()
        return (try? container.mainContext.fetch(descriptor).first) ?? SampleData.insertReferenceWeek(in: container.mainContext)
    }
}
