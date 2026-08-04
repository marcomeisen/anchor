import SwiftUI

/// Eine neunstufige Helligkeitsleiter.
///
/// Der Dunkelmodus ist dieselbe Leiter, gespiegelt: 100↔900, 200↔800 und so weiter. Deshalb
/// gibt es pro Rampe genau eine Wertequelle — ein Dunkelwert kann nicht aus der Reihe fallen,
/// weil er nicht getrennt gepflegt wird.
struct AnkerRamp: Sendable {
    private let light: [String]

    fileprivate init(mirroring light: [String]) {
        precondition(light.count == 9)
        self.light = light
    }

    /// 100 bis 900. Zwischenwerte rasten auf die naechste Stufe.
    subscript(step: Int) -> Color {
        let index = min(max((step / 100) - 1, 0), 8)
        return Color(hex: light[index], darkHex: light[8 - index])
    }
}

/// Farbtokens des Modernist-Systems.
///
/// Grundsatz aus dem Systemblatt: die App ist Tinte auf hellem Grund, Rot ist ein Signal und
/// keine Farbe. Es gibt genau eine Flaeche, auf der Rot voll laeuft — das Rueckblick-Plakat.
enum AnkerColor {
    private enum Raw {
        static let neutral = [
            "#F8F4F4", "#EAE7E7", "#D7D3D3", "#BAB6B6", "#9B9797",
            "#7D7979", "#605D5D", "#444141", "#2D2B2B",
        ]
        static let accent = [
            "#FFF2EF", "#FFE0D9", "#FFC4B8", "#FF9783", "#FF563C",
            "#DD2B0F", "#AE1800", "#7C1405", "#4D170E",
        ]
    }

    /// Neutralrampe, spiegelt im Dunkelmodus.
    static let neutral = AnkerRamp(mirroring: Raw.neutral)
    /// Akzentrampe. Spiegelt ebenfalls: die blassen Toenungen 100–300 spielen auf hellem Grund
    /// dieselbe Rolle wie die tiefen Rottoene 900–700 auf dunklem — getoente Flaeche hinter Text.
    static let accent = AnkerRamp(mirroring: Raw.accent)

    // MARK: - Flaechen
    //
    // Der helle Grund des Systems liegt hoch (zwischen Stufe 100 und 200). Eine reine
    // Indexspiegelung landete bei Stufe 850 und liesse darunter keinen Platz fuer eine
    // zweite Ebene und die Schrift. Deshalb genau ein Schritt weiter — und nur fuer die
    // Flaechen, nicht fuer die Schrift.

    static let ground = Color(light: "#F3F2F2", dark: "#1A1918")
    static let surface = Color(light: "#EAE9E9", dark: "#2D2B2B")

    // MARK: - Schrift

    static let ink = Color(light: "#201E1D", dark: "#F5F1F1")
    /// Zweite Textstufe — genau der Wert des Entwurfs (#605D5D), 5,83:1 auf hellem Grund.
    /// Auch Mikrobeschriftungen nehmen diese Stufe: die Hierarchie des Entwurfs entsteht aus
    /// Groesse, Gewicht und Sperrung, nicht daraus, dass der Text zu blass zum Lesen ist.
    /// Der Entwurf setzt dort #9B9797 — das waeren 2,59:1 und damit unlesbar.
    static let inkSecond = neutral[700]
    /// Nur fuer wirklich schmueckende Marken ohne Informationswert. 3,85:1.
    static let inkTertiary = neutral[600]

    // MARK: - Akzent in drei Rollen
    //
    // Das Systemblatt gibt einen Akzent an (#EC3013) und sagt selbst dazu: "The
    // accent-to-ground pair is tuned to at least 3:1 — enough for icons, large text and
    // interface chrome, not for body copy — so for paragraph-size text in the accent use a
    // deep ramp step". Gemessen auf #F3F2F2: #EC3013 als Schrift 3,76:1, Weiss auf #EC3013
    // 4,20:1. Die Schaltflaechenbeschriftungen im Entwurf sind 14–17pt und liegen damit unter
    // der Grenze fuer grossen Text — eine einzige Akzentfarbe kann Marke, Flaeche und Schrift
    // nicht gleichzeitig tragen. Aufgeteilt, alle drei aus derselben Rampe.

