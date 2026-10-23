import XCTest

/// M0：工程能跑起来
@MainActor
final class M0UiTests: M3EUITestCase {
    func test_m0_0_appLaunches() {
        launch(stage: 0)
        XCTAssertTrue(app.staticTexts["m0-title"].waitForExistence(timeout: 10))
    }
}
