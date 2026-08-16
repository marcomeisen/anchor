#!/usr/bin/env swift

// Erzeugt den App-Iconsatz von **Lot** — aus der Repowurzel aufrufen:
//
//     swift Scripts/make-app-icons.swift
//
// Das Icon ist kein Symbol fuer die App, es ist die App: **vier Anker, sieben Tage**, gefuellt
// so weit die Woche steht. Dieselbe Figur traegt Icon, Menueleiste, Sidebar und Widget — der
// Wochenpuls.
//
// Warum gezeichnet und nicht skaliert: die kleinen Groessen sind **nicht** dasselbe Bild in
// klein. Ab 40 px Kantenlaenge fallen die Tagesfugen weg und aus 4x7 Feldern werden vier
// Balken mit denselben Fuellstaenden. Das laesst sich nicht herunterrechnen, das muss gezeichnet
// werden — und deshalb steht die Geometrie hier als Vorschrift und nicht in achtzehn Dateien.
//
// Die beiden Plattformen brauchen ausdruecklich Verschiedenes:
//
// **macOS** maskiert App-Icons *nicht*. Die Form muss mitgeliefert werden — nach Apples Raster:
// auf 1024 Punkten Flaeche ein Koerper von 824x824 zentriert (also 100 Punkte Rand, 9,77 %) mit
// einem Eckenradius von 185,4. Der Rand bleibt transparent, die Datei braucht einen Alphakanal.
// Ohne das steht die App im Dock als randloses Quadrat neben allen anderen.
//
// **iOS** maskiert selbst, und zwar mit demselben fortlaufend gerundeten Quadrat. Dort muss das
// Bild randlos und **ohne** Alphakanal sein: eine mitgelieferte Rundung ergaebe eine doppelte
// Kante, und der App Store lehnt einen Alphakanal ab — auch einen vollstaendig deckenden.
//
// Die Ecke entsteht ueber eine fortlaufende Kurve (Squircle), nicht ueber `CGPath(roundedRect:)`:
// Apples Ecke ist keine Kreisbogenecke, ein Kreisbogen ist sichtbar kantiger.
//
// Reines CoreGraphics, kein AppKit-Zeichnen: `NSImage.draw` in einen selbst gesetzten
// `NSGraphicsContext` zeichnet in einem Prozess ohne `NSApplication` **nichts**, die Bitmap
// bleibt genullt — das war schon einmal der Fehler, und er fiel nur an gleichen Pruefsummen auf.

import CoreGraphics
import Foundation
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Die Figur
//
// Alle Masse als Anteil der Kantenlaenge, gemessen am Entwurf (`Daivento AppIcon Lot.dc.html`,
// Fassung 128 @2x): Koerper nach Apples Raster, darin ein quadratisches Feld von 688/1024 mit
// 68/1024 Einzug, darin 7 Spalten zu 84/1024 und 4 Zeilen zu 120/1024.

let bodyInset = 100.0 / 1024      // 9,77 % Rand — Apples Big-Sur-Raster
let cornerRatio = 185.4 / 824     // Eckenradius, bezogen auf den Koerper
let matrixInset = 168.0 / 1024    // Rand bis zum Feld
let matrixSide = 688.0 / 1024
let cellWidth = 84.0 / 1024
let columnPitch = 100.6667 / 1024
let rowHeight = 120.0 / 1024
let rowPitch = 189.3333 / 1024

/// Unter dieser Kantenlaenge fallen die Tagesfugen weg. Der Entwurf nennt 40 px.
let simplifyBelow = 40

/// Die Woche, die das Icon zeigt: je Anker, wie viele der sieben Tage stehen.
///
/// Bewusst eine feste Woche und keine Zufallszahlen — ein Icon ist eine Marke, und eine Marke
/// sieht jedes Mal gleich aus. Die Werte stammen aus dem Entwurf.
let filledDays = [6, 3, 7, 4]
let dayCount = 7
let anchorCount = 4

/// Wie stark die offenen Tage stehen. „Ohne Graustufen-Fassung rechnet das System selbst — und
/// verliert die 26-%-Spuren der offenen Tage."
let openTrace = 0.26

// MARK: - Farben

struct Palette {
    let ground: (Double, Double, Double)
    let mark: (Double, Double, Double)
    /// Ob der Grund gezeichnet wird. Die Menueleiste ist ein Template: dort traegt nur das Alpha.
    var drawsGround = true
}

