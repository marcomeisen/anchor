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
    enum SyncError: Error {
        case managedObjectModelUnavailable
    }

    static let containerIdentifier = "iCloud.com.marcomeisen.Anchor"

    static func modelConfiguration(schema: Schema) -> ModelConfiguration {
        ModelConfiguration(
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
    }
#endif
}

@main
struct AnchorApp: App {
#if os(macOS)
    @NSApplicationDelegateAdaptor(AnchorAppDelegate.self) private var appDelegate
#endif

    var sharedModelContainer: ModelContainer = {
        let schema = Schema(AnkerSchema.models)
        let modelConfiguration = CloudSyncConfiguration.modelConfiguration(schema: schema)

#if DEBUG
        do {
            try CloudSyncConfiguration.initializeDevelopmentSchema(for: modelConfiguration)
        } catch {
            print("CloudKit schema initialization skipped: \(error)")
        }
#endif

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    CloudSyncConfiguration.registerForRemoteNotifications()
                    CloudSyncStatusCenter.shared.markReady()
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
