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
    static let launchArgument = "-AnchoritUITest"
    /// Zusätzlich zu `launchArgument`: legt eine Beispielwoche im Speicher-Store an — für
    /// Bildschirmfotos und UI-Tests, die nicht beim Onboarding beginnen sollen.
    static let demoDataArgument = "-AnchoritDemoData"

    static var isActive: Bool {
        ProcessInfo.processInfo.arguments.contains(launchArgument)
    }

    /// Die Schluessel, die ein UI-Test-Start zurueckstellt — und **nur** diese.
    ///
    /// Bewusst eine benannte Liste statt einer Schleife im Rumpf, damit ein Test sie pruefen kann:
    /// `prepare` ist in einem Unit-Test wirkungslos (`isActive` ist dort falsch), eine Zusicherung
    /// ueber das Verhalten waere also eine Zusicherung ueber nichts.
    ///
    /// Zurueckgestellt wird nur, was der Testlauf frisch braucht, und ausschliesslich durch
    /// **Entfernen**. Kein Wert wird gesetzt. Vorher stand hier `cloudSyncEnabled = false`, und das
    /// war ein Fehler mit langer Reichweite: der Wert ueberlebt den Lauf, und weil Debug- und
    /// TestFlight-Build dieselbe Bundle-ID und damit denselben Defaults-Bereich benutzen, blieb der
    /// iCloud-Sync auf einem Geraet, auf dem je ein UI-Test lief, danach dauerhaft aus — lautlos,
    /// ohne Fehler, mit lokal weiterlaufender App. Der Testmodus braucht den Schreibvorgang gar
    /// nicht: `CloudSyncPreference` und `CloudSyncConfiguration` fragen `UITestMode.isActive` direkt ab.
    static let resetKeys = [
        AppSettingsKey.appearance,
        AppSettingsKey.startupViewMode,
        "hasCompletedOnboarding",
        "onboardingVersion"
    ]

    /// Muss vor dem `ModelContainer` und vor der ersten View laufen.
    static func prepare(defaults: UserDefaults = .standard) {
        guard isActive else { return }

        for key in resetKeys {
            defaults.removeObject(forKey: key)
        }
    }
}
#endif

/// Schluessel der Nutzereinstellungen an einer Stelle, damit `@AppStorage` und die
/// Vorab-Abfrage beim Start nicht auseinanderlaufen.
enum AppSettingsKey {
    static let appearance = "appearanceMode"
    static let startupViewMode = "startupViewMode"
    static let cloudSyncEnabled = "cloudSyncEnabled"
    static let hasChosenCloudSync = "hasChosenCloudSync"
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
}

/// Öffentliche Seiten zur App. App Store Connect verlangt beide URLs, Richtlinie 5.1.1(i)
/// zusätzlich den Link zur Datenschutzerklärung in der App selbst. Ein `Link` öffnet den
/// Browser — die App selbst baut keine Netzwerkverbindung auf.
enum AppLinks {
    static let privacyPolicy = URL(string: "https://marcomeisen.github.io/anchor/datenschutz.html")!
    static let support = URL(string: "https://marcomeisen.github.io/anchor/support.html")!
}

/// Welche Ansicht beim Start geöffnet wird.
enum StartupViewMode: String, CaseIterable, Identifiable {
    case currentWeek
    case currentDay
    case lastView

    var id: String { rawValue }

    var title: String {
        switch self {
        case .currentDay: "Heute"
        case .currentWeek: "Woche"
        case .lastView: "Zuletzt"
        }
    }

    var icon: AnkerIcon {
        switch self {
        case .currentDay: .today
        case .currentWeek: .week
        case .lastView: .refresh
        }
    }

    var explanation: String {
        switch self {
        case .currentDay: "Anchorit öffnet beim Start immer Heute."
        case .currentWeek: "Anchorit öffnet beim Start immer die laufende Woche."
        case .lastView: "Anchorit öffnet beim Start dort, wo du zuletzt warst."
        }
    }

