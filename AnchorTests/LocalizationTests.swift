import XCTest
@testable import Anchorit

/// Englisch als zweite Sprache — geprüft am **gebauten** App-Paket, nicht am Katalog.
///
/// Der Testlauf selbst ist auf Deutsch festgelegt (Scheme → Test → App Language), damit die
/// übrigen Tests deutsche Texte vergleichen können. Diese Tests lesen die Sprachtabellen
/// deshalb direkt aus `de.lproj` und `en.lproj`.
final class LocalizationTests: XCTestCase {

    private func table(_ language: String) throws -> [String: String] {
        let path = try XCTUnwrap(Bundle.main.path(forResource: "Localizable", ofType: "strings", inDirectory: nil, forLocalization: language),
                                 "\(language).lproj/Localizable.strings fehlt im App-Paket")
        return try XCTUnwrap(NSDictionary(contentsOfFile: path) as? [String: String])
    }

    /// Ohne eigene deutsche Tabelle fiele ein deutsches Gerät auf die Rückfallsprache
    /// Englisch — so sah es in der ersten Fassung aus.
    func testBothLanguagesShipAndCoverTheSameKeys() throws {
        let german = try table("de")
        let english = try table("en")
        XCTAssertGreaterThan(german.count, 300)
        XCTAssertGreaterThan(english.count, 400)
        XCTAssertEqual(Set(german.keys).subtracting(english.keys), [], "Englisch fehlt für diese Schlüssel")
        // Xcode lässt deutsche Einträge mit mehreren Platzhaltern weg, wenn sie dem Schlüssel
        // gleichen; dann liefert das System den Schlüssel selbst — also das Deutsche. Wichtig
        // ist nur: Es gibt eine deutsche Tabelle, sonst wählte das System Englisch.
        for (key, value) in german {
            XCTAssertEqual(value, key, "Deutsch weicht vom Schlüssel ab: \(key)")
        }
    }

    func testEnglishIsTranslatedNotCopied() throws {
        let english = try table("en")
        let umlauts = english.filter { $0.value.rangeOfCharacter(from: CharacterSet(charactersIn: "äöüÄÖÜß")) != nil }
        XCTAssertEqual(umlauts.keys.sorted(), [], "Englische Texte mit Umlaut")

        XCTAssertEqual(english["Heute"], "Today")
        XCTAssertEqual(english["Anker setzen"], "Set anchors")
        XCTAssertEqual(english["Noch ohne Tag"], "No day yet")
        XCTAssertEqual(english["Rückblick"], "Review")
        XCTAssertEqual(english["KW %@"], "Week %@")
        XCTAssertEqual(english["Gehalten"], "Held")
    }

