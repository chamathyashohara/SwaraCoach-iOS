import XCTest

/// UI tests run with `-uiTesting`, which replaces the microphone with a simulated singer and uses an in-memory store.
final class SwaraCoachUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-hasOnboarded", "YES"]
        app.launch()
    }

    func testTabsNavigate() {
        XCTAssertTrue(app.navigationBars["Sing"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Tuner"].tap()
        XCTAssertTrue(app.navigationBars["Tuner"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Progress"].tap()
        XCTAssertTrue(app.navigationBars["Progress"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Sing"].tap()
        XCTAssertTrue(app.navigationBars["Sing"].waitForExistence(timeout: 5))
    }

    func testTunerShowsSimulatedNote() {
        app.tabBars.buttons["Tuner"].tap()
        let note = app.staticTexts["tunerNote"]
        XCTAssertTrue(note.waitForExistence(timeout: 5))
        let predicate = NSPredicate(format: "label == 'A4'")
        expectation(for: predicate, evaluatedWith: note)
        waitForExpectations(timeout: 5)
        XCTAssertTrue(app.staticTexts["singingChip"].exists || app.otherElements["singingChip"].exists)
    }

    func testSingFlowShowsScoreAndSavesHistory() {
        // Songs tab has no test tone; it is in the Exercises list.
        app.segmentedControls.buttons["Exercises"].tap()
        let row = app.buttons["melody-test-tone"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        app.buttons["startButton"].tap()
        app.buttons["beginSinging"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["scoreLabel"].waitForExistence(timeout: 15), "results should appear after the 3 s melody")
        app.buttons["doneResults"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()   // back to the library

        app.tabBars.buttons["Progress"].tap()
        XCTAssertTrue(app.buttons["history-row"].firstMatch.waitForExistence(timeout: 5))
    }

    func testSwipeToDeleteSession() {
        testSingFlowShowsScoreAndSavesHistory()
        let row = app.buttons["history-row"].firstMatch
        row.swipeLeft()
        app.buttons["Delete"].tap()
        XCTAssertFalse(app.buttons["history-row"].firstMatch.waitForExistence(timeout: 2))
    }

    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) { XCUIApplication().launch() }
    }
}
