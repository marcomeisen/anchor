import CoreText
import SwiftUI
import XCTest
@testable import Daivento

#if os(macOS)
import AppKit
#endif

/// Prueft die Tokenschicht von **Lot** headless.
///
/// Der Wert dieser Tests: eine fehlende Schriftdatei, ein falscher Pfad im Info.plist oder ein
/// verschobener Hexwert faellt in CI auf, nicht erst beim Draufschauen. Die Serif faellt still
/// auf die System-Serif zurueck — genau die Art Fehler, die ohne Test durchrutscht.
///
/// Was hier **nicht** steht, steht in `Scripts/design-guard.swift`: wo ein Token benutzt werden
/// darf, ist eine Frage an den Quelltext, nicht an die Laufzeit.
final class AnkerThemeTests: XCTestCase {

    // MARK: - Schrift

    @MainActor
    func testInstrumentSerifIsBundledAndRegisters() {
        XCTAssertTrue(
            AnkerFont.bootstrap(),
            "InstrumentSerif-Regular.ttf fehlt im Bundle oder ist nicht registrierbar"
        )
        XCTAssertTrue(AnkerFont.isRitualAvailable)
    }

    @MainActor
    func testRitualFontResolvesToInstrumentSerif() throws {
        AnkerFont.bootstrap()
        let font = try XCTUnwrap(AnkerFont.makeRitualFont(size: 64, tabular: false))
        XCTAssertEqual(CTFontCopyFamilyName(font) as String, AnkerFont.ritualFamilyName)
    }

    /// Instrument Serif hat **keine** tabellarischen Ziffern — und das ist hier festgehalten,
    /// nicht behoben.
    ///
    /// Das Systemblatt verlangt „Ziffern immer tabellarisch". Die Schrift bringt keine
    /// `tnum`-Tabelle mit, das OpenType-Feature laeuft ins Leere. Die beiden Regeln des Entwurfs
    /// sind an dieser Stelle unvereinbar; geloest ist es ueber einen festen Kasten um den
    /// Zaehler (`WeeklyReviewView.ritualCount`). Dieser Test misst die Grundlage dieses Kastens:
    /// **die breiteste Ziffer muss hineinpassen.** Bei einem Schriftwechsel faellt es hier auf.
    @MainActor
    func testRitualDigitsAreProportionalAndFitTheFixedBox() throws {
        AnkerFont.bootstrap()

        let size: CGFloat = 100
        let font = try XCTUnwrap(AnkerFont.makeRitualFont(size: size, tabular: true))
        let advances = (0...9).map { advance(of: Character("\($0)"), in: font) }
        let widest = try XCTUnwrap(advances.max())
        let narrowest = try XCTUnwrap(advances.min())

        XCTAssertGreaterThan(
            widest - narrowest, 1,
            "Diese Fassung der Serif hat tabellarische Ziffern — dann kann der feste Kasten weg"
        )
        XCTAssertLessThanOrEqual(
            widest / size, 0.5,
            "Die breiteste Ziffer passt nicht mehr in den Kasten von 0,5 em — "
                + "WeeklyReviewView.widestDigitEm nachziehen"
        )
    }

    /// „Die Schrift sagt, in welchem Modus du bist."
    ///
    /// Genau vier Tokens sprechen die Serif, und alle vier gehoeren dem Ritual. Ein fuenftes
    /// waere die Aufweichung, gegen die die Regel steht.
    func testOnlyRitualTokensUseTheSerif() {
        let serif = AnkerType.all.filter { $0.style.family == .ritual }.map(\.name)
        XCTAssertEqual(
            Set(serif), ["poster", "display", "ritualTitle", "ritualQuestion"],
            "Die Serif ist Display im Ritual, sonst nichts"
        )
    }

    /// „Regel: nie unter 28 px und nie fuer Fliesstext. Der Serif ist Display, sonst nichts."
    func testSerifIsNeverSmallerThanTwentyEight() {
        for (name, style) in AnkerType.all where style.family == .ritual {
            XCTAssertGreaterThanOrEqual(style.size, 28, "\(name) unterschreitet die Serif-Grenze")
        }
    }

