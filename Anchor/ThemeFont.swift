import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Die Gewichte, die das Designsystem benutzt.
///
/// „Blatt" setzt in der **Systemschrift** (SF Pro). Archivo ist entfallen: die Entwürfe sind in
/// einer neutralen Grotesk gesetzt, SF steht ihr am nächsten — und nur die Systemschrift
/// wächst mit Dynamic Type mit, ohne dass eine Schriftdatei mitgeliefert werden muss.
enum AnkerFontWeight: Int, CaseIterable, Sendable {
    case medium = 500
    case semibold = 600
    case bold = 700
    case extraBold = 800
    case black = 900

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

enum AnkerFont {
    /// Die Schrift eines Tokens. Auf dem iPhone und iPad mit Dynamic Type skaliert, auf dem
    /// Mac in der festen Größe des Entwurfs.
    static func system(_ weight: AnkerFontWeight, size: CGFloat, tabular: Bool) -> Font {
        let font = Font.system(size: scaled(size), weight: weight.systemWeight)
        return tabular ? font.monospacedDigit() : font
    }

    /// Skaliert wie die passende Textstufe des Systems — ein 16pt-Titel wächst wie `callout`.
    static func scaled(_ size: CGFloat) -> CGFloat {
#if canImport(UIKit)
        let style: UIFont.TextStyle = switch size {
        case 28...: .largeTitle
        case 20..<28: .title3
        case 15..<20: .body
        case 13..<15: .footnote
        default: .caption1
        }
        return UIFontMetrics(forTextStyle: style).scaledValue(for: size)
#else
        return size
#endif
    }
}
