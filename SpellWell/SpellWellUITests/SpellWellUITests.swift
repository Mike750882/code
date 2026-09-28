import XCTest

/// Drives the app through a realistic demo session -- launch with seeded
/// demo data (see `UITestSupport.seedDemoData`), take the current week's
/// spelling test typing from memory, then visit Rewards and the Progress
/// Report -- taking a `fastlane snapshot` screenshot at five points along
/// the way. This exists because there's no way to run the app or Simulator
/// from this environment, so it's the only way to produce App Store
/// screenshots that actually reflect the real UI rather than mockups.
///
/// Always types the answers (never taps letter tiles), regardless of which
/// real-world weekday the screenshots happen to be taken on --
/// `UITestSupport.seedDemoData` sets the demo child's Monday/Tuesday/
/// Wednesday input modes to `.typed` to match, and Thursday/Friday already
/// default to `.typed` on every `Child` (see `Child.thursdayInputMode` and
/// the hardcoded Friday case in `Child.inputMode(forWeekday:)`).
final class SpellWellUITests: XCTestCase {
    /// This week's demo words, in the exact order `UITestSupport.
    /// seedDemoData` inserts them -- index 3 is deliberately mistyped
    /// below (one dropped letter) so the results screen shows a realistic
    /// mixed grade (9 of 10, a solid A-) instead of an implausible 100%.
    private let demoWords = [
        "friend", "because", "thought", "beautiful", "whisper",
        "garden", "shoulder", "quietly", "mountain", "journey"
    ]
    private let typoWordIndex = 3

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testTakeScreenshots() throws {
        let app = XCUIApplication()
        setupSnapshot(app)
        app.launchArguments += ["-UITestSeedDemoData"]
        app.launch()

        // 1. Home -- populated with this week's word list, daily grade
        // history, and rewards, instead of an empty first-launch state.
        let practiceCard = app.buttons["practiceCard"]
        XCTAssertTrue(practiceCard.waitForExistence(timeout: 15))
        snapshot("01Home")

        // Switch to Test mode before starting -- a graded session is a
        // more representative screenshot than open-ended practice.
        app.segmentedControls["modeToggle"].buttons["Test"].tap()
        practiceCard.tap()

        // Friday's test goes through an extra "review or start" screen
        // first (see FridayTestChoiceView) -- only relevant if this
        // happens to run on a real-world Friday.
        let startTestButton = app.buttons["Start the test"]
        if startTestButton.waitForExistence(timeout: 3) {
            startTestButton.tap()
        }

        // 2. The practice/test screen -- captured with the first word
        // typed in but not yet submitted, so the field's real contents
        // show rather than an empty placeholder.
        let field = app.textFields["typedAnswerField"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()
        field.typeText(demoWords[0])
        snapshot("02Practice")
        app.buttons["checkWordButton"].tap()
        // Test mode's own 700ms transition to the next word (see
        // PracticeView.checkWord) -- give it a moment to settle before
        // interacting with the next word's fresh field.
        Thread.sleep(forTimeInterval: 1.0)

        for index in 1..<demoWords.count {
            let nextField = app.textFields["typedAnswerField"]
            XCTAssertTrue(nextField.waitForExistence(timeout: 5))
            nextField.tap()
            let toType = index == typoWordIndex ? String(demoWords[index].dropLast()) : demoWords[index]
            nextField.typeText(toType)
            app.buttons["checkWordButton"].tap()
            Thread.sleep(forTimeInterval: 1.0)
        }

        // 3. Results -- let the grade letter's bounce-in and (at 9/10,
        // an A-) its sparkle burst mostly finish before capturing.
        let backToHomeButton = app.buttons["backToHomeButton"]
        XCTAssertTrue(backToHomeButton.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 1.5)
        snapshot("03Results")
        backToHomeButton.tap()

        XCTAssertTrue(practiceCard.waitForExistence(timeout: 5))

        // 4. Rewards -- first visit to any grown-up screen creates the
        // demo PIN (a fresh in-memory store has none yet), so this is a
        // two-step "enter, then confirm" flow rather than a single entry.
        app.buttons["rewardsCard"].tap()
        enterPIN("1234", in: app)
        Thread.sleep(forTimeInterval: 0.3)
        enterPIN("1234", in: app)

        let rewardsTitle = app.staticTexts["Rewards"]
        XCTAssertTrue(rewardsTitle.waitForExistence(timeout: 5))
        snapshot("04Rewards")

        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(practiceCard.waitForExistence(timeout: 5))

        // 5. Progress report -- the PIN already exists now, so Settings
        // only needs one round of entry.
        app.buttons["settingsCard"].tap()
        enterPIN("1234", in: app)

        let reportButton = app.buttons["viewReportButton"]
        var scrollAttempts = 0
        while !(reportButton.exists && reportButton.isHittable) && scrollAttempts < 6 {
            app.swipeUp()
            scrollAttempts += 1
        }
        XCTAssertTrue(reportButton.waitForExistence(timeout: 5))
        reportButton.tap()
        Thread.sleep(forTimeInterval: 1.0)
        snapshot("05ProgressReport")
    }

    @MainActor
    private func enterPIN(_ pin: String, in app: XCUIApplication) {
        for character in pin {
            app.buttons[String(character)].tap()
        }
    }
}
