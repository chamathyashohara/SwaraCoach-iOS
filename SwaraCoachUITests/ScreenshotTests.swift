import XCTest

/// Walks the main screens and attaches a screenshot of each. CI exports these so the UI can be reviewed without a Mac.
final class ScreenshotTests: XCTestCase {
    private func shot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testCaptureScreens() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-hasOnboarded", "YES"]
        app.launch()
        _ = app.navigationBars["Sing"].waitForExistence(timeout: 5)
        shot("01-library-songs")

        app.segmentedControls.buttons["Exercises"].tap()
        shot("02-library-exercises")

        app.tabBars.buttons["Tuner"].tap()
        _ = app.staticTexts["tunerNote"].waitForExistence(timeout: 5)
        sleep(1)
        shot("03-tuner")

        app.tabBars.buttons["Sing"].tap()
        app.segmentedControls.buttons["Exercises"].tap()
        let row = app.buttons["melody-test-tone"]
        if row.waitForExistence(timeout: 5) {
            row.tap()
            shot("04-session-intro")
            app.buttons["startButton"].tap()
            shot("05-session-ready")
            app.buttons["beginSinging"].tap()
            sleep(2)
            shot("06-session-singing")
            if app.descendants(matching: .any)["scoreLabel"].waitForExistence(timeout: 15) {
                shot("07-results")
                app.buttons["doneResults"].tap()
            }
        }

        app.tabBars.buttons["Progress"].tap()
        sleep(1)
        shot("08-progress")
    }
}