    /// Marke: 2px-Regeln, Fokusring, Marker, Vollflaeche. Braucht nur 3:1.
    static let accentMark = Color(light: "#EC3013", dark: "#FF563C")
    /// Flaeche unter weisser Schrift. Eine Rampenstufe tiefer, damit 4,74:1 statt 4,20:1.
    static let accentFill = Color(hex: "#DD2B0F")
    /// Akzent **als Schrift** auf Grund oder Flaeche. 6,41:1 hell, 5,56:1 dunkel.
    static let accentInk = Color(light: "#AE1800", dark: "#FF563C")
    /// Schrift auf `accentFill` und auf dem Plakat. Bewusst statisch — dynamisch wuerde es
    /// die Plakatflaeche invertieren.
    static let onAccent = Color(hex: "#FFFFFF")

    // MARK: - Linien

    /// Entspricht `color-mix(in srgb, #201e1d 40%, transparent)`. Dunkel 32 %: ueber dunklem
    /// Grund traegt dieselbe Deckkraft mehr Kontrast, 32 % gleicht das aus.
    static let divider = Color(hex: "#201E1D66", darkHex: "#F5F1F152")
    /// Fuer Linien, die eine Bedeutung tragen — Feldgrenze, Rahmen.
    static let dividerStrong = Color(hex: "#201E1DB3", darkHex: "#F5F1F1A6")

    // MARK: - Zustaende

    /// Getoente Flaeche hinter dem heutigen Tag und der ausgewaehlten Zeile.
    static let highlight = surface
    /// Drop-Ziel und Hinweisflaeche.
    static let accentTint = accent[200]

    // MARK: - Nutzerdaten

    /// `Goal.colorHex` ist gespeicherte, ueber CloudKit synchronisierte Nutzereingabe und wird
    /// **nicht** migriert. Altwerte aus der Indigo-Palette rasten hier auf die naechste
    /// Stufe der neuen Rampe, damit der Neuentwurf ohne Datenmigration vollstaendig ist.
    static func goalTint(_ hex: String) -> Color {
        let normalized = hex.uppercased()
        if let mapped = legacyGoalTints[normalized] { return mapped }
        return Color(hex: hex)
    }

    /// Auswahl im Zielformular. Tinte und Rampe statt Regenbogen.
    /// Jede Stufe traegt weisse Schrift mit mindestens 4,5:1 — geprueft in `AnkerThemeTests`.
    static let goalTintOptions = ["#DD2B0F", "#2D2B2B", "#444141", "#605D5D"]

    /// Monate unterscheidbar, ohne Bedeutung zu behaupten: eine Wanderung durch die
    /// Neutralrampe statt zwoelf Farben. `month` 1…12.
    static func monthTint(_ month: Int) -> Color {
        let step = 300 + ((max(month, 1) - 1) % 6) * 100
        return neutral[step]
    }

    private static let legacyGoalTints: [String: Color] = [
        "#5B6EE8": accentFill,      // altes Indigo
        "#C9974B": neutral[800],    // altes Messing
        "#7FCDA8": neutral[900],
        "#8A8D98": neutral[700],
    ]
}

// MARK: - Metriken

enum AnkerSpacing {
    static let s1: CGFloat = 4
    static let s2: CGFloat = 8
    static let s3: CGFloat = 12
    static let s4: CGFloat = 16
    static let s5: CGFloat = 24
    static let s6: CGFloat = 32

    /// Bestandsnamen, auf das neue Raster gelegt. Damit rasten rund 30 Aufrufstellen ohne
    /// eigene Aenderung gemeinsam ein.
    static let screenPadding = s5
    static let stack = s3

