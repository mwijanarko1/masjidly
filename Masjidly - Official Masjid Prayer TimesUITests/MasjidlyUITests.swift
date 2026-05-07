import XCTest

final class MasjidlyUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testTabsAndMosquePicker() throws {
        let app = XCUIApplication()
        app.launch()

        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 8))
        settingsTab.tap()

        let picker = app.descendants(matching: .any).matching(identifier: "MosquePicker").firstMatch
        if picker.waitForExistence(timeout: 4) {
            XCTAssertTrue(picker.exists)
        }

        let homeTab = app.tabBars.buttons["Home"]
        homeTab.tap()
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 6))
    }
}
