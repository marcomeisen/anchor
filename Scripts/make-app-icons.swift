import AppKit
import ImageIO
import SwiftUI

// Erzeugt den App-Iconsatz aus den Vorlagen in `assets/icon/` — aus der Repowurzel aufrufen:
//
//     swift Scripts/make-app-icons.swift
//
// Warum ein Skript und kein Handgriff: die macOS-Varianten sind **abgeleitet**. Sie entstehen aus
// derselben 1024er Vorlage, und ihre Geometrie folgt einer Vorschrift, die man nachlesen können
// muss, statt sie in sieben Dateien zu vermuten.
//
// Die beiden Plattformen brauchen ausdrücklich Verschiedenes:
//
// **macOS** maskiert App-Icons *nicht*. Die Form muss mitgeliefert werden — nach Apples Raster:
// auf 1024 Punkten Fläche ein Körper von 824×824 zentriert (also 100 Punkte Rand) mit einem
// Eckenradius von 185,4. Der Rand bleibt transparent, die Datei braucht also einen Alphakanal.
// Ohne das steht die App im Dock als randloses Quadrat neben allen anderen.
//
// **iOS** maskiert selbst, und zwar mit demselben fortlaufend gerundeten Quadrat. Dort muss das
// Bild randlos und **ohne** Alphakanal sein: eine mitgelieferte Rundung ergäbe eine doppelte
// Kante, und der App Store lehnt einen Alphakanal ab — auch einen vollständig deckenden.
//
// Die Ecke entsteht über SwiftUIs `RoundedRectangle(style: .continuous)` statt über einen
// Kreisbogen: Apples Ecke ist eine fortlaufende Kurve, ein `CGPath(roundedRect:)` wäre sichtbar
// kantiger. Bewusst **ohne** den Schatten aus Apples Vorlage — er ist nicht verlangt, und das
// Designsystem dieses Projekts kennt keinen.

let bodyRatio = 824.0 / 1024.0
let cornerRatio = 185.4 / 824.0
/// Die Größen, die `AppIcon.appiconset` für macOS in 1x und 2x braucht.
let macSizes = [16, 32, 64, 128, 256, 512, 1024]

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let sources = root.appendingPathComponent("assets/icon")
let target = root.appendingPathComponent("Anchor/Assets.xcassets/AppIcon.appiconset")

guard FileManager.default.fileExists(atPath: sources.path),
      FileManager.default.fileExists(atPath: target.path) else {
    print("make-app-icons: assets/icon oder AppIcon.appiconset nicht gefunden — aus der Repowurzel aufrufen.")
    exit(2)
}

func writePNG(_ image: CGImage, to url: URL) -> Bool {
    // Erst daneben schreiben, dann ersetzen: die Quelle kann dieselbe Datei sein, und
    // `CGImageSource` liest verzögert.
    let temporary = url.deletingLastPathComponent().appendingPathComponent(".new-" + url.lastPathComponent)
    guard let destination = CGImageDestinationCreateWithURL(temporary as CFURL, "public.png" as CFString, 1, nil) else {
        return false
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { return false }
    try? FileManager.default.removeItem(at: url)
    do { try FileManager.default.moveItem(at: temporary, to: url) } catch { return false }
    return true
}

/// macOS: gerundeter Körper mit transparentem Rand.
@MainActor
func renderMac(from source: URL, size: Int, to destination: URL) -> Bool {
    guard let image = NSImage(contentsOf: source) else { return false }
    let canvas = Double(size)
    let body = canvas * bodyRatio

    let view = ZStack {
        Color.clear
        Image(nsImage: image)
            .resizable()
            .interpolation(.high)
            .frame(width: body, height: body)
            .clipShape(RoundedRectangle(cornerRadius: body * cornerRatio, style: .continuous))
    }
    .frame(width: canvas, height: canvas)

    let renderer = ImageRenderer(content: view)
    renderer.scale = 1
    renderer.isOpaque = false
    guard let cgImage = renderer.cgImage else { return false }
    return writePNG(cgImage, to: destination)
}

/// iOS: randlos, Alphakanal entfernt.
///
/// Bewusst reines CoreGraphics: `NSImage.draw` in einen selbst gesetzten `NSGraphicsContext`
/// zeichnet in einem Prozess ohne `NSApplication` nichts, die Bitmap bleibt genullt — das war
/// schon einmal der Fehler, und er fiel nur an gleichen Prüfsummen auf.
func copyWithoutAlpha(from source: URL, to destination: URL) -> Bool {
    guard let imageSource = CGImageSourceCreateWithURL(source as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil),
          let space = CGColorSpace(name: CGColorSpace.sRGB),
          let context = CGContext(
            data: nil, width: image.width, height: image.height,
            bitsPerComponent: 8, bytesPerRow: 0, space: space,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
          ) else { return false }

    context.interpolationQuality = .high
    context.draw(image, in: CGRect(x: 0, y: 0, width: Double(image.width), height: Double(image.height)))
    guard let flat = context.makeImage() else { return false }
    return writePNG(flat, to: destination)
}

var failures = 0

MainActor.assumeIsolated {
    let lightSource = sources.appendingPathComponent("AppIcon-1024.png")
    // Dieselbe Marke auf dunklem Grund. Die App hat keinen Dokumenttyp, für den ein
    // Dokument-Icon Verwendung hätte — hier ist es die dunkle Erscheinung auf iOS.
    let darkSource = sources.appendingPathComponent("DocumentIcon-1024.png")

    for (source, name) in [(lightSource, "AppIcon-1024.png"), (darkSource, "AppIcon-dark-1024.png")] {
        let ok = copyWithoutAlpha(from: source, to: target.appendingPathComponent(name))
        print("  \(ok ? "✓" : "✗") \(name) — iOS, randlos, ohne Alpha")
        if !ok { failures += 1 }
    }

    for size in macSizes {
        let name = "AppIconMac-\(size).png"
        let ok = renderMac(from: lightSource, size: size, to: target.appendingPathComponent(name))
        print("  \(ok ? "✓" : "✗") \(name) — macOS, Körper \(Int(Double(size) * bodyRatio)) px, Rand \(Int((Double(size) - Double(size) * bodyRatio) / 2)) px")
        if !ok { failures += 1 }
    }
}

if failures == 0 {
    print("\nmake-app-icons: Iconsatz erzeugt.")
    exit(0)
}
print("\nmake-app-icons: \(failures) Dateien nicht geschrieben.")
exit(1)
