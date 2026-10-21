//
//  LifePilotUITests.swift
//  LifePilotUITests
//
//  Created by AYUSH PRASAD on 20/10/26.
//

import XCTest

final class LifePilotUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }


    @MainActor
    func testPrimaryTabNavigation() throws {
        let app = XCUIApplication()
        app.launch()

        for name in ["Home", "Documents", "Assistant", "Chat"] {
            let tab = app.tabBars.buttons[name]
            XCTAssertTrue(tab.waitForExistence(timeout: 5), "Missing tab: \\(name)")
            tab.tap()
            XCTAssertTrue(tab.isSelected, "Tab was not selected: \\(name)")
        }
    }

    @MainActor
    func testActionPreviewCanBeCancelled() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-reset-tasks", "-ui-testing-action-preview"]
        app.launch()
        app.tabBars.buttons["Chat"].tap()

        XCTAssertTrue(app.navigationBars["Review actions"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
        XCTAssertFalse(app.navigationBars["Review actions"].exists)

        app.terminate()
        app.launchArguments = ["-ui-testing-calendar"]
        app.launch()
        app.buttons["All"].tap()
        XCTAssertFalse(app.staticTexts["Action Preview Test Task"].exists)
    }

    @MainActor
    func testActionPreviewCanBeConfirmed() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-reset-tasks", "-ui-testing-action-preview"]
        app.launch()
        app.tabBars.buttons["Chat"].tap()

        XCTAssertTrue(app.navigationBars["Review actions"].waitForExistence(timeout: 5))
        app.buttons["Confirm"].tap()
        XCTAssertFalse(app.navigationBars["Review actions"].exists)

        app.terminate()
        app.launchArguments = ["-ui-testing-calendar"]
        app.launch()
        app.buttons["All"].tap()
        XCTAssertTrue(app.staticTexts["Action Preview Test Task"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