    /// „Gewichte 400 / 500 / 600 — nie schwerer, das uebernimmt der Grad."
    func testEveryTypeTokenStaysWithinTheThreeWeights() {
        for (name, style) in AnkerType.all {
            XCTAssertTrue(AnkerFontWeight.allCases.contains(style.weight), name)
            XCTAssertLessThanOrEqual(style.weight.rawValue, 600, "\(name) ist schwerer als 600")
            XCTAssertGreaterThan(style.size, 0, name)
            // Die Mikrobeschriftungen des Entwurfs sind ausnahmslos gesperrt und gross.
            if style.isUppercase {
                XCTAssertGreaterThan(style.trackingEm, 0, "\(name) ist gross geschrieben, aber nicht gesperrt")
            }
        }
    }

    /// „Ziffern immer tabellarisch. Jede Kennzahl, jedes Datum, jeder Bruch."
    ///
    /// Gilt fuer die Arbeitsflaeche ausnahmslos. Die vier Ritual-Tokens sind ausgenommen, weil
    /// Instrument Serif es nicht kann — siehe `testRitualDigitsAreProportionalAndFitTheFixedBox`.
    func testNumericWorkfaceTokensAreTabular() throws {
        let mustBeTabular = ["title1", "title2", "title3", "meta",
                             "numeric", "numericSmall", "statValue"]
        for name in mustBeTabular {
            let style = try XCTUnwrap(AnkerType.all.first { $0.name == name }?.style)
            XCTAssertEqual(style.family, .workface, name)
            XCTAssertTrue(style.isTabular, "\(name) muss tabellarische Ziffern setzen")
        }

        for (name, style) in AnkerType.all where style.family == .ritual {
            XCTAssertFalse(
                style.isTabular,
                "\(name) verspricht tabellarische Ziffern, die die Serif nicht liefert"
            )
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

    // MARK: - Radius und Hoehe

    /// Die Radiusrollen des Entwurfs: 8 · 12 · 16 · 20 · 28, alles auf 4pt-Basis.
    ///
    /// Der Test haelt die Werte fest **und** dass sie nach Groesse des Objekts aufsteigen: ein
    /// Haekchen ist kleiner als ein Knopf, ein Knopf kleiner als eine Karte, eine Karte kleiner
    /// als ein Sheet. Wer eine neue Rolle einfuehrt, muss sie hier einordnen.
    func testRadiusRolesFollowTheDesign() {
        XCTAssertEqual(AnkerRadius.check, 8)
        XCTAssertEqual(AnkerRadius.control, 12)
        XCTAssertEqual(AnkerRadius.card, 16)
        XCTAssertEqual(AnkerRadius.group, 20)
        XCTAssertEqual(AnkerRadius.glass, 28)
        XCTAssertEqual(AnkerRadius.tile, AnkerRadius.control, "Eine Auswahlkachel ist ein Knopf")

        let ladder = [AnkerRadius.check, AnkerRadius.control, AnkerRadius.card,
                      AnkerRadius.group, AnkerRadius.glass]
        for (smaller, larger) in zip(ladder, ladder.dropFirst()) {
            XCTAssertLessThan(smaller, larger)
        }
        for radius in ladder {
            XCTAssertEqual(radius.truncatingRemainder(dividingBy: 4), 0, "4pt-Basis verlassen: \(radius)")
        }
    }

    /// Vier Hoehenstufen, jede mit einem Zweck — und `flat` traegt ausdruecklich keine.
    func testElevationStepsRiseAndFlatCarriesNothing() {
        XCTAssertTrue(AnkerElevation.flat.layers.isEmpty, "Hoehe 0 hat keinen Schatten")

        let ladder: [AnkerElevation] = [.card, .lifted, .sheet]
        let spreads = ladder.map { $0.layers.map(\.radius).max() ?? 0 }
        for (lower, higher) in zip(spreads, spreads.dropFirst()) {
            XCTAssertLessThan(lower, higher, "Eine hoehere Stufe muss weiter fallen")
        }
        for elevation in ladder {
            XCTAssertEqual(elevation.layers.count, 2, "Zwei Lagen: die enge fuer die Kante, die weite fuer die Ebene")
        }
    }

    /// Das Abstandsraster des Entwurfs — und die 1,4 des Ritual-Modus.
    func testSpacingFollowsTheGridAndRitualIsWider() {
        XCTAssertEqual(
            [AnkerSpacing.s1, AnkerSpacing.s2, AnkerSpacing.s3, AnkerSpacing.s4,
             AnkerSpacing.s5, AnkerSpacing.s6, AnkerSpacing.s7,
             AnkerSpacing.touchTarget, AnkerSpacing.section],
            [4, 8, 12, 16, 20, 24, 32, 44, 56]
        )
        XCTAssertEqual(AnkerSpacing.touchTarget, 44, "Mindestgroesse jedes Fingerziels")
        for value in [AnkerSpacing.s3, AnkerSpacing.s5, AnkerSpacing.s6] {
            XCTAssertGreaterThan(AnkerSpacing.ritual(value), value, "Ritual ist weiter, nicht gleich")
        }
        XCTAssertEqual(AnkerSpacing.ritual(AnkerSpacing.s5), 28)
    }

    /// In Lot ist die Abschnittsgrenze eine Haarlinie — die Trennung traegt Flaeche und Hoehe.
    /// Was zwei Bereiche unterscheidet, ist jetzt die **Farbe** der Linie, nicht ihre Staerke.
    func testSectionAndRowLinesAreBothHairlines() {
        XCTAssertEqual(AnkerRule.Weight.section.thickness, AnkerBorder.rule)
        XCTAssertEqual(AnkerRule.Weight.row.thickness, AnkerBorder.hairline)
        XCTAssertEqual(AnkerBorder.rule, 1, "Lot ersetzt die 2px-Regel durch Haarlinie plus Hoehe")
#if os(macOS)
        for dark in [false, true] {
            let section = contrast(AnkerRule.Weight.section.defaultColor, AnkerColor.card, dark: dark)
            let row = contrast(AnkerRule.Weight.row.defaultColor, AnkerColor.card, dark: dark)
            XCTAssertGreaterThan(section, row, "Der Unterschied liegt in der Farbe (dunkel: \(dark))")
        }
#endif
    }

    // MARK: - Kontrast
    //
    // Drei Werte des Entwurfs sind gemessen korrigiert; diese Tests halten die Korrekturen
    // fest, damit sie beim naechsten Aufraeumen nicht zurueckgedreht werden.

#if os(macOS)
    func testContrastRatiosMeetTargetsInLightMode() {
        assertContrast(dark: false)
    }

    func testContrastRatiosMeetTargetsInDarkMode() {
        assertContrast(dark: true)
    }

    private func assertContrast(dark: Bool) {
        let mode = dark ? "dunkel" : "hell"

        for (name, surface) in [("Grund", AnkerColor.ground), ("Flaeche", AnkerColor.surface),
                                ("Karte", AnkerColor.card)] {
            expect(AnkerColor.ink, on: surface, atLeast: 7, "Text auf \(name) (\(mode))", dark: dark)
            expect(AnkerColor.inkSecond, on: surface, atLeast: 4.5, "Zweite Textstufe auf \(name) (\(mode))", dark: dark)
            expect(AnkerColor.inkMuted, on: surface, atLeast: 4.5, "Fliesstext auf \(name) (\(mode))", dark: dark)
            expect(AnkerColor.inkTertiary, on: surface, atLeast: 4.5, "Mikro-Beschriftung auf \(name) (\(mode))", dark: dark)
            expect(AnkerColor.accentInk, on: surface, atLeast: 4.5, "Akzent als Schrift auf \(name) (\(mode))", dark: dark)
            expect(AnkerColor.rustInk, on: surface, atLeast: 4.5, "Rueckstand als Schrift auf \(name) (\(mode))", dark: dark)
            // Marke, Linien, Icons und Balken: 3:1 genuegt.
            expect(AnkerColor.accentMark, on: surface, atLeast: 3, "Akzent als Marke auf \(name) (\(mode))", dark: dark)
            expect(AnkerColor.rust, on: surface, atLeast: 3, "Rueckstandsbalken auf \(name) (\(mode))", dark: dark)
        }

        // Der Akzent als Flaeche mit Schrift darauf — die Korrektur, die den primaeren Knopf
        // ueberhaupt lesbar macht.
        expect(AnkerColor.onAccent, on: AnkerColor.accentFill, atLeast: 4.5,
               "Schrift auf Akzentflaeche (\(mode))", dark: dark)
        // Das Erledigt-Kaestchen: der Haken steht auf einer Flaeche in `ink`.
        expect(AnkerColor.card, on: AnkerColor.ink, atLeast: 4.5, "Haken im Kaestchen (\(mode))", dark: dark)
        // Die getoente Hinweisflaeche traegt den Tempo-Satz.
        expect(AnkerColor.accentInk, on: AnkerColor.accentTint, atLeast: 4.5,
               "Akzenttext auf getoenter Flaeche (\(mode))", dark: dark)
        expect(AnkerColor.ink, on: AnkerColor.accentTint, atLeast: 7,
               "Tempo-Satz auf getoenter Flaeche (\(mode))", dark: dark)

        // Die drei Prioritaetsstufen sind in Lot Text, keine gefuellten Marken — jede muss
        // deshalb selbst lesbar sein, statt sich auf `onAccent` zu verlassen.
        for priority in Priority.allCases {
            expect(PriorityTag(priority: priority).color, on: AnkerColor.card, atLeast: 4.5,
                   "Prioritaet \(priority.label) (\(mode))", dark: dark)
        }

        // Zielfarben tragen **keine** Schrift: sie sind Balkenfarbe, Marker und Farbfeld.
        for hex in AnkerColor.goalTintOptions {
            expect(AnkerColor.goalTint(hex), on: AnkerColor.ground, atLeast: 3,
                   "Zielfarbe \(hex) gegen Grund (\(mode))", dark: dark)
        }
    }

    /// Der Ritual-Modus ist immer dunkel und kippt deshalb nicht mit — genau deshalb muss er
    /// **einmal** gemessen werden, statt in beiden Modi mitzulaufen.
    func testRitualPaletteIsReadableOnItsOwnGround() {
        let surface = AnkerColor.Ritual.surface
        expect(AnkerColor.Ritual.ink, on: surface, atLeast: 7, "Ritualtext", dark: true)
        expect(AnkerColor.Ritual.inkSecond, on: surface, atLeast: 4.5, "Ritual sekundaer", dark: true)
        expect(AnkerColor.Ritual.inkMuted, on: surface, atLeast: 4.5, "Ritual Metazeile", dark: true)
        expect(AnkerColor.Ritual.amber, on: surface, atLeast: 4.5, "Ritual Bernstein", dark: true)
        expect(AnkerColor.Ritual.rust, on: surface, atLeast: 4.5, "Ritual Rueckstand", dark: true)
        // Der primaere Ritual-Knopf: Tinte auf Bernstein.
        expect(AnkerColor.Ritual.surface, on: AnkerColor.Ritual.amber, atLeast: 4.5,
               "Schrift auf dem Ritual-Knopf", dark: true)
        // `faint` traegt auch hier keine Information — nur die zweite Haelfte des Bruchs.
        expect(AnkerColor.Ritual.faint, on: surface, atLeast: 3, "Ritual Platzhalter", dark: true)
    }

    /// Die drei gemessenen Korrekturen am Entwurf, als Test festgehalten.
    ///
    /// Ohne diese Faelle sieht der naechste Leser nur „weicht ab" und dreht es zurueck. Hier
    /// steht, **warum** — jede Zeile ist der Messwert, der den Entwurfswert ausgeschlossen hat.
    func testTheThreeMeasuredDeviationsFromTheDesign() {
        // 1. LotTextFaint als Mikro-Beschriftung.
        let faintOnGround = contrast(Color(hex: "#A09889"), Color(hex: "#E2DCD2"))
        XCTAssertLessThan(faintOnGround, 3, "Wenn #A09889 hier bestuende, waere inkTertiary unnoetig")

        // 2. LotAmber als Marke auf hellem Grund.
        let amberAsMark = contrast(Color(hex: "#D9820F"), Color(hex: "#E2DCD2"))
        XCTAssertLessThan(amberAsMark, 3, "Wenn #D9820F hier bestuende, waere accentMark unnoetig")
        let amberDeepAsMark = contrast(Color(hex: "#B26608"), Color(hex: "#E2DCD2"))
        XCTAssertGreaterThanOrEqual(amberDeepAsMark, 3, "Die Marke muss 3:1 halten")

        // 3. Papierweiss auf Bernstein — der primaere Knopf des Entwurfs.
        let paperOnAmber = contrast(Color(hex: "#FFFDFA"), Color(hex: "#D9820F"))
        XCTAssertLessThan(paperOnAmber, 4.5, "Wenn Weiss hier bestuende, muesste onAccent nicht Tinte sein")
        let inkOnAmber = contrast(Color(hex: "#1C1A16"), Color(hex: "#D9820F"))
        XCTAssertGreaterThanOrEqual(inkOnAmber, 4.5, "Tinte auf Bernstein ist die Loesung")
    }

    // MARK: - Flaechen

    /// Die Kartenflaeche muss sich vom Grund abheben, in **beiden** Modi — sonst ist die
    /// Elevation erfunden.
    ///
    /// „Eine Ebene naeher" heisst auf beiden Seiten **mehr Licht**: hell geht die Karte ueber
    /// den Grund hinaus, dunkel darueber. Eine reine Spiegelung waere hier falsch — im Dunkeln
    /// kann eine Karte nicht heller als Weiss werden.
    func testSurfacesStackFromGroundToCardInBothModes() {
        for dark in [false, true] {
            let ground = relativeLuminance(AnkerColor.ground, dark: dark)
            let sunken = relativeLuminance(AnkerColor.surface, dark: dark)
            let card = relativeLuminance(AnkerColor.card, dark: dark)
            XCTAssertGreaterThan(sunken, ground, "Die eingelassene Flaeche liegt ueber dem Grund (dunkel: \(dark))")
            XCTAssertGreaterThan(card, sunken, "Die Karte liegt ueber der Flaeche (dunkel: \(dark))")
        }
    }

    /// Trenner **innerhalb** einer Karte duerfen nicht staerker wirken als die Karte selbst.
    func testCardDividerIsSubtleOnTheCard() {
        for dark in [false, true] {
            let ratio = contrast(AnkerColor.cardDivider, AnkerColor.card, dark: dark)
            XCTAssertLessThan(ratio, 3, "Ein Zeilentrenner ist kein Rahmen (dunkel: \(dark))")
            XCTAssertGreaterThan(ratio, 1.05, "Sichtbar muss er trotzdem sein (dunkel: \(dark))")
        }
    }

    /// Getoente Hinweisflaechen sind teiltransparent — sie **entstehen** erst beim Zeichnen.
    ///
    /// Genau dort stirbt Kontrast unbemerkt: im Code steht ein Token, gezeichnet wird eine
    /// Mischung aus Token und Grund darunter. Dieser Test misst, was tatsaechlich auf dem Schirm
    /// steht, nicht was im Aufruf steht.
    func testGlassChromeStaysReadable() {
        for dark in [false, true] {
            let mode = dark ? "dunkel" : "hell"
            // Glas sitzt ueber der Karte — der ungünstigste Fall ist die helle Flaeche darunter.
            let chrome = composite(AnkerColor.glassFill, over: AnkerColor.card, dark: dark)
            expect(AnkerColor.ink, on: chrome, atLeast: 7, "Beschriftung auf Glas (\(mode))", dark: dark)
            expect(AnkerColor.inkMuted, on: chrome, atLeast: 4.5, "Nebentext auf Glas (\(mode))", dark: dark)

            // Eine Flaeche, die sich nicht vom Untergrund abhebt, ist keine.
            XCTAssertNotEqual(relativeLuminance(chrome, dark: dark),
                              relativeLuminance(AnkerColor.card, dark: dark),
                              accuracy: 0.0005,
                              "Glas ohne Unterschied zur Flaeche darunter (\(mode))")
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

    /// Zwei Farben so mischen, wie SwiftUI sie uebereinander zeichnet — deckendes Ergebnis.
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
            // Alpha ueber dem jeweiligen Grund aufloesen: Glas und Schatten sind
            // teiltransparent, und ein Kontrast gegen den reinen Farbwert waere geraten.
            let backdrop: Double = dark ? 0.078 : 0.86
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

    private func advance(of character: Character, in font: CTFont) -> CGFloat {
        var glyph = CGGlyph()
        var unichar = Array(String(character).utf16)
        CTFontGetGlyphsForCharacters(font, &unichar, &glyph, 1)
        var advances = CGSize.zero
        CTFontGetAdvancesForGlyphs(font, .horizontal, &glyph, &advances, 1)
        return advances.width
    }
}
