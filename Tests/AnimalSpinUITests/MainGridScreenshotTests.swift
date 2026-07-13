import XCTest

/// Captures the main animal grid for design review and regression. On an iPad the grid should tile
/// the whole screen with no blank cell and with photos that aren't cropped through the animals'
/// heads — a 4×6 grid for the 24-animal roster in portrait (the orientation-independent column
/// math is unit-tested in `GridLayoutTests`).
///
/// Runs on the simulator (no signing). The screenshot is attached with `.keepAlways` so it survives
/// a passing run and can be exported with `xcresulttool`.
final class MainGridScreenshotTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    @MainActor
    func testCaptureGrid() throws {
        let app = XCUIApplication()
        app.launch()

        // Each animal cell is exposed as a button (accessibility label + `.isButton`); wait for the
        // grid to populate before the shot.
        XCTAssertTrue(app.buttons.firstMatch.waitForExistence(timeout: 15), "Grid never appeared")
        attach("01-Grid", app.screenshot())
    }

    private func attach(_ name: String, _ shot: XCUIScreenshot) {
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
