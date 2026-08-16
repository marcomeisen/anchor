import SwiftUI

/// Farbtokens des **Lot**-Systems.
///
/// Grundsatz aus dem Systemblatt: warme Neutralen tragen die ganze Oberflaeche, Bernstein ist
/// „jetzt, aktiv, primaer" und Rost ausschliesslich Rueckstand. Kein Gruen, kein Gelb, kein
/// Blau — vier Zustaende, die sich ueber **Fuellung** unterscheiden, nicht ueber Farbton.
///
/// Die fuenfzehn Tokens des Entwurfs stehen hier als Wertequelle. Anders als im
/// Modernist-System gibt es **keine gespiegelte Rampe** mehr: der Entwurf gibt fuer jede Rolle
/// ein eigenes Paar an, weil eine Spiegelung im Warmen daneben liegt („Keine Invertierung —
/// eigene Stufen").
///
/// Drei Werte des Entwurfs sind gemessen korrigiert; jede Abweichung steht an ihrem Token.
enum AnkerColor {

    // MARK: - Schrift
    //
    // Vier Stufen, absteigend. Was sie tragen muessen, ist Kontrast — nicht Blaesse.

    /// `LotInk` — Primaertext, erledigte Fuellung, Ritual-Grund. 12,7:1 auf Grund.
    static let ink = Color(light: "#1C1A16", dark: "#F6F3EE")
    /// `LotInkSecondary` — Sekundaertext in Karten. 7,7:1 auf Grund.
    static let inkSecond = Color(light: "#443F37", dark: "#E2DCD2")
    /// `LotTextMuted` — Fliesstext und Metazeilen. 5,3:1 auf Grund.
    static let inkMuted = Color(light: "#5C564B", dark: "#C8C0B2")
    /// Dritte Textstufe.
    ///
    /// **Abweichung vom Entwurf.** Dort steht hier `LotTextFaint` (`#A09889`) fuer
    /// Mikro-Beschriftungen. Gemessen sind das 2,10:1 auf dem Grund und 2,82:1 auf der Karte —
    /// dieselbe Falle, die dieses Projekt schon einmal fuer `#9B9797` (2,59:1) verworfen hat.
    /// Eine Mikro-Beschriftung ist Information, keine Zierde; sie nimmt deshalb `LotTextMuted`.
    /// Der Entwurfswert lebt als ``faint`` weiter — fuer Flaechen, nicht fuer Schrift.
    static let inkTertiary = inkMuted
    /// `LotTextFaint` — **keine Schriftfarbe.** Platzhalterspur, leeres Tagesfeld, ausgegraute
    /// Marke. Alles, was gelesen werden muss, nimmt ``inkTertiary``.
    static let faint = Color(light: "#A09889", dark: "#7A7365")

    // MARK: - Flaechen
    //
    // Drei Ebenen: Grund liegt unten, Karte oben. In **beiden** Modi geht die Karte nach oben
    // ins Licht — im Dunkeln kann sie nicht heller als Weiss werden, deshalb waere eine
    // Spiegelung hier falsch.

    /// `LotGround` — Schreibtisch und Balkenspur. Die unterste Ebene.
    static let ground = Color(light: "#E2DCD2", dark: "#14120F")
    /// `LotSurfaceSunken` — Fensterkopf, Eingangskorb, eingelassene Felder.
    static let surface = Color(light: "#F6F3EE", dark: "#232019")
    /// `LotSurface` — Karten, Listen, Fenster. Die Flaeche, auf der gearbeitet wird.
    static let card = Color(light: "#FFFDFA", dark: "#2E2A24")

    // MARK: - Linien
    //
    // Lot ersetzt die 2px-Regeln des Modernist-Systems durch Haarlinien und Hoehe. Es bleiben
    // genau zwei Staerken von Bedeutung: die Zeile in einer Liste und die Grenze eines
    // Abschnitts.

    /// `LotHairline` — Trennlinie **innerhalb** einer Karte.
    static let cardDivider = Color(light: "#EDE8E0", dark: "#3A342C")
    /// `LotHairlineStrong` — Abschnittslinie und Umriss.
    static let divider = Color(light: "#C8C0B2", dark: "#4A443A")
    /// Bestandsname. In Lot gibt es keine dritte Linienstaerke mehr — eine Linie, die mehr
    /// sagen soll, wird zur Flaeche oder zur Hoehe.
    static let dividerStrong = divider

    // MARK: - Bernstein: jetzt, aktiv, primaer
    //
    // Nie Warnung. Der Entwurf gibt vier Stufen an; welche wofuer taugt, ist gemessen und
    // nicht geraten.

