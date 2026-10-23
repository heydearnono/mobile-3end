import WebKit
import XCTest
@testable import Mobile3End

/// M4 纯逻辑检查：MIME、离线包映射、来源校验、bridge 分发、白屏判定
@MainActor
final class M4LogicTests: XCTestCase {

    // MARK: M4-1

    func test_m4_1_mimeByExtension() async {
        XCTAssertEqual(OfflinePackage.mimeType(forExtension: "html"), "text/html")
        XCTAssertEqual(OfflinePackage.mimeType(forExtension: "css"), "text/css")
        XCTAssertTrue(["text/javascript", "application/javascript"].contains(OfflinePackage.mimeType(forExtension: "js")))
        XCTAssertEqual(OfflinePackage.mimeType(forExtension: "json"), "application/json")
        XCTAssertEqual(OfflinePackage.mimeType(forExtension: "png"), "image/png")
        XCTAssertEqual(OfflinePackage.mimeType(forExtension: "PNG"), "image/png", "扩展名大小写不敏感")
        XCTAssertEqual(OfflinePackage.mimeType(forExtension: "m3eunknown"), "application/octet-stream")
        XCTAssertEqual(OfflinePackage.mimeType(forExtension: ""), "application/octet-stream")
    }

    // MARK: M4-2

    /// 临时离线包：root/index.html、root/js/a.js；root 旁边放一个不该被读到的 secret.txt
    private func makePackage(_ sink: LogSink) throws -> OfflinePackage {
        let base = makeTempDir()
        let root = base.appending(path: "h5")
        try FileManager.default.createDirectory(at: root.appending(path: "js"), withIntermediateDirectories: true)
        try Data("<p>hi</p>".utf8).write(to: root.appending(path: "index.html"))
        try Data("var a = 1;".utf8).write(to: root.appending(path: "js/a.js"))
        try Data("secret".utf8).write(to: base.appending(path: "secret.txt"))
        return OfflinePackage(root: root, log: sink.log)
    }

    func test_m4_2_existingFile_200WithMimeAndBody() async throws {
        let sink = LogSink()
        let pkg = try makePackage(sink)
        let r = pkg.resolve(URL(string: "appoffline://h5/index.html")!)
        XCTAssertEqual(r.status, 200)
        XCTAssertEqual(r.mime, "text/html")
        XCTAssertEqual(String(decoding: r.data, as: UTF8.self), "<p>hi</p>")

        let js = pkg.resolve(URL(string: "appoffline://h5/js/a.js")!)
        XCTAssertEqual(js.status, 200, "子目录也要能找到")
        XCTAssertTrue(js.mime.contains("javascript"))
        XCTAssertTrue(sink.lines.isEmpty, "找到文件时不应打 404 日志：\(sink.lines)")
    }

    func test_m4_2_queryStringIgnored() async throws {
        let pkg = try makePackage(LogSink())
        XCTAssertEqual(pkg.resolve(URL(string: "appoffline://h5/index.html?case=blank")!).status, 200)
    }

    func test_m4_2_missingFile_404AndLog() async throws {
        let sink = LogSink()
        let pkg = try makePackage(sink)
        let url = URL(string: "appoffline://h5/missing.js")!
        let r = pkg.resolve(url)
        XCTAssertEqual(r.status, 404)
        XCTAssertEqual(sink.lines, ["[OFFLINE_404] appoffline://h5/missing.js"])
    }

    func test_m4_2_directoryAndRoot_404() async throws {
        let pkg = try makePackage(LogSink())
        XCTAssertEqual(pkg.resolve(URL(string: "appoffline://h5/js")!).status, 404)
        XCTAssertEqual(pkg.resolve(URL(string: "appoffline://h5/")!).status, 404)
    }

    func test_m4_2_otherSchemeOrHost_404() async throws {
        let pkg = try makePackage(LogSink())
        XCTAssertEqual(pkg.resolve(URL(string: "appoffline://other/index.html")!).status, 404)
        XCTAssertEqual(pkg.resolve(URL(string: "https://h5/index.html")!).status, 404)
    }

