//
//  AnchorUITestsLaunchTests.swift
//  AnchoritUITests
//
//  Created by Marco Meisen on 31.07.26.
//

import XCTest

final class AnchorUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        // Ohne `-AnchoritUITest` liefe der Test gegen den echten Store und das echte iCloud
        // des Nutzers — und legte ein Bildschirmfoto davon ins Testergebnis.
        let app = XCUIApplication()
        app.launchArguments = ["-AnchoritUITest", "-AnchoritDemoData", "-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
        app.launch()

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