    /// `LotAmber` — die **Flaeche**: primaerer Knopf, heutiger Tag, Drop-Ziel, Fortschritt.
    static let accentFill = Color(light: "#D9820F", dark: "#F0A034")
    /// Marke: Linien, Icons, Fokusring, Marker. Braucht 3:1.
    ///
    /// **Abweichung vom Entwurf.** Dort traegt `LotAmber` (`#D9820F`) auch diese Rolle —
    /// gemessen 2,15:1 auf dem Grund und 2,89:1 auf der Karte. Als Flaeche ist der Wert richtig
    /// (dort zaehlt, was darauf steht), als Strich auf hellem Grund ist er unsichtbar. Die Marke
    /// nimmt deshalb `LotAmberDeep`: 3,21:1 auf Grund, 4,31:1 auf Karte. Im Dunkelmodus fallen
    /// beide auf `#F0A034` zusammen — dort traegt derselbe Wert beide Rollen (8,71:1).
    static let accentMark = Color(light: "#B26608", dark: "#F0A034")
    /// `LotAmberInk` — Akzent **als Schrift** in Fliessgroesse. 4,81:1 auf Grund.
    static let accentInk = Color(light: "#8A4F06", dark: "#F5B65E")
    /// `LotAmberTint` — getoente Flaeche: Tempo-Karte, Chip, Filterpille.
    static let accentTint = Color(light: "#FEF4E6", dark: "#3A2A12")
    /// Schrift **auf** ``accentFill``.
    ///
    /// **Abweichung vom Entwurf.** Die Entwuerfe setzen Papierweiss auf Bernstein
    /// (`#FFFDFA` auf `#D9820F`) — gemessen 2,89:1, also unlesbar. Tinte auf Bernstein sind
    /// 5,92:1 hell und 8,09:1 dunkel. Damit ist dieses Token als einziges **statisch**: es
    /// kippt nicht mit dem Modus, weil Bernstein in beiden Modi hell ist. Der Ritual-Knopf des
    /// Entwurfs macht es an einer Stelle schon richtig — hier gilt es ueberall.
    static let onAccent = Color(light: "#1C1A16", dark: "#1C1A16")

    // MARK: - Rost: nur Rueckstand
    //
    // „Rost erscheint hoechstens zweimal pro Bildschirm." Nie Marke, nie „aktiv", nie ein Knopf.

    /// `LotRust` — Rueckstandsbalken, abgelaufene Kontur. 3,60:1 auf Grund.
    static let rust = Color(light: "#C4472B", dark: "#E0674A")
    /// `LotRustInk` — Rueckstandstext und Uebertrag. 6,07:1 auf Grund.
    static let rustInk = Color(light: "#8C2F1C", dark: "#E88A72")

    // MARK: - Zustaende

    /// Getoente Flaeche hinter der ausgewaehlten Zeile.
    static let highlight = surface

    // MARK: - Nutzerdaten

    /// `Goal.colorHex` ist gespeicherte, ueber CloudKit synchronisierte Nutzereingabe und wird
    /// **nicht** migriert. Werte aus den beiden Vorgaengerpaletten (Indigo, Modernist) rasten
    /// hier auf einen Lot-Ton, damit der Reskin ohne Datenmigration vollstaendig ist.
    static func goalTint(_ hex: String) -> Color {
        let normalized = hex.uppercased()
        if let mapped = legacyGoalTints[normalized] { return mapped }
        if let index = Raw.goalTints.firstIndex(of: normalized) { return goalTintColors[index] }
        // Ein Wert, der zu keinem Ton passt, bleibt wie er ist: es ist Nutzereingabe.
        return Color(hex: hex)
    }

    /// Auswahl im Zielformular. Tinte und Erde statt Regenbogen.
    ///
    /// Sie tragen **keine** Schrift — sie sind Balkenfarbe, Marker und Farbfeld. Was sie halten
    /// muessen, ist 3:1 gegen den Grund in beiden Modi; geprueft in `AnkerThemeTests`.
    static let goalTintOptions = Raw.goalTints

    private enum Raw {
        /// Die vier angebotenen Zieltoene, als gespeicherter Wert.
        static let goalTints = ["#B26608", "#1C1A16", "#5C564B", "#8C2F1C"]
    }

    /// Zu jedem gespeicherten Zielton der Farbwert, der im Dunkelmodus mitgeht — sonst ist ein
    /// dunkles Ziel als Balken auf dunklem Grund unsichtbar.
    private static let goalTintColors: [Color] = [
        accentMark,
        Color(light: "#1C1A16", dark: "#E2DCD2"),
        Color(light: "#5C564B", dark: "#A09889"),
        rustInk,
    ]