    func test_m4_2_pathTraversalBlocked() async throws {
        let sink = LogSink()
        let pkg = try makePackage(sink)
        XCTAssertEqual(pkg.resolve(URL(string: "appoffline://h5/../secret.txt")!).status, 404)
        XCTAssertEqual(pkg.resolve(URL(string: "appoffline://h5/js/../../secret.txt")!).status, 404)
        XCTAssertEqual(pkg.resolve(URL(string: "appoffline://h5/%2E%2E/secret.txt")!).status, 404)
    }

    func test_m4_2_bundledPackageHasMockH5() async {
        // 检查 project.yml 里的 folder reference 真的把 mock/h5 打进了包
        let pkg = OfflinePackage.bundled(log: { _ in })
        for name in ["index.html", "app.js", "style.css"] {
            XCTAssertEqual(pkg.resolve(URL(string: "appoffline://h5/\(name)")!).status, 200, name)
        }
    }

    // MARK: M4-4

    private func origin(_ scheme: String, _ host: String, main: Bool = true) -> BridgeOrigin {
        BridgeOrigin(scheme: scheme, host: host, port: 0, isMainFrame: main)
    }

    func test_m4_4_onlyOfflineOriginTrusted() async {
        XCTAssertTrue(BridgeSecurity.isTrusted(origin("appoffline", "h5")))
        XCTAssertFalse(BridgeSecurity.isTrusted(origin("https", "example.com")))
        XCTAssertFalse(BridgeSecurity.isTrusted(origin("https", "h5.offline.test")), "Android 的离线包地址在 iOS 上不算")
        XCTAssertFalse(BridgeSecurity.isTrusted(origin("appoffline", "evil")))
        XCTAssertFalse(BridgeSecurity.isTrusted(origin("https", "h5")), "只看 host 不够")
        XCTAssertFalse(BridgeSecurity.isTrusted(origin("", "")), "opaque origin（about:blank、data: 等）")
    }

    // MARK: M4-5

    private let device = DeviceInfo(platform: "ios", osVersion: "26.2", appVersion: "0.1.0")
    private let trusted = BridgeOrigin(scheme: "appoffline", host: "h5", port: 0, isMainFrame: true)

    /// 把 window.__bridgeCallback({...}) 拆回 JSON
    private func payload(_ js: String?, fn: String = "__bridgeCallback", file: StaticString = #filePath, line: UInt = #line) -> [String: Any] {
        guard let js else {
            XCTFail("没有返回 JS", file: file, line: line)
            return [:]
        }
        let prefix = "window.\(fn)("
        XCTAssertTrue(js.hasPrefix(prefix) && js.hasSuffix(")"), "返回的 JS 应形如 \(prefix)...)，实际：\(js)", file: file, line: line)
        let json = js.dropFirst(prefix.count).dropLast()
        return (try? JSONSerialization.jsonObject(with: Data(json.utf8))) as? [String: Any] ?? [:]
    }

