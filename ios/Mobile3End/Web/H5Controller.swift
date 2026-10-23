import Foundation
import SwiftUI
import WebKit

/// H5 页的原生状态：toast、白屏检测结果、404 计数。H5Screen 读它来画顶部状态条和 toast
@Observable
final class H5PageState {
    var toast: String?
    var offline404Count = 0
    let detector = WhiteScreenDetector()
    @ObservationIgnored private var toastTask: Task<Void, Never>?

    /// iOS 没有系统 toast，自己画一个，2s 后消失
    func showToast(_ text: String) {
        toast = text
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            self?.toast = nil
        }
    }
}

/// WKWebView 容器：离线包拦截 + bridge + 白屏检测都在这里接线
final class H5Controller: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    static let bridgeName = "NativeBridge"
    static let errorName = "M3EError"

    let webView: WKWebView
    let page = H5PageState()
    private let schemeHandler: OfflineSchemeHandler
    private var dispatcher: BridgeDispatcher!
    private var bridgeInjected = false
    private var checkTask: Task<Void, Never>?

    init(deviceInfo: DeviceInfo = .current()) {
        let page = self.page
        let package = OfflinePackage.bundled { message in
            M3ELog.d(message)
            if message.hasPrefix("[OFFLINE_404]") { page.offline404Count += 1 }
        }
        schemeHandler = OfflineSchemeHandler(package: package)

        let config = WKWebViewConfiguration()
        // 必须在创建 WKWebView 之前注册，之后改 configuration 不生效
        config.setURLSchemeHandler(schemeHandler, forURLScheme: OfflinePackage.scheme)
        // M5：H5 未捕获异常转发到原生日志。atDocumentStart：在页面任何脚本执行前注入
        config.userContentController.addUserScript(
            WKUserScript(source: H5ErrorCapture.js, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        )
        webView = WKWebView(frame: .zero, configuration: config)
        // iOS 16.4 起，不设这个 Safari Web Inspector 连不上（Debug 包也一样）
        webView.isInspectable = true
        super.init()

        dispatcher = BridgeDispatcher(deviceInfo: deviceInfo, showToast: { page.showToast($0) })
        webView.navigationDelegate = self
    }

    func load(_ testCase: H5Case) {
        M3ELog.d("H5 load case=\(testCase.rawValue) url=\(testCase.url.absoluteString)")
        switch testCase {
        case .foreign:
            webView.loadHTMLString(H5Case.foreignHTML, baseURL: testCase.url)
        case .delayed:
            webView.loadHTMLString(H5Case.delayedHTML, baseURL: testCase.url)
        default:
            webView.load(URLRequest(url: testCase.url))
        }
    }

    /// 只在离线包页面上暴露 NativeBridge（spec：加载其他页面时不注入）。
    /// 注意 add 会强引用 handler，直接 add(self) 会和 webView 形成循环引用，所以包一层 WeakScriptMessageHandler
    private func setBridgeInjected(_ on: Bool) {
        guard on != bridgeInjected else { return }
        bridgeInjected = on
        let ucc = webView.configuration.userContentController
        if on {
            ucc.add(WeakScriptMessageHandler(self), name: Self.bridgeName)
            ucc.add(WeakScriptMessageHandler(self), name: Self.errorName)
        } else {
            ucc.removeScriptMessageHandler(forName: Self.bridgeName)
            ucc.removeScriptMessageHandler(forName: Self.errorName)
        }
        M3ELog.d("[BRIDGE] \(on ? "注入" : "移除") NativeBridge")
    }

    func runJS(_ js: String) {
        // 用回调版本：async 版 evaluateJavaScript 在 JS 返回 undefined 时会崩（返回值类型是非可选的 Any）
        webView.evaluateJavaScript(js) { _, error in
            if let error { M3ELog.d("[BRIDGE] evaluateJavaScript 失败：\(error)") }
        }
    }

    // MARK: - H5 → Native

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == Self.errorName {
            H5ErrorCapture.log(message.body)
            return
        }
        handleBridgeMessage(message)
    }

    // 空 M4-6：从 message 里取出来源（frameInfo.securityOrigin、frameInfo.isMainFrame）组装成 BridgeOrigin，
    // 取出消息体（H5 发的是字符串），交给 dispatcher；dispatcher 返回了 JS 就用 runJS 执行回去
    // 提示 1：securityOrigin 的 protocol / host / port 三个属性；message.body 是 Any，要 as? String
    private func handleBridgeMessage(_ message: WKScriptMessage) {
        TODO("M4-6")
    }

    // MARK: - Native → H5 推送

    // 空 M4-7：App 前后台切换时给 H5 推 appState 事件 { event: "appState", data: { state } }。
    // 当前不是离线包页面（bridgeInjected 为 false）时不推
    // 提示 1：M3-5 的 appStateName 已经把 phase 翻译好了；BridgeJS.event 拼 JS
    func scenePhaseChanged(_ phase: ScenePhase) {
        TODO("M4-7")
    }

    // MARK: - 导航与白屏检测

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
        // 主文档要换页时决定注不注入：此时新页面的脚本还没开始执行
        if navigationAction.targetFrame?.isMainFrame ?? false {
            setBridgeInjected(OfflinePackage.owns(navigationAction.request.url))
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        M3ELog.d("didStartProvisionalNavigation \(webView.url?.absoluteString ?? "nil")")
        checkTask?.cancel()
        page.detector.reset()
        page.offline404Count = 0
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        M3ELog.d("didCommit \(webView.url?.absoluteString ?? "nil")")
    }

    // 空 M4-9：主文档加载完成。延迟 WhiteScreen.checkDelay 后执行 WhiteScreen.probeJS，
    // 用 judge 判定，结果交给 page.detector.report(_:url:)。
    // 延迟期间又开始了新的导航，这次检测要作废（didStartProvisionalNavigation 里会 cancel checkTask）
    // 提示 1：Task { } + Task.sleep(for:)；这里 JS 一定返回数字，可以用 async 版 evaluateJavaScript，失败当 nil
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        M3ELog.d("didFinish \(webView.url?.absoluteString ?? "nil")")
        TODO("M4-9")
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
        handleLoadFailure(error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: any Error) {
        handleLoadFailure(error)
    }

    private func handleLoadFailure(_ error: any Error) {
        let ns = error as NSError
        let url = ns.userInfo[NSURLErrorFailingURLErrorKey] as? URL ?? webView.url
        M3ELog.d("主文档加载失败 \(ns.domain) \(ns.code) \(url?.absoluteString ?? "nil")")
        if let reason = WhiteScreen.reasonForLoadError(error) {
            checkTask?.cancel()
            page.detector.report(reason, url: url)
        }
    }

    /// 渲染进程（WebContent 进程）挂了：被系统因内存回收、或崩溃。页面会整个变白
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        checkTask?.cancel()
        page.detector.report(.renderGone, url: webView.url)
    }

    /// 调试用：杀掉 WebContent 进程，模拟 render_gone。私有 API，只在 Debug 包里出现
    func debugKillWebContentProcess() {
        #if DEBUG
        let selector = NSSelectorFromString("_killWebContentProcess")
        if webView.responds(to: selector) {
            webView.perform(selector)
        } else {
            M3ELog.d("这个系统版本没有 _killWebContentProcess")
        }
        #endif
    }
}

/// 弱引用转发，避免 userContentController → handler → webView → configuration → userContentController 循环引用
final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    private weak var target: (any WKScriptMessageHandler)?

    init(_ target: any WKScriptMessageHandler) {
        self.target = target
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(userContentController, didReceive: message)
    }
}
