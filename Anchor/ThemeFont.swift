import CoreText
import OSLog
import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Die drei Gewichte, die Lot benutzt.
///
/// „Gewichte 400 / 500 / 600 — nie schwerer, das uebernimmt der Grad." Das ist der sichtbarste
/// Bruch mit dem Modernist-System, das bis 900 ging: dort trug das Gewicht die Hierarchie, in
/// Lot tragen sie Groesse, Farbe und Flaeche.
enum AnkerFontWeight: Int, CaseIterable, Sendable {
    case regular = 400
    case medium = 500
    case semibold = 600

    var systemWeight: Font.Weight {
        switch self {
        case .regular: .regular
        case .medium: .medium
        case .semibold: .semibold
        }
    }
}

/// Welche Familie eine Schriftrolle spricht — und damit, in welchem Modus der Nutzer ist.
///
/// „Die Schrift sagt, in welchem Modus du bist." Das ist keine Zierde: der Wechsel auf die
/// Serif ist das einzige Signal, dass gerade nicht gearbeitet wird.
enum AnkerFontFamily: Sendable {
    /// Arbeitsflaeche — die Systemschrift.
    case workface
    /// Ritual — Instrument Serif.
    case ritual
}

/// Die beiden Familien des Systems.
///
/// **Arbeitsflaeche: San Francisco.** Der Entwurf verlangt hier ausdruecklich die Systemschrift
/// („SF Pro. In der App. Dynamic Type, optische Groessen, alle Sprachen"); Instrument Sans ist
/// dort nur der Stellvertreter fuer Web und Dokumente. Damit faellt die Archivo-Buendelung des
/// Modernist-Systems weg — und Dynamic Type, optische Groessen und die Sprachabdeckung kommen
/// ohne eigene Datei.
///
/// **Ritual: Instrument Serif** (OFL-1.1), als einzige geliefert. Ein Serif in einer
/// Produktivitaets-App ist ungewoehnlich — genau deshalb markiert er den Modus.
enum AnkerFont {
    static let ritualFamilyName = "Instrument Serif"

    /// Registriert die mitgelieferte Serif im Prozess. Mehrfachaufruf ist unschaedlich.
    ///
    /// Zusaetzlich zu `UIAppFonts`/`ATSApplicationFontsPath`, weil die
    /// `PBXFileSystemSynchronizedRootGroup` Ressourcen flach in den Resources-Wurzelordner
    /// legt — stimmt der Pfad im Info.plist nicht, faellt die App **still** auf die
    /// Systemschrift zurueck. Dieser Weg macht den Fehlschlag sichtbar.
    @discardableResult
    static func bootstrap() -> Bool {
        guard !isRegistered else { return true }

        // Hat `UIAppFonts` bzw. `ATSApplicationFontsPath` die Datei schon geladen, ist hier
        // nichts mehr zu tun. Ohne diese Abkuerzung laeuft `CTFontManagerRegisterFontsForURL`
        // trotzdem los und das System meldet „GSFont: file already registered" in die Konsole —
        // harmlos, aber es sieht im Gerätelog nach einem Fehler aus.
        if isRitualFamilyAvailable {
            isRegistered = true
            return true
        }

        // Beide Orte probieren: die synchronisierte Gruppe legt Ressourcen flach ab, ein
        // Unterordner ist aber nicht ausgeschlossen.
        let candidates = ["Fonts", nil].compactMap { subdirectory in
            Bundle.main.url(
                forResource: "InstrumentSerif-Regular",
                withExtension: "ttf",
                subdirectory: subdirectory
            )
        }

        for url in candidates {
            if CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil) { break }
        }

        isRegistered = isRitualFamilyAvailable
        if !isRegistered {
            fontLog.error("Instrument Serif konnte nicht registriert werden — der Ritual-Modus laeuft mit der System-Serif.")
        }
        return isRegistered
    }

    /// Ist die Serif ansprechbar? Einmal geprueft, dann gemerkt.
    static var isRitualAvailable: Bool {
        if let cached = availabilityCache { return cached }
        let available = isRitualFamilyAvailable || bootstrap()
        availabilityCache = available
        return available
    }

    /// Die Schrift zu einer Rolle.
    static func font(
        _ family: AnkerFontFamily,
        weight: AnkerFontWeight,
        size: CGFloat,
        tabular: Bool = false
    ) -> Font {
        switch family {
        case .workface: workface(weight, size: size, tabular: tabular)
        case .ritual: ritual(size: size)
        }
    }

    /// Arbeitsflaeche: die Systemschrift. `monospacedDigit()` ist genau fuer sie spezifiziert.
    static func workface(_ weight: AnkerFontWeight, size: CGFloat, tabular: Bool = false) -> Font {
        // design-guard: erlaubt — hier *entsteht* die Schrift des Systems.
        let font = Font.system(size: size, weight: weight.systemWeight)
        return tabular ? font.monospacedDigit() : font
    }

    /// Ritual: Instrument Serif — oder die System-Serif, wenn die Datei fehlt.
    ///
    /// Der Rueckfall ist bewusst `design: .serif` und nicht die Standardschrift: faellt die
    /// Datei aus, soll der Modus trotzdem als Modus lesbar bleiben.
    static func ritual(size: CGFloat) -> Font {
        guard isRitualAvailable else {
            // design-guard: erlaubt — Rueckfall der Ritual-Familie.
            return Font.system(size: size, weight: .regular, design: .serif)
        }
        return Font.custom(ritualFamilyName, fixedSize: size)
    }

    // MARK: - Intern

    private nonisolated(unsafe) static var isRegistered = false
    private nonisolated(unsafe) static var availabilityCache: Bool?

    /// Nicht `private`, damit `AnkerThemeTests` genau diesen Weg prueft und nicht einen
    /// nachgebauten daneben.
    static var isRitualFamilyAvailable: Bool {
#if os(macOS)
        NSFont(name: ritualFamilyName, size: 12) != nil
#else
        UIFont(name: ritualFamilyName, size: 12) != nil
#endif
    }

    /// Der Weg, den `ritual(size:)` nimmt — als `CTFont`, damit ein Test die Familie und die
    /// Ziffernbreite messen kann statt der Selbstauskunft zu glauben.
    static func makeRitualFont(size: CGFloat, tabular: Bool) -> CTFont? {
        var descriptor = CTFontDescriptorCreateWithAttributes([
            kCTFontFamilyNameAttribute: ritualFamilyName,
        ] as CFDictionary)

        if tabular {
            descriptor = CTFontDescriptorCreateCopyWithFeature(
                descriptor,
                kNumberSpacingType as CFNumber,
                kMonospacedNumbersSelector as CFNumber
            )
        }

        return CTFontCreateWithFontDescriptor(descriptor, size, nil)
    }
}

let fontLog = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.marcomeisen.Anchor",
    category: "Font"
)
