//
//  AnchorApp.swift
//  Anchorit
//
//  Created by Marco Meisen on 31.07.26.
//

import SwiftUI
import SwiftData
import CoreData
import OSLog
import Security
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

enum CloudSyncConfiguration {
    enum SyncError: LocalizedError {
        case managedObjectModelUnavailable
        case cloudKitStoreUnavailable

        var errorDescription: String? {
            switch self {
            case .managedObjectModelUnavailable:
                "Das Datenmodell konnte nicht für CloudKit aufgebaut werden."
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
    /// iCloud-Entitlements wuerde deshalb sofort abstuerzen — der Testlauf braucht also einen
    /// signierten Host, und CloudKit bleibt dabei trotzdem aussen vor.
    ///
    /// Nicht nur über `XCTestConfigurationFilePath`: seit Xcode 26.x setzt das Testsystem diese
    /// Variable nicht mehr zuverlässig, bevor der Host startet. Der Host öffnete dann einen
    /// CloudKit-Store und brach im unsignierten Lauf ab („test runner crashed before
    /// establishing connection"). Gezählt wird jedes Zeichen der Testeinspritzung.
    static var isRunningTests: Bool {
        let environment = ProcessInfo.processInfo.environment
        if environment["XCTestConfigurationFilePath"] != nil { return true }
        if environment.keys.contains(where: { $0.hasPrefix("XCTest") || $0.hasPrefix("XCInject") }) {
            return true
        }
        if let inserted = environment["DYLD_INSERT_LIBRARIES"], inserted.contains("XCTest") {
            return true
        }
        return false
    }

    /// Trägt dieses Programm die iCloud-Berechtigung überhaupt?
    ///
    /// Ein unsignierter Build (`CODE_SIGNING_ALLOWED=NO`) hat sie nie. Ohne diese Prüfung
    /// bricht CloudKit einen solchen Start asynchron ab, außerhalb jedes `catch`. Mit ihr
    /// arbeitet er lokal und meldet das. Auf iOS startet ein Build ohne Berechtigungen gar
    /// nicht erst auf dem Gerät; dort ist die Prüfung nicht nötig.
    static var hasCloudKitEntitlement: Bool {
#if os(macOS)
        guard let task = SecTaskCreateFromSelf(nil) else { return false }
        return SecTaskCopyValueForEntitlement(task, "com.apple.developer.icloud-services" as CFString, nil) != nil
#else
        return true
#endif
    }

    /// Ist CloudKit in diesem Prozess angebunden?
    ///
    /// Wer ohne iCloud-Entitlements einen `CKContainer` anspricht oder einen CloudKit-Store
    /// oeffnet, bekommt keinen Fehler, sondern einen Abbruch aus CloudKit heraus. Jeder
    /// CloudKit-Zugriff muss deshalb hierueber abgesichert sein.
    ///
    /// Zusaetzlich zaehlt die Nutzereinstellung, und zwar in dem Stand, den sie beim Start
    /// hatte — siehe `CloudSyncPreference.activeAtLaunch`.
    @MainActor
    static var usesCloudKit: Bool {
#if DEBUG
        if UITestMode.isActive { return false }
#endif
        return !isRunningTests && hasCloudKitEntitlement && CloudSyncPreference.activeAtLaunch
    }

    @MainActor
    static func modelConfiguration(schema: Schema) -> ModelConfiguration {
        // `cloudKitDatabase` ist standardmaessig `.automatic` — ohne die explizite Angabe
        // wuerde SwiftData CloudKit selbst einschalten und im unsignierten Testhost abbrechen.
        if isRunningTests {
            return ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        }

#if DEBUG
        // UI-Tests starten immer im leeren Zustand — sonst haengt ihr Ergebnis daran, was
        // vorher im Store lag.
        if UITestMode.isActive {
            return ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        }
#endif

        // Ohne iCloud-Berechtigung (unsignierter Build) lokal arbeiten statt in CloudKit
        // abzustürzen. Ein unsignierter Mac-Build läuft ohne Sandbox und damit ohnehin in
        // einem anderen Verzeichnis als die installierte App — er berührt deren Daten nicht.
        guard CloudSyncPreference.activeAtLaunch, hasCloudKitEntitlement else {
            // Bewusst dieselbe Store-Datei wie mit Sync, nur ohne Mirroring: wer den Sync
            // abschaltet, will nicht seine Daten verlieren, sondern sie nur nicht mehr
            // uebertragen. Beim Wiedereinschalten liest CloudKit denselben Store weiter.
            return ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        }

        return ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .private(containerIdentifier)
        )
    }

    @MainActor
    static func registerForRemoteNotifications() {
        // Ohne Sync gibt es nichts zu empfangen; die Registrierung wuerde nur unnoetig
        // einen Push-Token anfordern.
        guard usesCloudKit else { return }

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
    /// Scheme > Run > Arguments > `-AnchoritInitializeCloudKitSchema` setzen.
    static let schemaInitializationArgument = "-AnchoritInitializeCloudKitSchema"

    static var shouldInitializeDevelopmentSchema: Bool {
        ProcessInfo.processInfo.arguments.contains(schemaInitializationArgument)
    }

    static func initializeDevelopmentSchema(for configuration: ModelConfiguration) throws {
        guard let managedObjectModel = NSManagedObjectModel.makeManagedObjectModel(for: AnkerSchema.models) else {
            throw SyncError.managedObjectModelUnavailable
        }

        let persistentContainer = NSPersistentCloudKitContainer(
            name: "Anchorit",
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

        // Muss ein `defer` sein: schlaegt `initializeCloudKitSchema` fehl — etwa ohne
        // iCloud-Account —, bleibt dieser Container sonst geladen und behaelt seinen
        // Mirroring-Delegate. SwiftData oeffnet danach denselben Store ein zweites Mal und
        // CloudKit bricht mit 134422 ab ("another instance of this persistent store
        // actively syncing with CloudKit in this process").
        defer {
            let coordinator = persistentContainer.persistentStoreCoordinator
            for store in coordinator.persistentStores {
                try? coordinator.remove(store)
            }
        }

        try persistentContainer.initializeCloudKitSchema(options: [])
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

    @MainActor
    static func make() -> AnkerStore {
#if DEBUG
        // Vor allem anderen: setzt die gespeicherten Einstellungen zurueck.
        UITestMode.prepare()
#endif

        // Vor dem Container, sonst entstehen die CloudKit-Beobachter erst, wenn eine View den
        // Status anfasst — `setup` und der erste Import sind dann schon durchgelaufen.
        CloudSyncStatusCenter.startObserving()

        let schema = Schema(AnkerSchema.models)
        let cloudConfiguration = CloudSyncConfiguration.modelConfiguration(schema: schema)
        cloudSyncLog.notice("Store-Konfiguration: CloudKit=\(CloudSyncConfiguration.usesCloudKit, privacy: .public)")

#if DEBUG
        // Nie im Testlauf und nie ohne iCloud-Berechtigung: die Initialisierung öffnet einen
        // echten CloudKit-Container, und der bricht einen unsignierten Prozess ab.
        if CloudSyncConfiguration.shouldInitializeDevelopmentSchema && CloudSyncConfiguration.usesCloudKit {
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
#if DEBUG
            // Nur im UI-Testmodus — dort ist der Store im Speicher, es geht nichts in iCloud.
            if UITestMode.isActive && ProcessInfo.processInfo.arguments.contains(UITestMode.demoDataArgument) {
                SampleData.insertDemoWeek(in: container.mainContext)
            }
#endif
            return AnkerStore(container: container, cloudKitError: nil)
        } catch {
            print("CloudKit store unavailable, falling back to local store: \(error)")
        }

        do {
            // `.none` ist hier wesentlich: ohne die Angabe gilt `.automatic` und SwiftData
            // wuerde CloudKit erneut anbinden — der "lokale" Fallback waere keiner.
            let localConfiguration = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [localConfiguration])
            return AnkerStore(container: container, cloudKitError: CloudSyncConfiguration.SyncError.cloudKitStoreUnavailable)
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }
}

@main
@MainActor
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

                    if !CloudSyncPreference.activeAtLaunch {
                        CloudSyncStatusCenter.shared.markCloudSyncDisabled()
                    } else if let cloudKitError = store.cloudKitError {
                        CloudSyncStatusCenter.shared.markCloudUnavailable(cloudKitError)
                    } else {
                        CloudSyncStatusCenter.shared.markReady()
                    }
                }
                .task {
                    await CloudSyncStatusCenter.shared.refreshAccountStatus()
                }
#if os(macOS)
                .onAppear {
                    appDelegate.configure(modelContainer: sharedModelContainer)
                }
#endif
        }
        .modelContainer(sharedModelContainer)
#if os(macOS)
        // „Blatt" zeichnet seinen eigenen Fensterkopf; die Ampelknöpfe liegen darüber.
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1280, height: 820)
        // Die Mindestgröße kommt aus dem Inhalt — Seitenleiste plus lesbares Raster.
        .windowResizability(.contentMinSize)
#endif

#if os(macOS)
        // Eigenes Fenster ueber Command-Komma, wie auf dem Mac erwartet.
        Settings {
            SettingsView(showsDoneButton: false)
                .frame(width: 460, height: 560)
        }
        .modelContainer(sharedModelContainer)
#endif
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
            if let image = NSImage(named: "MenuBarTemplate") {
                image.size = NSSize(width: 18, height: 18)
                image.isTemplate = true
                image.accessibilityDescription = "Anchorit"
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