    func testPlaceholdersSurviveTranslation() throws {
        let english = try table("en")
        let pattern = try NSRegularExpression(pattern: #"%(?:\d+\$)?(@|lld|ld|d)"#)
        func kinds(_ text: String) -> [String] {
            pattern.matches(in: text, range: NSRange(text.startIndex..., in: text))
                .map { String(text[Range($0.range(at: 1), in: text)!]) }.sorted()
        }
        let broken = english.filter { kinds($0.key) != kinds($0.value) }
        XCTAssertEqual(broken.keys.sorted(), [], "Platzhalter passen nicht")
    }

    func testDeclaredLanguagesAndEnglishFallback() {
        let info = Bundle.main.infoDictionary ?? [:]
        XCTAssertEqual(info["CFBundleDevelopmentRegion"] as? String, "en",
                       "Ohne passende Übersetzung soll Englisch gelten, nicht die Quellsprache Deutsch")
        XCTAssertEqual(Set(info["CFBundleLocalizations"] as? [String] ?? []), ["de", "en"])
        // Ein französisches Gerät bekommt Englisch.
        XCTAssertEqual(Bundle.preferredLocalizations(from: ["de", "en"], forPreferences: ["fr-FR"]).first, "en")
        XCTAssertEqual(Bundle.preferredLocalizations(from: ["de", "en"], forPreferences: ["de-AT"]).first, "de")
    }

    // MARK: - Sprachwahl

    func testLanguageChoiceWritesAndClearsTheAppleLanguagesOverride() throws {
        let suite = "LocalizationTests.\(#function)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        XCTAssertEqual(AppLanguage.stored(in: defaults), .system)

        AppLanguage.select(.english, in: defaults)
        XCTAssertEqual(AppLanguage.stored(in: defaults), .english)
        XCTAssertEqual(defaults.persistentDomain(forName: suite)?[AppSettingsKey.appleLanguages] as? [String], ["en"])

        AppLanguage.select(.german, in: defaults)
        XCTAssertEqual(defaults.persistentDomain(forName: suite)?[AppSettingsKey.appleLanguages] as? [String], ["de"])

        // „Wie das System" entfernt die Vorgabe wieder, statt eine Sprache festzuschreiben.
        AppLanguage.select(.system, in: defaults)
        XCTAssertNil(defaults.persistentDomain(forName: suite)?[AppSettingsKey.appleLanguages])
    }

    func testSystemLanguageMeansGermanOnlyForGermanSystems() {
        XCTAssertEqual(AppLanguage.expectedCode(for: .system, systemLanguages: ["de-DE", "en-US"]), "de")
        XCTAssertEqual(AppLanguage.expectedCode(for: .system, systemLanguages: ["de-CH"]), "de")
        XCTAssertEqual(AppLanguage.expectedCode(for: .system, systemLanguages: ["en-US", "de-DE"]), "en")
        XCTAssertEqual(AppLanguage.expectedCode(for: .system, systemLanguages: ["fr-FR"]), "en")
        XCTAssertEqual(AppLanguage.expectedCode(for: .german, systemLanguages: ["fr-FR"]), "de")
        XCTAssertEqual(AppLanguage.expectedCode(for: .english, systemLanguages: ["de-DE"]), "en")
    }

    func testUITestModeNeverTouchesTheLanguage() {
#if DEBUG
        let before = [AppSettingsKey.language, AppSettingsKey.appleLanguages].map { UserDefaults.standard.object(forKey: $0) as? NSObject }
        UITestMode.resetTestDefaults()
        let after = [AppSettingsKey.language, AppSettingsKey.appleLanguages].map { UserDefaults.standard.object(forKey: $0) as? NSObject }
        XCTAssertEqual(before, after)
#endif
    }

    // MARK: - Erfassung auf Englisch

    func testEnglishCaptureUsesEnglishWeekdays() {
        let tokens = CaptureSyntax.englishWeekdayTokens
        XCTAssertEqual(CaptureSyntax.parse("Call grandma th", weekdayTokens: tokens).weekdayIndex, 4)
        XCTAssertEqual(CaptureSyntax.parse("Long run sun #2", weekdayTokens: tokens).weekdayIndex, 7)
        XCTAssertEqual(CaptureSyntax.parse("Review notes tu", weekdayTokens: tokens).title, "Review notes")
    }

    /// „do" ist im Englischen ein Wort und kein Donnerstag, „so" ebenso kein Sonntag.
    func testEnglishCaptureKeepsCommonWords() {
        let tokens = CaptureSyntax.englishWeekdayTokens
        let todo = CaptureSyntax.parse("Things to do", weekdayTokens: tokens)
        XCTAssertNil(todo.weekdayIndex)
        XCTAssertEqual(todo.title, "Things to do")
        XCTAssertNil(CaptureSyntax.parse("Do it so", weekdayTokens: tokens).weekdayIndex)
    }

    func testGermanCaptureIsUnchanged() {
        let tokens = CaptureSyntax.germanWeekdayTokens
        XCTAssertEqual(CaptureSyntax.parse("Bericht do", weekdayTokens: tokens).weekdayIndex, 4)
        XCTAssertNil(CaptureSyntax.parse("Call grandma th", weekdayTokens: tokens).weekdayIndex)
    }

    // MARK: - Rechtstexte

    func testLegalTextsKnowTheirPlaceholders() {
        // Solange Name und Kontakt nicht eingetragen sind, darf kein Mail-Link entstehen.
        if LegalInfo.hasPlaceholders {
            XCTAssertNil(LegalInfo.mailURL)
        } else {
            XCTAssertNotNil(LegalInfo.mailURL)
        }
        XCTAssertFalse(LegalDocument.privacy.sections.isEmpty)
        XCTAssertFalse(LegalDocument.support.sections.isEmpty)
    }
}