    /// Freiraum unter scrollenden Inhalten auf dem iPhone: darunter liegen Tableiste und
    /// Erfassungszeile. Gemessen, nicht geraten — sonst verschwindet die letzte Zeile darunter.
    static let bottomBarClearance: CGFloat = 96
    /// Abstand **innerhalb** einer Markergruppe — die sieben Tagesquadrate einer Wochenzeile.
    /// Kein Layoutrhythmus, sondern die Körnung des Rasters: auf der kleinsten Stufe (4) fielen
    /// die sieben Quadrate auseinander und lasen sich als sieben Dinge statt als eine Woche.
    static let markerGap: CGFloat = 2
    /// Einzug der Tageszeilen in der Zeitschiene — unter der Wochenbeschriftung, nicht unter
    /// deren Quadraten. Gemessen aus dem Entwurf.
    static let sidebarIndent: CGFloat = 28
}

enum AnkerBorder {
    /// Trennlinien und Rahmen. Es gibt keine Haarlinie.
    static let rule: CGFloat = 2
    static let focus: CGFloat = 2
    /// Plakatrahmen und Marker.
    static let heavy: CGFloat = 3
}

/// Das Systemblatt definiert `shadow sm/md/lg` (0 1px 2px @14 %, 0 3px 10px @16 %,
/// 0 12px 32px @22 %). Im App-Code werden sie **nicht** benutzt: nichts schwebt. Bewusst
/// nicht als Token modelliert — ein vorhandenes Token waere eine Einladung. Was der Schatten
/// leisten sollte, die Kante sichtbar machen, uebernimmt `AnkerBorder.rule`.
enum AnkerElevation {}

// MARK: - Farbaufbau

extension Color {
    init(light: String, dark: String) {
        self.init(hex: light, darkHex: dark)
    }

    init(hex: String, darkHex: String? = nil) {
        let light = PlatformColor(hex: hex)
        let dark: PlatformColor?
        if let darkHex {
            dark = PlatformColor(hex: darkHex)
        } else {
            dark = nil
        }

#if os(macOS)
        if let dark {
            self.init(nsColor: NSColor(name: nil) { appearance in
                appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            })
        } else {
            self.init(nsColor: light)
        }
#else
        if let dark {
            self.init(uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark ? dark : light
            })
        } else {
            self.init(uiColor: light)
        }
#endif
    }
}

#if os(macOS)
private typealias PlatformColor = NSColor

private extension NSColor {
    convenience init(hex: String) {
        let components = hex.hexComponents
        // `calibratedRed:` ist ein anderer Farbraum als sRGB — Hexwerte aus dem
        // Designsystem kamen damit messbar verschoben heraus.
        self.init(
            srgbRed: components.red,
            green: components.green,
            blue: components.blue,
            alpha: components.alpha
        )
    }
}
#else
private typealias PlatformColor = UIColor

private extension UIColor {
    convenience init(hex: String) {
        let components = hex.hexComponents
        self.init(
            red: components.red,
            green: components.green,
            blue: components.blue,
            alpha: components.alpha
        )
    }
}
#endif

private extension String {
    var hexComponents: (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        let trimmed = trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: trimmed).scanHexInt64(&value)

        switch trimmed.count {
        case 8:
            return (
                red: CGFloat((value & 0xFF00_0000) >> 24) / 255,
                green: CGFloat((value & 0x00FF_0000) >> 16) / 255,
                blue: CGFloat((value & 0x0000_FF00) >> 8) / 255,
                alpha: CGFloat(value & 0x0000_00FF) / 255
            )
        default:
            return (
                red: CGFloat((value & 0xFF0000) >> 16) / 255,
                green: CGFloat((value & 0x00FF00) >> 8) / 255,
                blue: CGFloat(value & 0x0000FF) / 255,
                alpha: 1
            )
        }
    }
}
