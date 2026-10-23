import Foundation
import Observation
import WebKit

enum WhiteScreenReason: String {
    case emptyRoot = "empty_root"
    case renderGone = "render_gone"
    case loadError = "load_error"
}

enum WhiteScreen {
    /// spec 规定的探测脚本：#app 的子元素个数
    static let probeJS = "(document.getElementById('app') || {}).childElementCount || 0"
    /// 主文档加载完多久后探测。slow case 会误报，M4 手工任务里由你来改检测时机
    static let checkDelay: Duration = .seconds(1)

    // 空 M4-8：probeJS 的执行结果 → 是否白屏。子元素数为 0、结果不是数字、没拿到结果（nil）都算 .emptyRoot，否则 nil
    // 提示 1：evaluateJavaScript 拿到的 JS number 在 Swift 里是 NSNumber（也能 as? Int）
    static func judge(probeResult: Any?) -> WhiteScreenReason? {
        TODO("M4-8")
    }

    // 空 M4-10：主文档加载失败的回调里拿到的 error → 是否算白屏
    // - 被取消的导航（NSURLErrorCancelled，-999，比如还没加载完就跳了别的页）不算，返回 nil
    // - WebKit 的 102「Frame load interrupted」（导航被策略拦下 / 转去下载）也不算
    // - 其他都是 .loadError
    // 提示 1：转成 NSError 看 domain 和 code；WebKit 的 domain 是 WKError.errorDomain
    static func reasonForLoadError(_ error: any Error) -> WhiteScreenReason? {
        TODO("M4-10")
    }
}

/// 白屏上报。真实容器里这里会打点上报，这里只打日志 + 把结果显示在 H5 页顶部的状态条上
@Observable
final class WhiteScreenDetector {
    private(set) var status = "检测中…"
    @ObservationIgnored private let log: (String) -> Void

    init(log: @escaping (String) -> Void = M3ELog.d) {
        self.log = log
    }

    func reset() {
        status = "检测中…"
    }

    /// M4_WHITE_SCREEN 关着：状态条上说明没检测，免得一直显示「检测中…」
    func markDisabled() {
        status = "未开启"
    }

    func report(_ reason: WhiteScreenReason?, url: URL?) {
        let urlText = url?.absoluteString ?? "nil"
        if let reason {
            log("[WHITE_SCREEN] reason=\(reason.rawValue) url=\(urlText)")
            status = reason.rawValue
        } else {
            log("白屏检测通过 url=\(urlText)")
            status = "正常"
        }
    }
}
