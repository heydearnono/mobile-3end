import Foundation
import XCTest
@testable import Mobile3End

/// 测试共用的假对象。方法名前缀 = 覆盖的空，check.sh 按它汇总
///
/// 为什么所有测试方法都是 async：Xcode 27 + iOS 26.x 模拟器上，hosted 单测里同步的测试方法一旦释放
/// @MainActor 类的对象（FileListModel、LogSink……），会在 swift_task_deinitOnExecutor 里崩
/// （malloc: pointer being freed was not allocated）。async 测试方法跑在 Task 里，不受影响。App 本身运行不受影响

/// 收集日志，断言用
@MainActor
final class LogSink {
    private(set) var lines: [String] = []

    /// 传给被测对象：`log: sink.log`
    func log(_ line: String) { lines.append(line) }

    func contains(_ text: String) -> Bool { lines.contains { $0.contains(text) } }
}

/// 立刻返回结果的假数据源，记录被调用次数
@MainActor
final class FakeRemote: FileRemote {
    var result: Result<[FileItem], any Error>
    private(set) var calls = 0

    init(_ result: Result<[FileItem], any Error>) {
        self.result = result
    }

    func fetch() async throws -> [FileItem] {
        calls += 1
        return try result.get()
    }
}

/// 请求会一直挂着，直到测试手动放行。用来观察「请求进行中」的界面状态
@MainActor
final class GatedRemote: FileRemote {
    private var continuations: [CheckedContinuation<[FileItem], any Error>] = []
    private(set) var calls = 0

    var isWaiting: Bool { !continuations.isEmpty }

    func fetch() async throws -> [FileItem] {
        calls += 1
        return try await withCheckedThrowingContinuation { continuations.append($0) }
    }

    /// 放行所有挂着的请求（同时发了两次的话两次都放行，测试才不会卡死）
    func finish(_ result: Result<[FileItem], any Error>) {
        let pending = continuations
        continuations = []
        pending.forEach { $0.resume(with: result) }
    }

    /// 等到 fetch 真的被调用、挂起
    func waitUntilWaiting(file: StaticString = #filePath, line: UInt = #line) async {
        for _ in 0..<200 where !isWaiting {
            try? await Task.sleep(for: .milliseconds(5))
        }
        XCTAssertTrue(isWaiting, "1s 内没有发出请求", file: file, line: line)
    }
}

/// URLSession 的假网络层：注册进 URLSessionConfiguration.protocolClasses，拦下所有请求
final class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var status = 200
    nonisolated(unsafe) static var body = Data()
    nonisolated(unsafe) static var requestedURLs: [URL] = []

    static func session() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: config)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let url = request.url!
        Self.requestedURLs.append(url)
        let response = HTTPURLResponse(url: url, statusCode: Self.status, httpVersion: "HTTP/1.1",
                                       headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

/// 每个测试一个临时目录，测完删掉
func makeTempDir() -> URL {
    let dir = FileManager.default.temporaryDirectory.appending(path: "m3e-test-\(UUID().uuidString)")
    try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
}

/// 每个测试一个独立的 UserDefaults
func makeDefaults() -> UserDefaults {
    let name = "m3e-test-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    return defaults
}

func item(_ id: String, _ name: String, _ type: FileType = .doc, size: Int64 = 1, mtime: Int64 = 0) -> FileItem {
    FileItem(id: id, name: name, type: type, size: size, mtime: mtime)
}
