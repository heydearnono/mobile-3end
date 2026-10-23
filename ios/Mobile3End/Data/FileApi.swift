import Foundation

/// 接口返回体：{ "files": [ ... ] }
struct FilesResponse: Decodable {
    let files: [FileItem]
}

extension FileType {
    // 空 M2-1：自己实现解码。接口里出现不认识的 type（比如以后加了 "audio"）时不要整份数据解析失败，当成 .doc
    // 提示 1：先从 decoder 里取出一个 String，再试着变成 FileType
    init(from decoder: any Decoder) throws {
        TODO("M2-1")
    }
}

// 空 M2-2：把接口返回的 JSON 解析成 [FileItem]
// 提示 1：JSONDecoder，解出来的是 FilesResponse，要的是它里面的数组
func decodeFiles(_ data: Data) throws -> [FileItem] {
    TODO("M2-2")
}

enum FileApiError: Error, Equatable {
    case badStatus(Int)
}

/// 数据源抽象：App 里是 URLSession，测试里换成假的
protocol FileRemote {
    func fetch() async throws -> [FileItem]
}

struct URLSessionFileRemote: FileRemote {
    let url: URL
    var session: URLSession = .m3e

    func fetch() async throws -> [FileItem] {
        do {
            let files = try await fetchRaw()
            M3ELog.d("GET \(url.absoluteString) → \(files.count) 条")
            return files
        } catch let error as URLError where error.code == .appTransportSecurityRequiresSecureConnection {
            // -1022：明文 http 被 ATS 拦了
            M3ELog.d("[ATS] 明文 http 被 App Transport Security 拦截：\(url.absoluteString)。在 Info.plist 里放行，见 hints/ios-M2.md")
            throw error
        } catch {
            M3ELog.d("GET \(url.absoluteString) 失败：\(error)")
            throw error
        }
    }

    // 空 M2-3：发 GET 请求，状态码不是 2xx 时抛 FileApiError.badStatus(状态码)，成功则解析成 [FileItem]
    // 提示 1：session.data(from:) 是 async 的；返回的 URLResponse 要转成 HTTPURLResponse 才有状态码
    private func fetchRaw() async throws -> [FileItem] {
        TODO("M2-3")
    }
}

extension URLSession {
    /// 不用 HTTP 缓存，免得调试时分不清是缓存还是服务端返回的；超时调短，关掉 mock 服务时失败得快一点
    static let m3e: URLSession = {
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = 5
        return URLSession(configuration: config)
    }()
}

/// UI 测试和手动调试用的假数据源，启动参数 `-M3EFake ok|empty|fail|slow`
struct DebugRemote: FileRemote {
    enum Mode: String { case ok, empty, fail, slow }
    let mode: Mode

    func fetch() async throws -> [FileItem] {
        M3ELog.d("DebugRemote.fetch mode=\(mode.rawValue)")
        switch mode {
        case .ok: return SampleData.files
        case .empty: return []
        case .fail: throw URLError(.cannotConnectToHost)
        case .slow:
            try await Task.sleep(for: .seconds(3))
            return SampleData.files
        }
    }
}
