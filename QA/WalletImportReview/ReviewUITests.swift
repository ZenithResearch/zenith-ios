import XCTest

final class WalletReviewUITests: XCTestCase {
  private func launch(_ scenario: String, large: Bool = false) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchEnvironment["WALLET_REVIEW_SCENARIO"] = scenario
    app.launchEnvironment["WALLET_REVIEW_LARGE_TEXT"] = large ? "1" : "0"
    app.launch()
    let title = ["recovery", "combined"].contains(scenario) ? "Review your wallet" : "Review your data"
    XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 10))
    return app
  }
  private func capture(_ name: String) {
    let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
  }
  private func expand(_ title: String, in app: XCUIApplication) {
    let button = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch
    for _ in 0..<8 where !button.isHittable { app.scrollViews.firstMatch.swipeUp() }
    XCTAssertTrue(button.exists, app.debugDescription)
    button.tap()
  }
  func testRecoveryOnlyAndCancellation() {
    let app = launch("recovery")
    XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label CONTAINS 'Saved account identities'")).firstMatch.exists)
    XCTAssertFalse(app.staticTexts["Castaway data"].exists)
    XCTAssertEqual(app.buttons.matching(identifier: "Import wallet").count, 1)
    capture("recovery-collapsed")
    expand("Wallet public key", in: app)
    expand("Derived blockchain accounts (4)", in: app)
    XCTAssertTrue(app.staticTexts["cardano:mainnet"].exists)
    XCTAssertTrue(app.staticTexts["solana:mainnet-beta"].exists)
    capture("recovery-expanded")
    app.buttons["Cancel"].tap()
    XCTAssertTrue(app.staticTexts["Review cancelled · synthetic data only"].exists)
  }
  func testCombinedIdentitiesHaveOneHeadingAndWarnings() {
    let app = launch("combined")
    XCTAssertTrue(app.staticTexts["Castaway data"].exists)
    expand("Saved account identities (4)", in: app)
    XCTAssertFalse(app.staticTexts["Wallet identities (4)"].exists)
    XCTAssertTrue(app.staticTexts["Matrix · Chat"].exists)
    XCTAssertTrue(app.staticTexts["X · Social"].exists)
    XCTAssertTrue(app.staticTexts["Your saved profile will be replaced."].exists)
    capture("combined-identities")
    let lastIdentity = app.staticTexts["X · Social"]
    for _ in 0..<6 where !lastIdentity.isHittable { app.scrollViews.firstMatch.swipeUp() }
    XCTAssertTrue(lastIdentity.isHittable, "Every imported identity must remain reachable")
    capture("combined-identities-last-record")
  }
  func testLegacyAndEmptyAreDistinct() {
    let old = launch("legacy")
    XCTAssertTrue(old.staticTexts["This older Castaway file has no saved account identities. Existing identities are preserved."].exists)
    XCTAssertFalse(old.buttons.matching(NSPredicate(format: "label CONTAINS 'Saved account identities'")).firstMatch.exists)
    capture("legacy-data")
    old.terminate()
    let empty = launch("empty")
    expand("Saved account identities (0)", in: empty)
    XCTAssertTrue(empty.staticTexts["No saved account identities after import."].exists)
    capture("empty-data")
  }
  func testLargeTextKeepsConfirmationReachable() {
    let app = launch("combined", large: true)
    XCTAssertTrue(app.buttons["Import wallet"].isHittable)
    expand("Saved account identities (4)", in: app)
    XCTAssertTrue(app.buttons["Import wallet"].isHittable)
    capture("large-text")
  }
}
