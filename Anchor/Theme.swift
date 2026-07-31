import SwiftUI

enum AnkerColor {
    static let indigo = Color(hex: "#5B6EE8", darkHex: "#7F8DFF")
    static let indigoDark = Color(hex: "#3F4FBF", darkHex: "#A8B1FF")
    static let brass = Color(hex: "#C9974B", darkHex: "#E0B56C")
    static let ink = Color(hex: "#1C1E27", darkHex: "#F1F2F7")
    static let paper = Color(hex: "#F7F7FA", darkHex: "#101116")
    static let card = Color(hex: "#FFFFFF", darkHex: "#17181F")
    static let line = Color(hex: "#E4E5EA", darkHex: "#2A2C36")
    static let lineSoft = Color(hex: "#EDEEF2", darkHex: "#202127")
    static let muted = Color(hex: "#8A8D98", darkHex: "#AEB0BA")
    static let success = Color(hex: "#34C759", darkHex: "#4FDB74")
    static let prioA = Color(hex: "#E0574D", darkHex: "#FF746B")

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
    init(hex: String, darkHex: String? = nil) {
        let light = PlatformColor(hex: hex)
        let dark = darkHex.map(PlatformColor.init(hex:))

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
