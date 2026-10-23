import XCTest
@testable import Mobile3End

/// S1 Swift 语言专项，纯逻辑单测。方法名前缀 = 覆盖的空，`_0_` 是示例（不用填空就能过）
/// 方法都写成 async 的原因见 TestSupport.swift 开头
@MainActor
final class S1Tests: XCTestCase {

    private let folder = item("d1", "工作资料", .folder, size: 0, mtime: 1760500000)
    private let doc = item("f1", "季度复盘.docx", .doc, size: 482133, mtime: 1760830000)
    private let image = item("f2", "猫.heic", .image, size: 2097152, mtime: 1759900000)
    private let smallImage = item("f3", "截图.png", .image, size: 212004, mtime: 1759300000)
    private let video = item("f4", "会议录音.m4a", .video, size: 15728640, mtime: 1757500000)

    // MARK: - 示例

    func test_s1_0_optionalExample() async {
        XCTAssertEqual(parsePort("8000"), 8000)
        XCTAssertEqual(parsePort("abc"), 80, "Int(\"abc\") 是 nil")
        XCTAssertEqual(parsePort(nil), 80)
    }

    func test_s1_0_structIsCopiedClassIsShared() async {
        // struct：b 是 a 的副本
        let a = UploadTask(name: "a")
        var b = a
        b.progress = 0.5
        XCTAssertEqual(a.progress, 0, "改副本不影响原来的")

        // 数组也是 struct
        let xs = [1, 2]
        var ys = xs
        ys.append(3)
        XCTAssertEqual(xs, [1, 2], "Swift 的数组赋值就是复制，和 JS 不一样")

        // class：q 和 r 是同一个对象
        let q = UploadQueue()
        let r = q
        r.add("a")
        XCTAssertEqual(q.tasks.count, 1, "class 赋值只复制引用")
        XCTAssertTrue(q === r)
    }

    // MARK: - 第 1 节 可选类型

    func test_s1_1_firstImageSize() async {
        XCTAssertEqual(firstImageSize(nil), 0)
        XCTAssertEqual(firstImageSize([]), 0)
        XCTAssertEqual(firstImageSize([folder, doc]), 0)
        XCTAssertEqual(firstImageSize([doc, smallImage, image]), 212004, "要的是第一个图片")
    }

    func test_s1_2_toastText() async {
        XCTAssertEqual(toastText(["method": "toast", "params": ["text": "hi"]]), "hi")
        XCTAssertNil(toastText(["method": "toast"]), "没有 params")
        XCTAssertNil(toastText(["params": "text=hi"]), "params 不是字典")
        XCTAssertNil(toastText(["params": ["text": 42]]), "text 不是字符串")
        XCTAssertNil(toastText(["params": ["text": ""]]), "空字符串也算没有")
    }

    // MARK: - 第 2 节 闭包

    func test_s1_3_imageNamesBySizeDesc() async {
        XCTAssertEqual(imageNamesBySizeDesc([smallImage, doc, image, video, folder]), ["猫.heic", "截图.png"])
        XCTAssertEqual(imageNamesBySizeDesc([doc, folder]), [])
    }

    func test_s1_4_eventHubCallsHandlersInOrder() async {
        let hub = EventHub()
        var got: [String] = []
        hub.on("appState") { got.append("A:\($0)") }
        hub.on("appState") { got.append("B:\($0)") }
        hub.on("other") { got.append("X:\($0)") }

        hub.emit("appState", "background")
        hub.emit("appState", "foreground")
        XCTAssertEqual(got, ["A:background", "B:background", "A:foreground", "B:foreground"])
    }

    // MARK: - 第 3 节 值类型

    func test_s1_5_advanceClampsAtOne() async {
        var task = UploadTask(name: "a")
        task.advance(by: 0.25)
        XCTAssertEqual(task.progress, 0.25, accuracy: 1e-9)
        task.advance(by: 0.5)
        XCTAssertEqual(task.progress, 0.75, accuracy: 1e-9)
        task.advance(by: 0.5)
        XCTAssertEqual(task.progress, 1, "最多到 1")
    }

