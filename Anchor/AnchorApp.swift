//
//  AnchorApp.swift
//  Anchorit
//
//  Created by Marco Meisen on 31.07.26.
//

import Combine
import SwiftUI
import SwiftData
import CoreData
import OSLog
import Security
import UserNotifications
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
                String(localized: "Das Datenmodell konnte nicht für CloudKit aufgebaut werden.")
            case .cloudKitStoreUnavailable:
                String(localized: "Der iCloud-Container konnte nicht geöffnet werden.")
            }
        }
    }

    static let containerIdentifier = "iCloud.com.marcomeisen.Anchor"
    @MainActor private static var requestedRemoteNotificationRegistration = false

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
#if DEBUG
        let environment = ProcessInfo.processInfo.environment
        if environment["XCTestConfigurationFilePath"] != nil { return true }
        if environment.keys.contains(where: { $0.hasPrefix("XCTest") || $0.hasPrefix("XCInject") }) {
            return true
        }
        if let inserted = environment["DYLD_INSERT_LIBRARIES"], inserted.contains("XCTest") {
            return true
        }
        return false
#else
        // Unit-Tests laufen gegen Debug. Im Release kann eine Umgebungsvariable die App so
        // nicht in einen flüchtigen Speicher-Store schicken.
        return false
#endif
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
        guard usesCloudKit, !requestedRemoteNotificationRegistration else { return }
        requestedRemoteNotificationRegistration = true

#if os(macOS)
        NSApplication.shared.registerForRemoteNotifications()
#elseif os(iOS)
        UIApplication.shared.registerForRemoteNotifications()
#endif
    }

    @MainActor
    static func allowRemoteNotificationRegistrationRetry() {
        requestedRemoteNotificationRegistration = false
    }

