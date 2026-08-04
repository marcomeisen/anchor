import Foundation
import SwiftUI
#if os(macOS)
import AppKit
#endif

#if DEBUG
/// Startzustand fuer UI-Tests.
///
/// Ohne das liefen UI-Tests gegen den echten Store und den echten iCloud-Account des Nutzers:
/// der Testhost ist die vollstaendige App, `XCTestConfigurationFilePath` ist im
/// App-Prozess nicht gesetzt, und `@AppStorage` haelt den Onboarding-Zustand ueber Laeufe
/// hinweg. Aktiv nur mit dem Startargument, und nur in Debug-Builds.
enum UITestMode {
    static let launchArgument = "-DaiventoUITest"

    static var isActive: Bool {
        ProcessInfo.processInfo.arguments.contains(launchArgument)
    }

    /// Muss vor dem `ModelContainer` und vor der ersten View laufen.
    static func prepare(defaults: UserDefaults = .standard) {
        guard isActive else { return }

        for key in [AppSettingsKey.appearance, "hasCompletedOnboarding", "onboardingVersion"] {
            defaults.removeObject(forKey: key)
        }

        // Sync aus und als beantwortet markiert: der Test soll weder CloudKit anfassen noch
        // ueber die Sync-Frage im Onboarding laufen.
        defaults.set(false, forKey: AppSettingsKey.cloudSyncEnabled)
        defaults.set(true, forKey: AppSettingsKey.hasChosenCloudSync)
    }
}
#endif

/// Schluessel der Nutzereinstellungen an einer Stelle, damit `@AppStorage` und die
/// Vorab-Abfrage beim Start nicht auseinanderlaufen.
enum AppSettingsKey {
    static let appearance = "appearanceMode"
    static let cloudSyncEnabled = "cloudSyncEnabled"
    static let hasChosenCloudSync = "hasChosenCloudSync"
}

/// Hell, dunkel oder wie das System.
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Hell"
        case .dark: "Dunkel"
        }
    }

    var symbolName: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max"
        case .dark: "moon"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    /// Auf macOS zusaetzlich die App-Appearance setzen.
    ///
    /// `preferredColorScheme` gilt nur fuer SwiftUI-Fenster. Die Farbtokens loesen ueber
    /// `NSColor(name:)` gegen die Appearance auf, und das Statusbar-Popover haengt an
    /// `NSApp` statt am Fenster — ohne diesen Schritt bliebe es im Systemmodus stehen.
    @MainActor
    func apply() {
#if os(macOS)
        switch self {
        case .system: NSApp?.appearance = nil
        case .light: NSApp?.appearance = NSAppearance(named: .aqua)
        case .dark: NSApp?.appearance = NSAppearance(named: .darkAqua)
        }
#endif
    }

    static func stored(in defaults: UserDefaults = .standard) -> AppearanceMode {
        guard let raw = defaults.string(forKey: AppSettingsKey.appearance),
              let mode = AppearanceMode(rawValue: raw) else {
            return .system
        }
        return mode
    }
}

/// Ob der iCloud-Sync angebunden wird.
///
/// Die Entscheidung faellt einmal pro Prozess: `AnkerStore.make()` baut den `ModelContainer`
/// vor der ersten View auf, und ein Umschalten zur Laufzeit ist hier nachweislich nicht
/// moeglich — wird derselbe Store ein zweites Mal mit CloudKit verbunden, bricht CoreData mit
/// 134422 ab ("another instance of this persistent store actively syncing with CloudKit in
/// this process"). Deshalb `activeAtLaunch` und ein ehrlicher Neustart-Hinweis statt einer
/// Umschaltung, die halb funktioniert.
@MainActor
enum CloudSyncPreference {
    /// Standard ist eingeschaltet: bestehende Installationen synchronisieren bereits, und ein
    /// stiller Wechsel auf "aus" waere aus Nutzersicht ein Datenverlust.
    static func isEnabled(in defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: AppSettingsKey.cloudSyncEnabled) as? Bool ?? true
    }

    /// Hat der Nutzer die Frage im Onboarding schon beantwortet?
    static func hasBeenChosen(in defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: AppSettingsKey.hasChosenCloudSync)
    }

    static func set(_ isEnabled: Bool, in defaults: UserDefaults = .standard) {
        defaults.set(isEnabled, forKey: AppSettingsKey.cloudSyncEnabled)
        defaults.set(true, forKey: AppSettingsKey.hasChosenCloudSync)
    }

    /// Der Wert, mit dem dieser Prozess gestartet ist. Wird beim ersten Zugriff festgeschrieben
    /// und aendert sich danach nicht mehr — auch nicht, wenn der Nutzer die Einstellung umlegt.
    static let activeAtLaunch: Bool = isEnabled()

    /// Weicht die Einstellung von dem ab, was gerade laeuft?
    static var needsRestart: Bool {
        isEnabled() != activeAtLaunch
    }

#if os(macOS)
    /// Startet die App neu, damit der Store mit der neuen Einstellung geoeffnet wird.
    /// Auf iOS gibt es dafuer keinen erlaubten Weg — dort bleibt nur der Hinweis.
    static func relaunch() {
        let url = Bundle.main.bundleURL
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, _ in
            Task { @MainActor in NSApp.terminate(nil) }
        }
    }
#endif
}
