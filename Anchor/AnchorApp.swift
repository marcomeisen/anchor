//
//  AnchorApp.swift
//  Anchor
//
//  Created by Marco Meisen on 31.07.26.
//

import SwiftUI
import SwiftData
#if os(macOS)
import AppKit
#endif

private enum CloudSyncConfiguration {
    static let containerIdentifier = "iCloud.com.marcomeisen.Anchor"
}

@main
struct AnchorApp: App {
#if os(macOS)
    @NSApplicationDelegateAdaptor(AnchorAppDelegate.self) private var appDelegate
#endif

    var sharedModelContainer: ModelContainer = {
        let schema = Schema(AnkerSchema.models)
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .private(CloudSyncConfiguration.containerIdentifier)
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
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
            if let image = NSImage(systemSymbolName: "anchor", accessibilityDescription: "Anker") {
                button.image = image
                button.imagePosition = .imageOnly
            } else {
                button.title = "A"
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
