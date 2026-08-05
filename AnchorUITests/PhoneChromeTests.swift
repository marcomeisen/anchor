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
    private func launchAtTopLevel() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-DaiventoUITest"]
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

        let dayRow = app.staticTexts["Donnerstag"].firstMatch
        XCTAssertTrue(dayRow.waitForExistence(timeout: 10), "Tageszeile fehlt")
        dayRow.tap()

        // Auf dem Stapel: die Tableiste ist weg, die Kopfzeile trägt den Weg zurück.
        let back = app.buttons["Zurück"].firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 10),
                      "Kein Zurück-Knopf — ohne Systemleiste wäre die Detailansicht eine Sackgasse")
        back.tap()

        XCTAssertTrue(week.waitForExistence(timeout: 10), "Der Zurück-Knopf hat nicht navigiert")
    }

    /// Die Tableiste ist der Titel des Bildschirms — deshalb hat die Kopfzeile keinen.
    /// Alle vier Ziele müssen erreichbar sein; „Mehr" ist auf dem iPhone der **einzige** Weg
    /// zu Rückblick, Archiv und Einstellungen.
    @MainActor
    func testEveryTabIsReachable() throws {
        let app = launchAtTopLevel()

        for title in ["Woche", "Jahr", "Mehr", "Heute"] {
            let tab = app.buttons[title].firstMatch
            XCTAssertTrue(tab.waitForExistence(timeout: 10), "Tab \(title) fehlt")
            tab.tap()
            XCTAssertTrue(tab.waitForExistence(timeout: 5), "Tab \(title) verschwindet nach dem Antippen")
        }
    }
}

#endif