    func test_s1_6_queueAdvanceChangesTheElementInPlace() async {
        let queue = UploadQueue()
        queue.add("a")
        queue.add("b")
        let before = queue.changes

        queue.advance("b", by: 0.5)
        XCTAssertEqual(queue.tasks.map(\.progress), [0, 0.5], "数组里的 b 要真的被改掉")
        XCTAssertEqual(queue.changes, before + 1, "改数组元素 = 给整个 tasks 赋了新值，didSet 会触发")

        queue.advance("nope", by: 0.5)
        XCTAssertEqual(queue.tasks.map(\.progress), [0, 0.5])
    }

    func test_s1_7_applyAndUndo() async {
        let list = UndoableList([folder, doc, image])
        XCTAssertFalse(list.canUndo)

        list.apply { $0.removeAll { $0.type == .folder } }
        XCTAssertEqual(list.files.map(\.id), ["f1", "f2"])
        list.apply { $0.append(video) }
        XCTAssertEqual(list.files.map(\.id), ["f1", "f2", "f4"])

        list.undo()
        XCTAssertEqual(list.files.map(\.id), ["f1", "f2"])
        list.undo()
        XCTAssertEqual(list.files.map(\.id), ["d1", "f1", "f2"])
        XCTAssertFalse(list.canUndo)
        list.undo()
        XCTAssertEqual(list.files.map(\.id), ["d1", "f1", "f2"], "没有可撤销的就不变")
    }

    // MARK: - 第 4 节 enum

    func test_s1_8_stateSummary() async {
        XCTAssertEqual(stateSummary(.loading), "loading")
        XCTAssertEqual(stateSummary(.failed("服务器返回 500")), "failed: 服务器返回 500")
        XCTAssertEqual(stateSummary(.loaded([])), "empty")
        XCTAssertEqual(stateSummary(.loaded([doc, image])), "loaded 2")
    }

    func test_s1_9_bridgeCallFromMethod() async {
        XCTAssertEqual(BridgeCall(method: "getDeviceInfo", params: [:]), .getDeviceInfo)
        XCTAssertEqual(BridgeCall(method: "toast", params: ["text": "hi"]), .toast(text: "hi"))
        XCTAssertEqual(BridgeCall(method: "toast", params: [:]), .toast(text: ""), "缺 text")
        XCTAssertEqual(BridgeCall(method: "toast", params: ["text": 1]), .toast(text: ""), "text 不是字符串")
        XCTAssertEqual(BridgeCall(method: "openFile", params: [:]), .unknown(method: "openFile"))
        XCTAssertEqual(BridgeCall(method: "GetDeviceInfo", params: [:]), .unknown(method: "GetDeviceInfo"), "大小写敏感")
    }

    // MARK: - 第 5 节 protocol + extension

    func test_s1_10_totalSize() async {
        XCTAssertEqual([FileItem]().totalSize, 0)
        XCTAssertEqual([folder, doc, image].totalSize, 482133 + 2097152)
    }

    func test_s1_11_defaultSubtitle() async {
        XCTAssertEqual(folder.subtitle, "—")
        XCTAssertEqual(item("x", "x", size: 1024).subtitle, "1.0 KB")
        // 装进 [any Listable]：每个元素用自己的 subtitle
        let rows: [any Listable] = [folder, image, TrashSummary(count: 3, bytes: 4096)]
        XCTAssertEqual(rows.map(\.subtitle), ["—", "2.0 MB", "3 项"])
        XCTAssertEqual(rows.map(\.title), ["📁 工作资料", "🖼️ 猫.heic", "🗑️ 回收站"])
    }

    // MARK: - 第 6 节 错误处理

    private func assertParseError(_ text: String, _ expected: BridgeParseError,
                                  file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertThrowsError(try parseRequest(text), file: file, line: line) { error in
            XCTAssertEqual(error as? BridgeParseError, expected, "输入：\(text)", file: file, line: line)
        }
    }

