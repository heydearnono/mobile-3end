import XCTest
@testable import Mobile3End

/// M2 纯逻辑检查：解码、请求、缓存、排序持久化、加载状态机
@MainActor
final class M2LogicTests: XCTestCase {

    // 和 mock/api/files.json 同结构（截取前 3 条）
    private let mockJSON = """
    { "files": [
      { "id": "f001", "name": "工作资料", "type": "folder", "size": 0, "mtime": 1760500000 },
      { "id": "f003", "name": "季度复盘.docx", "type": "doc", "size": 482133, "mtime": 1760830000 },
      { "id": "f007", "name": "发布会录屏.mp4", "type": "video", "size": 268435456, "mtime": 1758900000 }
    ] }
    """.data(using: .utf8)!

    // MARK: M2-1 / M2-2 解码

    func test_m2_1_knownTypesDecode() async throws {
        let types = try JSONDecoder().decode([FileType].self, from: #"["folder","doc","image","video"]"#.data(using: .utf8)!)
        XCTAssertEqual(types, [.folder, .doc, .image, .video])
    }

    func test_m2_1_unknownTypeFallsBackToDoc() async throws {
        let types = try JSONDecoder().decode([FileType].self, from: #"["audio","image"]"#.data(using: .utf8)!)
        XCTAssertEqual(types, [.doc, .image])
    }

    func test_m2_2_decodesApiResponse() async throws {
        let files = try decodeFiles(mockJSON)
        XCTAssertEqual(files.map(\.id), ["f001", "f003", "f007"])
        XCTAssertEqual(files[0].type, .folder)
        XCTAssertEqual(files[2].size, 268435456)
        XCTAssertEqual(files[1].mtime, 1760830000)
    }

    func test_m2_2_missingFieldThrows() async {
        let bad = #"{ "files": [ { "id": "x", "name": "x" } ] }"#.data(using: .utf8)!
        XCTAssertThrowsError(try decodeFiles(bad))
    }

    // MARK: M2-3 请求

    func test_m2_3_fetchDecodesBody() async throws {
        StubURLProtocol.status = 200
        StubURLProtocol.body = mockJSON
        let remote = URLSessionFileRemote(url: AppConfig.filesURL, session: StubURLProtocol.session())
        let files = try await remote.fetch()
        XCTAssertEqual(files.count, 3)
    }

    func test_m2_3_non2xxThrowsBadStatus() async {
        StubURLProtocol.status = 500
        StubURLProtocol.body = Data("oops".utf8)
        let remote = URLSessionFileRemote(url: AppConfig.filesURL, session: StubURLProtocol.session())
        do {
            _ = try await remote.fetch()
            XCTFail("500 应该抛错")
        } catch {
            XCTAssertEqual(error as? FileApiError, .badStatus(500))
        }
    }

    /// 连真实的 mock 服务。check.sh 会自动启动它；在 Xcode 里跑时没开服务就跳过
    func test_m2_3_realMockServer() async throws {
        let remote = URLSessionFileRemote(url: AppConfig.filesURL)
        let files: [FileItem]
        do {
            files = try await remote.fetch()
        } catch let error as URLError where error.code == .cannotConnectToHost || error.code == .timedOut {
            throw XCTSkip("mock 服务没开：python3 -m http.server 8000 -d mock")
        }
        XCTAssertEqual(files.count, 12)
    }

    // MARK: M2-4 / M2-5 缓存

    func test_m2_4_m2_5_cacheRoundTrip() async {
        let cache = FileCache(fileURL: makeTempDir().appending(path: "c.json"))
        let files = [item("a", "a.txt", mtime: 1), item("F", "F", .folder)]
        cache.save(files)
        XCTAssertEqual(cache.load(), files)
    }

    func test_m2_4_saveOverwrites() async {
        let cache = FileCache(fileURL: makeTempDir().appending(path: "c.json"))
        cache.save([item("a", "a")])
        cache.save([])
        XCTAssertEqual(cache.load(), [])
    }

    func test_m2_5_missingCacheIsNil() async {
        let cache = FileCache(fileURL: makeTempDir().appending(path: "none.json"))
        XCTAssertNil(cache.load())
    }

    func test_m2_5_corruptCacheIsNil() async throws {
        let url = makeTempDir().appending(path: "c.json")
        try Data("{ not json".utf8).write(to: url)
        XCTAssertNil(FileCache(fileURL: url).load())
    }

    // MARK: M2-6 排序持久化

    func test_m2_6_defaultIsName() async {
        XCTAssertEqual(SortStore(defaults: makeDefaults()).order, .name)
    }

    func test_m2_6_persistsAcrossInstances() async {
        let defaults = makeDefaults()
        SortStore(defaults: defaults).order = .time
        XCTAssertEqual(SortStore(defaults: defaults).order, .time)
        SortStore(defaults: defaults).order = .name
        XCTAssertEqual(SortStore(defaults: defaults).order, .name)
    }

    func test_m2_6_unknownValueFallsBackToName() async {
        let defaults = makeDefaults()
        defaults.set("size", forKey: SortStore.key)
        XCTAssertEqual(SortStore(defaults: defaults).order, .name)
    }

    func test_m2_6_modelWritesOrderThrough() async {
        let defaults = makeDefaults()
        let model = FileListModel(remote: FakeRemote(.success([])), cache: FileCache(fileURL: makeTempDir().appending(path: "c.json")),
                                  sortStore: SortStore(defaults: defaults))
        model.order = .time
        XCTAssertEqual(SortStore(defaults: defaults).order, .time)
    }

    // MARK: M2-7 加载状态机

    private func makeModel(_ remote: any FileRemote, cached: [FileItem]? = nil) -> (FileListModel, FileCache) {
        let cache = FileCache(fileURL: makeTempDir().appending(path: "c.json"), log: { _ in })
        if let cached { cache.save(cached) }
        let model = FileListModel(remote: remote, cache: cache, sortStore: SortStore(defaults: makeDefaults()), log: { _ in })
        return (model, cache)
    }

    private let cachedFiles = [item("old", "旧数据")]
    private let freshFiles = [item("new1", "新数据1"), item("new2", "新数据2")]

    func test_m2_7_noCache_showsLoadingThenData() async {
        let remote = GatedRemote()
        let (model, cache) = makeModel(remote)
        let task = Task { await model.load() }
        await remote.waitUntilWaiting()
        XCTAssertEqual(model.state, .loading)

        remote.finish(.success(freshFiles))
        await task.value
        XCTAssertEqual(model.state, .loaded(freshFiles))
        XCTAssertEqual(cache.load(), freshFiles, "成功后要写缓存")
    }

    func test_m2_7_cacheShownFirstThenReplaced() async {
        let remote = GatedRemote()
        let (model, cache) = makeModel(remote, cached: cachedFiles)
        let task = Task { await model.load() }
        await remote.waitUntilWaiting()
        XCTAssertEqual(model.state, .loaded(cachedFiles), "请求还没回来时应先显示缓存，而不是 loading")

        remote.finish(.success(freshFiles))
        await task.value
        XCTAssertEqual(model.state, .loaded(freshFiles))
        XCTAssertEqual(cache.load(), freshFiles)
    }

    func test_m2_7_failureWithCacheKeepsCache() async {
        let (model, _) = makeModel(FakeRemote(.failure(URLError(.cannotConnectToHost))), cached: cachedFiles)
        await model.load()
        XCTAssertEqual(model.state, .loaded(cachedFiles))
    }

    func test_m2_7_failureWithoutCacheShowsFailed() async {
        let (model, _) = makeModel(FakeRemote(.failure(URLError(.cannotConnectToHost))))
        await model.load()
        guard case .failed(let message) = model.state else {
            return XCTFail("应为失败态，实际 \(model.state)")
        }
        XCTAssertEqual(message, FileListModel.message(for: URLError(.cannotConnectToHost)))
    }

    func test_m2_7_emptyListIsSuccess() async {
        let (model, cache) = makeModel(FakeRemote(.success([])), cached: cachedFiles)
        await model.load()
        XCTAssertEqual(model.state, .loaded([]), "空列表也是成功，要覆盖掉旧缓存")
        XCTAssertEqual(cache.load(), [])
    }

    func test_m2_7_retryAfterFailure() async {
        let remote = FakeRemote(.failure(URLError(.timedOut)))
        let (model, _) = makeModel(remote)
        await model.load()
        remote.result = .success(freshFiles)
        await model.load()
        XCTAssertEqual(model.state, .loaded(freshFiles))
        XCTAssertEqual(remote.calls, 2)
    }

    // MARK: 手工任务：ATS

    /// Info.plist 是手工改的，没法挖空。这个测试检查你有没有放行 localhost 的明文 http，而且没有全局放开
    func test_m2_task_atsAllowsLocalhost() async {
        let ats = Bundle.main.object(forInfoDictionaryKey: "NSAppTransportSecurity") as? [String: Any]
        XCTAssertNotNil(ats, "Info.plist 里还没有 NSAppTransportSecurity，见 hints/ios-M2.md「手工任务：ATS」")
        XCTAssertNotEqual(ats?["NSAllowsArbitraryLoads"] as? Bool, true, "不要用 NSAllowsArbitraryLoads 全局放开明文 http")
        let localhost = (ats?["NSExceptionDomains"] as? [String: Any])?["localhost"] as? [String: Any]
        let allowsLocalhost = localhost?["NSExceptionAllowsInsecureHTTPLoads"] as? Bool == true
        let allowsLocal = ats?["NSAllowsLocalNetworking"] as? Bool == true
        XCTAssertTrue(allowsLocalhost || allowsLocal, "没有找到对 localhost 的明文 http 放行")
    }
}
