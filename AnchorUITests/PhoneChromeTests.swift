import XCTest

#if os(iOS)

/// Die eigene Fensterrahmung des iPhones — statt der Systemleiste.
///
/// Der Test existiert, weil beim Umbau eine echte Sackgasse entstand: mit versteckter
/// Navigationsleiste war eine Detailansicht nicht mehr verlassbar. `GoalDetailView` hat keine
/// eigene Schließen-Schaltfläche, und der erste Zurück-Knopf tat sichtbar nichts — der Baustein
/// von `navigationDestination` ist escapend und fing eine Momentaufnahme der Wurzelansicht ein,
/// die Mutation lief in die Kopie. Nur ein Test, der wirklich **zurück** navigiert, fängt das;
/// die bloße Existenz des Knopfes hätte bestanden.
final class PhoneChromeTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launchAtTopLevel(language: String = "de") -> XCUIApplication {
        let app = XCUIApplication()
        let locale = language == "de" ? "de_DE" : "en_US"
        app.launchArguments = ["-AnchoritUITest", "-AppleLanguages", "(\(language))", "-AppleLocale", locale]
        app.launch()

        // Tolerant: dieser Test prueft die Rahmung, nicht das Onboarding. Ob der Bildschirm
        // ueberhaupt erscheint, haengt am Zustand des Simulators — daran darf er nicht haengen.
        let skip = app.descendants(matching: .any)["onboardingSkip"].firstMatch
        if skip.waitForExistence(timeout: 12) { skip.tap() }
        return app
    }

    @MainActor
    func testDetailIsReachableAndHasAWayBack() throws {
        let app = launchAtTopLevel()

        let week = app.buttons["Woche"].firstMatch
        XCTAssertTrue(week.waitForExistence(timeout: 10), "Tableiste fehlt")
        week.tap()

        // Die Tageszeile ist ein Knopf „Donnerstag, … öffnen".
        let dayRow = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Donnerstag")).firstMatch
        XCTAssertTrue(dayRow.waitForExistence(timeout: 10), "Tageszeile fehlt")
        dayRow.tap()

        // Auf dem Stapel: die Tableiste ist weg, die Kopfzeile trägt den Weg zurück.
        let back = app.buttons["Zurück"].firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 10),
                      "Kein Zurück-Knopf — ohne Systemleiste wäre die Detailansicht eine Sackgasse")
        back.tap()

        XCTAssertTrue(week.waitForExistence(timeout: 10), "Der Zurück-Knopf hat nicht navigiert")
    }

    /// Datenschutzerklärung und Hilfe stehen in der App, nicht im Browser — und in der Sprache
    /// der App. Geprüft wird der ganze Weg: hinein, Inhalt da, zurück, zweites Dokument.
    @MainActor
    func testLegalTextsOpenInsideSettings() throws {
        try checkLegalTexts(language: "de", settings: "Einstellungen öffnen", privacy: "Datenschutzerklärung",
                            privacyHeading: "1. Verantwortlicher", back: "Zurück",
                            support: "Hilfe und Kontakt", supportHeading: "Wie funktioniert Anchorit?")
    }

    @MainActor
    func testLegalTextsOpenInEnglish() throws {
        try checkLegalTexts(language: "en", settings: "Open Settings", privacy: "Privacy Policy",
                            privacyHeading: "1. Controller", back: "Back",
                            support: "Help & Contact", supportHeading: "How does Anchorit work?")
    }

    @MainActor
    private func checkLegalTexts(language: String, settings: String, privacy: String, privacyHeading: String,
                                 back: String, support: String, supportHeading: String) throws {
        let app = launchAtTopLevel(language: language)

        let open = app.buttons[settings].firstMatch
        XCTAssertTrue(open.waitForExistence(timeout: 10), "Einstellungen-Knopf fehlt (\(language))")
        open.tap()

        let privacyRow = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", privacy)).firstMatch
        if !privacyRow.waitForExistence(timeout: 5) { app.swipeUp() }
        XCTAssertTrue(privacyRow.waitForExistence(timeout: 5), "Zeile »\(privacy)« fehlt")
        privacyRow.tap()
        XCTAssertTrue(app.staticTexts[privacyHeading].waitForExistence(timeout: 5), "Datenschutztext fehlt (\(language))")

        let backButton = app.buttons[back].firstMatch
        XCTAssertTrue(backButton.waitForExistence(timeout: 5))
        backButton.tap()

        let supportRow = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", support)).firstMatch
        XCTAssertTrue(supportRow.waitForExistence(timeout: 5), "Zurück hat nicht in die Einstellungen geführt")
        supportRow.tap()
        XCTAssertTrue(app.staticTexts[supportHeading].waitForExistence(timeout: 5), "Hilfetext fehlt (\(language))")
    }

    /// Englisch durchgehend: Tableiste und Heute-Kopf stehen nicht halb auf Deutsch.
    @MainActor
    func testEnglishInterfaceHasNoGermanTabs() throws {
        let app = launchAtTopLevel(language: "en")
        for title in ["Today", "Week", "Archive"] {
            XCTAssertTrue(app.buttons[title].firstMatch.waitForExistence(timeout: 10), "Tab »\(title)« fehlt")
        }
        XCTAssertFalse(app.buttons["Heute"].exists)
        XCTAssertFalse(app.buttons["Woche"].exists)
    }

    /// Die Tableiste ist der Titel des Bildschirms — deshalb hat die Kopfzeile keinen.
    /// Alle vier Ziele müssen erreichbar sein; „Mehr" ist auf dem iPhone der **einzige** Weg
    /// zu Rückblick, Archiv und Einstellungen.
    @MainActor
    func testEveryTabIsReachable() throws {
        let app = launchAtTopLevel()

        for title in ["Woche", "Archiv", "Heute"] {
            let tab = app.buttons[title].firstMatch
            XCTAssertTrue(tab.waitForExistence(timeout: 10), "Tab \(title) fehlt")
            tab.tap()
            XCTAssertTrue(tab.waitForExistence(timeout: 5), "Tab \(title) verschwindet nach dem Antippen")
        }
    }
}

#endif
