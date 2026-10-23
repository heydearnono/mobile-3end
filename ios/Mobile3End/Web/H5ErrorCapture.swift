import Foundation

/// M5：把 H5 里的未捕获异常转发到原生日志 `[H5_ERROR]`。
/// 真实容器里这一步通常由 H5 的监控 SDK 自己做，原生只负责兜底
enum H5ErrorCapture {
    static let js = """
    (function () {
      function send(p) {
        try { window.webkit.messageHandlers.M3EError.postMessage(JSON.stringify(p)); } catch (e) {}
      }
      window.addEventListener('error', function (e) {
        send({ type: 'error', message: e.message, source: e.filename, line: e.lineno, col: e.colno,
               stack: e.error && e.error.stack });
      });
      window.addEventListener('unhandledrejection', function (e) {
        var r = e.reason || {};
        send({ type: 'unhandledrejection', message: String(r.message || r), stack: r.stack });
      });
    })();
    """

    static func log(_ body: Any) {
        guard let text = body as? String,
              let data = text.data(using: .utf8),
              let info = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            M3ELog.d("[H5_ERROR] \(body)")
            return
        }
        let message = info["message"] as? String ?? "?"
        let source = info["source"] as? String ?? ""
        let line = info["line"] as? Int ?? 0
        let stack = info["stack"] as? String ?? "(无堆栈)"
        M3ELog.d("[H5_ERROR] \(message) @ \(source):\(line)\n\(stack)")
    }
}
