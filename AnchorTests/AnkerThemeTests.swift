import CoreText
import SwiftUI
import XCTest
@testable import Anchorit

#if os(macOS)
import AppKit
#endif

/// Prueft die Tokenschicht headless.
///
/// Der Wert dieser Tests: eine fehlende Schriftdatei, ein falscher Pfad im Info.plist oder ein
/// verschobener Hexwert faellt in CI auf, nicht erst beim Draufschauen. Die Schrift faellt
/// still auf San Francisco zurueck — genau die Art Fehler, die ohne Test durchrutscht.
final class AnkerThemeTests: XCTestCase {

    // MARK: - Schrift

    /// Zahlen-Tokens setzen tabellarische Ziffern, damit Spalten stehen.
    func testNumberTokensAreTabular() {
        for style in [AnkerType.numeric, AnkerType.numericSmall, AnkerType.statValue, AnkerType.anchorNumber, AnkerType.poster] {
            XCTAssertTrue(style.isTabular)
        }
    }

    /// Beschriftungen stehen in „Blatt" in normaler Schreibung.
    func testLabelsAreNotUppercased() {
        for style in [AnkerType.overline, AnkerType.eyebrow, AnkerType.microLabel] {
            XCTAssertFalse(style.isUppercase)
        }
    }

    // MARK: - Icons

    func testEveryIconAssetExists() {
        for icon in AnkerIcon.all {
#if os(macOS)
            XCTAssertNotNil(NSImage(named: icon.assetName), "Asset fehlt: \(icon.assetName)")
#else
            XCTAssertNotNil(UIImage(named: icon.assetName), "Asset fehlt: \(icon.assetName)")
#endif
        }
    }

    func testNoBundledIconIsOrphaned() throws {
        // Andere Richtung als der Test darueber: liegt ein Asset im Katalog, auf das keine
        // Rolle zeigt? Das faengt ein Icon, das beschafft aber nie verdrahtet wurde.
        let used = Set(AnkerIcon.all.map(\.assetName))
        let catalog = try bundledIconAssetNames()
        XCTAssertFalse(catalog.isEmpty, "Keine Lucide-Assets gefunden — Pfad im Test pruefen")
        XCTAssertEqual(catalog.subtracting(used), [], "Unbenutzte Assets im Katalog")
        XCTAssertEqual(used.subtracting(catalog), [], "Rollen ohne Asset")
    }

    private func bundledIconAssetNames() throws -> Set<String> {
        // Der Asset-Katalog ist zur Laufzeit kompiliert; die Namen kommen deshalb aus den
        // Quelldateien neben dem Test.
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()      // AnchorTests
            .deletingLastPathComponent()      // Repowurzel
            .appendingPathComponent("Anchor/Assets.xcassets/Icons")
        let entries = try FileManager.default.contentsOfDirectory(atPath: root.path)
        return Set(entries.filter { $0.hasSuffix(".imageset") }.map {
            String($0.dropLast(".imageset".count))
        })
    }

    // MARK: - Radien und Linien

    func testRadiusRolesFollowTheDesign() {
        XCTAssertEqual(AnkerRadius.check, 6)
        XCTAssertEqual(AnkerRadius.control, 10)
        XCTAssertEqual(AnkerRadius.card, 14)
        XCTAssertEqual(AnkerRadius.tile, AnkerRadius.control, "Eine Auswahlkachel ist ein Knopf")
        XCTAssertLessThan(AnkerRadius.check, AnkerRadius.control)
        XCTAssertLessThan(AnkerRadius.control, AnkerRadius.card)
    }

    /// In „Blatt" ist jede Linie eine Haarlinie; Bereiche trennt der Abstand.
    func testEveryLineIsAHairline() {
        XCTAssertEqual(AnkerRule.Weight.section.thickness, 1)
        XCTAssertEqual(AnkerRule.Weight.row.thickness, 1)
    }

    // MARK: - Kontrast
    //
    // Das Systemblatt gibt einen Akzent an und sagt selbst, dass das Paar nur auf 3:1 getunt
    // ist. Diese Tests halten die Aufteilung in accentMark/accentFill/accentInk fest — ohne
    // sie fiele sie beim naechsten Aufraeumen wieder zu einem Token zusammen.

#if os(macOS)
    func testContrastRatiosMeetTargetsInLightMode() {
        assertContrast(dark: false)
    }

    func testContrastRatiosMeetTargetsInDarkMode() {
        assertContrast(dark: true)
    }