/// Standard — Bernstein auf Papierweiss.
let light = Palette(ground: (0xD9 / 255, 0x82 / 255, 0x0F / 255), mark: (0xFF / 255, 0xFD / 255, 0xFA / 255))
/// Dunkel — Tinte, Bernstein hell. Eigene Fassung, nicht abgeleitet: ohne sie stuende der helle
/// Bernstein-Grund auf dem dunklen Homescreen als Leuchtflaeche.
let dark = Palette(ground: (0x1C / 255, 0x1A / 255, 0x16 / 255), mark: (0xF0 / 255, 0xA0 / 255, 0x34 / 255))
/// Getoent — Graustufen, das System faerbt. Auch hier gezeichnet statt abgeleitet, sonst
/// verliert das System die Spuren der offenen Tage.
let tinted = Palette(ground: (0, 0, 0), mark: (1, 1, 1))
/// Menueleiste — die Form steckt im Alpha, die Farbe kommt von der Leiste.
let template = Palette(ground: (0, 0, 0), mark: (0, 0, 0), drawsGround: false)

// MARK: - Zeichnen

/// Apples fortlaufend gerundetes Quadrat — direkt von SwiftUI.
///
/// Nicht selbst genaehert: Apples Ecke ist eine fortlaufende Kurve, und jede Bezier-Naeherung
/// aus zwei Kontrollpunkten liegt entweder zu eckig (Kreisbogen, `CGPath(roundedRect:)`) oder
/// beult die Kante aus. `Shape.path(in:)` braucht keinen Renderer und liefert genau die Kurve,
/// die die App an jeder anderen Stelle ueber `style: .continuous` zeichnet — dieselbe Quelle,
/// dieselbe Form.
func squirclePath(in rect: CGRect, radius: Double) -> CGPath {
    RoundedRectangle(cornerRadius: radius, style: .continuous).path(in: rect).cgPath
}

/// Wie die Form auf die Flaeche gelegt wird.
enum Shape {
    /// macOS: gerundeter Koerper mit transparentem Rand.
    case masked
    /// iOS: randlos, das System maskiert selbst.
    case bleed
    /// Menueleiste: nur die Balken, kein Grund.
    case glyph
}

/// `pointSize` ist die Groesse, in der das Bild **erscheint** — nicht die der Datei.
///
/// Fuer den Iconsatz sind beide gleich. Fuer die Menueleiste nicht: sie zeigt 18 pt, egal ob die
/// Datei 18, 36 oder 54 px hat. Die Vereinfachung folgt der scheinbaren Groesse, sonst traegt
/// ausgerechnet die schaerfste Fassung sieben Fugen, die niemand aufloesen kann.
func drawIcon(size: Int, pointSize: Int, palette: Palette, shape: Shape, into context: CGContext) {
    let side = Double(size)

    // Der Koerper. Randlos heisst: der Koerper ist die ganze Flaeche.
    let body: CGRect
    switch shape {
    case .masked:
        let inset = (side * bodyInset).rounded()
        body = CGRect(x: inset, y: inset, width: side - 2 * inset, height: side - 2 * inset)
    case .bleed, .glyph:
        body = CGRect(x: 0, y: 0, width: side, height: side)
    }

    if palette.drawsGround {
        context.setFillColor(red: palette.ground.0, green: palette.ground.1,
                             blue: palette.ground.2, alpha: 1)
        switch shape {
        case .masked:
            context.addPath(squirclePath(in: body, radius: body.width * cornerRatio))
            context.fillPath()
        case .bleed, .glyph:
            context.fill(body)
        }
    }

    // Das Feld. Beim Glyph nimmt es die ganze Flaeche — eine Menueleiste hat keinen Rand zu
    // verschenken.
    let field: CGRect
    if shape == .glyph {
        field = body
    } else {
        let inset = (side * matrixInset).rounded()
        let extent = (side * matrixSide).rounded()
        field = CGRect(x: inset, y: inset, width: extent, height: extent)
    }

    let simplified = pointSize < simplifyBelow
    let rowStep = field.height * (rowPitch / matrixSide)
    let barHeight = max(1, (field.height * (rowHeight / matrixSide)).rounded())

    for anchor in 0..<anchorCount {
        // Von oben nach unten: Anker 1 steht oben, CoreGraphics zaehlt von unten.
        let top = field.maxY - Double(anchor) * rowStep
        let y = (top - barHeight).rounded()
        let done = filledDays[anchor]

        if simplified {
            // Vier Balken, dieselben Fuellstaende. Die einzige erlaubte Vereinfachung — die
            // Zeilenzahl bleibt **immer** vier, sonst zeigt das Icon eine andere Woche als die App.
            let filled = (field.width * Double(done) / Double(dayCount)).rounded()
            fill(context, CGRect(x: field.minX, y: y, width: field.width, height: barHeight),
                 palette.mark, alpha: openTrace)
            if filled > 0 {
                fill(context, CGRect(x: field.minX, y: y, width: filled, height: barHeight),
                     palette.mark, alpha: 1)
            }
        } else {
            let step = field.width * (columnPitch / matrixSide)
            let cell = max(1, (field.width * (cellWidth / matrixSide)).rounded())
            for day in 0..<dayCount {
                let x = (field.minX + Double(day) * step).rounded()
                fill(context, CGRect(x: x, y: y, width: cell, height: barHeight),
                     palette.mark, alpha: day < done ? 1 : openTrace)
            }
        }
    }
}

