import Foundation
import WebKit

/// 接管 appoffline:// 的所有请求。
/// iOS 和另外两端最大的差异：WKURLSchemeHandler 只能注册自定义 scheme，http / https 注册了会直接抛异常
final class OfflineSchemeHandler: NSObject, WKURLSchemeHandler {
    let package: OfflinePackage

    init(package: OfflinePackage) {
        self.package = package
    }

    // 已写好（原空 M4-3）：WebView 发来一个 appoffline:// 请求，用 package.resolve 找到内容，按顺序回给 task。读懂即可
    // 顺序固定：响应头（状态码 + Content-Type）→ 数据（可以分多次）→ 完成。task.request.url 为 nil 时 didFailWithError。
    // 响应要用 HTTPURLResponse：普通 URLResponse 带不了状态码，404 时 H5 的 <script> 就收不到 onerror
    func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url else {
            urlSchemeTask.didFailWithError(URLError(.badURL))
            return
        }
        let result = package.resolve(url)
        let response = HTTPURLResponse(
            url: url,
            statusCode: result.status,
            httpVersion: "HTTP/1.1",
            headerFields: [
                "Content-Type": result.mime,
                "Content-Length": String(result.data.count),
            ]
        )!
        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(result.data)
        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {
        // start 里是同步处理完的，没有要取消的东西。
        // 如果改成异步读文件 / 走网络：这里要记下 task 已停止，之后再调它的 didReceive 会直接崩
    }
}
