import Foundation

// S1 第 7 节：async / await、Task、@MainActor
//
//   Swift                                   Kotlin 协程                               TS
//   func f() async -> T                     suspend fun f(): T                        async function f(): Promise<T>
//   let x = await f()                       val x = f()                               const x = await f()
//   async let a = f(); async let b = g()    coroutineScope { val a = async { f() }    const [a, b] = await Promise.all([f(), g()])
//   let (x, y) = await (a, b)                 ... a.await() + b.await() }
//   withTaskGroup { group in ... }          coroutineScope + 循环里 async              Promise.all(list.map(...))
//   Task { ... }                            scope.launch { ... }                       不 await 的 promise
//   Task.detached { ... }                   launch(Dispatchers.Default)               —
//   task.cancel() / Task.isCancelled        job.cancel() / isActive                   AbortController
//   CancellationError                       CancellationException                     AbortError
//   @MainActor                              Dispatchers.Main / withContext(Main)      —（JS 只有一个线程）
//   try await Task.sleep(for: .seconds(1))  delay(1000)                               await new Promise(r => setTimeout(r, 1000))
//
// - 和 TS 一样要写 await，和 Kotlin 一样默认是「顺序」的：let a = await f(); let b = await g() 是一个做完再做下一个。
//   TS 里先调用再 await 就并发了（Promise 创建时就开始跑），Swift 里没有这种隐式并发，要并发必须写 async let 或 TaskGroup
// - async let 起的是「子任务」：所在的函数返回前一定会等它们结束；函数被取消，它们一起被取消（结构化并发，同 Kotlin）
// - Task { } 是「非结构化」任务：立刻开始跑，不等它也行，返回的 Task 对象可以存起来以后 cancel()。
//   它继承当前的 actor：在主线程代码里写 Task { }，里面也在主线程（只是排到后面执行）。M3-4 要的是 Task.detached
// - 取消是「协作式」的：cancel() 只是打个标记。Task.sleep 等系统 API 发现被取消会抛 CancellationError；
//   自己写的循环要自己查 Task.isCancelled。用 try? 吞掉了 sleep 的错误，就必须再查一次 Task.isCancelled
// - @MainActor 标在类型 / 函数上：「只能在主线程跑」，编译器检查。这个工程的 App target 打开了「默认 MainActor」，
//   没标注的代码都算 @MainActor，要在后台跑的得写 nonisolated（MainThreadDemo.blockingWork、CrashReporter）。
//   为什么这么配，见 hints/ios-M3.md「语言模式」
// - @Sendable：闭包会被拿到别的线程执行时要求的标记，意思是「里面捕获的东西可以安全跨线程」。看到它不用慌，
//   编译器要你加你就加，Swift 6 的数据竞争检查就靠这些标记
// - 库 vs 语言：async / await / async let / actor 是语言；Task、TaskGroup、Task.sleep 是标准库（Concurrency 模块）；
//   SwiftUI 的 .task { } 是框架：视图出现时 Task { }，消失时 cancel()（RootView 里的 ModelListScreen）

// 空 S1-14：同时请求两个来源，结果按 first 在前、second 在后拼起来（就是 K1-14）
// 测试会让两个来源各花 0.4 秒，总耗时必须明显小于 0.8 秒
// 提示 1：async let 两个，再一起 await
func loadBoth(
    first: @escaping @Sendable () async -> [FileItem],
    second: @escaping @Sendable () async -> [FileItem]
) async -> [FileItem] {
    TODO("S1-14")
}

/// 防抖 ≈ lodash.debounce。H5PageState.showToast（2s 后消失，期间再弹就重新计时）、
/// M4-9 白屏检测（加载完 1s 后再探测，期间换页就作废）都是这个模式
@MainActor
final class Debouncer {
    private let delay: Duration
    private var task: Task<Void, Never>?

    init(delay: Duration) {
        self.delay = delay
    }

    // 空 S1-15：delay 之后执行 action；delay 期间又调了 call，前一次作废，只执行最后一次
    // 提示 1：把 Task { } 存进 task，下次 call 先 cancel 上一个；Task 里先 sleep 再执行 action，
    //         sleep 被取消时会抛错，想想抛错之后怎么让 action 不执行
    func call(_ action: @escaping () -> Void) {
        TODO("S1-15")
    }

    func cancel() {
        task?.cancel()
        task = nil
    }
}
