import Foundation

// S1 第 2 节：闭包、尾随闭包、@escaping
//
// 闭包 ≈ Kotlin 的 lambda ≈ TS 的箭头函数：
//   Swift                                  Kotlin                         TS
//   { (a: Int) -> Int in a + 1 }           { a: Int -> a + 1 }            (a: number) => a + 1
//   { a in a + 1 }（类型能推断时）         { a -> a + 1 }                 a => a + 1
//   { $0 + 1 }                             { it + 1 }                     —
//   { $0.size > $1.size }（两个参数）      { a, b -> a.size > b.size }    (a, b) => a.size > b.size
//   (FileItem) -> Void（函数类型）         (FileItem) -> Unit             (f: FileItem) => void
//   files.map(\.name)（key path）          files.map { it.name }          files.map(f => f.name)
//
// - 参数用 in 和函数体隔开；没起名字就按位置叫 $0、$1
// - 单表达式闭包自动 return 那个表达式；多行闭包要自己写 return（这点和 Kotlin「最后一行就是返回值」不同）
// - 尾随闭包和 Kotlin 一样：最后一个参数是闭包可以写在括号外，只有这一个参数时括号也省掉：
//     files.sorted { a, b in ... }         Button("重试") { ... }        Task { ... }
//   SwiftUI 里的 VStack { }、.toolbar { }、.task { } 全是这个写法，看着像关键字，其实都是函数调用
//
// @escaping（Kotlin / TS 都没有，最容易卡）：
// - 闭包参数默认是「非逃逸」的：只能在函数返回之前调用，函数一返回闭包就作废，编译器借此省掉内存管理开销
// - 如果要把闭包存起来以后再调（存进属性、数组，丢给 Task、异步回调），参数类型前必须标 @escaping，
//   否则编译报错 Converting non-escaping parameter ... may allow it to escape
// - 工程里：LifecycleTracker.init(onRefresh: @escaping ...) 把回调存进属性；
//   H5Controller 的 decisionHandler: @escaping 是 WebKit 先存着、等你决定之后再调
// - 逃逸闭包会持有（强引用）它用到的对象。闭包被对象自己存着、闭包里又用了 self，就是循环引用，
//   所以会看到 Task { [weak self] in ... }（H5PageState.showToast）。[weak self] 叫捕获列表

// 空 S1-3：返回所有图片的名字，按大小从大到小
// 要求：链式调用 + 尾随闭包，不写 for 循环
// 提示 1：filter { } → sorted { } → map(\.name)；sorted 的闭包回答「$0 是否该排在 $1 前面」
func imageNamesBySizeDesc(_ files: [FileItem]) -> [String] {
    TODO("S1-3")
}

/// 最小的事件中心 ≈ 前端的 mitt / EventEmitter。
/// M3 的 LifecycleTracker（onRefresh）、M4 的 BridgeDispatcher（showToast）都是「先存闭包，以后再调」
final class EventHub {
    private var handlers: [String: [(String) -> Void]] = [:]

    // 空 S1-4：注册 handler，之后 emit(event, ...) 时按注册顺序调用；同一个事件可以注册多个
    // 提示 1：把 handler 加进 handlers[event] 的数组。写完看编译器报什么错，按它说的改签名
    func on(_ event: String, _ handler: (String) -> Void) {
        TODO("S1-4")
    }

    func emit(_ event: String, _ data: String) {
        handlers[event, default: []].forEach { $0(data) }
    }
}
