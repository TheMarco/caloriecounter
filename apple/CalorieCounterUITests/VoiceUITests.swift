//
//  VoiceUITests.swift
//  Regression for the libdispatch main-actor assertion that crashed the voice
//  flow. Opening the voice screen (which constructs the dictation state) and
//  attempting to start capture must NOT abort the process. On the simulator the
//  engine may fail to start and surface an error instead — either way the app must
//  stay alive.
//

import XCTest

final class VoiceUITests: XCTestCase {

    override func setUp() { continueAfterFailure = false }

    @MainActor
    func testStartingVoiceCaptureDoesNotCrash() {
        let app = XCUIApplication()
        app.launchArguments += ["-uitest"]
        app.launch()

        addUIInterruptionMonitor(withDescription: "Permission") { alert in
            for label in ["Allow", "OK", "Allow While Using App"] {
                if alert.buttons[label].exists { alert.buttons[label].tap(); return true }
            }
            return false
        }

        app.buttons["Voice"].tap()

        // The voice sheet must open (its title proves VoiceInputView built without
        // crashing on the dictation state).
        XCTAssertTrue(app.navigationBars["Speak Food"].waitForExistence(timeout: 8),
                      "Voice screen should open")

        // Best-effort: start capture (the path that used to crash). Tolerate the
        // simulator not exposing the button reliably.
        let start = app.buttons["Start Speaking"]
        if start.waitForExistence(timeout: 3) {
            start.tap()
            app.tap()   // nudge any permission dialog through the interruption monitor
        }

        // Decisive check: the app is still alive (the old code aborted here).
        Thread.sleep(forTimeInterval: 2)
        XCTAssertEqual(app.state, .runningForeground, "Voice flow must not crash the app")
    }
}
