import SwiftUI

/// Ein Typo-Token: Familie, Groesse, Gewicht, Laufweite, Grossschreibung, Ziffernbreite.
///
/// `Font` allein traegt weder Laufweite noch Grossschreibung, deshalb ist ein Token ein
/// Wertetyp und wird ueber `.ankerType(_:)` angewandt statt ueber `.font(_:)`.
struct AnkerTextStyle: Sendable, Hashable {
    let family: AnkerFontFamily
    let size: CGFloat
    let weight: AnkerFontWeight
    /// Laufweite in em, wie im Entwurfsdokument notiert (-0,04 bis +0,16).
    let trackingEm: CGFloat
    let isUppercase: Bool
    /// Tabellarische Ziffern — fuer alles, was in einer Spalte untereinander steht.
    let isTabular: Bool

    init(
        family: AnkerFontFamily = .workface,
        size: CGFloat,
        weight: AnkerFontWeight = .regular,
        trackingEm: CGFloat = 0,
        uppercase: Bool = false,
        tabular: Bool = false
    ) {
        self.family = family
        self.size = size
        self.weight = weight
        self.trackingEm = trackingEm
        self.isUppercase = uppercase
        self.isTabular = tabular
    }

    var font: Font { AnkerFont.font(family, weight: weight, size: size, tabular: isTabular) }
    var tracking: CGFloat { size * trackingEm }
}

/// Die Typo-Skala von Lot.
///
/// Zwei Familien, acht Rollen — der Entwurf zaehlt sie so auf. Die zwanzig Tokennamen des
/// Modernist-Systems bleiben erhalten und rasten auf diese acht Rollen ein; das haelt rund 190
/// Aufrufstellen unveraendert, waehrend sich Familie, Grad und Gewicht darunter komplett
/// wechseln.
///
/// **Die Serif ist Display, sonst nichts.** Sie erscheint nur im Ritual und nie unter 28 pt —
/// beides ist in `AnkerThemeTests` festgehalten.
enum AnkerType {

    // MARK: - Ritual (Instrument Serif)

    /// `LotDisplay` — 104/Serif. Die eine grosse Zahl im Rueckblick. Der einzige Ort, an dem
    /// eine Kennzahl gross sein darf.
    ///
    /// **Bewusst nicht tabellarisch.** Das Systemblatt verlangt „Ziffern immer tabellarisch",
    /// und Instrument Serif kann das nicht: die Schrift bringt keine `tnum`-Tabelle mit, das
    /// OpenType-Feature laeuft ins Leere (gemessen bei 20 pt: „1" 4,98 pt gegen „0" 9,20 pt,
    /// vor **und** nach dem Setzen des Features). Die beiden Regeln des Entwurfs sind an
    /// dieser einen Stelle unvereinbar; die Serif gewinnt, weil sie den Modus markiert.
    ///
    /// Damit die Zahl beim Wochenschluss trotzdem nicht springt, steht der Zaehler in einem
    /// festen Kaesten — siehe `WeeklyReviewView.ritualCount`. `AnkerThemeTests` haelt fest,
    /// dass die breiteste Ziffer in diesen Kasten passt.
    static let poster = AnkerTextStyle(family: .ritual, size: 104, trackingEm: -0.04)
    /// 54/Serif — die Zahl in der engeren Fassung (Telefon, Popover). Siehe ``poster``.
    static let display = AnkerTextStyle(family: .ritual, size: 54, trackingEm: -0.03)
    /// `LotRitualTitle` — 31/Serif. Die Aussage unter der Zahl.
    static let ritualTitle = AnkerTextStyle(family: .ritual, size: 31, trackingEm: -0.015)
    /// 28/Serif — die eine Frage. Der Kleinstwert, den die Regel zulaesst.
    static let ritualQuestion = AnkerTextStyle(family: .ritual, size: 28, trackingEm: -0.015)

    // MARK: - Arbeitsflaeche (San Francisco)

    /// `LotWindowTitle` — 40/600. Nur die Mac-Kopfzeile.
    static let title1 = AnkerTextStyle(size: 40, weight: .semibold, trackingEm: -0.03, tabular: true)
    /// 34/600
    static let title2 = AnkerTextStyle(size: 34, weight: .semibold, trackingEm: -0.03, tabular: true)
    /// `LotTitle` — 29/600. Bildschirmtitel auf dem iPhone.
    static let title3 = AnkerTextStyle(size: 29, weight: .semibold, trackingEm: -0.02, tabular: true)

