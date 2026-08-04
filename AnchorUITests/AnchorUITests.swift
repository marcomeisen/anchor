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

        // 1. Onboarding: der Nutzer setzt seine Anker selbst. Der Bestand hatte hier ein
        //    einzelnes Feld „Mein Wochenziel"; der Neuentwurf vier numerierte.
        let firstAnchor = element(app, "anchorField.1")
        XCTAssertTrue(firstAnchor.waitForExistence(timeout: 10), "Onboarding wurde nicht angezeigt")
        firstAnchor.click()
        firstAnchor.typeText(goalTitle)

        let commit = element(app, "onboardingCommit")
        XCTAssertTrue(commit.waitForExistence(timeout: 5))
        commit.click()

        // 2. Bei genau einem Anker landet man im Zieldetail — noch ohne Aufgaben.
        let taskCount = element(app, "goalStat.Aufgaben")
        XCTAssertTrue(taskCount.waitForExistence(timeout: 10), "Zieldetailansicht fehlt")
        XCTAssertEqual(taskCount.label, "0 von 0 Aufgaben")

        // Der Ring ist weg, der Prozentwert nicht.
        XCTAssertTrue(element(app, "goalProgress").label.contains("0 Prozent"))

        // 3. Aufgabe anlegen und dabei an den Anker verankern.
        app.buttons["Neue Aufgabe erstellen"].firstMatch.click()

        let titleField = app.textFields["Was steht an?"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5), "Erfassungsblatt fehlt")
        titleField.click()
        titleField.typeText(taskTitle)

        // Das Blatt hat eine eigene `@Query`; die braucht einen Moment, bis die Ziele der
        // Woche darin stehen.
        let goalChip = element(app, "goalChip.\(goalTitle)")
        XCTAssertTrue(goalChip.waitForExistence(timeout: 15), "Ziel-Chip zum Verankern fehlt")
        XCTAssertTrue(waitUntil(timeout: 5) { goalChip.isHittable })
        goalChip.click()

        app.buttons["Sichern"].firstMatch.click()

        // Nach dem Sichern springt die App in die Woche des geplanten Tages. Zurück über den
        // Ankerstreifen — seit der zweiten Entwurfsrunde sind die Anker Inhalt und stehen nicht
        // mehr in der Navigation.
        let anchorChip = element(app, "anchorChip.\(goalTitle)")
        XCTAssertTrue(anchorChip.waitForExistence(timeout: 10), "Anker fehlt im Streifen")
        anchorChip.click()

        // 4. Die Aufgabe hängt am Anker — das ist die Verankerung.
        // Der Zaehler ist erledigt/gesamt: die Aufgabe haengt am Anker, ist aber noch offen.
        XCTAssertTrue(
            waitUntil(timeout: 10) { taskCount.label == "0 von 1 Aufgaben" },
            "Aufgabe wurde nicht verankert (Stand: \(taskCount.label))"
        )

        // 5. Der Tempo-Satz ersetzt die Prozentzahl als Aussage.
        XCTAssertTrue(element(app, "goalPace").exists, "Der Tempo-Satz fehlt")

        // 6. Erledigen — in der Tagesliste über das Kontextmenü der Karte. Bewusst dieser Weg
        //    und nicht das Kästchen im Zieldetail: er prüft zusätzlich, dass die Aufgabe im
        //    Tag steht, und führt über den Bildschirmwechsel zurück ins Detail.
        // Der Ansichtswechsel sitzt in der Toolbar, nicht mehr in der Sidebar.
        app.buttons["Heute anzeigen"].firstMatch.click()

        let card = element(app, "taskCard")
        XCTAssertTrue(card.waitForExistence(timeout: 10), "Aufgabenkarte fehlt in der Tagesliste")
        card.rightClick()

        let markDone = app.menuItems["Als erledigt markieren"]
        XCTAssertTrue(markDone.waitForExistence(timeout: 5), "Kontextmenü ohne Erledigt-Eintrag")
        markDone.click()

        app.buttons["Wochenübersicht anzeigen"].firstMatch.click()
        anchorChip.click()

        // 7. Der Fortschritt aktualisiert sich.
        XCTAssertTrue(
            waitUntil(timeout: 10) { taskCount.label == "1 von 1 Aufgaben" },
            "Erledigt-Zähler blieb bei \(taskCount.label)"
        )
        XCTAssertTrue(
            waitUntil(timeout: 10) { element(app, "goalProgress").label.contains("100 Prozent") },
            "Fortschritt blieb bei \(element(app, "goalProgress").label)"
        )
    }

    /// Der zweite Kernfluss des Neuentwurfs: eine Zeile tippen, Enter, fertig — mit Prio,
    /// Anker und Wochentag als Kürzel.
    @MainActor
    func testCaptureBarCreatesAnchoredTaskFromOneLine() throws {
        let app = launchApp()

        let firstAnchor = element(app, "anchorField.1")
        XCTAssertTrue(firstAnchor.waitForExistence(timeout: 10))
        firstAnchor.click()
        firstAnchor.typeText(goalTitle)
        element(app, "onboardingCommit").click()

        // Die Erfassungszeile sitzt im Fuss der Anker-Matrix, nicht im Zieldetail — erst
        // dorthin wechseln.
        let weekButton = app.buttons["Wochenübersicht anzeigen"].firstMatch
        XCTAssertTrue(weekButton.waitForExistence(timeout: 10), "Der Ansichtswechsel fehlt")
        weekButton.click()

        let field = element(app, "captureBar.field")
        XCTAssertTrue(field.waitForExistence(timeout: 10), "Erfassungszeile fehlt")

        // Die Hinweiszeile zeigt den aufgelösten Stand, bevor etwas angelegt wird.
        field.click()
        field.typeText("Vertrag prüfen !a #1")
        let hint = element(app, "captureBar.hint")
        XCTAssertTrue(
            waitUntil(timeout: 5) {
                let text = text(of: hint)
                return text.contains("Prio A") && text.contains("Anker 1")
            },
            "Hinweiszeile löst nicht auf (Stand: \(text(of: hint)))"
        )

        // Ueber `app.buttons` und nicht ueber `descendants(matching: .any)`: letztere trifft
        // die aeussere Huelle, der Klick kommt dann nicht am Knopf an.
        // Ueber `app.buttons` und nicht ueber `descendants(matching: .any)`: letztere trifft
        // die aeussere Huelle, der Klick kommt dann nicht am Knopf an.
        let commitButton = app.buttons["captureBar.commit"].firstMatch
        XCTAssertTrue(commitButton.isHittable, "Der Sichern-Knopf liegt ausserhalb des Fensters")
        commitButton.click()

        // Die Aufgabe ist am Anker gelandet.
        let anchorChip = element(app, "anchorChip.\(goalTitle)")
        XCTAssertTrue(anchorChip.waitForExistence(timeout: 10))
        anchorChip.click()

        let taskCount = element(app, "goalStat.Aufgaben")
        // Der Zaehler ist erledigt/gesamt — die erfasste Aufgabe ist noch offen.
        XCTAssertTrue(
            waitUntil(timeout: 10) { taskCount.label == "0 von 1 Aufgaben" },
            "Die erfasste Aufgabe hängt nicht am Anker (Stand: \(taskCount.label))"
        )
    }

    /// Die Regel der Aufgabenzeile: **das Kästchen hakt ab, der Titel wird bearbeitet.**
    ///
    /// Vorher hakte in der Matrix ein Klick auf die ganze Chipfläche ab — jeder Versuch, eine
    /// Aufgabe anzusehen, änderte ihren Zustand. Der Test hält beide Hälften der Regel fest.
    @MainActor
    func testClickingATaskTitleEditsItInsteadOfCompletingIt() throws {
        let app = launchApp()

        let firstAnchor = element(app, "anchorField.1")
        XCTAssertTrue(firstAnchor.waitForExistence(timeout: 10))
        firstAnchor.click()
        firstAnchor.typeText(goalTitle)
        element(app, "onboardingCommit").click()

        // In die Matrix und über die Erfassungszeile eine Aufgabe anlegen.
        let weekButton = app.buttons["Wochenübersicht anzeigen"].firstMatch
        XCTAssertTrue(weekButton.waitForExistence(timeout: 10))
        weekButton.click()

        let field = element(app, "captureBar.field")
        XCTAssertTrue(field.waitForExistence(timeout: 10), "Erfassungszeile fehlt")
        field.click()
        field.typeText("Vertrag prüfen #1")
        app.buttons["captureBar.commit"].firstMatch.click()

        // 1. Der Titel: ein Doppelklick öffnet ihn zum Tippen, statt abzuhaken.
        let chip = app.staticTexts["Vertrag prüfen"].firstMatch
        XCTAssertTrue(chip.waitForExistence(timeout: 10), "Aufgabe fehlt in der Matrix")
        chip.doubleClick()

        let titleField = app.textFields["taskTitleField"].firstMatch
        XCTAssertTrue(titleField.waitForExistence(timeout: 5), "Der Titel öffnet sich nicht zum Tippen")
        // Ausdrücklich anklicken: das Feld setzt seinen Fokus selbst, aber im Testläufer ist das
        // Fenster nicht zwingend das Tastaturfenster.
        titleField.click()
        titleField.typeKey("a", modifierFlags: .command)
        titleField.typeText("Vertrag gegengelesen\n")

        XCTAssertTrue(
            waitUntil(timeout: 10) { app.staticTexts["Vertrag gegengelesen"].firstMatch.exists },
            "Der neue Titel steht nicht in der Matrix"
        )

        // Und der Zustand ist unberührt: der Anker zählt weiter 0 von 1.
        let anchorChip = element(app, "anchorChip.\(goalTitle)")
        XCTAssertTrue(anchorChip.waitForExistence(timeout: 5))
        XCTAssertTrue(
            anchorChip.label.contains("0 von 1"),
            "Bearbeiten darf nichts abhaken (Stand: \(anchorChip.label))"
        )

        // 2. Das Kästchen: das hakt ab.
        let toggle = app.buttons["matrixChipToggle"].firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 5), "Kästchen im Chip fehlt")
        toggle.click()

        XCTAssertTrue(
            waitUntil(timeout: 10) { element(app, "anchorChip.\(goalTitle)").label.contains("1 von 1") },
            "Das Kästchen hakt nicht ab (Stand: \(element(app, "anchorChip.\(goalTitle)").label))"
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
