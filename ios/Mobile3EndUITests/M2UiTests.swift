import XCTest

/// M2 UI 检查：三种状态的界面、排序持久化、缓存。用假数据源，不依赖 mock 服务
@MainActor
final class M2UiTests: M3EUITestCase {

    func test_m2_7_failureWithoutCacheShowsRetry() {
        launch(stage: 2, fake: "fail")
        XCTAssertTrue(app.buttons["retry"].waitForExistence(timeout: 10), "没缓存 + 请求失败，应显示带重试按钮的失败态")
    }

    func test_m2_7_emptyListShowsEmptyState() {
        launch(stage: 2, fake: "empty")
        XCTAssertTrue(app.descendants(matching: .any)["empty"].waitForExistence(timeout: 10), "空列表应有空态")
    }

    func test_m2_7_loadingStateVisible() {
        launch(stage: 2, fake: "slow")
        // slow 模式请求要 3s 才回来
        XCTAssertTrue(app.descendants(matching: .any)["loading"].waitForExistence(timeout: 2), "请求中应显示加载态")
        XCTAssertTrue(row("工作资料").waitForExistence(timeout: 10))
    }

    func test_m2_6_sortOrderSurvivesRelaunch() {
        launch(stage: 2, fake: "ok")
        let sort = app.buttons["sort"]
        XCTAssertTrue(row("工作资料").waitForExistence(timeout: 10))
        sort.tap()
        XCTAssertTrue(sort.label.contains("时间"))
        app.terminate()

        launch(stage: 2, fake: "ok", reset: false)
        XCTAssertTrue(app.buttons["sort"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["sort"].label.contains("时间"), "重启后排序应保持为「时间」")
    }

    func test_m2_e2e_cacheShownWhenServerDown() {
        launch(stage: 2, fake: "ok")
        XCTAssertTrue(row("工作资料").waitForExistence(timeout: 10))
        app.terminate()

        // 第二次启动请求失败：应显示上次的缓存，而不是失败态
        launch(stage: 2, fake: "fail", reset: false)
        XCTAssertTrue(row("工作资料").waitForExistence(timeout: 10), "有缓存时应显示缓存")
        XCTAssertFalse(app.buttons["retry"].exists)
    }
}
