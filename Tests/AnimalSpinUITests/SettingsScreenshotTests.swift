import XCTest

/// Captures the parent-facing Settings screen and the Voices picker list for design review and
/// regression. Runs on the simulator (no signing). Screenshots are attached to the `.xcresult`
/// with `.keepAlways` so they survive a passing run and can be exported with `xcresulttool`.
///
/// The app is launched straight into Settings via the DEBUG-only `-startOnSettings` hook in
/// `RootView`, so no on-device gesture (the hidden square unlock) has to be synthesized.
final class SettingsScreenshotTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = true   // still emit the screenshots we did capture if a step fails
    }

    @MainActor
    func testCaptureVoiceSettings() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-startOnSettings"]
        app.launch()

        // The Settings screen (TTS toggle, Voices row, sliders, presets, Save).
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 15),
                      "Settings screen never appeared")
        attach("01-Settings", app.screenshot())

        // Open the Voices row → the grouped country/voice list the parent sees.
        let voicesRow = findVoicesRow(in: app)
        guard voicesRow.waitForExistence(timeout: 5) else {
            // Leave a breadcrumb so a lookup failure is diagnosable from the result bundle/log.
            attach("02-Voices-not-found", app.screenshot())
            NSLog("Voices row not found. Element tree:\n%@", app.debugDescription)
            return XCTFail("Could not locate the Voices row")
        }
        voicesRow.tap()
        // The pushed list adopts "Voices" as its title.
        _ = app.navigationBars["Voices"].waitForExistence(timeout: 5)
        attach("02-Voices-top", app.screenshot())   // country sections (Australia, India, …)

        // Scroll to the bottom to reveal the dedicated "Retro Mac" section (Albert … Zarvox).
        app.swipeUp(); app.swipeUp(); app.swipeUp()
        attach("02b-Voices-retro", app.screenshot())

        // A retro voice must be selectable: pick Zarvox, confirm it persists and pops back with the
        // Settings row now showing it.
        let zarvox = app.buttons["Zarvox"]
        XCTAssertTrue(zarvox.waitForExistence(timeout: 5), "Zarvox (retro) row not found")
        zarvox.tap()

        let voicesRowAfter = findVoicesRow(in: app)
        XCTAssertTrue(voicesRowAfter.waitForExistence(timeout: 5), "did not pop back to Settings")
        XCTAssertTrue(voicesRowAfter.label.contains("Zarvox"),
                      "Voices row should show the new selection; label was \"\(voicesRowAfter.label)\"")
        attach("03-Settings-after-select", app.screenshot())
    }

    /// Prefer the stable accessibility identifier; fall back to matching the localized label
    /// (a navigation-link Picker's row label is "Voices" plus the selected value).
    private func findVoicesRow(in app: XCUIApplication) -> XCUIElement {
        let byId = app.buttons["voicesPicker"]
        if byId.exists { return byId }
        return app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Voices")).firstMatch
    }

    private func attach(_ name: String, _ shot: XCUIScreenshot) {
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
