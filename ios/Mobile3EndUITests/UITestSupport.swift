import XCTest

/// UI 测试共用：启动参数、按名字找行、判断是否在屏幕上
/// accessibilityIdentifier 和 Android 的 testTag 一一对应：sort、file-list、detail-name
@MainActor
class M3EUITestCase: XCTestCase {
    var app: XCUIApplication!

    /// 以指定阶段启动 App。reset：清掉缓存和排序设置；fake：假数据源 ok / empty / fail / slow
    @discardableResult
    func launch(stage: Int, fake: String? = nil, reset: Bool = true, extra: [String] = []) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        var args = ["-M3EStage", "\(stage)"]
        if reset { args += ["-M3EReset", "YES"] }
        if let fake { args += ["-M3EFake", fake] }
        app.launchArguments = args + extra
        // check.sh 传进来的：App 撞到没填的空时，把「测试名 → 空编号」写到这个文件
        if let path = ProcessInfo.processInfo.environment["M3E_TODO_LOG"] {
            app.launchEnvironment["M3E_TODO_LOG"] = path
            app.launchEnvironment["M3E_TEST"] = name
        }
        app.launch()
        self.app = app
        return app
    }

    /// 列表里的一行。整行是一个 Button，label 由图标、名称、大小时间拼成
    func row(_ name: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", name)).firstMatch
    }

    func isOnScreen(_ element: XCUIElement) -> Bool {
        element.exists && element.isHittable
    }

    /// 向上滑直到这一行出现在屏幕上
    func scrollTo(_ name: String, file: StaticString = #filePath, line: UInt = #line) {
        let list = app.collectionViews["file-list"]
        for _ in 0..<10 where !isOnScreen(row(name)) {
            list.swipeUp(velocity: .slow)
        }
        XCTAssertTrue(isOnScreen(row(name)), "滑了 10 次也没看到「\(name)」", file: file, line: line)
    }

    /// WebView 里的文字
    func webText(_ contains: String) -> XCUIElement {
        app.webViews.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", contains)).firstMatch
    }
}