    private func assertContrast(dark: Bool) {
        let mode = dark ? "dunkel" : "hell"

        for (surfaceName, surface) in [("Grund", AnkerColor.ground), ("Karte", AnkerColor.card)] {
            expect(AnkerColor.ink, on: surface, atLeast: 7, "Text auf \(surfaceName) (\(mode))", dark: dark)
            expect(AnkerColor.inkSecond, on: surface, atLeast: 4.5, "Zweite Textstufe auf \(surfaceName) (\(mode))", dark: dark)
            expect(AnkerColor.accentInk, on: surface, atLeast: 4.5, "Akzent als Schrift auf \(surfaceName) (\(mode))", dark: dark)
            expect(AnkerColor.accentMark, on: surface, atLeast: 3, "Akzent als Marke auf \(surfaceName) (\(mode))", dark: dark)
        }
        expect(AnkerColor.inkTertiary, on: AnkerColor.card, atLeast: 4.5, "Dritte Stufe auf Karte (\(mode))", dark: dark)
        expect(AnkerColor.inkTertiary, on: AnkerColor.ground, atLeast: 3, "Dritte Stufe auf Grund (\(mode))", dark: dark)
        expect(AnkerColor.onAccent, on: AnkerColor.accentFill, atLeast: 4.5, "Schrift auf Blau (\(mode))", dark: dark)
        expect(AnkerColor.onInk, on: AnkerColor.ink, atLeast: 7, "Schrift auf Tinte (\(mode))", dark: dark)

        for (name, tint) in [("Akzenttönung", AnkerColor.accentTint), ("Heute-Spalte", AnkerColor.todayTint), ("Fläche", AnkerColor.surface)] {
            expect(AnkerColor.ink, on: tint, atLeast: 7, "Text auf \(name) (\(mode))", dark: dark)
            expect(AnkerColor.accentInk, on: tint, atLeast: 4.5, "Akzent auf \(name) (\(mode))", dark: dark)
            expect(AnkerColor.inkSecond, on: tint, atLeast: 4.5, "Zweite Stufe auf \(name) (\(mode))", dark: dark)
        }
    }

    // MARK: - Messung

    private func expect(
        _ foreground: Color,
        on background: Color,
        atLeast minimum: Double,
        _ label: String,
        dark: Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let ratio = contrast(foreground, background, dark: dark)
        XCTAssertGreaterThanOrEqual(
            ratio, minimum,
            "\(label): \(String(format: "%.2f", ratio)):1, verlangt \(minimum):1",
            file: file, line: line
        )
    }

    /// Die Kartenfläche muss sich vom Grund abheben, in **beiden** Modi — sonst ist die Elevation
    /// erfunden.
    ///
    /// „Eine Ebene näher" heisst auf beiden Seiten **mehr Licht**: hell geht die Karte über den
    /// Grund hinaus (Weiss), dunkel darüber (aufgehellt). Eine reine Rampenspiegelung wäre hier
    /// falsch — im Dunkeln kann eine Karte nicht heller als Weiss werden.
    func testCardStandsOutFromTheGroundInBothModes() {
        for dark in [false, true] {
            let card = relativeLuminance(AnkerColor.card, dark: dark)
            let ground = relativeLuminance(AnkerColor.ground, dark: dark)
            XCTAssertGreaterThan(card, ground,
                                 "Die Karte muss heller als ihr Grund sein (dunkel: \(dark))")
        }
    }

    /// Trenner **innerhalb** einer Karte dürfen nicht stärker wirken als die Karte selbst.
    func testCardDividerIsSubtleOnTheCard() {
        for dark in [false, true] {
            let ratio = contrast(AnkerColor.cardDivider, AnkerColor.card, dark: dark)
            XCTAssertLessThan(ratio, 3, "Ein Zeilentrenner ist kein Rahmen (dunkel: \(dark))")
            XCTAssertGreaterThan(ratio, 1.05, "Sichtbar muss er trotzdem sein (dunkel: \(dark))")
        }
    }

    /// Zwei Farben so mischen, wie SwiftUI sie übereinander zeichnet — deckendes Ergebnis.
    private func composite(_ color: Color, over backdrop: Color, dark: Bool) -> Color {
        var result = Color.clear
        let appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        appearance?.performAsCurrentDrawingAppearance {
            guard let top = NSColor(color).usingColorSpace(.sRGB),
                  let bottom = NSColor(backdrop).usingColorSpace(.sRGB) else { return }
            let alpha = top.alphaComponent
            func mix(_ a: CGFloat, _ b: CGFloat) -> Double { Double(a * alpha + b * (1 - alpha)) }
            result = Color(
                .sRGB,
                red: mix(top.redComponent, bottom.redComponent),
                green: mix(top.greenComponent, bottom.greenComponent),
                blue: mix(top.blueComponent, bottom.blueComponent),
                opacity: 1
            )
        }
        return result
    }

