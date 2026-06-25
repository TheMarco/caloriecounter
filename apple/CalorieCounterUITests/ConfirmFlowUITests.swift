//
//  ConfirmFlowUITests.swift
//  The signature log → confirm → save → undo journey against the real stack
//  (-uitest: in-memory store, deterministic heuristic parser). Confirms the
//  reworked MealCard confirmation still saves, and that a save offers a one-tap
//  undo that removes the entry.
//

import XCTest

final class ConfirmFlowUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testSaveOffersUndoThatRemovesTheEntry() {
        let app = XCUIApplication()
        app.launchArguments += ["-uitest"]
        app.launch()

        // Log a known food: dock + → fan → Text → confirm → Add.
        let plus = app.buttons["Log food"]
        XCTAssertTrue(plus.waitForExistence(timeout: 10), "The dock's + (Log food) should exist")
        plus.tap()
        app.buttons["Text"].tap()
        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Text field should appear")
        field.tap()
        field.typeText("apple")
        app.buttons["Analyze"].tap()

        let add = app.buttons["Add"]
        XCTAssertTrue(add.waitForExistence(timeout: 5), "The reworked confirm screen should still offer Add")
        add.tap()

        // The entry appears on Today, with a one-tap undo toast.
        XCTAssertTrue(app.staticTexts["apple"].waitForExistence(timeout: 5),
                      "Saved entry should appear on Today")
        let undo = app.buttons["Undo"]
        XCTAssertTrue(undo.waitForExistence(timeout: 5), "A save should offer an undo toast")
        undo.tap()

        // Undo removes the just-logged entry, restoring the empty state.
        XCTAssertTrue(app.staticTexts["Nothing logged yet"].waitForExistence(timeout: 5),
                      "Undo should remove the entry and restore the empty state")
    }
}
