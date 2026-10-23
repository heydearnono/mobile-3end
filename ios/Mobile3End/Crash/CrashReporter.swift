import Darwin
import Foundation

/// M5：原生侧未捕获异常采集。
/// iOS 上「崩溃」分两类，要两个钩子：
/// - ObjC 的 NSException（UIKit / Foundation 抛的，比如数组越界的 NSArray、KVC 写错 key）→ NSSetUncaughtExceptionHandler
/// - 信号（Swift 运行时错误 fatalError / 数组越界 / 强解包 nil 是 SIGTRAP，野指针是 SIGSEGV / SIGBUS，abort 是 SIGABRT）→ signal / sigaction
/// 崩溃现场写进文件，下次启动时打出来（崩溃那一刻打的日志不一定来得及刷出去）
nonisolated enum CrashReporter {
    static let reportURL = URL.cachesDirectory.appending(path: "crash-last.txt")
    static let signals: [Int32] = [SIGABRT, SIGSEGV, SIGBUS, SIGILL, SIGTRAP, SIGFPE]

    static func install() {
        installExceptionHandler()
        installSignalHandlers()
        M3ELog.d("CrashReporter 已安装")
    }

    // 空 M5-1：注册 ObjC 未捕获异常的钩子，钩子里调 CrashReporter.handle(exception)
    // 提示 1：NSSetUncaughtExceptionHandler 要的是 C 函数指针，闭包里不能捕获任何外部变量
    static func installExceptionHandler() {
        TODO("M5-1")
    }

    // 空 M5-2：给 signals 里的每个信号注册 crashSignalHandler
    // 提示 1：Darwin 的 signal(_:_:)，和 C 里一样
    static func installSignalHandlers() {
        TODO("M5-2")
    }

    static func handle(_ exception: NSException) {
        let text = """
        [CRASH] 未捕获的 NSException \(exception.name.rawValue): \(exception.reason ?? "")
        \(exception.callStackSymbols.joined(separator: "\n"))
        """
        write(text)
    }

    static func write(_ text: String) {
        M3ELog.d(text)
        try? text.write(to: reportURL, atomically: false, encoding: .utf8)
    }

    /// 启动时调用：上次崩溃留下了记录就打出来，然后删掉
    static func reportPrevious() {
        guard let text = try? String(contentsOf: reportURL, encoding: .utf8) else { return }
        M3ELog.d("[CRASH] 上次运行崩溃了，现场记录：\n\(text)")
        try? FileManager.default.removeItem(at: reportURL)
    }
}

/// 信号处理函数。严格说这里只能调 async-signal-safe 的函数（write、_exit 等），
/// 为了能直接看到堆栈，这里破例用了 Foundation；真实的崩溃 SDK（KSCrash、PLCrashReporter）不会这么写
nonisolated private func crashSignalHandler(_ sig: Int32) {
    let name = String(cString: strsignal(sig))
    CrashReporter.write("""
    [CRASH] 信号 \(sig)（\(name)）
    \(Thread.callStackSymbols.joined(separator: "\n"))
    """)
    // 恢复默认处理再抛一次，让系统照常生成崩溃报告、结束进程
    signal(sig, SIG_DFL)
    raise(sig)
}

/// 崩溃测试菜单（STAGE ≥ 5）。连着 Xcode 调试器时，调试器会先接住信号，钩子不执行——要在模拟器 / 手机上直接点图标启动
enum CrashDemo {
    static func raiseObjCException() {
        NSException(name: NSExceptionName("M3EDemoException"), reason: "M5 刻意抛出的 NSException", userInfo: nil).raise()
    }

    static func swiftOutOfRange() {
        let empty: [Int] = []
        let index = Int.random(in: 1...1)
        M3ELog.d("越界读：\(empty[index])")
    }
}
