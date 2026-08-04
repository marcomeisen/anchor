import CoreText
import OSLog
import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Die fuenf Gewichte, die das Designsystem benutzt.
enum AnkerFontWeight: Int, CaseIterable, Sendable {
    case medium = 500
    case semibold = 600
    case bold = 700
    case extraBold = 800
    case black = 900

    /// Rueckfall, wenn Archivo nicht geladen werden konnte.
    var systemWeight: Font.Weight {
        switch self {
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        case .extraBold: .heavy
        case .black: .black
        }
    }
}

/// Archivo, ueber die Gewichtsachse angesprochen.
///
/// Ausgeliefert wird der **Variable Font** `Archivo.ttf` — statische Schnitte gibt es im
/// Google-Fonts-Repository nicht. Das Gewicht wird deshalb nicht ueber einen PostScript-Namen
/// gewaehlt (`Font.custom("Archivo-Bold", …)` haengt daran, dass Core Text die benannten
/// Instanzen der `fvar`-Tabelle als eigene Namen anbietet — das ist nicht zugesichert),
/// sondern die Achse `wght` wird direkt auf den Zahlwert gesetzt. Das ist deterministisch,
/// braucht eine Datei statt fuenf und deckt jedes Gewicht ab, das die Achse hergibt.
///
/// `wdth` wird bewusst auf 100 festgenagelt: Archivo hat auch eine Breitenachse, und ohne
/// Angabe entscheidet die Standardinstanz der Datei.
enum AnkerFont {
    static let familyName = "Archivo"

    /// Vierzeichen-Codes der Achsen, als Zahl. `'wght'` bzw. `'wdth'`.
    private static let weightAxis = 0x7767_6874
    private static let widthAxis = 0x7764_7468

    /// Registriert die mitgelieferte Schrift im Prozess. Mehrfachaufruf ist unschaedlich.
    ///
    /// Zusaetzlich zu `UIAppFonts`/`ATSApplicationFontsPath`, weil die
    /// `PBXFileSystemSynchronizedRootGroup` Ressourcen flach in den Resources-Wurzelordner
    /// legt — stimmt der Pfad im Info.plist nicht, faellt die App **still** auf die
    /// Systemschrift zurueck. Dieser Weg macht den Fehlschlag sichtbar.
    @discardableResult
    static func bootstrap() -> Bool {
        guard !isRegistered else { return true }

        // Beide Orte probieren: die synchronisierte Gruppe legt Ressourcen flach ab, ein
        // Unterordner ist aber nicht ausgeschlossen.
        let candidates = ["Fonts", nil].compactMap { subdirectory in
            Bundle.main.url(forResource: "Archivo", withExtension: "ttf", subdirectory: subdirectory)
        }

        for url in candidates {
            if CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil) { break }
        }

        isRegistered = isFamilyAvailable
        if !isRegistered {
            fontLog.error("Archivo konnte nicht registriert werden — die App laeuft mit der Systemschrift.")
        }
        return isRegistered
    }

    /// Ist die Familie ansprechbar? Einmal geprueft, dann gemerkt.
    static var isAvailable: Bool {
        if let cached = availabilityCache { return cached }
        let available = isFamilyAvailable || bootstrap()
        availabilityCache = available
        return available
    }

    /// Archivo im gewuenschten Gewicht — oder die Systemschrift, wenn die Datei fehlt.
    static func archivo(_ weight: AnkerFontWeight, size: CGFloat, tabular: Bool = false) -> Font {
        guard isAvailable, let ctFont = makeFont(weight, size: size, tabular: tabular) else {
            let system = Font.system(size: size, weight: weight.systemWeight)
            return tabular ? system.monospacedDigit() : system
        }
        return Font(ctFont)
    }

    // MARK: - Intern

    private nonisolated(unsafe) static var isRegistered = false
    private nonisolated(unsafe) static var availabilityCache: Bool?

    private static var isFamilyAvailable: Bool {
#if os(macOS)
        NSFont(name: familyName, size: 12) != nil
#else
        UIFont(name: familyName, size: 12) != nil
#endif
    }

    /// Nicht `private`, damit `AnkerThemeTests` genau diesen Weg prueft und nicht einen
    /// nachgebauten daneben.
    static func makeFont(_ weight: AnkerFontWeight, size: CGFloat, tabular: Bool) -> CTFont? {
        // Die Achsen im Attributwoerterbuch setzen, nicht nachtraeglich ueber
        // `CTFontDescriptorCreateCopyWithVariation` — nur so nimmt der Deskriptor beide
        // Werte verlaesslich an (nachtraeglich kopiert ging ab 600 verloren).
        var descriptor = CTFontDescriptorCreateWithAttributes([
            kCTFontFamilyNameAttribute: familyName,
            kCTFontVariationAttribute: [
                weightAxis as CFNumber: weight.rawValue,
                widthAxis as CFNumber: 100,
            ],
        ] as CFDictionary)

        if tabular {
            // `Font.monospacedDigit()` ist fuer die Systemschrift spezifiziert und bleibt bei
            // einer eigenen Schrift wirkungslos. Die Ziffernbreite kommt deshalb aus dem
            // OpenType-Feature.
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