    /// `nil` heißt: nichts ändern. So überschreibt „Zuletzt" ohne gespeicherten Stand keinen
    /// Deep Link, der die Navigation vor dem Start schon gesetzt hat.
    func initialNavigation(storedNavigation: String?, now: Date = Date()) -> AnkerNavigationState? {
        switch self {
        case .currentDay:
            var navigation = AnkerNavigationState(now: now)
            navigation.moveToToday(now: now)
            return navigation
        case .currentWeek:
            var navigation = AnkerNavigationState(now: now)
            navigation.select(.week)
            return navigation
        case .lastView:
            return AnkerNavigationState(encoded: storedNavigation)
        }
    }

    static func stored(in defaults: UserDefaults = .standard) -> StartupViewMode {
        guard let raw = defaults.string(forKey: AppSettingsKey.startupViewMode),
              let mode = StartupViewMode(rawValue: raw) else {
            return .lastView
        }
        return mode
    }
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

    var icon: AnkerIcon {
        switch self {
        case .system: .appearanceSystem
        case .light: .appearanceLight
        case .dark: .appearanceDark
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
    /// Ohne gespeicherte Wahl entscheidet, ob das Onboarding schon durchlaufen ist:
    /// - **Bestehende Installationen** (Onboarding fertig) synchronisierten bisher — für sie
    ///   bleibt es an. Ein stiller Wechsel auf „aus" wäre aus Nutzersicht ein Datenverlust.
    /// - **Ein frisches Gerät** überträgt nichts, bevor gefragt wurde. Vorher war der Sync
    ///   auch hier an, und wer „Nur auf diesem Gerät" wählte, hatte seine ersten Anker
    ///   trotzdem schon in iCloud — gegen die eigene, ausdrückliche Wahl.
    ///
    /// Im UI-Test **immer** aus, und zwar hier statt ueber einen geschriebenen Wert: der Testmodus
    /// darf keine Einstellung hinterlassen, die den naechsten echten Start ueberlebt.
    static func isEnabled(in defaults: UserDefaults = .standard) -> Bool {
#if DEBUG
        if UITestMode.isActive { return false }
#endif
        if let stored = defaults.object(forKey: AppSettingsKey.cloudSyncEnabled) as? Bool {
            return stored
        }
        return defaults.bool(forKey: AppSettingsKey.hasCompletedOnboarding)
    }

    /// Hat der Nutzer die Frage im Onboarding schon beantwortet?
    ///
    /// Im UI-Test gilt sie als beantwortet, damit der Lauf nicht ueber die iCloud-Frage geht —
    /// ebenfalls ohne Schreibvorgang, aus demselben Grund.
    static func hasBeenChosen(in defaults: UserDefaults = .standard) -> Bool {
#if DEBUG
        if UITestMode.isActive { return true }
#endif
        return defaults.bool(forKey: AppSettingsKey.hasChosenCloudSync)
    }

    static func set(_ isEnabled: Bool, in defaults: UserDefaults = .standard) {
        defaults.set(isEnabled, forKey: AppSettingsKey.cloudSyncEnabled)
        defaults.set(true, forKey: AppSettingsKey.hasChosenCloudSync)
    }

    /// Der Wert, mit dem dieser Prozess gestartet ist. Wird beim ersten Zugriff festgeschrieben
    /// und aendert sich danach nicht mehr — auch nicht, wenn der Nutzer die Einstellung umlegt.
    ///
    /// Einzige Ausnahme: `AnkerStoreHolder.enableCloudSyncNow()` im Onboarding. Dort lief der
    /// Store noch nie mit CloudKit, ein Neuaufbau mit Sync ist also kein zweites Spiegeln.
    private(set) static var activeAtLaunch: Bool = isEnabled()

    static func markEnabledAtRuntime() {
        activeAtLaunch = true
    }

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
