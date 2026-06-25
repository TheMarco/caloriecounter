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

        let historyTab = app.buttons["History"]
        XCTAssertTrue(historyTab.waitForExistence(timeout: 10), "History dock button should exist")
        historyTab.tap()

        // Range selector, the Weight section, and (after scrolling past the charts)
        // the calendar section confirm the History screen built without crashing.
        XCTAssertTrue(app.buttons["7 Days"].waitForExistence(timeout: 5), "Range selector should appear")
        XCTAssertTrue(app.staticTexts["Current weight"].waitForExistence(timeout: 5), "Weight section should appear")
        app.swipeUp(); app.swipeUp()
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

    @MainActor
    func testWeightSectionRendersAndLogs() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-demo", "-screen-history"]
        app.launch()

        // The Weight section renders with demo measurements (no empty overlay).
        XCTAssertTrue(app.staticTexts["Current weight"].waitForExistence(timeout: 10), "Weight section should render")
        XCTAssertFalse(app.staticTexts["No weight logged yet"].exists, "Demo seeds a weight trend")

        // Logging opens the sheet and saves back to History.
        app.buttons["Log"].tap()
        XCTAssertTrue(app.staticTexts["Log Weight"].waitForExistence(timeout: 5), "Log Weight sheet should appear")
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["Current weight"].waitForExistence(timeout: 5), "Should return to History after saving")
    }
}
