import Foundation
import UniformTypeIdentifiers

/// 离线包请求的处理结果
struct OfflineResponse: Equatable {
    let status: Int
    let mime: String
    let data: Data
}

/// 离线包：appoffline://h5/<path> → App 包里的 h5/<path>
/// 纯逻辑，不依赖 WebKit，方便单测；接到 WKWebView 上的胶水在 OfflineSchemeHandler
struct OfflinePackage {
    static let scheme = "appoffline"
    static let host = "h5"
    static let entryURL = URL(string: "appoffline://h5/index.html")!

    /// 离线包根目录（Mobile3End.app/h5/）
    let root: URL
    var log: (String) -> Void = M3ELog.d

    static func bundled(log: @escaping (String) -> Void = M3ELog.d) -> OfflinePackage {
        // project.yml 里以 folder reference 加进来的 mock/h5，在包里就是一个叫 h5 的目录
        let root = Bundle.main.url(forResource: "h5", withExtension: nil)
            ?? Bundle.main.bundleURL.appending(path: "h5")
        return OfflinePackage(root: root, log: log)
    }

    /// 这个地址是不是归离线包管
    static func owns(_ url: URL?) -> Bool {
        url?.scheme == scheme && url?.host == host
    }

    // 已写好（原空 M4-1）：按扩展名给 MIME（"html" → "text/html"），认不出来的给 "application/octet-stream"。读懂即可
    // 用的是系统的 UniformTypeIdentifiers：UTType(filenameExtension:) 查系统类型表，preferredMIMEType 取 MIME。
    // 系统表里的扩展名是小写的，所以先 lowercased()；也可以自己写一张 [扩展名: MIME] 表
    static func mimeType(forExtension ext: String) -> String {
        UTType(filenameExtension: ext.lowercased())?.preferredMIMEType ?? "application/octet-stream"
    }

    // 已写好（原空 M4-2）：把离线包地址映射成包内文件。读懂即可
    // - scheme / host 不对、文件不存在、是目录、路径跳出了 root（../）：都返回 notFound(url)
    // - 找到：200 + mimeType + 文件内容
    // - 查询串（?case=blank）不影响找文件
    // 要点：url.path 是解码后的路径（不含 ? 后面），%2E%2E 也已经变成 ..；
    // standardizedFileURL 把 ../ 消掉，消完再看还在不在 root 里。
    // 比的是 root + "/"，否则 h5-secret/ 也会被当成在 h5/ 里。目录用 Data(contentsOf:) 读不出来，自然落到 404
    func resolve(_ url: URL) -> OfflineResponse {
        guard Self.owns(url) else { return notFound(url) }
        let relative = String(url.path.drop { $0 == "/" })
        let rootPath = root.standardizedFileURL.path
        let file = root.appending(path: relative).standardizedFileURL
        guard file.path.hasPrefix(rootPath + "/"),
              let data = try? Data(contentsOf: file) else {
            return notFound(url)
        }
        return OfflineResponse(status: 200, mime: Self.mimeType(forExtension: file.pathExtension), data: data)
    }

    /// 404 + 日志。日志格式是 spec 定的，三端一致，排查时按它搜
    private func notFound(_ url: URL) -> OfflineResponse {
        log("[OFFLINE_404] \(url.absoluteString)")
        return OfflineResponse(status: 404, mime: "text/plain", data: Data())
    }
}