    private func contrast(_ lhs: Color, _ rhs: Color, dark: Bool = false) -> Double {
        let a = relativeLuminance(lhs, dark: dark)
        let b = relativeLuminance(rhs, dark: dark)
        let lighter = max(a, b)
        let darker = min(a, b)
        return (lighter + 0.05) / (darker + 0.05)
    }

    private func relativeLuminance(_ color: Color, dark: Bool) -> Double {
        var result = 0.0
        let appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        appearance?.performAsCurrentDrawingAppearance {
            guard let srgb = NSColor(color).usingColorSpace(.sRGB) else { return }
            // Alpha ueber dem jeweiligen Grund auflösen: `divider` ist teiltransparent, und
            // ein Kontrast gegen den reinen Farbwert waere geraten.
            let backdrop: Double = dark ? 0.102 : 0.953
            func channel(_ raw: Double) -> Double {
                let mixed = raw * srgb.alphaComponent + backdrop * (1 - srgb.alphaComponent)
                return mixed <= 0.03928 ? mixed / 12.92 : pow((mixed + 0.055) / 1.055, 2.4)
            }
            result = 0.2126 * channel(Double(srgb.redComponent))
                + 0.7152 * channel(Double(srgb.greenComponent))
                + 0.0722 * channel(Double(srgb.blueComponent))
        }
        return result
    }
#endif

    // MARK: - Typografie

    func testEveryTypeTokenUsesABundledWeight() {
        let tokens: [(String, AnkerTextStyle)] = [
            ("poster", AnkerType.poster), ("display", AnkerType.display),
            ("title1", AnkerType.title1), ("title2", AnkerType.title2), ("title3", AnkerType.title3),
            ("headline", AnkerType.headline), ("subheadline", AnkerType.subheadline),
            ("taskTitle", AnkerType.taskTitle), ("bodyStrong", AnkerType.bodyStrong),
            ("body", AnkerType.body), ("label", AnkerType.label),
            ("metaStrong", AnkerType.metaStrong), ("meta", AnkerType.meta),
            ("caption", AnkerType.caption), ("overline", AnkerType.overline),
            ("eyebrow", AnkerType.eyebrow), ("microLabel", AnkerType.microLabel),
            ("numeric", AnkerType.numeric), ("numericSmall", AnkerType.numericSmall),
            ("statValue", AnkerType.statValue),
        ]

        for (name, style) in tokens {
            XCTAssertTrue(AnkerFontWeight.allCases.contains(style.weight), "\(name)")
            XCTAssertGreaterThan(style.size, 0, name)
            // Die Mikrobeschriftungen des Entwurfs sind ausnahmslos gesperrt und gross.
            if style.isUppercase {
                XCTAssertGreaterThan(style.trackingEm, 0, "\(name) ist gross geschrieben, aber nicht gesperrt")
            }
        }
    }

    // MARK: - Hilfen

    /// Anteil gedeckter Flaeche, wenn die Glyphe in ein Quadrat gerendert wird.
    /// Direkter Beleg fuer das Gewicht — unabhaengig davon, was Core Text ueber sich sagt.
    private func inkCoverage(of character: Character, in font: CTFont) throws -> Double {
        let side = 128
        var glyph = CGGlyph()
        var unichar = Array(String(character).utf16)
        CTFontGetGlyphsForCharacters(font, &unichar, &glyph, 1)

        let space = CGColorSpaceCreateDeviceGray()
        let context = try XCTUnwrap(CGContext(
            data: nil, width: side, height: side, bitsPerComponent: 8,
            bytesPerRow: side, space: space, bitmapInfo: CGImageAlphaInfo.none.rawValue
        ))
        context.setFillColor(gray: 0, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: side, height: side))
        context.setFillColor(gray: 1, alpha: 1)

        var position = CGPoint(x: 24, y: 32)
        CTFontDrawGlyphs(font, &glyph, &position, 1, context)

        let data = try XCTUnwrap(context.data)
        let pixels = data.bindMemory(to: UInt8.self, capacity: side * side)
        var lit = 0
        for index in 0..<(side * side) where pixels[index] > 127 { lit += 1 }
        return Double(lit) / Double(side * side)
    }

    private func advance(of character: Character, in font: CTFont) -> CGFloat {
        var glyph = CGGlyph()
        var unichar = Array(String(character).utf16)
        CTFontGetGlyphsForCharacters(font, &unichar, &glyph, 1)
        var advances = CGSize.zero
        CTFontGetAdvancesForGlyphs(font, .horizontal, &glyph, &advances, 1)
        return advances.width
    }
}
