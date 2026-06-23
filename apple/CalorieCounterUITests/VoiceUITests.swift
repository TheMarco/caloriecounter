//
//  VoiceUITests.swift
//  Regression for the libdispatch main-actor assertion that crashed the voice
//  flow the instant audio started. Tapping "Start Speaking" must NOT abort the
//  process (on the simulator the engine may fail to start and surface an error
//  instead — either way the app must stay alive, never crash).
//

import XCTest

final class VoiceUITests: XCTestCase {

    override func setUp() { continueAfterFailure = false }

    @MainActor
    func testStartingVoiceCaptureDoesNotCrash() {
        let app = XCUIApplication()
        app.launchArguments += ["-uitest"]
        app.launch()

        // Auto-dismiss the mic / speech permission prompts if they appear.
        addUIInterruptionMonitor(withDescription: "Permission") { alert in
            for label in ["Allow", "OK", "Allow While Using App"] {
                if alert.buttons[label].exists { alert.buttons[label].tap(); return true }
            }
            return false
        }

        app.buttons["Voice"].tap()

        let start = app.buttons["Start Speaking"]
        XCTAssertTrue(start.waitForExistence(timeout: 5), "Voice screen should show the start button")
        start.tap()
        app.tap()   // nudge the interruption monitor to handle any permission dialog

        // The decisive check: a couple seconds after audio would have started, the
        // app is still running in the foreground (the old code aborted here).
        Thread.sleep(forTimeInterval: 2)
        XCTAssertEqual(app.state, .runningForeground, "Voice capture must not crash the app")
    }
}
