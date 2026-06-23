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
        XCTAssertTrue(app.staticTexts["This Month"].waitForExistence(timeout: 5), "Calendar section should appear")
    }

    @MainActor
    func testHistoryRendersDataAcrossRanges() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-demo", "-screen-history"]
        app.launch()

        // Demo seeds ~2 months. With the date-scale chart fitting the whole range
        // in view, no range (incl. 90 Days, which previously opened scrolled onto
        // an empty stretch) should show the empty-state overlay.
        let empty = app.staticTexts["No data in this range yet"]
        for range in ["7 Days", "90 Days", "All"] {
            let seg = app.buttons[range]
            XCTAssertTrue(seg.waitForExistence(timeout: 10), "\(range) segment should exist")
            seg.tap()
            XCTAssertFalse(empty.waitForExistence(timeout: 2), "\(range) should show data, not the empty overlay")
        }
    }
}
