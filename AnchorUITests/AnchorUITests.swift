import XCTest

/// Der im Spec geforderte Kernfluss: Aufgabe erstellen, an ein Wochenziel verankern,
/// Fortschritt prüfen.
///
/// Läuft mit `-AnchoritUITest`: leerer In-Memory-Store, iCloud aus, Onboarding-Zustand
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
        app.launchArguments = ["-AnchoritUITest", "-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
        app.launch()
        return app
    }

    /// Der Kern von „Blatt": eine Aufgabe an einen Anker hängen, abhaken, und der Punkt beim
    /// Anker füllt sich.
    @MainActor
    func testCaptureAnchorsATaskAndCheckingItFillsTheAnchor() throws {
        let app = launchApp()
        completeOnboarding(app)

        // Heute ist der Einstieg. Die Ankerleiste zeigt den einen Anker, noch ohne Aufgabe.
        let cell = element(app, "anchorCell.1")
        XCTAssertTrue(cell.waitForExistence(timeout: 10), "Ankerleiste fehlt auf Heute")
        XCTAssertTrue(cell.label.contains("0 von 0"), "Stand: \(cell.label)")

        // Eine Zeile, ein Anker: `#1` hängt die Aufgabe an Anker 1, ohne Wochentag auf heute.
        let field = element(app, "captureBar.field")
        XCTAssertTrue(field.waitForExistence(timeout: 10), "Erfassungszeile fehlt")
        field.click()
        field.typeText("Vertrag prüfen !a #1")
        let hint = element(app, "captureBar.hint")
        XCTAssertTrue(
            waitUntil(timeout: 5) { text(of: hint).contains("Prio A") && text(of: hint).contains("Anker 1") },
            "Hinweiszeile löst nicht auf (Stand: \(text(of: hint)))"
        )
        app.buttons["captureBar.commit"].firstMatch.click()

        XCTAssertTrue(
            waitUntil(timeout: 10) { element(app, "anchorCell.1").label.contains("0 von 1") },
            "Aufgabe wurde nicht verankert (Stand: \(element(app, "anchorCell.1").label))"
        )

        // Abhaken über das Kontextmenü der Karte in der Tagesliste.
        let card = element(app, "taskCard")
        XCTAssertTrue(card.waitForExistence(timeout: 10), "Aufgabenkarte fehlt in der Tagesliste")
        card.rightClick()
        let markDone = app.menuItems["Als erledigt markieren"]
        XCTAssertTrue(markDone.waitForExistence(timeout: 5), "Kontextmenü ohne Erledigt-Eintrag")
        markDone.click()

        XCTAssertTrue(
            waitUntil(timeout: 10) { element(app, "anchorCell.1").label.contains("1 von 1") },
            "Der Punkt beim Anker füllt sich nicht (Stand: \(element(app, "anchorCell.1").label))"
        )

        // Und der Anker selbst sagt dasselbe.
        element(app, "anchorCell.1").click()
        let progress = element(app, "anchorProgress")
        XCTAssertTrue(progress.waitForExistence(timeout: 10), "Ankeransicht fehlt")
        XCTAssertTrue(waitUntil(timeout: 5) { text(of: progress).contains("1 von 1") }, "Stand: \(text(of: progress))")

        // Zurück muss es geben — ohne Systemleiste wäre die Ansicht eine Sackgasse.
        let back = app.buttons["Zurück"].firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 5), "Kein Weg zurück aus der Ankeransicht")
        back.click()
        XCTAssertTrue(element(app, "anchorCell.1").waitForExistence(timeout: 5), "Zurück führt nicht nach Heute")
    }

    /// Die Woche zeigt beide Ansichten mit denselben Daten.
    @MainActor
    func testWeekOffersGridAndAnchorViewWithTheSameTask() throws {
        let app = launchApp()
        completeOnboarding(app)

        let field = element(app, "captureBar.field")
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.click()
        field.typeText("Vertrag prüfen #1")
        app.buttons["captureBar.commit"].firstMatch.click()

        app.buttons["Woche"].firstMatch.click()
        let grid = app.buttons["Raster"].firstMatch
        XCTAssertTrue(grid.waitForExistence(timeout: 10), "Der Ansichtswechsel der Woche fehlt")
        XCTAssertTrue(element(app, "taskChip").waitForExistence(timeout: 10), "Aufgabe fehlt im Raster")

        app.buttons["Nach Anker"].firstMatch.click()
        XCTAssertTrue(element(app, "taskChip").waitForExistence(timeout: 10), "Aufgabe fehlt in der Ansicht nach Anker")
    }

    /// „Das Kästchen hakt ab, der Titel wird bearbeitet." Ein Doppelklick auf den Titel öffnet
    /// ihn zum Tippen und ändert den Zustand **nicht**.
    @MainActor
    func testClickingATaskTitleEditsItInsteadOfCompletingIt() throws {
        let app = launchApp()
        completeOnboarding(app)

        let field = element(app, "captureBar.field")
        XCTAssertTrue(field.waitForExistence(timeout: 10), "Erfassungszeile fehlt")
        field.click()
        field.typeText("Vertrag prüfen #1")
        app.buttons["captureBar.commit"].firstMatch.click()

        let title = app.staticTexts["Vertrag prüfen"].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 10), "Aufgabe fehlt in der Tagesliste")
        title.doubleClick()

        let titleField = app.textFields["taskTitleField"].firstMatch
        XCTAssertTrue(titleField.waitForExistence(timeout: 5), "Der Titel öffnet sich nicht zum Tippen")
        titleField.click()
        titleField.typeKey("a", modifierFlags: .command)
        titleField.typeText("Vertrag gegengelesen\n")

        XCTAssertTrue(
            waitUntil(timeout: 10) { app.staticTexts["Vertrag gegengelesen"].firstMatch.exists },
            "Der neue Titel steht nicht in der Liste"
        )
        XCTAssertTrue(
            element(app, "anchorCell.1").label.contains("0 von 1"),
            "Bearbeiten darf nichts abhaken (Stand: \(element(app, "anchorCell.1").label))"
        )
    }

    @MainActor
    private func completeOnboarding(_ app: XCUIApplication) {
        let firstAnchor = element(app, "anchorField.1")
        XCTAssertTrue(firstAnchor.waitForExistence(timeout: 10), "Onboarding wurde nicht angezeigt")
        firstAnchor.click()
        firstAnchor.typeText(goalTitle)
        element(app, "onboardingCommit").click()
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            let app = XCUIApplication()
            app.launchArguments = ["-AnchoritUITest", "-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
            app.launch()
        }
    }

    /// Die Kennzahlen sind über `accessibilityElement(children: .ignore)` zusammengefasst und
    /// tauchen deshalb als `Other` auf, nicht als `StaticText`. Suche über die Kennung.
    @MainActor
    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// Ein `Text` traegt seinen Inhalt in `value`, ein zusammengefasstes Element in `label`.
    /// Beides abfragen, sonst haengt die Zusicherung an einer Implementierungsentscheidung
    /// der Ansicht statt an dem, was der Nutzer liest.
    @MainActor
    private func text(of element: XCUIElement) -> String {
        if !element.label.isEmpty { return element.label }
        return element.value as? String ?? ""
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
