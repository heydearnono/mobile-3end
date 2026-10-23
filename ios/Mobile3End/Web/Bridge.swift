import Foundation
import UIKit

/// 消息来源。从 WKScriptMessage.frameInfo 里取出来，单独成一个结构体是为了能在单测里构造
/// （WKSecurityOrigin 没有公开的初始化方法，测试里 new 不出来）
struct BridgeOrigin: Equatable {
    /// securityOrigin.protocol，不带冒号，如 "appoffline"、"https"
    let scheme: String
    let host: String
    let port: Int
    let isMainFrame: Bool
}

enum BridgeSecurity {
    // 空 M4-4：只信任离线包 origin（scheme 和 host 都要对上，用 OfflinePackage 里的常量）
    // 提示 1：https://h5.offline.test 是 Android / 鸿蒙的离线包地址，在 iOS 上不算
    static func isTrusted(_ origin: BridgeOrigin) -> Bool {
        TODO("M4-4")
    }
}

/// 拼 Native → H5 要执行的 JS。payload 用 JSONSerialization 生成，JSON 本身就是合法的 JS 字面量，不用自己转义
enum BridgeJS {
    static func success(id: String, data: [String: Any]) -> String {
        call("__bridgeCallback", ["id": id, "ok": true, "data": data])
    }

    static func failure(id: String, code: String, message: String) -> String {
        call("__bridgeCallback", ["id": id, "ok": false, "error": ["code": code, "message": message]])
    }

    static func event(_ name: String, data: [String: Any]) -> String {
        call("__bridgeEvent", ["event": name, "data": data])
    }

    private static func call(_ function: String, _ payload: [String: Any]) -> String {
        let json = (try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        return "window.\(function)(\(json))"
    }
}

struct DeviceInfo {
    let platform: String
    let osVersion: String
    let appVersion: String

    static func current() -> DeviceInfo {
        DeviceInfo(
            platform: "ios",
            osVersion: UIDevice.current.systemVersion,
            appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        )
    }

    var dict: [String: Any] {
        ["platform": platform, "osVersion": osVersion, "appVersion": appVersion]
    }
}

/// bridge 分发：输入消息字符串 + 来源，输出要执行的 JS（nil 表示不回）。纯逻辑，单测覆盖
final class BridgeDispatcher {
    private let deviceInfo: DeviceInfo
    private let showToast: (String) -> Void
    private let log: (String) -> Void

    init(deviceInfo: DeviceInfo, showToast: @escaping (String) -> Void, log: @escaping (String) -> Void = M3ELog.d) {
        self.deviceInfo = deviceInfo
        self.showToast = showToast
        self.log = log
    }

    // 空 M4-5：处理一条 H5 消息 {"id":"1","method":"getDeviceInfo","params":{}}
    // - 来源不可信（BridgeSecurity）：打日志，返回 nil，什么都不做
    // - 不是合法 JSON / 缺 id 或 method：打日志，返回 nil
    // - getDeviceInfo → success(data: deviceInfo.dict)
    // - toast → 调 showToast(params.text)，success(data: [:])
    // - 其他 → failure(code: "METHOD_NOT_FOUND")
    // 提示 1：JSONSerialization.jsonObject 出来是 Any，用 as? [String: Any] 一层层取；用 BridgeJS 拼返回值
    func handle(_ body: String, origin: BridgeOrigin) -> String? {
        TODO("M4-5")
    }
}
