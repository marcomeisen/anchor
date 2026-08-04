import SwiftUI

/// Ein Typo-Token: Groesse, Gewicht, Laufweite, Grossschreibung, Ziffernbreite.
///
/// `Font` allein traegt weder Laufweite noch Grossschreibung, deshalb ist ein Token ein
/// Wertetyp und wird ueber `.ankerType(_:)` angewandt statt ueber `.font(_:)`.
struct AnkerTextStyle: Sendable, Hashable {
    let size: CGFloat
    let weight: AnkerFontWeight
    /// Laufweite in em, wie im Entwurfsdokument notiert (-0,05 bis +0,16).
    let trackingEm: CGFloat
    let isUppercase: Bool
    /// Tabellarische Ziffern — fuer alles, was in einer Spalte untereinander steht.
    let isTabular: Bool

    init(
        size: CGFloat,
        weight: AnkerFontWeight,
        trackingEm: CGFloat = 0,
        uppercase: Bool = false,
        tabular: Bool = false
    ) {
        self.size = size
        self.weight = weight
        self.trackingEm = trackingEm
        self.isUppercase = uppercase
        self.isTabular = tabular
    }

    var font: Font { AnkerFont.archivo(weight, size: size, tabular: isTabular) }
    var tracking: CGFloat { size * trackingEm }
}

/// Die Typo-Skala des Entwurfs. Sie ersetzt 191 einzelne `.font(.system(size:))`-Stellen.
enum AnkerType {

    // MARK: - Display

    /// 96/900 — die eine grosse Zahl auf dem Rueckblick-Plakat.
    static let poster = AnkerTextStyle(size: 96, weight: .black, trackingEm: -0.05, tabular: true)
    /// 56/900
    static let display = AnkerTextStyle(size: 56, weight: .black, trackingEm: -0.025, tabular: true)
    /// 40/900 — Kopfzeile der Matrix.
    static let title1 = AnkerTextStyle(size: 40, weight: .black, trackingEm: -0.03, tabular: true)
    /// 34/900
    static let title2 = AnkerTextStyle(size: 34, weight: .black, trackingEm: -0.03, tabular: true)
    /// 29/900 — Bildschirmtitel auf dem iPhone.
    static let title3 = AnkerTextStyle(size: 29, weight: .black, trackingEm: -0.02, tabular: true)

    // MARK: - Fliesstext

    /// 20/900
    static let headline = AnkerTextStyle(size: 20, weight: .black, trackingEm: -0.01)
    /// 17/800
    static let subheadline = AnkerTextStyle(size: 17, weight: .extraBold, trackingEm: -0.005)
    /// 17/700 — Aufgabentitel.
    static let taskTitle = AnkerTextStyle(size: 17, weight: .bold, trackingEm: -0.005)
    /// 15/700
    static let bodyStrong = AnkerTextStyle(size: 15, weight: .bold)
    /// 15/500 — der Grundtext.
    static let body = AnkerTextStyle(size: 15, weight: .medium)
    /// 14/800 — Beschriftung in Schaltflaechen.
    static let label = AnkerTextStyle(size: 14, weight: .extraBold)
    /// 13/800
    static let metaStrong = AnkerTextStyle(size: 13, weight: .extraBold)
    /// 13/600
    static let meta = AnkerTextStyle(size: 13, weight: .semibold)
    /// 12/700
    static let caption = AnkerTextStyle(size: 12, weight: .bold)

    // MARK: - Mikrobeschriftungen, immer in Grossbuchstaben

    /// 11/800, +0,12 em
    static let overline = AnkerTextStyle(size: 11, weight: .extraBold, trackingEm: 0.12, uppercase: true)
    /// 10/800, +0,16 em — die Abschnittsmarken des Entwurfs.
    static let eyebrow = AnkerTextStyle(size: 10, weight: .extraBold, trackingEm: 0.16, uppercase: true)
    /// 9/800, +0,08 em — Prioritaetsbuchstabe.
    static let microLabel = AnkerTextStyle(size: 9, weight: .extraBold, trackingEm: 0.08, uppercase: true)

    // MARK: - Zahlenspalten

    /// 15/700, tabellarisch
    static let numeric = AnkerTextStyle(size: 15, weight: .bold, tabular: true)
    /// 12/700, tabellarisch
    static let numericSmall = AnkerTextStyle(size: 12, weight: .bold, tabular: true)
    /// 32/900, tabellarisch — Kennzahlen in Rastern.
    static let statValue = AnkerTextStyle(size: 32, weight: .black, trackingEm: -0.03, tabular: true)
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
