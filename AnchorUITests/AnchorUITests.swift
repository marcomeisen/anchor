import XCTest

/// Der im Spec geforderte Kernfluss: Aufgabe erstellen, an ein Wochenziel verankern,
/// Fortschritt prüfen.
///
/// Läuft mit `-DaiventoUITest`: leerer In-Memory-Store, iCloud aus, Onboarding-Zustand
/// zurückgesetzt. Ohne das Argument liefe der Test gegen die echten Daten des Nutzers.
final class AnchorUITests: XCTestCase {
    private let goalTitle = "Testziel Vertragsprüfung"
    private let taskTitle = "Vertrag gegenlesen"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-DaiventoUITest"]
        app.launch()
        return app
    }

    @MainActor
    func testCreateTaskAnchorToGoalAndSeeProgress() throws {
        let app = launchApp()

        // 1. Onboarding: erstes Wochenziel setzen.
        let goalField = app.textFields["Mein Wochenziel"]
        XCTAssertTrue(goalField.waitForExistence(timeout: 10), "Onboarding wurde nicht angezeigt")
        goalField.click()
        goalField.typeText(goalTitle)

        let startButton = app.buttons["Erstes Wochenziel setzen"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5))
        startButton.click()

        // 2. Danach steht die Zieldetailansicht offen, noch ohne Aufgaben.
        let taskCount = element(app, "goalStat.Aufgaben")
        XCTAssertTrue(taskCount.waitForExistence(timeout: 10), "Zieldetailansicht fehlt")
        XCTAssertEqual(taskCount.label, "0 Aufgaben")
        XCTAssertTrue(element(app, "goalProgress").label.contains("0 Prozent"))

        // 3. Aufgabe anlegen und dabei an das Wochenziel verankern.
        app.buttons["Neue Aufgabe erstellen"].firstMatch.click()

        let titleField = app.textFields["Was steht an?"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5), "Erfassungsblatt fehlt")
        titleField.click()
        titleField.typeText(taskTitle)

        let goalChip = element(app, "goalChip.\(goalTitle)")
        XCTAssertTrue(goalChip.waitForExistence(timeout: 5), "Ziel-Chip zum Verankern fehlt")
        goalChip.click()

        app.buttons["Sichern"].firstMatch.click()

        // Nach dem Sichern springt die App in die Woche des geplanten Tages. Zurück auf das
        // Ziel über die Sidebar — das ist auch der Weg, den ein Nutzer nimmt.
        let sidebarGoal = element(app, "sidebarGoal.\(goalTitle)")
        XCTAssertTrue(sidebarGoal.waitForExistence(timeout: 10), "Ziel fehlt in der Sidebar")
        sidebarGoal.click()

        // 4. Die Aufgabe hängt am Ziel — das ist die Verankerung.
        XCTAssertTrue(
            waitUntil(timeout: 10) { taskCount.label == "1 Aufgaben" },
            "Aufgabe wurde nicht an das Wochenziel verankert (Stand: \(taskCount.label))"
        )
        XCTAssertEqual(element(app, "goalStat.Erledigt").label, "0 Erledigt")

        // 5. Erledigen — über das Kontextmenü der Karte, weil die Karte für VoiceOver ein
        //    zusammengefasstes Element ist und das innere Kästchen nicht einzeln adressierbar.
        let card = app.descendants(matching: .any).matching(identifier: "taskCard").firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5), "Aufgabenkarte fehlt in der Zieldetailansicht")
        card.rightClick()

        let markDone = app.menuItems["Als erledigt markieren"]
        XCTAssertTrue(markDone.waitForExistence(timeout: 5), "Kontextmenü ohne Erledigt-Eintrag")
        markDone.click()

        // 6. Der Fortschritt aktualisiert sich.
        XCTAssertTrue(
            waitUntil(timeout: 10) { element(app, "goalStat.Erledigt").label == "1 Erledigt" },
            "Erledigt-Zähler blieb bei \(element(app, "goalStat.Erledigt").label)"
        )
        XCTAssertTrue(
            waitUntil(timeout: 10) { element(app, "goalProgress").label.contains("100 Prozent") },
            "Fortschritt blieb bei \(element(app, "goalProgress").label)"
        )
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            let app = XCUIApplication()
            app.launchArguments = ["-DaiventoUITest"]
            app.launch()
        }
    }

    /// Die Kennzahlen sind über `accessibilityElement(children: .ignore)` zusammengefasst und
    /// tauchen deshalb als `Other` auf, nicht als `StaticText`. Suche über die Kennung.
    @MainActor
    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// `waitForExistence` prüft nur Existenz. Für einen Textwechsel braucht es ein eigenes
    /// Warten, sonst wird gegen den Stand vor der SwiftData-Aktualisierung geprüft.
    @MainActor
    private func waitUntil(timeout: TimeInterval, condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            _ = XCUIApplication().wait(for: .runningForeground, timeout: 0.2)
        }
        return condition()
    }
}
