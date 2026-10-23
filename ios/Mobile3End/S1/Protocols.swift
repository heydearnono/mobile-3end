import Foundation

// S1 第 5 节：protocol + extension
//
//   Swift                                    Kotlin                                  TS
//   protocol FileRemote { func fetch() }     interface FileRemote { fun fetch() }    interface FileRemote { fetch(): ... }
//   struct X: FileRemote { }                 class X : FileRemote                    class X implements FileRemote
//   extension P { func f() { 默认实现 } }    interface 里写方法体                     —（只能靠基类）
//   extension FileItem { var isMedia }       fun FileItem.isMedia() / val ... get()   改 prototype（不推荐）
//   extension Array where Element == X { }   fun List<X>.f()                          —
//   any FileRemote（存「某个实现」）         FileRemote                               FileRemote
//   some View（「某个具体类型」，编译器知道是谁）  —                                  —
//
// 和 Kotlin 不同的地方：
// - struct / enum 也能遵守 protocol（Kotlin 的 data class 也行，但 Swift 里这是主流用法，class 反而少）
// - extension 不只能加方法，还能让一个已有类型「补签」遵守某个 protocol：extension FileItem: Listable { }。
//   工程里 extension FileType { init(from:) }（M2-1）、extension URLSession { static let m3e } 都是 extension
// - Swift 没有 package / import 同模块文件这回事：同一个 target 里的 extension 写在哪个文件都全局可见。
//   Kotlin 的扩展函数要 import 才能用，这点正好相反
// - protocol 只声明不实现，默认实现写在 extension P { } 里；遵守者自己实现了就用自己的。
//   SwiftUI 的 View 就是一个 protocol：你只实现 body，.padding()、.navigationTitle() 都是 extension View 里的默认实现
// - Equatable / Hashable / Codable 这些 protocol，只要所有字段都满足，声明一下编译器就自动生成实现（≈ data class）。
//   FileItem: Codable, Hashable 就是这样，没写一行代码
// - any P 是「装着某个 P 实现的盒子」，运行时才知道是谁（M2 的 remote: any FileRemote）；
//   some P 是「某个确定的类型，只是不告诉你名字」，编译期就定了（var body: some View）

// 空 S1-10：所有文件的总大小（就是 K1-13，换成 Swift 写一遍）
// 提示 1：Swift 没有 sumOf，用 reduce(初始值) { 累计, 元素 in ... }；这里的 self 就是那个数组
extension Array where Element == FileItem {
    var totalSize: Int64 {
        TODO("S1-10")
    }
}

/// 能在列表里显示成一行的东西
protocol Listable {
    var title: String { get }
    var bytes: Int64 { get }
    /// 副标题。protocol 里声明了、extension 里又给了默认实现：遵守者可以不写，也可以自己写一个覆盖
    var subtitle: String { get }
}

extension Listable {
    // 空 S1-11：subtitle 的默认实现：bytes 为 0 时是 "—"，否则是 formatSize(bytes)
    // 提示 1：默认实现里可以用 protocol 声明过的其他属性（这里是 bytes），因为每个遵守者都一定有
    var subtitle: String {
        TODO("S1-11")
    }
}

/// FileItem 补签 Listable：只给 title / bytes，subtitle 用默认实现
extension FileItem: Listable {
    var title: String { "\(iconOf(type)) \(name)" }
    var bytes: Int64 { size }
}

/// 回收站的汇总行：自己实现了 subtitle，覆盖默认实现
struct TrashSummary: Listable {
    let count: Int
    let bytes: Int64
    var title: String { "🗑️ 回收站" }
    var subtitle: String { "\(count) 项" }
}