    /// 20/600
    static let headline = AnkerTextStyle(size: 20, weight: .semibold, trackingEm: -0.01)
    /// 17/600
    static let subheadline = AnkerTextStyle(size: 17, weight: .semibold, trackingEm: -0.005)
    /// `LotBody` — 17/500. Der Aufgabentitel; ab hier greift Dynamic Type.
    static let taskTitle = AnkerTextStyle(size: 17, weight: .medium)
    /// 15/600
    static let bodyStrong = AnkerTextStyle(size: 15, weight: .semibold)
    /// `LotBodySmall` — 15/500. Der Grundtext einer Kartenzeile.
    static let body = AnkerTextStyle(size: 15, weight: .medium)
    /// 14/600 — Beschriftung in Schaltflaechen.
    static let label = AnkerTextStyle(size: 14, weight: .semibold)
    /// 13/600
    static let metaStrong = AnkerTextStyle(size: 13, weight: .semibold)
    /// `LotCaption` — 12,5/500, Ziffern tabellarisch.
    static let meta = AnkerTextStyle(size: 12.5, weight: .medium, tabular: true)
    /// 12,5/500
    static let caption = AnkerTextStyle(size: 12.5, weight: .medium)

    // MARK: - Mikrobeschriftungen, immer in Grossbuchstaben
    //
    // „Nie als Fliesstext."

    /// 11/600, +0,13 em
    static let overline = AnkerTextStyle(size: 11, weight: .semibold, trackingEm: 0.13, uppercase: true)
    /// `LotOverline` — 10,5/600, +0,13 em. Die Abschnittsmarken des Entwurfs.
    static let eyebrow = AnkerTextStyle(size: 10.5, weight: .semibold, trackingEm: 0.13, uppercase: true)
    /// 10/600, +0,08 em — Prioritaetsbuchstabe.
    static let microLabel = AnkerTextStyle(size: 10, weight: .semibold, trackingEm: 0.08, uppercase: true)

    // MARK: - Zahlenspalten
    //
    // „Ziffern immer tabellarisch. Jede Kennzahl, jedes Datum, jeder Bruch — sonst springt
    // ‚3/5' gegen ‚1/2', sobald sich etwas aktualisiert."

    /// 15/600, tabellarisch
    static let numeric = AnkerTextStyle(size: 15, weight: .semibold, tabular: true)
    /// 12,5/500, tabellarisch
    static let numericSmall = AnkerTextStyle(size: 12.5, weight: .medium, tabular: true)
    /// 32/600, tabellarisch — Kennzahlen in Rastern.
    static let statValue = AnkerTextStyle(size: 32, weight: .semibold, trackingEm: -0.03, tabular: true)

    /// Alle Tokens mit ihrem Namen — die Pruefliste von `AnkerThemeTests`. Ein neues Token, das
    /// hier fehlt, wird nicht geprueft; deshalb steht die Liste hier und nicht im Test.
    static let all: [(name: String, style: AnkerTextStyle)] = [
        ("poster", poster), ("display", display),
        ("ritualTitle", ritualTitle), ("ritualQuestion", ritualQuestion),
        ("title1", title1), ("title2", title2), ("title3", title3),
        ("headline", headline), ("subheadline", subheadline),
        ("taskTitle", taskTitle), ("bodyStrong", bodyStrong),
        ("body", body), ("label", label),
        ("metaStrong", metaStrong), ("meta", meta),
        ("caption", caption), ("overline", overline),
        ("eyebrow", eyebrow), ("microLabel", microLabel),
        ("numeric", numeric), ("numericSmall", numericSmall),
        ("statValue", statValue),
    ]
}

extension View {
    /// Schrift, Laufweite und Grossschreibung in einem Zug.
    func ankerType(_ style: AnkerTextStyle) -> some View {
        font(style.font)
            .tracking(style.tracking)
            .textCase(style.isUppercase ? .uppercase : nil)
    }
}

extension Text {
    /// Fuer Stellen, die ein `Text` bleiben muessen — Verkettung mit `+`, `Label`-Slots.
    /// Setzt **keine** Grossschreibung; die bleibt beim Aufrufer.
    func ankerType(_ style: AnkerTextStyle) -> Text {
        font(style.font).tracking(style.tracking)
    }
}
