import Foundation

// S1 第 1 节：可选类型（Optional）
//
// 和 Kotlin 一样，类型后面带 ? 才能是 nil：String 一定有值，String? 可能是 nil。对照表：
//   Swift                      Kotlin                    TS
//   a?.b                       a?.b                      a?.b
//   a ?? b                     a ?: b                    a ?? b
//   a!                         a!!                       a!（TS 只骗编译器，Swift / Kotlin 运行时真会崩）
//   a as? T                    a as? T                   —
//   if let a { use(a) }        if (a != null) use(a)     if (a != null) use(a)
//   if let x = f() { }         f()?.let { x -> }         —
//   guard let x = a else { return }   val x = a ?: return   if (a == null) return
//   a.map { $0 + 1 }           a?.let { it + 1 }         —
//
// 和 Kotlin 不同的地方：
// - T? 不是「T 或 null」，是一个真正的枚举 Optional<T>，只有 .none 和 .some(值) 两个 case。
//   所以 Optional 自己也有方法：a.map { } / a.flatMap { }，⌘ 点 Optional 能看到定义
// - Kotlin 判断 a != null 之后 a 自动变成非空（smart cast），Swift 没有这个：要用 if let / guard let
//   把值「解包」到一个新的常量里（同名也行：if let file { } 就是 if let file = file { } 的简写）
// - guard let 解包出来的常量在 guard 之后一直可用，else 里必须离开当前作用域（return / throw / continue）。
//   多个条件用逗号连起来，一个不满足就进 else。工程里到处是这种写法，比如 H5ErrorCapture.log
// - a! 解包 nil 是运行时错误，进程直接被杀（SIGTRAP），M5 的信号钩子能抓到它
//
// 工程里真实出现的样子：
//   LaunchOptions.stage：defaults.string(forKey:).flatMap(Int.init) ?? STAGE
//   FileDetailScreen：if let file { ... } else { Text("文件不存在") }
//   DeviceInfo.current()：Bundle.main.object(...) as? String ?? "?"

// 示例（不用改）：Int("abc") 是 nil，Int(String) 本身就返回 Int?
func parsePort(_ raw: String?) -> Int {
    guard let raw, let port = Int(raw) else { return 80 }
    return port
}

// 空 S1-1：第一个图片的大小；列表是 nil、或者里面没有图片，都返回 0（就是 K1-5，换成 Swift 写一遍）
// 要求：一个表达式，不用 if
// 提示 1：files?.first { ... }?.size ?? 0，一路 ?. 下去
func firstImageSize(_ files: [FileItem]?) -> Int64 {
    TODO("S1-1")
}

// 空 S1-2：H5 发来的消息解析成字典之后是 [String: Any]（M4-5 会遇到）。取出 params.text，
// 要求是非空字符串，否则返回 nil。例：["method": "toast", "params": ["text": "hi"]] → "hi"
// 要求：用 guard let
// 提示 1：字典取值得到的是 Any?，要 as? 成具体类型才能接着用；guard 后面的多个条件用逗号隔开
func toastText(_ message: [String: Any]) -> String? {
    TODO("S1-2")
}
