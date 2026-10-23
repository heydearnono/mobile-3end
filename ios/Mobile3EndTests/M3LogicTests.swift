import SwiftUI
import XCTest
@testable import Mobile3End

/// M3 纯逻辑检查：回前台刷新、加载去重、主线程、appState 映射
@MainActor
final class M3LogicTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1_000_000)

    // MARK: M3-1

    func test_m3_1_neverBackgrounded_noRefresh() async {
        XCTAssertFalse(RefreshPolicy.shouldRefresh(backgroundAt: nil, now: t0))
    }

    func test_m3_1_thresholdIs30sInclusive() async {
        XCTAssertFalse(RefreshPolicy.shouldRefresh(backgroundAt: t0, now: t0.addingTimeInterval(29.9)))
        XCTAssertTrue(RefreshPolicy.shouldRefresh(backgroundAt: t0, now: t0.addingTimeInterval(30)))
        XCTAssertTrue(RefreshPolicy.shouldRefresh(backgroundAt: t0, now: t0.addingTimeInterval(600)))
    }

    // MARK: M3-2

    private final class Clock {
        var now: Date
        init(_ now: Date) { self.now = now }
    }

    private func makeTracker() -> (LifecycleTracker, Clock, LogSink, () -> Int) {
        let clock = Clock(t0)
        let sink = LogSink()
        var refreshes = 0
        let tracker = LifecycleTracker(now: { clock.now }, log: sink.log, onRefresh: { refreshes += 1 })
        return (tracker, clock, sink, { refreshes })
    }

    func test_m3_2_backFromBackgroundAfter31s_refreshesOnce() async {
        let (tracker, clock, _, refreshes) = makeTracker()
        tracker.scenePhaseChanged(.active)
        tracker.scenePhaseChanged(.inactive)
        tracker.scenePhaseChanged(.background)
        clock.now = t0.addingTimeInterval(31)
        tracker.scenePhaseChanged(.inactive)
        tracker.scenePhaseChanged(.active)
        XCTAssertEqual(refreshes(), 1)

        // 紧接着再切一次 inactive / active（比如下拉通知中心），不应再刷新
        tracker.scenePhaseChanged(.inactive)
        tracker.scenePhaseChanged(.active)
        XCTAssertEqual(refreshes(), 1)
    }

    func test_m3_2_shortBackground_noRefresh() async {
        let (tracker, clock, _, refreshes) = makeTracker()
        tracker.scenePhaseChanged(.active)
        tracker.scenePhaseChanged(.background)
        clock.now = t0.addingTimeInterval(10)
        tracker.scenePhaseChanged(.active)
        XCTAssertEqual(refreshes(), 0)
    }

    func test_m3_2_longInactiveOnly_noRefresh() async {
        // 停在 inactive（控制中心、来电界面）很久，不算进过后台
        let (tracker, clock, _, refreshes) = makeTracker()
        tracker.scenePhaseChanged(.active)
        tracker.scenePhaseChanged(.inactive)
        clock.now = t0.addingTimeInterval(120)
        tracker.scenePhaseChanged(.active)
        XCTAssertEqual(refreshes(), 0)
    }

    func test_m3_2_logsEveryTransition() async {
        let (tracker, _, sink, _) = makeTracker()
        tracker.scenePhaseChanged(.active)
        tracker.scenePhaseChanged(.background)
        XCTAssertEqual(sink.lines.count(where: { $0.contains("scenePhase") }), 2, "每次变化打一行 scenePhase 日志，实际：\(sink.lines)")
        XCTAssertTrue(sink.contains("active → background"), "日志里要能看出从哪变到哪，实际：\(sink.lines)")
        XCTAssertEqual(tracker.phase, .background)
    }

    // MARK: M3-3

    private func makeModel(_ remote: any FileRemote) -> FileListModel {
        FileListModel(remote: remote, cache: FileCache(fileURL: makeTempDir().appending(path: "c.json"), log: { _ in }),
                      sortStore: SortStore(defaults: makeDefaults()), log: { _ in })
    }

    func test_m3_3_loadIfNeeded_onlyFirstCallFetches() async {
        let remote = FakeRemote(.success([item("a", "a")]))
        let model = makeModel(remote)
        await model.loadIfNeeded()
        await model.loadIfNeeded()
        XCTAssertEqual(remote.calls, 1)
        XCTAssertEqual(model.state, .loaded([item("a", "a")]))
    }

    func test_m3_3_concurrentCalls_fetchOnce() async {
        let remote = GatedRemote()
        let model = makeModel(remote)
        async let first: Void = model.loadIfNeeded()
        async let second: Void = model.loadIfNeeded()
        await remote.waitUntilWaiting()
        try? await Task.sleep(for: .milliseconds(50))
        remote.finish(.success([]))
        _ = await (first, second)
        XCTAssertEqual(remote.calls, 1, "两次同时调用应只发一次请求")
    }

    func test_m3_3_refreshStillFetches() async {
        let remote = FakeRemote(.success([]))
        let model = makeModel(remote)
        await model.loadIfNeeded()
        await model.refresh()
        XCTAssertEqual(remote.calls, 2, "loadIfNeeded 的去重不能挡住主动刷新")
    }

    // MARK: M3-4

    func test_m3_4_runOffMain_runsInBackground_mainStaysResponsive() async {
        let start = ContinuousClock.now
        async let thread = MainThreadDemo.runOffMain()
        // 这个测试本身跑在主线程上。主线程没被卡住的话，200ms 后就能醒过来
        try? await Task.sleep(for: .milliseconds(200))
        let waited = ContinuousClock.now - start
        XCTAssertLessThan(waited, .seconds(1), "主线程被卡了 \(waited)")
        let result = await thread
        XCTAssertEqual(result, "background")
    }

    // MARK: M3-5

    func test_m3_5_appStateName() async {
        XCTAssertEqual(appStateName(for: .active), "foreground")
        XCTAssertEqual(appStateName(for: .background), "background")
        XCTAssertNil(appStateName(for: .inactive), "inactive 是过渡态，不推给 H5")
    }
}