    /// Monate unterscheidbar, ohne Bedeutung zu behaupten: eine Wanderung durch die warmen
    /// Neutralen statt zwoelf Farben. `month` 1…12.
    static func monthTint(_ month: Int) -> Color {
        let tones = [
            Color(light: "#443F37", dark: "#C8C0B2"),
            Color(light: "#5C564B", dark: "#B4AC9E"),
            Color(light: "#6E6757", dark: "#A09889"),
            Color(light: "#807865", dark: "#8C8474"),
            Color(light: "#928975", dark: "#7A7365"),
            Color(light: "#A09889", dark: "#6A6357"),
        ]
        return tones[(max(month, 1) - 1) % tones.count]
    }

    private static let legacyGoalTints: [String: Color] = [
        "#5B6EE8": accentMark,      // altes Indigo
        "#C9974B": accentMark,      // altes Messing
        "#7FCDA8": Color(light: "#5C564B", dark: "#A09889"),
        "#8A8D98": Color(light: "#5C564B", dark: "#A09889"),
        "#DD2B0F": rustInk,         // Modernist-Akzent
        "#2D2B2B": Color(light: "#1C1A16", dark: "#E2DCD2"),
        "#444141": Color(light: "#1C1A16", dark: "#E2DCD2"),
        "#605D5D": Color(light: "#5C564B", dark: "#A09889"),
    ]
}

// MARK: - Ritual
//
// „Immer dunkel." Der zweite Modus des Systems ist der einzige Ort, an dem die Farbe **nicht**
// mit dem Erscheinungsbild kippt: der Rueckblick ist dunkel, auch wenn die App hell laeuft.
// Deshalb stehen hier feste Werte und keine Paare — ein `Color(light:dark:)` waere hier ein
// Fehler, kein Token.

extension AnkerColor {
    /// Die Farben des Ritual-Modus. Fest, nicht dynamisch.
    enum Ritual {
        /// Der Rand um die Flaeche.
        static let ground = Color(hex: "#14120F")
        /// Die Flaeche, auf der das Ritual steht.
        static let surface = Color(hex: "#1C1A16")
        /// Das Antwortfeld und die eingelassene Flaeche.
        static let field = Color(hex: "#2E2A24")
        /// Primaertext.
        static let ink = Color(hex: "#F6F3EE")
        /// Sekundaertext.
        static let inkSecond = Color(hex: "#C8C0B2")
        /// Metazeilen und Mikro-Beschriftung.
        static let inkMuted = Color(hex: "#A09889")
        /// Die zweite Haelfte des Bruchs, Platzhalter — **keine** Schriftfarbe fuer Information.
        static let faint = Color(hex: "#7A7365")
        /// Trennlinie.
        static let hairline = Color(hex: "#3A342C")
        /// Bernstein im Ritual — der hellere Wert, weil der Grund immer dunkel ist.
        static let amber = Color(hex: "#F0A034")
        /// Rost: „Nicht gehalten". 4,66:1 auf der Ritualflaeche.
        static let rust = Color(hex: "#E0674A")
    }
}

// MARK: - Glas
//
// „Glas nur fuer Chrome, das ueber Inhalt schwebt." Kopfzeile, Erfassungsleiste, Tableiste,
// Sheets — nie Inhalt, nie hinter Fliesstext. Das ist die eine Materialregel des Systems, und
// sie ist in `Scripts/design-guard.swift` als Schranke festgehalten.

extension AnkerColor {
    /// Deckung der Glasflaeche ueber dem Inhalt. Hell 72 %, dunkel 62 % — der Entwurf gibt
    /// beide Werte an, weil dieselbe Deckung auf dunklem Grund schwerer wirkt.
    static let glassFill = Color(hex: "#F6F3EEB8", darkHex: "#2320199E")
    /// Die Lichtkante innen oben. Dunkel auf 14 %, „mehr wirkt wie eine Naht".
    static let glassSheen = Color(hex: "#FFFFFFB3", darkHex: "#FFFFFF24")
}

// MARK: - Hoehe
//
// Vier Stufen, jede mit einem Zweck. Der Entwurf ordnet sie ausdruecklich zu; ein fuenfter
// Schatten waere eine Ebene ohne Bedeutung.

