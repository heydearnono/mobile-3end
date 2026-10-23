import Foundation
import os

// 全工程统一的日志 tag。Xcode 控制台底部的过滤框输入 `M3E`；
// 命令行：xcrun simctl spawn booted log stream --predicate 'category == "M3E"'
nonisolated let TAG = "M3E"

nonisolated enum M3ELog {
    private static let logger = Logger(subsystem: "com.example.mobile3end", category: TAG)

    /// 对应 Android 的 Log.d(TAG, ...)。
    /// `privacy: .public` 不能省：os.Logger 默认把动态字符串当隐私数据，脱离 Xcode 后在 Console.app 里只显示 <private>
    static func d(_ message: String) {
        logger.log("\(message, privacy: .public)")
    }
}

/// 填空占位，等价于 Kotlin 的 TODO()：能编译，跑到这一行才崩，
/// 控制台出现 `Fatal error: An operation is not implemented: M1-3`
nonisolated func TODO(_ id: String) -> Never {
    TodoTrace.record(id)
    fatalError("An operation is not implemented: \(id)")
}

/// 只给 check.sh 用：UI 测试里 App 是另一个进程，崩溃信息传不回测试报告，
/// 所以崩之前把「哪个测试 → 哪个空」追加写到 check.sh 指定的文件里。平时运行时什么都不做
nonisolated enum TodoTrace {
    static func record(_ id: String) {
        let env = ProcessInfo.processInfo.environment
        guard let path = env["M3E_TODO_LOG"], let test = env["M3E_TEST"],
              let line = "\(test)\t\(id)\n".data(using: .utf8) else { return }
        if let handle = FileHandle(forWritingAtPath: path) {
            handle.seekToEndOfFile()
            handle.write(line)
            try? handle.close()
        } else {
            FileManager.default.createFile(atPath: path, contents: line)
        }
    }
}
