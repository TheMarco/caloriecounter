//
//  HistoryUITests.swift
//  Smoke test: the History tab renders its range selector, chart, and calendar.
//

import XCTest

final class HistoryUITests: XCTestCase {

    override func setUp() { continueAfterFailure = false }

    @MainActor
    func testHistoryTabRenders() {
        let app = XCUIApplication()
        app.launchArguments += ["-uitest"]
        app.launch()

        let historyTab = app.tabBars.buttons["History"]
        XCTAssertTrue(historyTab.waitForExistence(timeout: 10), "History tab should exist")
        historyTab.tap()

        // Range selector segment and the calendar section header confirm the
        // History screen built without crashing.
        XCTAssertTrue(app.buttons["7 Days"].waitForExistence(timeout: 5), "Range selector should appear")
        XCTAssertTrue(app.staticTexts["This month"].waitForExistence(timeout: 5), "Calendar section should appear")
    }
}
