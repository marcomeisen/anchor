import SwiftUI

enum AnkerColor {
    static let appBackground = Color(light: "#F7F7FA", dark: "#111219")
    static let surface = Color(light: "#FFFFFF", dark: "#1C1D24")
    static let surfaceRaised = Color(light: "#FFFFFF", dark: "#23242D")
    static let line = Color(light: "#E4E5EA", dark: "#FFFFFF1F")
    static let lineSoft = Color(light: "#EDEEF2", dark: "#FFFFFF12")
    static let textStrong = Color(light: "#1C1E27", dark: "#F2F2F7")
    static let textSoft = Color(light: "#8A8D98", dark: "#A6A9B5")

    static let indigo = Color(hex: "#5B6EE8")
    static let indigoBadge = Color(hex: "#4D61E6")
    static let indigoText = Color(light: "#3F4FBF", dark: "#90A0F5")
    static let brass = Color(light: "#C9974B", dark: "#E0BC85")
    static let successIcon = Color(hex: "#2A9F47")
    static let prioA = Color(hex: "#D93327")
    static let prioC = Color(hex: "#6E7180")

    static let ink = textStrong
    static let paper = appBackground
    static let card = surface
    static let muted = textSoft
    static let indigoDark = indigoText
    static let success = successIcon
    /// Rot fuer destruktive Aktionen. Gleicher Farbwert wie `prioA`, aber eigene Benennung —
    /// eine Loeschaktion ist keine Prioritaet A und soll sich unabhaengig davon aendern lassen.
    static let destructive = prioA

    static let month: [Color] = [
        "#8FA8E8", "#7FCDA8", "#B9D97A", "#F0C955",
        "#F0A968", "#F09EA9", "#C79BE8", "#A79BE8",
        "#7FB4E8", "#6FD6C4", "#AEB0BA", "#E8B98A"
    ].map { Color(hex: $0) }
}

enum AnkerRadius {
    static let card: CGFloat = 11
    static let pill: CGFloat = 14
    static let sheet: CGFloat = 13
}

enum AnkerSpacing {
    static let screenPadding: CGFloat = 20
    static let stack: CGFloat = 10
}

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
        self.init(
            calibratedRed: components.red,
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
