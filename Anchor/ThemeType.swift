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

    var font: Font { AnkerFont.system(weight, size: size, tabular: isTabular) }
    var tracking: CGFloat { size * trackingEm }
}

/// Die Typo-Skala des Entwurfs. Sie ersetzt 191 einzelne `.font(.system(size:))`-Stellen.
enum AnkerType {
    // MARK: Schlagzeilen — schwer, eng gesetzt

    static let poster = AnkerTextStyle(size: 72, weight: .extraBold, trackingEm: -0.04, tabular: true)
    static let display = AnkerTextStyle(size: 48, weight: .extraBold, trackingEm: -0.035, tabular: true)
    static let title1 = AnkerTextStyle(size: 40, weight: .extraBold, trackingEm: -0.035, tabular: true)
    static let title2 = AnkerTextStyle(size: 34, weight: .extraBold, trackingEm: -0.035, tabular: true)
    static let title3 = AnkerTextStyle(size: 30, weight: .extraBold, trackingEm: -0.03, tabular: true)

    // MARK: Text

    static let headline = AnkerTextStyle(size: 22, weight: .bold, trackingEm: -0.01)
    static let subheadline = AnkerTextStyle(size: 17, weight: .semibold)
    /// Der Titel einer Aufgabe. Mittel, nicht fett — die Liste soll ruhig bleiben.
    static let taskTitle = AnkerTextStyle(size: 16, weight: .medium)
    static let bodyStrong = AnkerTextStyle(size: 15, weight: .semibold)
    static let body = AnkerTextStyle(size: 15, weight: .medium)
    static let label = AnkerTextStyle(size: 14, weight: .semibold)
    static let metaStrong = AnkerTextStyle(size: 13, weight: .semibold)
    static let meta = AnkerTextStyle(size: 13, weight: .medium)
    static let caption = AnkerTextStyle(size: 12, weight: .semibold)

    // MARK: Beschriftungen — in „Blatt" in normaler Schreibung, nicht in Versalien

    static let overline = AnkerTextStyle(size: 13, weight: .semibold)
    static let eyebrow = AnkerTextStyle(size: 12, weight: .semibold)
    static let microLabel = AnkerTextStyle(size: 11, weight: .semibold)

    // MARK: Zahlen — tabellarisch, damit Spalten stehen

    /// Die Ankernummer neben einem Titel.
    static let anchorNumber = AnkerTextStyle(size: 22, weight: .heavyNumber, trackingEm: -0.02, tabular: true)
    static let numeric = AnkerTextStyle(size: 15, weight: .semibold, tabular: true)
    static let numericSmall = AnkerTextStyle(size: 12, weight: .semibold, tabular: true)
    static let statValue = AnkerTextStyle(size: 28, weight: .extraBold, trackingEm: -0.03, tabular: true)
}

private extension AnkerFontWeight {
    static let heavyNumber = AnkerFontWeight.extraBold
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
