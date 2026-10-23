import Foundation

// S1 第 8 节：property wrapper（@State、@Binding 背后的机制）
//
// @State var order: SortOrder = .name 不是魔法，编译器把它展开成三样东西：
//   private var _order = State(wrappedValue: .name)          // 真正的存储：一个 State 结构体
//   var order: SortOrder {                                   // 你用的名字：读写都转给 _order.wrappedValue
//       get { _order.wrappedValue }
//       nonmutating set { _order.wrappedValue = newValue }
//   }
//   var $order: Binding<SortOrder> { _order.projectedValue } // 加 $ 拿到 projectedValue，State 给的是 Binding
//
// 对照 Kotlin：var order by orderState —— 读写转给委托对象的 getValue / setValue，是同一个思路。
// TS 里最接近的是 Vue 的 ref：.value 是 wrappedValue，只是 Swift 帮你把 .value 省掉了
//
// 自己写一个：类型前面标 @propertyWrapper，里面必须有 var wrappedValue，可选 var projectedValue（给 $ 用）。
// 用的时候 @Stored(key: "k", defaultValue: 0) var count: Int，括号里的参数传给 Stored 的 init
//
// 为什么 View 是 struct、每次刷新都重建，@State 还能存住：State 的 wrappedValue 不存在结构体里，
// 存在 SwiftUI 按视图身份保管的一块外部存储上，结构体里只有一个「指向那块存储」的句柄
//
// 语言 vs 库：
//   语言：@propertyWrapper 机制本身、$ 前缀、_ 前缀的存储属性
//   SwiftUI（库）：@State、@Binding、@Environment、@Bindable、@AppStorage、@UIApplicationDelegateAdaptor 都是 property wrapper
//   不是 property wrapper：@Observable 是宏（macro，右键 → Expand Macro 能看到展开结果）；
//   @MainActor 是全局 actor 标注；@escaping、@Sendable 是类型标注；@main、@objc 是编译器属性

/// 读写直接转给 UserDefaults ≈ SwiftUI 的 @AppStorage 去掉「刷新界面」那一半。M2-6 的 SortStore 是手写版
@propertyWrapper
struct Stored<Value> {
    let key: String
    let defaultValue: Value
    var defaults: UserDefaults = .standard

    // 空 S1-16：读：UserDefaults 里有这个 key、而且类型对得上就返回它，否则返回 defaultValue；写：存进 UserDefaults
    // 提示 1：defaults.object(forKey:) 返回 Any?，as? Value 转一下，?? 兜底；写用 defaults.set(_:forKey:)
    var wrappedValue: Value {
        get {
            TODO("S1-16")
        }
        set {
            TODO("S1-16")
        }
    }

    /// $xxx 拿到的东西。这里给 key，调试用；SwiftUI 的 @State 给的是 Binding
    var projectedValue: String { key }
}

/// 用法示例。平时写 @Stored(key: "s1.launchCount", defaultValue: 0) var launchCount: Int 就行；
/// 这里测试要换成独立的 UserDefaults，所以声明时不给参数，在 init 里直接给 _launchCount 赋值 ——
/// 这个 _ 开头的属性就是编译器生成的存储，和上面讲的展开一一对应
final class S1Prefs {
    @Stored var launchCount: Int
    @Stored var lastCase: String

    init(defaults: UserDefaults = .standard) {
        _launchCount = Stored(key: "s1.launchCount", defaultValue: 0, defaults: defaults)
        _lastCase = Stored(key: "s1.lastCase", defaultValue: "normal", defaults: defaults)
    }
}
