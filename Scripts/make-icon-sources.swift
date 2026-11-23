import AppKit
import ImageIO
import SwiftUI

// Zeichnet die Icon-Vorlagen von „Blatt" nach `assets/icon/` — aus der Repowurzel aufrufen:
//
//     swift Scripts/make-icon-sources.swift
//     swift Scripts/make-app-icons.swift      # leitet daraus den Katalog ab
//
// Das Motiv ist das Blatt selbst: vier Reihen zu fünf Quadraten — vier Anker, ihre Aufgaben.
// Erledigtes ist gefüllt, in der einen Farbe der App; Offenes ist nur eine Kante. Kein Verlauf,
// kein Schatten, kein Glas: dieselbe Sprache wie die Oberfläche.
//
// Die Füllung folgt keiner Woche, sondern einer Lesbarkeit: jede Reihe anders weit, damit das
// Raster auch bei 16 px noch als „Fortschritt in Reihen" lesbar bleibt und nicht als Gitter.

struct Palette {
    let ground: Color
    let filled: Color
    let open: Color
}

let light = Palette(ground: Color(red: 1, green: 1, blue: 1),
                    filled: Color(red: 0x23 / 255, green: 0x33 / 255, blue: 0x8A / 255),
                    open: Color(red: 0xC9 / 255, green: 0xCC / 255, blue: 0xD1 / 255))
let dark = Palette(ground: Color(red: 0x11 / 255, green: 0x13 / 255, blue: 0x17 / 255),
                   filled: Color(red: 0x8C / 255, green: 0x9B / 255, blue: 0xFF / 255),
                   open: Color(red: 0x3A / 255, green: 0x3F / 255, blue: 0x48 / 255))
/// iOS färbt diese Variante selbst ein und erwartet dafür Graustufen auf Schwarz.
let tinted = Palette(ground: Color(red: 0, green: 0, blue: 0),
                     filled: Color(red: 1, green: 1, blue: 1),
                     open: Color(red: 0.32, green: 0.32, blue: 0.32))

/// Erledigte Quadrate pro Reihe, von fünf.
let progress = [4, 2, 3, 1]

/// Das Raster auf einer Fläche der Kantenlänge `canvas`.
struct Sheet: View {
    let canvas: CGFloat
    let palette: Palette?
    /// Für die Menüleiste: nur Formen, schwarz auf transparent — macOS färbt selbst.
    var template = false

    var body: some View {
        // 5 Spalten, 4 Reihen. Auf 1024 Punkten: Quadrat 120, Abstand 40 → 760 × 600, zentriert.
        let unit = canvas / 1024
        let square = 120 * unit
        let gap = 40 * unit
        let radius = 28 * unit
        let stroke = max(14 * unit, template ? 1.4 : 0.8)

        ZStack {
            if let palette, !template { palette.ground }
            VStack(spacing: gap) {
                ForEach(0..<4, id: \.self) { row in
                    HStack(spacing: gap) {
                        ForEach(0..<5, id: \.self) { column in
                            let isDone = column < progress[row]
                            let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
                            if template {
                                if isDone {
                                    shape.fill(Color.black)
                                } else {
                                    shape.strokeBorder(Color.black, lineWidth: stroke)
                                }
                            } else if let palette {
                                if isDone {
                                    shape.fill(palette.filled)
                                } else {
                                    shape.strokeBorder(palette.open, lineWidth: stroke)
                                }
                            }
                        }
                        .frame(width: square, height: square)
                    }
                }
            }
        }
        .frame(width: canvas, height: canvas)
    }
}

/// Die Menüleiste ist 18 pt hoch und breiter als hoch erlaubt — das Raster ohne Rand.
struct MenuGlyph: View {
    let height: CGFloat

    var body: some View {
        let square = height * 0.19
        let gap = height * 0.07
        let radius = square * 0.22
        VStack(spacing: gap) {
            ForEach(0..<4, id: \.self) { row in
                HStack(spacing: gap) {
                    ForEach(0..<5, id: \.self) { column in
                        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
                        if column < progress[row] {
                            shape.fill(Color.black)
                        } else {
                            shape.strokeBorder(Color.black, lineWidth: max(1, height / 18))
                        }
                    }
                    .frame(width: square, height: square)
                }
            }
        }
        .frame(width: height * 1.3, height: height)
    }
}

func writePNG(_ image: CGImage, to url: URL) -> Bool {
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
        return false
    }
    CGImageDestinationAddImage(destination, image, nil)
    return CGImageDestinationFinalize(destination)
}

@MainActor
func render<V: View>(_ view: V, opaque: Bool, to url: URL) -> Bool {
    let renderer = ImageRenderer(content: view)
    renderer.scale = 1
    renderer.isOpaque = opaque
    guard let image = renderer.cgImage else { return false }
    return writePNG(image, to: url)
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let sources = root.appendingPathComponent("assets/icon")
let menuTarget = root.appendingPathComponent("Anchor/Assets.xcassets/MenuBarTemplate.imageset")
var failures = 0

MainActor.assumeIsolated {
    let jobs: [(String, AnyView, Bool)] = [1024, 512, 256, 128, 64, 48, 32, 24, 16].map { size in
        ("AppIcon-\(size).png", AnyView(Sheet(canvas: CGFloat(size), palette: light)), true)
    } + [1024, 512, 256].map { size in
        // „DocumentIcon" ist im Iconskript die dunkle Erscheinung auf iOS.
        ("DocumentIcon-\(size).png", AnyView(Sheet(canvas: CGFloat(size), palette: dark)), true)
    } + [
        ("TintedIcon-1024.png", AnyView(Sheet(canvas: 1024, palette: tinted)), true),
    ]

    for (name, view, opaque) in jobs {
        let ok = render(view, opaque: opaque, to: sources.appendingPathComponent(name))
        print("  \(ok ? "✓" : "✗") \(name)")
        if !ok { failures += 1 }
    }

    // Menüleiste: Vorlage in assets/icon und direkt im Katalog.
    for (height, scale) in [(18.0, 1), (18.0, 2), (16.0, 1), (16.0, 2), (16.0, 3)] {
        let suffix = scale == 1 ? "" : "-\(scale)x"
        let name = "MenuBarTemplate-\(Int(height))\(suffix).png"
        let view = MenuGlyph(height: height * Double(scale))
        let ok = render(view, opaque: false, to: sources.appendingPathComponent(name))
        if Int(height) == 18 {
            _ = render(view, opaque: false, to: menuTarget.appendingPathComponent(name))
        }
        print("  \(ok ? "✓" : "✗") \(name)")
        if !ok { failures += 1 }
    }
}

if failures == 0 {
    print("\nmake-icon-sources: Vorlagen gezeichnet. Jetzt `swift Scripts/make-app-icons.swift`.")
    exit(0)
}
print("\nmake-icon-sources: \(failures) Dateien nicht geschrieben.")
exit(1)
