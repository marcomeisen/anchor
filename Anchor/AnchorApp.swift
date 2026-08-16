//
//  AnchorApp.swift
//  Daivento
//
//  Created by Marco Meisen on 31.07.26.
//

import SwiftUI
import SwiftData
import CoreData
import OSLog
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
    static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
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
        return !isRunningTests && CloudSyncPreference.activeAtLaunch
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

        guard CloudSyncPreference.activeAtLaunch else {
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
    /// Das CloudKit-Entwicklungsschema muss nach **jeder** Modelaenderung einmal hochgeladen
    /// werden, sonst fehlen die neuen Felder. Der normale Export legt sie nicht zwangslaeufig an:
    /// CloudKit erzeugt ein Feld erst, wenn ein Record mit einem Wert darin exportiert wird —
    /// ein durchgehend `nil` gebliebener Optional bleibt dem Schema deshalb unbekannt.
    ///
    /// Bei jedem Start ausgefuehrt legt `initializeCloudKitSchema` fuer jede Entity Beispielrecords
    /// an und wieder loescht sie und blockiert dabei den Start. Deshalb laeuft es nur noch auf
    /// Anforderung: Scheme > Run > Arguments > `-DaiventoInitializeCloudKitSchema` setzen.
    static let schemaInitializationArgument = "-DaiventoInitializeCloudKitSchema"

    static var shouldInitializeDevelopmentSchema: Bool {
        ProcessInfo.processInfo.arguments.contains(schemaInitializationArgument)
    }

    /// Startet den Schema-Upload **nach** dem Start und abseits des Main-Threads.
    ///
    /// Inline in `App.init` aufgerufen scheiterte er reproduzierbar nach rund 130 Sekunden mit
    /// "Failed to initialize CloudKit schema because the requests timed out (a 30s wait failed)":
    /// `initializeCloudKitSchema` wartet synchron auf den Setup-Request des Mirroring-Delegate,
    /// und der kommt nicht durch, solange der Main-Thread in `App.init` blockiert und die
    /// Runloop noch gar nicht laeuft. Der Aufruf wartete also auf etwas, das er selbst aufhielt —
    /// erkennbar daran, dass der regulaere Container eine Sekunde spaeter anstandslos hochkam.
    static func scheduleDevelopmentSchemaUpload(storeURL: URL) {
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 3) {
            do {
                try initializeDevelopmentSchema(storeURL: storeURL)
                cloudSyncLog.notice("CloudKit-Schema hochgeladen")
                print("CloudKit schema initialized.")
            } catch {
                // `localizedDescription` ist bei Core-Data-CloudKit-Fehlern nichtssagend
                // ("Ein Core Data-Fehler ist aufgetreten"); die Aussage steckt in
                // `NSLocalizedFailureReason` und `encounteredErrors`.
                let detail = CloudSyncErrorFormatter.describe(error)
                cloudSyncLog.error("CloudKit-Schema fehlgeschlagen: \(detail, privacy: .public)")
                print("CloudKit schema initialization failed: \(error)")
            }
        }
    }

    /// Laeuft bewusst gegen die **echte** Store-Datei.
    ///
    /// Ein leerer Wegwerf-Store waere naheliegend — das Schema kommt schliesslich aus dem
    /// Managed Object Model, nicht aus den Daten. Er ist aber schaedlich: der Mirroring-Delegate
    /// startet darauf einen vollstaendigen Import der bestehenden Zone, der nach dem Abraeumen
    /// des Containers noch laeuft. Wird die Datei dabei geloescht, wirft Core Data aus
    /// `_performImportWithRequest:` heraus `_coordinator_you_never_successfully_opened_the_database_corrupted:`
    /// — eine ObjC-Exception ausserhalb jedes `catch`, die den Prozess mit SIGABRT beendet.
    static func initializeDevelopmentSchema(storeURL: URL) throws {
        guard let managedObjectModel = NSManagedObjectModel.makeManagedObjectModel(for: AnkerSchema.models) else {
            throw SyncError.managedObjectModelUnavailable
        }

        let persistentContainer = NSPersistentCloudKitContainer(
            name: "Daivento",
            managedObjectModel: managedObjectModel
        )

        let storeDescription = NSPersistentStoreDescription(url: storeURL)
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

        // Vor der ersten View, damit keine Fassung in der Systemschrift aufblitzt.
        AnkerFont.bootstrap()

        // Vor dem Container, sonst entstehen die CloudKit-Beobachter erst, wenn eine View den
        // Status anfasst — `setup` und der erste Import sind dann schon durchgelaufen.
        CloudSyncStatusCenter.startObserving()

        let schema = Schema(AnkerSchema.models)
        let cloudConfiguration = CloudSyncConfiguration.modelConfiguration(schema: schema)
        cloudSyncLog.notice("Store-Konfiguration: CloudKit=\(CloudSyncConfiguration.usesCloudKit, privacy: .public)")

#if DEBUG
        if CloudSyncConfiguration.shouldInitializeDevelopmentSchema {
            CloudSyncConfiguration.scheduleDevelopmentSchemaUpload(storeURL: cloudConfiguration.url)

            // Solange der Schema-Upload laeuft, bleibt die App selbst ohne CloudKit: zwei
            // Stores, die im selben Prozess dieselbe Zone desselben Containers spiegeln,
            // konkurrieren um den Setup-Request. Der Upload ist ein Werkzeuglauf, kein
            // normaler Start — die Oberflaeche wird dabei nicht gebraucht.
            let toolConfiguration = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
            if let container = try? ModelContainer(for: schema, configurations: [toolConfiguration]) {
                return AnkerStore(container: container, cloudKitError: nil)
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
#elseif os(iOS)
    @UIApplicationDelegateAdaptor(AnchorIOSAppDelegate.self) private var appDelegate
#endif

    private let store = AnkerStore.make()

    private var sharedModelContainer: ModelContainer { store.container }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
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
        // Eigenes Fenster ueber Command-Komma, wie auf dem Mac erwartet. Der Eintrag in der
        // Sidebar bleibt zusaetzlich, weil er auf dem iPad der einzige Weg ist.
        Settings {
            SettingsView(showsDoneButton: false)
                .frame(width: 460, height: 560)
        }
        .modelContainer(sharedModelContainer)
#endif
    }
}

#if os(iOS)
@MainActor
final class AnchorIOSAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        CloudSyncConfiguration.registerForRemoteNotifications()
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        CloudSyncStatusCenter.shared.markRemoteNotificationsRegistered()
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        CloudSyncStatusCenter.shared.markRemoteNotificationsUnavailable(error)
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        CloudSyncStatusCenter.shared.markRemoteNotificationReceived()
        let baseline = CloudSyncStatusCenter.shared.remoteChangeCount

        Task { @MainActor in
            let imported = await CloudSyncStatusCenter.shared.waitForRemoteChange(after: baseline)
            completionHandler(imported ? .newData : .noData)
        }
    }
}
#endif

#if os(macOS)
@MainActor
final class AnchorAppDelegate: NSObject, NSApplicationDelegate {
    private var statusItemController: AnchorStatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        CloudSyncConfiguration.registerForRemoteNotifications()
    }

    func application(
        _ application: NSApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        CloudSyncStatusCenter.shared.markRemoteNotificationsRegistered()
    }

    func application(
        _ application: NSApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        CloudSyncStatusCenter.shared.markRemoteNotificationsUnavailable(error)
    }

    func application(_ application: NSApplication, didReceiveRemoteNotification userInfo: [String: Any]) {
        CloudSyncStatusCenter.shared.markRemoteNotificationReceived()
    }

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
