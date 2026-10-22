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

        app.tabBars.buttons["More"].tap()
        let calendarRow = app.staticTexts["Calendar"]
        XCTAssertTrue(calendarRow.waitForExistence(timeout: 5))
        calendarRow.tap()

        let allFilter = app.buttons["All"]
        XCTAssertTrue(allFilter.waitForExistence(timeout: 5))
        allFilter.tap()
        XCTAssertTrue(app.staticTexts["Action Preview Test Task"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testInvalidActionShowsErrorAndDoesNotCreateTask() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing-reset-tasks",
            "-ui-testing-invalid-action-preview"
        ]
        app.launch()
        app.tabBars.buttons["Chat"].tap()

        XCTAssertTrue(
            app.navigationBars["Review actions"].waitForExistence(timeout: 5)
        )
        app.buttons["Confirm"].tap()

        let error = app.staticTexts[
            "A proposed task changed or is invalid. Nothing was saved; please ask LifePilot to prepare the actions again."
        ]
        XCTAssertTrue(error.waitForExistence(timeout: 5))

        app.terminate()
        app.launchArguments = ["-ui-testing-calendar"]
        app.launch()
        app.buttons["All"].tap()

        XCTAssertFalse(app.staticTexts["Invalid Preview Test Task"].exists)
    }

    @MainActor
    func testTaskActionSaveFailureShowsErrorAndPreservesExistingData() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing-reset-tasks",
            "-ui-testing-corrupt-task-storage",
            "-ui-testing-action-preview"
        ]
        app.launch()
        app.tabBars.buttons["Chat"].tap()

        XCTAssertTrue(app.navigationBars["Review actions"].waitForExistence(timeout: 5))
        app.buttons["Confirm"].tap()

        XCTAssertTrue(
            app.staticTexts[
                "Could not save calendar changes. Your existing task data was preserved."
            ].waitForExistence(timeout: 5)
        )
        XCTAssertFalse(app.navigationBars["Review actions"].exists)
    }

    @MainActor
    func testCalendarSaveFailureKeepsEditorOpenAndShowsError() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing-reset-tasks",
            "-ui-testing-corrupt-task-storage",
            "-ui-testing-calendar"
        ]
        app.launch()

        app.buttons["Add task"].tap()

        let titleField = app.textFields["What do you need to do?"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        titleField.tap()
        titleField.typeText("Must Not Be Saved")
        app.buttons["Save"].tap()

        let saveError = app.alerts["Couldn't Save Task"]
        XCTAssertTrue(saveError.waitForExistence(timeout: 5))
        saveError.buttons["OK"].tap()

        XCTAssertTrue(
            titleField.waitForExistence(timeout: 5),
            "The editor should remain open when saving fails."
        )
    }

    @MainActor
    func testTaskDeletionRequiresConfirmation() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-reset-tasks", "-ui-testing-calendar"]
        app.launch()

        let allFilter = app.buttons["All"]
        XCTAssertTrue(allFilter.waitForExistence(timeout: 5))
        allFilter.tap()

        app.buttons["Add task"].tap()
        let titleField = app.textFields["What do you need to do?"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        titleField.tap()
        titleField.typeText("UI Delete Test Task")
        app.buttons["Save"].tap()

        let taskTitle = app.staticTexts["UI Delete Test Task"]
        let taskList = app.collectionViews.firstMatch

        // New tasks are appended to the list and may initially be off-screen.
        for _ in 0..<8 {
            if taskTitle.waitForExistence(timeout: 1) {
                break
            }
            taskList.swipeUp()
        }

        XCTAssertTrue(taskTitle.exists, "Created task not found in Calendar UI")

        let taskActions = app.buttons["Task actions"]
        XCTAssertTrue(taskActions.waitForExistence(timeout: 5))
        taskActions.tap()
        app.buttons["Delete"].tap()

        let confirmation = app.alerts["Delete this task?"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5))
        confirmation.buttons["Cancel"].tap()
        XCTAssertTrue(taskTitle.waitForExistence(timeout: 5))

        let secondTaskActions = app.buttons["Task actions"]
        XCTAssertTrue(secondTaskActions.waitForExistence(timeout: 5))
        secondTaskActions.tap()
        app.buttons["Delete"].tap()

        let secondConfirmation = app.alerts["Delete this task?"]
        XCTAssertTrue(secondConfirmation.waitForExistence(timeout: 5))
        secondConfirmation.buttons["Delete"].tap()
        XCTAssertFalse(taskTitle.waitForExistence(timeout: 3))
    }

    @MainActor
    func testCalendarTaskCanBeEdited() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-reset-tasks", "-ui-testing-calendar"]
        app.launch()

        let allFilter = app.buttons["All"]
        XCTAssertTrue(allFilter.waitForExistence(timeout: 5))
        allFilter.tap()

        app.buttons["Add task"].tap()

        let titleField = app.textFields["What do you need to do?"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        titleField.tap()
        titleField.typeText("UI Edit Original Task")
        app.buttons["Save"].tap()

        XCTAssertTrue(
            app.staticTexts["UI Edit Original Task"].waitForExistence(timeout: 5)
        )

        app.buttons["Task actions"].firstMatch.tap()
        app.buttons["Edit"].tap()

        XCTAssertTrue(app.navigationBars["Edit task"].waitForExistence(timeout: 5))

        let editTitleField = app.textFields["What do you need to do?"]
        XCTAssertTrue(editTitleField.waitForExistence(timeout: 5))
        editTitleField.tap()
        XCTAssertTrue(
            app.keyboards.firstMatch.waitForExistence(timeout: 5),
            "Keyboard should appear when editing the task title"
        )
        editTitleField.typeText(
            String(
                repeating: XCUIKeyboardKey.delete.rawValue,
                count: "UI Edit Original Task".count
            )
        )
        editTitleField.typeText("UI Edit Updated Task")

        let priorityPicker = app.descendants(matching: .any)
            .matching(identifier: "taskPriorityPicker")
            .firstMatch

        XCTAssertTrue(
            priorityPicker.waitForExistence(timeout: 5),
            "Priority picker should exist on the Edit task screen"
        )
        XCTAssertTrue(
            priorityPicker.isHittable,
            "Priority picker should be hittable"
        )
        priorityPicker.tap()

        let urgentOption = app.buttons["Urgent"]
        XCTAssertTrue(urgentOption.waitForExistence(timeout: 5))
        urgentOption.tap()

        app.buttons["Save"].tap()

        XCTAssertTrue(
            app.staticTexts["UI Edit Updated Task"].waitForExistence(timeout: 5)
        )
        XCTAssertFalse(app.staticTexts["UI Edit Original Task"].exists)
        XCTAssertTrue(app.staticTexts["Urgent"].exists)
    }

    @MainActor
    func testCalendarTaskCanBeCompletedAndReopened() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-reset-tasks", "-ui-testing-calendar"]
        app.launch()

        let allFilter = app.buttons["All"]
        XCTAssertTrue(allFilter.waitForExistence(timeout: 5))
        allFilter.tap()

        app.buttons["Add task"].tap()

        let titleField = app.textFields["What do you need to do?"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        titleField.tap()
        titleField.typeText("UI Completion Lifecycle Task")
        app.buttons["Save"].tap()

        let taskTitle = app.staticTexts["UI Completion Lifecycle Task"]
        XCTAssertTrue(taskTitle.waitForExistence(timeout: 5))

        app.buttons["Task actions"].firstMatch.tap()
        app.buttons["Complete"].tap()

        let completedFilter = app.buttons["Completed"]
        XCTAssertTrue(completedFilter.waitForExistence(timeout: 5))
        completedFilter.tap()
        XCTAssertTrue(taskTitle.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Mark incomplete"].exists)

        app.buttons["Task actions"].firstMatch.tap()
        app.buttons["Mark Incomplete"].tap()

        allFilter.tap()
        XCTAssertTrue(taskTitle.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Complete task"].exists)
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
