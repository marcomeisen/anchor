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

    subscript(step: Int) -> Color {
        let index = min(max((step / 100) - 1, 0), 8)
        return Color(hex: light[index], darkHex: light[8 - index])
    }
}

/// Die Farben von „Blatt".
///
/// Tinte auf kühlem Hellgrau, weiße Flächen mit Haarlinie und **genau eine** Farbe: ein tiefes
/// Blau. Es bedeutet „erledigt" oder „heute", sonst nichts. Anker unterscheiden sich über ihre
/// Nummer, nicht über eine Farbe — damit hängt keine Bedeutung an einem Farbton, der bei
/// Farbsehschwäche verschwimmt.
enum AnkerColor {
    private enum Raw {
        static let neutral = [
            "#F6F6F7", "#EEEFF1", "#D9DBDF", "#C9CCD1", "#9EA3AB",
            "#6B7079", "#4A4F57", "#2A2E35", "#14161A",
        ]
        static let accent = [
            "#F3F5FB", "#E6E9F5", "#C8CFEA", "#9AA3CF", "#6A78C0",
            "#3E4FA8", "#23338A", "#1A276B", "#121B4D",
        ]
    }

    static let neutral = AnkerRamp(mirroring: Raw.neutral)
    static let accent = AnkerRamp(mirroring: Raw.accent)

    // MARK: - Flächen

    /// Der Grund jedes Bildschirms.
    static let ground = Color(light: "#EEEFF1", dark: "#111317")
    /// Zweite Fläche: Segmentleisten, ruhende Knöpfe, „ohne Tag".
    static let surface = Color(light: "#F4F5F7", dark: "#1E2127")
    /// Die Fläche, auf der Inhalt steht. Hell weiß, dunkel eine Stufe über dem Grund.
    static let card = Color(light: "#FFFFFF", dark: "#1A1D22")
    /// Zeilentrenner innerhalb einer Karte.
    static let cardDivider = Color(light: "#ECEDEF", dark: "#262A31")

    // MARK: - Schrift

    static let ink = Color(light: "#14161A", dark: "#F2F3F5")
    /// Zweite Stufe: Beschriftungen, Warum-Sätze, Datumszeilen. ≥ 4,5:1 auf Grund und Karte.
    static let inkSecond = Color(light: "#4A4F57", dark: "#B4B8BF")
    /// Dritte Stufe: Erledigtes, Platzhalter. ≥ 4,5:1 auf der Karte, ≥ 3:1 auf dem Grund.
    static let inkTertiary = Color(light: "#646973", dark: "#8E939B")
    /// Schrift auf einer Fläche in `ink` — dem schwarzen Hauptknopf.
    static let onInk = Color(light: "#FFFFFF", dark: "#111317")

    // MARK: - Die eine Farbe

    /// Haken, Fortschritt, „heute". Dunkel aufgehellt, damit es auf dunklem Grund trägt.
    static let accentMark = Color(light: "#23338A", dark: "#8C9BFF")
    static let accentFill = accentMark
    /// Akzent als Schrift. Hell identisch, dunkel eine Spur heller für 4,5:1 bei kleiner Schrift.
    static let accentInk = Color(light: "#23338A", dark: "#A9B4FF")
    static let onAccent = Color(light: "#FFFFFF", dark: "#111317")

    // MARK: - Linien

    /// Die Haarlinie um Karten und zwischen Bereichen.
    static let divider = Color(light: "#D9DBDF", dark: "#2E3239")
    /// Kanten, die man anfassen soll: Rahmen eines Knopfes, gestrichelter Vorrat.
    static let dividerStrong = Color(light: "#9EA3AB", dark: "#5A606A")

    // MARK: - Zustände

    static let highlight = surface
    /// Getönte Fläche: „heute", ausgewählte Zeile, Platz im Aufbau.
    static let accentTint = Color(light: "#E6E9F5", dark: "#1D2547")
    /// Der leiseste Ton für „heute" in Rastern — die Spalte soll auffallen, nicht schreien.
    static let todayTint = Color(light: "#F3F5FB", dark: "#171C2E")

    // MARK: - Nutzerdaten

    /// Zielfarben gibt es in „Blatt" nicht mehr — ein Anker ist eine Nummer. Altbestand trägt
    /// noch `colorHex`; die Funktion bleibt, damit nichts davon falsch gelesen wird, und gibt
    /// überall dieselbe Markenfarbe zurück.
    static func goalTint(_ hex: String) -> Color { accentMark }

    /// Für neu angelegte Ziele; der Wert wird nicht mehr angezeigt.
    static let goalTintOptions = ["#23338A"]

    static func monthTint(_ month: Int) -> Color {
        let step = 300 + ((max(month, 1) - 1) % 4) * 100
        return neutral[step]
    }
}

// MARK: - Metriken

enum AnkerSpacing {
    /// Zwischen eng zusammengehörenden Zeilen: Titel und Zahl, Zellen einer Leiste.
    static let s0: CGFloat = 2
    static let s1: CGFloat = 4
    /// Zwischen Chips und in kleinen Rastern.
    static let s1h: CGFloat = 6
    static let s2: CGFloat = 8
    static let s3: CGFloat = 12
    static let s4: CGFloat = 16
    static let s5: CGFloat = 24
    static let s6: CGFloat = 32

    /// Bildschirmrand. 20pt wie in den Entwürfen auf dem iPhone, 24pt auf dem Mac.
#if os(macOS)
    static let screenPadding = s5
#else
    static let screenPadding: CGFloat = 20
#endif
    static let stack = s3

    static let markerGap: CGFloat = 2
    static let sidebarIndent: CGFloat = 28
}

enum AnkerBorder {
    /// Eine Linie ist in „Blatt" immer eine Haarlinie. Bereiche trennt der Abstand, nicht die
    /// Strichstärke.
    static let rule: CGFloat = 1
    static let hairline: CGFloat = 1
    static let focus: CGFloat = 2
    /// Das Kästchen einer offenen Aufgabe.
    static let heavy: CGFloat = 2
}

/// Radius nach Rolle, nicht nach Zahl.
enum AnkerRadius {
    /// Knöpfe und Eingabefelder.
    static let control: CGFloat = 10
    /// Karten, Raster, Spalten.
    static let card: CGFloat = 14
    /// Das Erledigt-Kästchen.
    static let check: CGFloat = 6
    /// Das Kästchen in kleiner Größe: der Radius wächst mit, sonst wird ein 14pt-Kästchen im
    /// Raster zum Kreis.
    static func check(size: CGFloat) -> CGFloat { min(check, size * 0.27) }
    /// Chips einer Aufgabe im Wochenraster.
    static let chip: CGFloat = 7
    /// Kleine Zellen in Übersichtsrastern (Woche auf dem iPhone, Jahr).
    static let cell: CGFloat = 6
    /// Striche und Kästchen in Zellen.
    static let mark: CGFloat = 2
    /// Der schwarze Plus-Knopf in einem Eingabefeld.
    static let inlineButton: CGFloat = 9
    /// Große Felder und Blockknöpfe: Erfassungszeile, „Woche beginnen".
    static let bar: CGFloat = 12
    /// Auswahlkachel — dasselbe Maß wie ein Knopf.
    static let tile = control
}

extension AnkerColor {
    /// Nur für Gezogenes: eine Aufgabe, die man in der Hand hält, schwebt.
    static let elevationNear = Color(hex: "#14161A14", darkHex: "#00000066")
    static let elevationFar = Color(hex: "#14161A29", darkHex: "#00000080")
}

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