func fill(_ context: CGContext, _ rect: CGRect, _ color: (Double, Double, Double), alpha: Double) {
    context.setFillColor(red: color.0, green: color.1, blue: color.2, alpha: alpha)
    context.fill(rect)
}

// MARK: - Schreiben

func makeContext(size: Int, opaque: Bool) -> CGContext? {
    guard let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
    return CGContext(
        data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: space,
        // iOS lehnt einen Alphakanal ab — auch einen vollstaendig deckenden. `noneSkipLast`
        // liefert eine Datei ohne Alpha, `premultipliedLast` eine mit.
        bitmapInfo: (opaque ? CGImageAlphaInfo.noneSkipLast : .premultipliedLast).rawValue
    )
}

@discardableResult
func write(_ image: CGImage, to url: URL) -> Bool {
    // Erst daneben schreiben, dann ersetzen: `CGImageSource` liest verzoegert.
    let temporary = url.deletingLastPathComponent()
        .appendingPathComponent(".new-" + url.lastPathComponent)
    guard let destination = CGImageDestinationCreateWithURL(
        temporary as CFURL, UTType.png.identifier as CFString, 1, nil
    ) else { return false }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { return false }
    try? FileManager.default.removeItem(at: url)
    return (try? FileManager.default.moveItem(at: temporary, to: url)) != nil
}

func render(size: Int, pointSize: Int? = nil, palette: Palette, shape: Shape,
            opaque: Bool, to url: URL) -> Bool {
    guard let context = makeContext(size: size, opaque: opaque) else { return false }
    if opaque {
        // Ohne Alphakanal gibt es kein „transparent" — der Grund muss gezeichnet sein.
        context.setFillColor(red: palette.ground.0, green: palette.ground.1,
                             blue: palette.ground.2, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: Double(size), height: Double(size)))
    }
    drawIcon(size: size, pointSize: pointSize ?? size, palette: palette, shape: shape, into: context)
    guard let image = context.makeImage() else { return false }
    return write(image, to: url)
}

// MARK: - Lauf

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let appIcon = root.appendingPathComponent("Anchor/Assets.xcassets/AppIcon.appiconset")
let menuBar = root.appendingPathComponent("Anchor/Assets.xcassets/MenuBarTemplate.imageset")

guard FileManager.default.fileExists(atPath: appIcon.path),
      FileManager.default.fileExists(atPath: menuBar.path) else {
    print("make-app-icons: Asset-Katalog nicht gefunden — aus der Repowurzel aufrufen.")
    exit(2)
}

var failures = 0

func report(_ ok: Bool, _ name: String, _ note: String) {
    print("  \(ok ? "✓" : "✗") \(name) — \(note)")
    if !ok { failures += 1 }
}

// iOS: randlos, ohne Alpha, drei Erscheinungsbilder.
for (name, palette, note) in [
    ("AppIcon-1024.png", light, "iOS hell — Bernstein auf Papierweiss"),
    ("AppIcon-dark-1024.png", dark, "iOS dunkel — Tinte, Bernstein hell"),
    ("AppIcon-tinted-1024.png", tinted, "iOS getoent — Graustufen, System faerbt"),
] {
    report(
        render(size: 1024, palette: palette, shape: .bleed, opaque: true,
               to: appIcon.appendingPathComponent(name)),
        name, note
    )
}

// macOS: gerundeter Koerper mit transparentem Rand.
for size in [16, 32, 64, 128, 256, 512, 1024] {
    let name = "AppIconMac-\(size).png"
    let note = size < simplifyBelow
        ? "macOS — vier Balken, Tagesfugen fallen weg"
        : "macOS — 4x7, Koerper \(Int(Double(size) * (1 - 2 * bodyInset))) px"
    report(
        render(size: size, palette: light, shape: .masked, opaque: false,
               to: appIcon.appendingPathComponent(name)),
        name, note
    )
}

// Menueleiste: ein Template in drei Aufloesungen. Die Form steckt im Alpha.
for (name, size) in [("MenuBarTemplate-18.png", 18), ("MenuBarTemplate-18-2x.png", 36),
                     ("MenuBarTemplate-18-3x.png", 54)] {
    report(
        render(size: size, pointSize: 18, palette: template, shape: .glyph, opaque: false,
               to: menuBar.appendingPathComponent(name)),
        name, "Menueleiste \(size) px — Template, vier Balken"
    )
}

if failures == 0 {
    print("\nmake-app-icons: Iconsatz erzeugt.")
    exit(0)
}
print("\nmake-app-icons: \(failures) Dateien nicht geschrieben.")
exit(1)