    func test_s1_12_parseRequest() async throws {
        XCTAssertEqual(try parseRequest(#"{"id":"1","method":"toast","params":{"text":"hi"}}"#),
                       BridgeRequest(id: "1", method: "toast"))
        assertParseError("<html>502</html>", .notJSON)
        assertParseError("[1, 2]", .notJSON)
        assertParseError("", .notJSON)
        assertParseError(#"{"method":"toast"}"#, .missingField("id"))
        assertParseError(#"{"id":"1"}"#, .missingField("method"))
        assertParseError("{}", .missingField("id"))
        assertParseError(#"{"id":1,"method":"toast"}"#, .missingField("id"))
    }

    func test_s1_13_replyFor() async {
        XCTAssertEqual(replyFor(#"{"id":"1","method":"toast"}"#), .ok(data: ["method": "toast"]))
        XCTAssertEqual(replyFor("oops"), .err(code: "BAD_JSON", message: ""))
        XCTAssertEqual(replyFor(#"{"id":"1"}"#), .err(code: "MISSING_FIELD", message: "method"))
    }

    // MARK: - 第 7 节 并发

    func test_s1_14_loadBothRunsConcurrently() async {
        let a = item("a", "a"), b = item("b", "b")
        let start = ContinuousClock.now
        let files = await loadBoth(
            first: { try? await Task.sleep(for: .milliseconds(400)); return [a] },
            second: { try? await Task.sleep(for: .milliseconds(400)); return [b] }
        )
        let elapsed = ContinuousClock.now - start
        XCTAssertEqual(files.map(\.id), ["a", "b"])
        XCTAssertLessThan(elapsed, .milliseconds(700), "两个 0.4s 的请求花了 \(elapsed)，是不是一个等完才开始另一个？")
    }

    func test_s1_14_orderFollowsArgumentsNotFinishTime() async {
        let a = item("a", "a"), b = item("b", "b")
        let files = await loadBoth(
            first: { try? await Task.sleep(for: .milliseconds(200)); return [a] },
            second: { [b] }
        )
        XCTAssertEqual(files.map(\.id), ["a", "b"])
    }

    func test_s1_15_debounceRunsOnlyTheLastCall() async throws {
        let debouncer = Debouncer(delay: .milliseconds(100))
        var got: [Int] = []
        debouncer.call { got.append(1) }
        debouncer.call { got.append(2) }
        debouncer.call { got.append(3) }
        XCTAssertEqual(got, [], "要等 delay 之后才执行")
        try await Task.sleep(for: .milliseconds(400))
        XCTAssertEqual(got, [3], "前两次被作废了")

        // 隔开调用的，各执行一次
        debouncer.call { got.append(4) }
        try await Task.sleep(for: .milliseconds(400))
        XCTAssertEqual(got, [3, 4])
    }

    func test_s1_15_cancelStopsPendingCall() async throws {
        let debouncer = Debouncer(delay: .milliseconds(100))
        var got: [Int] = []
        debouncer.call { got.append(1) }
        debouncer.cancel()
        try await Task.sleep(for: .milliseconds(400))
        XCTAssertEqual(got, [], "cancel() 取消的是 call 里存下的 task")
    }

    // MARK: - 第 8 节 property wrapper

    func test_s1_16_storedReadsAndWritesDefaults() async {
        let defaults = makeDefaults()
        let prefs = S1Prefs(defaults: defaults)
        XCTAssertEqual(prefs.launchCount, 0, "没存过用 defaultValue")
        XCTAssertEqual(prefs.lastCase, "normal")

        prefs.launchCount += 1
        prefs.launchCount += 1
        prefs.lastCase = "blank"
        XCTAssertEqual(defaults.integer(forKey: "s1.launchCount"), 2, "要真的写进 UserDefaults")

        let again = S1Prefs(defaults: defaults)
        XCTAssertEqual(again.launchCount, 2, "换个实例还能读到")
        XCTAssertEqual(again.lastCase, "blank")
        XCTAssertEqual(again.$launchCount, "s1.launchCount", "$ 拿到的是 projectedValue")
    }

    func test_s1_16_wrongTypeFallsBackToDefault() async {
        let defaults = makeDefaults()
        defaults.set("not a number", forKey: "s1.launchCount")
        XCTAssertEqual(S1Prefs(defaults: defaults).launchCount, 0)
    }
}
