//
//  TextFlowUITests.swift
//  End-to-end smoke of the text capture flow against the real app stack (launched
//  with `-uitest`: in-memory store + deterministic heuristic parser). Verifies the
//  full chain: quick-add → type → analyze → confirm → saved entry appears on Today.
//

import XCTest

final class TextFlowUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testTypingAFoodSavesItToToday() {
        let app = XCUIApplication()
        app.launchArguments += ["-uitest"]
        app.launch()

        // Quick-add "Text" button (accessibility label from QuickAddBar).
        let textButton = app.buttons["Text"]
        XCTAssertTrue(textButton.waitForExistence(timeout: 10), "Text quick-add button should exist")
        textButton.tap()

        // Type a known food the heuristic parser recognizes.
        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Text field should appear")
        field.tap()
        field.typeText("apple")

        app.buttons["Analyze"].tap()

        // Confirm sheet → Add.
        let addButton = app.buttons["Add"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "Confirm 'Add' button should appear")
        addButton.tap()

        // The entry should now appear in Today's list.
        XCTAssertTrue(app.staticTexts["apple"].waitForExistence(timeout: 5),
                      "Saved entry should appear on the Today screen")
    }

    @MainActor
    func testCompoundFoodShowsEditableBreakdown() {
        let app = XCUIApplication()
        app.launchArguments += ["-uitest"]
        app.launch()

        app.buttons["Text"].tap()
        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        // A composite dish that resolves to a USDA database row carrying a recipe.
        field.typeText("bacon lettuce tomato sandwich")
        app.buttons["Analyze"].tap()

        // The confirm sheet shows a collapsed breakdown; expanding reveals ingredients.
        let breakdown = app.staticTexts["Breakdown"]
        XCTAssertTrue(breakdown.waitForExistence(timeout: 5), "A compound food should show a Breakdown section")
        breakdown.tap()
        app.swipeUp()   // the breakdown rows are at the bottom of the sheet
        XCTAssertTrue(app.staticTexts["Lettuce"].waitForExistence(timeout: 3),
                      "Expanding the breakdown should reveal its ingredient rows")
    }
}
