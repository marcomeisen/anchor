import CoreText
import SwiftUI
import XCTest
@testable import Daivento

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

    @MainActor
    func testArchivoIsBundledAndRegisters() {
        XCTAssertTrue(AnkerFont.bootstrap(), "Archivo.ttf fehlt im Bundle oder ist nicht registrierbar")
        XCTAssertTrue(AnkerFont.isAvailable)
    }

    @MainActor
    func testEveryTokenWeightResolvesToArchivo() throws {
        AnkerFont.bootstrap()

        // Geprueft wird das Verhalten, nicht die Selbstauskunft: `CTFontCopyVariation` gibt die
        // Achse nicht verlaesslich zurueck (fuer 500 ja, ab 600 nicht), und die Vorschubbreite
        // ist in Archivo nicht monoton zum Gewicht (500 → 84,57, 600 → 84,40). Eindeutig ist
        // die Farbmenge: ein schwereres Gewicht setzt mehr Deckung auf dieselbe Flaeche.
        var inkByWeight: [(AnkerFontWeight, Double)] = []

        for weight in AnkerFontWeight.allCases {
            // Bewusst der Produktionsweg, nicht ein Nachbau daneben.
            let font = try XCTUnwrap(AnkerFont.makeFont(weight, size: 64, tabular: false))
            XCTAssertEqual(CTFontCopyFamilyName(font) as String, "Archivo", "Gewicht \(weight.rawValue)")
            inkByWeight.append((weight, try inkCoverage(of: "B", in: font)))
        }

        let readable = inkByWeight
            .map { "\($0.0.rawValue): \(String(format: "%.4f", $0.1))" }
            .joined(separator: ", ")

        for (lighter, heavier) in zip(inkByWeight, inkByWeight.dropFirst()) {
            XCTAssertGreaterThan(
                heavier.1, lighter.1,
                "Gewicht \(heavier.0.rawValue) deckt nicht mehr als \(lighter.0.rawValue) — "
                    + "die Gewichtsachse greift nicht. Gemessen: \(readable)"
            )
        }
    }

    @MainActor
    func testTabularDigitsHaveEqualAdvance() throws {
        AnkerFont.bootstrap()

        // Zahlenspalten duerfen nicht wandern. Bei einer eigenen Schrift ist
        // `Font.monospacedDigit()` wirkungslos, deshalb laeuft es ueber ein OpenType-Feature —
        // dieser Test prueft, dass das Feature tatsaechlich greift.
        let advances = try (0...9).map { digit -> CGFloat in
            let font = try XCTUnwrap(AnkerFont.makeFont(.bold, size: 20, tabular: true))
            return advance(of: Character("\(digit)"), in: font)
        }
        let first = try XCTUnwrap(advances.first)
        for advance in advances {
            XCTAssertEqual(advance, first, accuracy: 0.05, "Ziffernbreiten sind nicht gleich")
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

        expect(AnkerColor.ink, on: AnkerColor.ground, atLeast: 7, "Text auf Grund (\(mode))", dark: dark)
        expect(AnkerColor.ink, on: AnkerColor.surface, atLeast: 7, "Text auf Flaeche (\(mode))", dark: dark)
        expect(AnkerColor.inkSecond, on: AnkerColor.ground, atLeast: 4.5, "Zweite Textstufe (\(mode))", dark: dark)
        expect(AnkerColor.accentInk, on: AnkerColor.ground, atLeast: 4.5, "Akzent als Schrift (\(mode))", dark: dark)
        expect(AnkerColor.onAccent, on: AnkerColor.accentFill, atLeast: 4.5, "Weiss auf Akzentflaeche (\(mode))", dark: dark)
        // Marke, Regeln, Icons: 3:1 genuegt und ist die Zusicherung des Systemblatts.
        expect(AnkerColor.accentMark, on: AnkerColor.ground, atLeast: 3, "Akzent als Marke (\(mode))", dark: dark)
        expect(AnkerColor.inkTertiary, on: AnkerColor.ground, atLeast: 3, "Dritte Textstufe (\(mode))", dark: dark)

        for hex in AnkerColor.goalTintOptions {
            expect(AnkerColor.onAccent, on: AnkerColor.goalTint(hex), atLeast: 4.5,
                   "Weiss auf Zielfarbe \(hex) (\(mode))", dark: dark)
        }
    }

    /// Der Grund, warum der Entwurfs-Akzent nicht als Schrift taugt — als Test festgehalten,
    /// damit die Aufteilung nachvollziehbar bleibt und niemand sie versehentlich zurueckdreht.
    func testDesignAccentWouldFailAsBodyTextOnLightGround() {
        let ratio = contrast(Color(hex: "#EC3013"), Color(hex: "#F3F2F2"))
        XCTAssertLessThan(ratio, 4.5, "Wenn #EC3013 hier bestehen wuerde, waere die Aufteilung unnoetig")
        XCTAssertGreaterThan(ratio, 3.0, "Als Marke muss es 3:1 halten")
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
