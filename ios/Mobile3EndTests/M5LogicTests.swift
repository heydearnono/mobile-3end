import Darwin
import XCTest
@testable import Mobile3End

/// M5 检查：两个异常钩子有没有装上、装上后能不能把现场记下来
@MainActor
final class M5LogicTests: XCTestCase {

    func test_m5_1_exceptionHandlerInstalledAndRecords() async throws {
        let previous = NSGetUncaughtExceptionHandler()
        defer { NSSetUncaughtExceptionHandler(previous) }
        NSSetUncaughtExceptionHandler(nil)
        try? FileManager.default.removeItem(at: CrashReporter.reportURL)

        CrashReporter.installExceptionHandler()
        let handler = try XCTUnwrap(NSGetUncaughtExceptionHandler(), "没有注册上 NSException 钩子")

        // 直接调钩子（真抛异常的话测试进程就没了）
        handler(NSException(name: NSExceptionName("M3ETestException"), reason: "from test", userInfo: nil))

        let report = try String(contentsOf: CrashReporter.reportURL, encoding: .utf8)
        XCTAssertTrue(report.contains("M3ETestException"), report)
        XCTAssertTrue(report.contains("from test"), report)
        try? FileManager.default.removeItem(at: CrashReporter.reportURL)
    }

    func test_m5_2_signalHandlersInstalled() async {
        defer { CrashReporter.signals.forEach { signal($0, SIG_DFL) } }
        CrashReporter.signals.forEach { signal($0, SIG_DFL) }

        CrashReporter.installSignalHandlers()

        for sig in CrashReporter.signals {
            var current = sigaction()
            sigaction(sig, nil, &current)
            let handler = current.__sigaction_u.__sa_handler
            let raw = handler.map { unsafeBitCast($0, to: Int.self) } ?? 0
            XCTAssertNotEqual(raw, 0, "信号 \(sig)（\(String(cString: strsignal(sig)))）还是系统默认处理")
            XCTAssertNotEqual(raw, 1, "信号 \(sig) 被设成了忽略（SIG_IGN），崩溃会被吞掉")
        }
    }
}
