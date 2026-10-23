import XCTest

/// M4 UI 检查：真实的 WKWebView 加载离线包，验证拦截、bridge、appState、白屏检测的胶水代码。
/// 用启动参数 -M3EH5Case 直接进 H5 页（不依赖 STAGE，不渲染列表页）。
/// M4 的两个开关用 -M3EBridge / -M3EWhiteScreen 显式指定，不受 Stage.swift 里常量的影响
@MainActor
final class M4UiTests: M3EUITestCase {

    /// bridge / whiteScreen 对应 M4_BRIDGE / M4_WHITE_SCREEN。默认都打开：后面的测试测的就是这两部分
    private func openH5(_ testCase: String = "normal", bridge: Bool = true, whiteScreen: Bool = true) {
        launch(stage: 4, fake: "ok", extra: [
            "-M3EH5Case", testCase,
            "-M3EBridge", bridge ? "YES" : "NO",
            "-M3EWhiteScreen", whiteScreen ? "YES" : "NO",
        ])
    }

    private var status: XCUIElement { app.staticTexts["wsd-status"] }

    private func waitStatus(_ text: String, timeout: TimeInterval = 8) -> Bool {
        let predicate = NSPredicate(format: "label CONTAINS %@", text)
        return XCTWaiter().wait(for: [expectation(for: predicate, evaluatedWith: status)], timeout: timeout) == .completed
    }

    /// 示例：离线包 case 的基线。STAGE = 0、两个开关都关（= 只写好了离线包拦截时的状态），页面照样能打开、App 不崩
    func test_m4_0_offlinePageLoads() {
        launch(stage: 0, extra: ["-M3EH5Case", "normal", "-M3EBridge", "NO", "-M3EWhiteScreen", "NO"])
        // 标题是 app.js 往 #app 里加的第一个子元素：看到它就说明 #app 有子元素
        XCTAssertTrue(webText("离线包测试页 case=normal").waitForExistence(timeout: 10), "离线包页面没加载出来")
        XCTAssertTrue(webText("location: appoffline://h5/index.html").exists, "location.href 应以离线包地址开头")
        XCTAssertTrue(webText("bridge: none").exists, "M4_BRIDGE 关着时不应注入 NativeBridge")
        XCTAssertTrue(webText("NO_BRIDGE").waitForExistence(timeout: 5), "getDeviceInfo 应立刻失败（NO_BRIDGE）")
        XCTAssertTrue(waitStatus("未开启"), "M4_WHITE_SCREEN 关着时不做白屏检测，实际：\(status.label)")
        sleep(2)
        XCTAssertEqual(app.state, .runningForeground, "App 不应崩")
        XCTAssertFalse(app.staticTexts["m0-title"].exists, "直达入口不应显示 M0 页")
    }

    // M4-1 ~ M4-3 已写好。两个开关关着测：只看离线包拦截本身，不依赖 bridge / 白屏检测的空
    func test_m4_1_m4_2_m4_3_pageLoadsFromOfflinePackage() {
        openH5(bridge: false, whiteScreen: false)
        XCTAssertTrue(webText("离线包测试页 case=normal").waitForExistence(timeout: 10), "离线包页面没加载出来")
        XCTAssertTrue(webText("location: appoffline://h5/index.html").exists)
    }

    func test_m4_2_m4_3_missingResourceIs404() {
        openH5("missing", bridge: false, whiteScreen: false)
        XCTAssertTrue(webText("离线包测试页 case=missing").waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["OFFLINE_404 ×1"].waitForExistence(timeout: 5), "应记到 1 次 [OFFLINE_404]")
        XCTAssertTrue(webText("missing.js load failed").waitForExistence(timeout: 5),
                      "H5 的 <script> 应收到 onerror：响应要带 404 状态码")
    }

    func test_m4_4_m4_5_m4_6_getDeviceInfoShowsIos() {
        openH5()
        XCTAssertTrue(webText("bridge: ios").waitForExistence(timeout: 10), "H5 应识别到 iOS 的 messageHandlers")
        XCTAssertTrue(webText(#""platform": "ios""#).waitForExistence(timeout: 10), "H5 没收到 getDeviceInfo 的返回")
    }

    func test_m4_5_m4_6_toastShowsNativeToastAndCallsBack() {
        openH5()
        let button = app.webViews.buttons["toast"]
        XCTAssertTrue(button.waitForExistence(timeout: 10))
        button.tap()
        XCTAssertTrue(app.staticTexts["toast"].waitForExistence(timeout: 3), "没有弹出原生 toast")
        XCTAssertEqual(app.staticTexts["toast"].label, "来自 H5 的 toast")
        XCTAssertTrue(webText("toast ok {}").waitForExistence(timeout: 3), "H5 没收到成功回调")
    }

    func test_m4_5_m4_6_unknownMethodGetsMethodNotFound() {
        openH5()
        let button = app.webViews.buttons["不存在的方法"]
        XCTAssertTrue(button.waitForExistence(timeout: 10))
        button.tap()
        XCTAssertTrue(webText("METHOD_NOT_FOUND").waitForExistence(timeout: 3))
        XCTAssertFalse(webText("TIMEOUT").exists, "应该立即收到失败回调，而不是等到超时")
    }

    func test_m4_7_appStateEventsReachH5() {
        openH5()
        XCTAssertTrue(webText("离线包测试页").waitForExistence(timeout: 10))
        XCUIDevice.shared.press(.home)
        sleep(2)
        app.activate()
        XCTAssertTrue(webText(#"event appState {"state":"background"}"#).waitForExistence(timeout: 5), "H5 没收到 background 事件")
        XCTAssertTrue(webText(#"event appState {"state":"foreground"}"#).waitForExistence(timeout: 5), "H5 没收到 foreground 事件")
    }

    func test_m4_8_m4_9_normalPageIsNotWhite() {
        openH5()
        XCTAssertTrue(waitStatus("正常"), "正常页面应判定为不白屏，实际：\(status.label)")
    }

    func test_m4_8_m4_9_blankCaseReportsEmptyRoot() {
        openH5("blank")
        XCTAssertTrue(waitStatus("empty_root"), "case=blank 应报 empty_root，实际：\(status.label)")
    }

    func test_m4_9_missingCaseIsNotWhite() {
        openH5("missing")
        XCTAssertTrue(waitStatus("正常"), "case=missing 页面其余部分正常，不应报白屏，实际：\(status.label)")
    }

    func test_m4_9_waitsBeforeProbing() {
        // 页面 0.5s 后才渲染：在 didFinish 里立刻检测会误报 empty_root
        openH5("delayed")
        XCTAssertTrue(webText("0.5s 后渲染完成").waitForExistence(timeout: 10))
        XCTAssertTrue(waitStatus("正常"), "检测要等 checkDelay 之后再做，实际：\(status.label)")
    }

    func test_m4_10_androidUrlIsLoadError() {
        // https://h5.offline.test 在 iOS 上拦不住，.test 域名解析失败 → 主文档加载失败
        openH5("android-url")
        XCTAssertTrue(waitStatus("load_error", timeout: 20), "实际：\(status.label)")
    }

    func test_m4_e2e_foreignPageHasNoBridge() {
        openH5("foreign")
        XCTAssertTrue(webText("外部页面 evil.test").waitForExistence(timeout: 10))
        XCTAssertTrue(webText("bridge: none").waitForExistence(timeout: 3), "非离线包页面不应暴露 NativeBridge")
    }
}
