import XCTest

/// M1 UI 检查，跑在模拟器上。方法名前缀 = 覆盖的空。
///
/// 依赖 SampleData 的排序结果（下标从 0 开始）：
/// - 「白屏率看板截图.png」名称序第 17 行，时间序第 4 行
/// - 「旅行vlog.mov」名称序第 15 行
/// iPhone 一屏约 11 行，所以「第 4 行」在首屏、「第 15 行以后」不在首屏。
@MainActor
final class M1UiTests: M3EUITestCase {

    private var sortButton: XCUIElement { app.buttons["sort"] }

    func test_m1_2_m1_3_sortToggleResortsList() {
        launch(stage: 1)
        XCTAssertTrue(app.collectionViews["file-list"].waitForExistence(timeout: 10))
        XCTAssertTrue(sortButton.label.contains("名称"))
        XCTAssertFalse(isOnScreen(row("白屏率看板截图.png")), "名称序下「白屏率看板截图.png」不应在首屏")

        sortButton.tap()

        XCTAssertTrue(sortButton.label.contains("时间"), "排序按钮应显示「时间」，实际：\(sortButton.label)")
        XCTAssertTrue(isOnScreen(row("白屏率看板截图.png")), "切到时间序后「白屏率看板截图.png」应在首屏")

        sortButton.tap()
        XCTAssertTrue(sortButton.label.contains("名称"))
    }

    func test_m1_4_m1_5_openDetailShowsTappedFile() {
        launch(stage: 1)
        row("Android学习笔记.md").tap()

        let name = app.staticTexts["detail-name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5), "没有进到详情页")
        XCTAssertTrue(name.label.contains("Android学习笔记.md"), "详情页显示的是：\(name.label)")
    }

    func test_m1_6_backButtonReturnsToList() {
        launch(stage: 1)
        row("Android学习笔记.md").tap()
        XCTAssertTrue(app.staticTexts["detail-name"].waitForExistence(timeout: 5))

        app.buttons["back"].tap()

        XCTAssertTrue(sortButton.waitForExistence(timeout: 5), "没有回到列表页")
        XCTAssertFalse(app.staticTexts["detail-name"].exists)
        // 回到的是根页面：导航栏上不应再有返回按钮
        XCTAssertFalse(app.navigationBars.buttons["BackButton"].exists)
    }

    func test_m1_e2e_backKeepsScrollPosition() {
        launch(stage: 1)
        XCTAssertTrue(app.collectionViews["file-list"].waitForExistence(timeout: 10))
        scrollTo("旅行vlog.mov")
        row("旅行vlog.mov").tap()
        XCTAssertTrue(app.staticTexts["detail-name"].waitForExistence(timeout: 5))

        // 用系统自带的返回按钮
        app.navigationBars.buttons.element(boundBy: 0).tap()

        XCTAssertTrue(sortButton.waitForExistence(timeout: 5))
        XCTAssertTrue(isOnScreen(row("旅行vlog.mov")), "从详情返回后应仍停在「旅行vlog.mov」附近")
    }

    func test_m1_e2e_rotationKeepsSortOrder() {
        launch(stage: 1)
        defer { XCUIDevice.shared.orientation = .portrait }
        sortButton.tap()
        XCTAssertTrue(sortButton.label.contains("时间"))

        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(sortButton.waitForExistence(timeout: 5))
        XCTAssertTrue(sortButton.label.contains("时间"), "旋转后排序应保持")

        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(sortButton.label.contains("时间"))
    }
}