    func test_m4_5_getDeviceInfo() async {
        let dispatcher = BridgeDispatcher(deviceInfo: device, showToast: { _ in }, log: { _ in })
        let p = payload(dispatcher.handle(#"{"id":"1","method":"getDeviceInfo","params":{}}"#, origin: trusted))
        XCTAssertEqual(p["id"] as? String, "1")
        XCTAssertEqual(p["ok"] as? Bool, true)
        let data = p["data"] as? [String: Any]
        XCTAssertEqual(data?["platform"] as? String, "ios")
        XCTAssertEqual(data?["osVersion"] as? String, "26.2")
        XCTAssertEqual(data?["appVersion"] as? String, "0.1.0")
    }

    func test_m4_5_toastShowsAndSucceeds() async {
        var toasts: [String] = []
        let dispatcher = BridgeDispatcher(deviceInfo: device, showToast: { toasts.append($0) }, log: { _ in })
        let p = payload(dispatcher.handle(#"{"id":"7","method":"toast","params":{"text":"你好"}}"#, origin: trusted))
        XCTAssertEqual(toasts, ["你好"])
        XCTAssertEqual(p["id"] as? String, "7")
        XCTAssertEqual(p["ok"] as? Bool, true)
        XCTAssertEqual((p["data"] as? [String: Any])?.isEmpty, true)
    }

    func test_m4_5_unknownMethod_METHOD_NOT_FOUND() async {
        let dispatcher = BridgeDispatcher(deviceInfo: device, showToast: { _ in }, log: { _ in })
        let p = payload(dispatcher.handle(#"{"id":"3","method":"notExist"}"#, origin: trusted))
        XCTAssertEqual(p["id"] as? String, "3")
        XCTAssertEqual(p["ok"] as? Bool, false)
        XCTAssertEqual((p["error"] as? [String: Any])?["code"] as? String, "METHOD_NOT_FOUND")
    }

    func test_m4_5_untrustedOrigin_ignored() async {
        var toasts: [String] = []
        let sink = LogSink()
        let dispatcher = BridgeDispatcher(deviceInfo: device, showToast: { toasts.append($0) }, log: sink.log)
        let evil = BridgeOrigin(scheme: "https", host: "example.com", port: 443, isMainFrame: true)
        XCTAssertNil(dispatcher.handle(#"{"id":"1","method":"toast","params":{"text":"x"}}"#, origin: evil))
        XCTAssertTrue(toasts.isEmpty, "不可信来源的 toast 不能弹")
        XCTAssertFalse(sink.lines.isEmpty, "拒绝时要打日志，方便排查")
    }

    func test_m4_5_malformedMessage_ignored() async {
        let dispatcher = BridgeDispatcher(deviceInfo: device, showToast: { _ in }, log: { _ in })
        XCTAssertNil(dispatcher.handle("not json", origin: trusted))
        XCTAssertNil(dispatcher.handle(#"{"method":"getDeviceInfo"}"#, origin: trusted), "缺 id 无法回调")
        XCTAssertNil(dispatcher.handle(#"[1,2]"#, origin: trusted))
    }

    func test_m4_0_eventJS_givenAsExample() async {
        let p = payload(BridgeJS.event("appState", data: ["state": "background"]), fn: "__bridgeEvent")
        XCTAssertEqual(p["event"] as? String, "appState")
        XCTAssertEqual((p["data"] as? [String: Any])?["state"] as? String, "background")
    }

    // MARK: M4-8

    func test_m4_8_judge() async {
        XCTAssertEqual(WhiteScreen.judge(probeResult: NSNumber(value: 0)), .emptyRoot)
        XCTAssertEqual(WhiteScreen.judge(probeResult: 0), .emptyRoot)
        XCTAssertNil(WhiteScreen.judge(probeResult: NSNumber(value: 4)))
        XCTAssertNil(WhiteScreen.judge(probeResult: 1))
        XCTAssertEqual(WhiteScreen.judge(probeResult: nil), .emptyRoot, "没拿到结果也按白屏处理")
        XCTAssertEqual(WhiteScreen.judge(probeResult: "abc"), .emptyRoot)
    }

    // MARK: M4-10

    func test_m4_10_cancelledIsNotWhiteScreen() async {
        XCTAssertNil(WhiteScreen.reasonForLoadError(URLError(.cancelled)))
        XCTAssertNil(WhiteScreen.reasonForLoadError(NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled)))
        XCTAssertNil(WhiteScreen.reasonForLoadError(NSError(domain: WKError.errorDomain, code: 102)), "Frame load interrupted")
    }

    func test_m4_10_realFailuresAreLoadError() async {
        XCTAssertEqual(WhiteScreen.reasonForLoadError(URLError(.cannotFindHost)), .loadError)
        XCTAssertEqual(WhiteScreen.reasonForLoadError(URLError(.notConnectedToInternet)), .loadError)
        XCTAssertEqual(WhiteScreen.reasonForLoadError(NSError(domain: WKError.errorDomain, code: 101)), .loadError)
        XCTAssertEqual(WhiteScreen.reasonForLoadError(NSError(domain: "Other", code: -999)), .loadError, "只有 NSURLErrorDomain 的 -999 是取消")
    }
}
