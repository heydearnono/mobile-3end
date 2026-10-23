import Foundation

/// M3 主线程实验。入口在列表页右上角「主线程」菜单（STAGE ≥ 3）
enum MainThreadDemo {
    /// 一段耗时 2s 的同步工作（老 SDK 的同步接口、大 JSON 解析、同步读大文件……）。
    /// 返回它实际跑在哪个线程上
    nonisolated static func blockingWork() -> String {
        Thread.sleep(forTimeInterval: 2)
        return Thread.isMainThread ? "main" : "background"
    }

    // 空 M3-4：让 blockingWork() 在后台线程执行，等它做完把结果返回。调用期间主线程不能被卡住
    // 提示 1：这个函数默认跑在主线程（工程设置了默认 MainActor）。想想怎么开一个「不继承当前 actor」的任务
    static func runOffMain() async -> String {
        TODO("M3-4")
    }

    // ---- 菜单按钮，不用改 ----

    /// 反面教材：直接在主线程跑。点完 2s 内列表滑不动、按钮没反应
    static func tapRunOnMain() {
        let start = Date()
        let thread = blockingWork()
        M3ELog.d("runOnMain 用时 \(String(format: "%.1f", Date().timeIntervalSince(start)))s thread=\(thread)")
    }

    /// 反面教材 2：主线程同步网络请求。Xcode 会报紫色的运行时警告
    static func tapSyncNetworkOnMain() {
        let start = Date()
        let data = try? Data(contentsOf: AppConfig.filesURL)
        M3ELog.d("syncNetworkOnMain 用时 \(String(format: "%.1f", Date().timeIntervalSince(start)))s bytes=\(data?.count ?? -1)")
    }

    static func tapRunOffMain() {
        let start = Date()
        Task {
            let thread = await runOffMain()
            M3ELog.d("runOffMain 用时 \(String(format: "%.1f", Date().timeIntervalSince(start)))s thread=\(thread)")
        }
    }
}