#if DEBUG
    /// Das CloudKit-Entwicklungsschema muss nach **jeder** Modelaenderung einmal hochgeladen
    /// werden, sonst fehlen die neuen Felder. Der normale Export legt sie nicht zwangslaeufig an:
    /// CloudKit erzeugt ein Feld erst, wenn ein Record mit einem Wert darin exportiert wird —
    /// ein durchgehend `nil` gebliebener Optional bleibt dem Schema deshalb unbekannt.
    ///
    /// Bei jedem Start ausgefuehrt legt `initializeCloudKitSchema` fuer jede Entity Beispielrecords
    /// an und wieder loescht sie. Deshalb laeuft es nur auf Anforderung:
    /// Scheme > Run > Arguments > `-AnchoritInitializeCloudKitSchema` setzen.
    static let schemaInitializationArgument = "-AnchoritInitializeCloudKitSchema"

    static var shouldInitializeDevelopmentSchema: Bool {
        ProcessInfo.processInfo.arguments.contains(schemaInitializationArgument)
    }

    /// Startet den Schema-Upload **nach** dem Start und abseits des Main-Threads.
    ///
    /// Inline in `App.init` aufgerufen scheiterte er reproduzierbar nach rund 130 Sekunden mit
    /// "Failed to initialize CloudKit schema because the requests timed out (a 30s wait failed)":
    /// `initializeCloudKitSchema` wartet synchron auf den Setup-Request des Mirroring-Delegate,
    /// und der kommt nicht durch, solange der Main-Thread in `App.init` blockiert.
    static func scheduleDevelopmentSchemaUpload(storeURL: URL) {
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 3) {
            do {
                try initializeDevelopmentSchema(storeURL: storeURL)
                cloudSyncLog.notice("CloudKit-Schema hochgeladen")
                print("CloudKit schema initialized.")
            } catch {
                // `localizedDescription` ist bei Core-Data-CloudKit-Fehlern nichtssagend; die
                // Aussage steckt in `NSLocalizedFailureReason` und `encounteredErrors`.
                let detail = CloudSyncErrorFormatter.describe(error)
                cloudSyncLog.error("CloudKit-Schema fehlgeschlagen: \(detail, privacy: .public)")
                print("CloudKit schema initialization failed: \(error)")
            }
        }
    }

    /// Laeuft bewusst gegen die **echte** Store-Datei. Auf einem Wegwerf-Store startet der
    /// Mirroring-Delegate einen Import der bestehenden Zone, der nach dem Abraeumen noch laeuft;
    /// wird die Datei dabei geloescht, endet der Prozess mit einer ObjC-Exception (SIGABRT).
    static func initializeDevelopmentSchema(storeURL: URL) throws {
        guard let managedObjectModel = NSManagedObjectModel.makeManagedObjectModel(for: AnkerSchema.models) else {
            throw SyncError.managedObjectModelUnavailable
        }

        let persistentContainer = NSPersistentCloudKitContainer(
            name: "Anchorit",
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
            CloudSyncConfiguration.scheduleDevelopmentSchemaUpload(storeURL: cloudConfiguration.url)

            // Solange der Schema-Upload laeuft, bleibt die App selbst ohne CloudKit: zwei
            // Stores, die im selben Prozess dieselbe Zone spiegeln, konkurrieren um den
            // Setup-Request. Der Upload ist ein Werkzeuglauf, kein normaler Start.
            let toolConfiguration = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
            if let container = try? ModelContainer(for: schema, configurations: [toolConfiguration]) {
                return AnkerStore(container: container, cloudKitError: nil)
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
            cloudSyncLog.error("CloudKit-Store nicht verfügbar, lokaler Rückfall — \(CloudSyncErrorFormatter.describe(error), privacy: .private)")
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

/// Hält den Store und baut ihn genau einmal neu auf: wenn ein frisches Gerät im Onboarding
/// „Mit iCloud synchronisieren" wählt.
///
/// Bis zu dieser Wahl läuft der Store ohne CloudKit (siehe `CloudSyncPreference.isEnabled`).
/// Der Neuaufbau öffnet dieselbe Datei mit CloudKit. Das ist kein zweites Spiegeln — der lokale
/// Container hat keinen Mirroring-Delegate, also auch kein 134422. In der Wartezeit vor der
/// Wahl ist noch nichts geschrieben worden.
@MainActor
final class AnkerStoreHolder: ObservableObject {
    static let shared = AnkerStoreHolder()

    @Published private(set) var store: AnkerStore

    private init() {
        store = AnkerStore.make()
    }

    func enableCloudSyncNow() {
        guard !CloudSyncConfiguration.usesCloudKit else { return }
        CloudSyncPreference.markEnabledAtRuntime()
        guard CloudSyncConfiguration.usesCloudKit else { return }

        let schema = Schema(AnkerSchema.models)
        let configuration = CloudSyncConfiguration.modelConfiguration(schema: schema)
        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            store = AnkerStore(container: container, cloudKitError: nil)
            CloudSyncStatusCenter.shared.markCloudSyncEnabledAtRuntime()
            CloudSyncConfiguration.registerForRemoteNotifications()
            Task { await CloudSyncStatusCenter.shared.refreshAccountStatus() }
        } catch {
            cloudSyncLog.error("iCloud-Store ließ sich nicht öffnen — \(CloudSyncErrorFormatter.describe(error), privacy: .public)")
            CloudSyncStatusCenter.shared.markCloudUnavailable(CloudSyncConfiguration.SyncError.cloudKitStoreUnavailable)
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

    @StateObject private var holder = AnkerStoreHolder.shared
    @Environment(\.scenePhase) private var scenePhase

    private var store: AnkerStore { holder.store }
    private var sharedModelContainer: ModelContainer { store.container }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .ankerAppStorage()
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
                // Erinnerungen an das Ritual: beim Start neu planen (Sprache, Zeitzone, Stand
                // der Woche), danach nach jedem Speichern und bei jedem Wechsel nach vorn.
                .task(id: ObjectIdentifier(sharedModelContainer)) {
                    RitualReminderCenter.shared.start(container: sharedModelContainer)
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { RitualReminderCenter.shared.scheduleSoon(delay: .zero) }
                }
#if os(macOS)
                .onAppear {
                    appDelegate.configure(modelContainer: sharedModelContainer)
                }
                .onChange(of: ObjectIdentifier(sharedModelContainer)) { _, _ in
                    appDelegate.configure(modelContainer: sharedModelContainer)
                }
#endif
        }
        .modelContainer(sharedModelContainer)
        .commands { AnkerCommands() }
#if os(macOS)
        // „Blatt" zeichnet seinen eigenen Fensterkopf; die Ampelknöpfe liegen darüber.
        .windowStyle(.hiddenTitleBar)
        // Das Fenster erscheint bei jedem Start, auch wenn die Wiederherstellung keins
        // mitbringt. Ohne das startete die App zeitweise ganz ohne Fenster, nur mit
        // Menüleiste — unter XCUITest bei jedem Lauf.
        .defaultLaunchBehavior(.presented)
        .defaultSize(width: 1280, height: 820)
        // Die Mindestgröße kommt aus dem Inhalt — Seitenleiste plus lesbares Raster.
        .windowResizability(.contentMinSize)
#endif

#if os(macOS)
        // Eigenes Fenster ueber Command-Komma, wie auf dem Mac erwartet.
        Settings {
            // Im eigenen Stapel, damit Datenschutzerklärung und Hilfe von rechts hereinkommen.
            NavigationStack { SettingsView(showsDoneButton: false) }
                .frame(width: 460, height: 560)
                .ankerAppStorage()
        }
        .modelContainer(sharedModelContainer)
#endif
    }
}

#if os(iOS)
/// Registriert die stillen CloudKit-Pushes so früh wie möglich und meldet ihr Eintreffen.
/// Ohne Registrierung erfährt ein iPhone von Änderungen anderer Geräte erst beim nächsten
/// Vordergrundwechsel.
@MainActor
final class AnchorIOSAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        CloudSyncConfiguration.registerForRemoteNotifications()
        // Vor dem Ende des Starts, sonst geht das Tippen auf eine Erinnerung verloren, die
        // die App erst startet.
        if !RitualReminderCenter.isInactiveInThisProcess {
            UNUserNotificationCenter.current().delegate = RitualNotificationDelegate.shared
        }
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
        CloudSyncConfiguration.allowRemoteNotificationRegistrationRetry()
        CloudSyncStatusCenter.shared.markRemoteNotificationsUnavailable(error)
    }

    /// Hält die App im Hintergrund wach, bis der Import angekommen ist (höchstens 25 s).
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
        if !RitualReminderCenter.isInactiveInThisProcess {
            UNUserNotificationCenter.current().delegate = RitualNotificationDelegate.shared
        }
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
        CloudSyncConfiguration.allowRemoteNotificationRegistrationRetry()
        CloudSyncStatusCenter.shared.markRemoteNotificationsUnavailable(error)
    }

    func application(_ application: NSApplication, didReceiveRemoteNotification userInfo: [String: Any]) {
        CloudSyncStatusCenter.shared.markRemoteNotificationReceived()
    }

    private weak var configuredContainer: ModelContainer?

    /// Erneut aufgerufen, wenn `AnkerStoreHolder` den Store neu aufbaut — die Schnellerfassung
    /// in der Menüleiste schreibt sonst in den alten Container.
    func configure(modelContainer: ModelContainer) {
        guard configuredContainer !== modelContainer else { return }
        configuredContainer = modelContainer
        if let statusItemController {
            statusItemController.update(modelContainer: modelContainer)
        } else {
            statusItemController = AnchorStatusItemController(modelContainer: modelContainer)
        }
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
                button.title = "A"
            }
            button.action = #selector(togglePopover(_:))
            button.target = self
        }

        popover.behavior = .transient
        update(modelContainer: modelContainer)
    }

    func update(modelContainer: ModelContainer) {
        let rootView = QuickCapturePopover(onClose: { [weak self] in self?.closePopover() })
            .modelContainer(modelContainer)
            .ankerAppStorage()
        let controller = NSHostingController(rootView: rootView)
        // Die Größe folgt dem Inhalt. Eine feste Höhe schnitt bei langen Ankertiteln, die in
        // mehrere Chipzeilen umbrechen, die Knöpfe ab.
        controller.sizingOptions = .preferredContentSize
        popover.contentViewController = controller
    }

    private func closePopover() {
        popover.performClose(nil)
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