/// Hoehe nach Rolle. `AnkerElevation` war im Modernist-System ein leeres Enum („nichts
/// schwebt") — Lot dreht das um: Naehe entsteht durch Material und Hoehe statt durch Rahmen.
enum AnkerElevation: Sendable {
    /// Listenzeilen und eingebettete Felder. Kein Schatten, eine Haarlinie traegt die Kante.
    case flat
    /// Karten und Gruppen.
    case card
    /// Gezogene Aufgabe, Popover, Menue.
    case lifted
    /// Sheet und Dialog. Sonst nichts.
    case sheet

    /// Die enge Lage macht die Kante sichtbar, die weite die Ebene.
    var layers: [(color: Color, radius: CGFloat, y: CGFloat)] {
        switch self {
        case .flat:
            []
        case .card:
            [(AnkerColor.elevationNear, 2, 1), (AnkerColor.elevationFar, 18, 8)]
        case .lifted:
            [(AnkerColor.elevationNear, 3, 1), (AnkerColor.elevationFar, 26, 12)]
        case .sheet:
            [(AnkerColor.elevationNear, 4, 2), (AnkerColor.elevationFar, 48, 24)]
        }
    }
}

extension AnkerColor {
    /// Die enge Schattenlage — macht die Kante sichtbar.
    static let elevationNear = Color(hex: "#1C1A1614", darkHex: "#00000073")
    /// Die weite Lage — macht die Ebene sichtbar.
    static let elevationFar = Color(hex: "#1C1A1621", darkHex: "#0000004D")
}

// MARK: - Metriken

/// Das Abstandsraster des Entwurfs: 4 · 8 · 12 · 16 · 20 · 24 · 32 · 44 · 56.
enum AnkerSpacing {
    static let s1: CGFloat = 4
    static let s2: CGFloat = 8
    static let s3: CGFloat = 12
    static let s4: CGFloat = 16
    /// Der Standardrand am Telefon.
    static let s5: CGFloat = 20
    static let s6: CGFloat = 24
    static let s7: CGFloat = 32
    /// Die Mindestgroesse jedes Fingerziels.
    static let touchTarget: CGFloat = 44
    /// Der Sprung zwischen Sektionen.
    static let section: CGFloat = 56

    /// Bestandsnamen, auf das Lot-Raster gelegt. Damit rasten rund 30 Aufrufstellen ohne
    /// eigene Aenderung gemeinsam ein.
    static let screenPadding = s5
    static let stack = s3

    /// Im Ritual-Modus wird jeder Wert weiter: „Dichte 1.4".
    static func ritual(_ value: CGFloat) -> CGFloat { (value * 1.4).rounded() }

    /// Abstand **innerhalb** einer Markergruppe — die sieben Tagesquadrate des Wochenpulses.
    /// Kein Layoutrhythmus, sondern die Koernung des Rasters.
    static let markerGap: CGFloat = 2
    /// Einzug der Tageszeilen in der Zeitschiene — unter der Wochenbeschriftung, nicht unter
    /// deren Quadraten.
    static let sidebarIndent: CGFloat = 28
}

enum AnkerBorder {
    /// **Abschnittsgrenze.** In Lot eine Haarlinie: die Trennung traegt Hoehe und Flaeche,
    /// nicht mehr die Strichstaerke.
    static let rule: CGFloat = 1
    /// **Trenner innerhalb einer Liste.**
    static let hairline: CGFloat = 1
    /// Umriss eines Bedienelements und der Fokusring — das Einzige, was in Lot noch zwei
    /// Punkte stark ist.
    static let focus: CGFloat = 2
    /// Kontur eines Kaestchens oder einer Auswahl.
    static let heavy: CGFloat = 2
}

/// Radius nach Rolle, nicht nach Zahl — 4pt-Basis, durchgehend `.continuous`.
///
/// Lot rundet alles, was Objekt ist. **Ohne Radius bleiben genau zwei Dinge:** der Wochenpuls
/// (die sieben Felder muessen als Raster lesbar bleiben) und der Fortschrittsbalken (ein rundes
/// Ende luegt ueber den Wert). Beide zeichnen deshalb `Rectangle` und haben hier kein Token.
enum AnkerRadius {
    /// Haekchen und Chip.
    static let check: CGFloat = 8
    /// Knopf und Eingabefeld.
    static let control: CGFloat = 12
    /// Karte.
    static let card: CGFloat = 16
    /// Sheet und Gruppe.
    static let group: CGFloat = 20
    /// Glasleiste.
    static let glass: CGFloat = 28
    /// Filter und Zaehler laufen als Pille — ueber `Capsule()`, nicht ueber eine Zahl.
    static let tile = control
}

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
