import Foundation

// S1 第 3 节：值类型 vs 引用类型（和 Kotlin / TS 差别最大的一节）
//
// TS 里对象、数组都是引用：const b = a; b.x = 1 之后 a.x 也是 1。Kotlin 的 class / data class / List 也一样。
// Swift 分两种：
//   struct / enum / 元组        值类型：赋值、传参、存进数组时整个复制一份，改副本不影响原来的
//   class / actor / 闭包         引用类型：和 TS / Kotlin 的对象一样，复制的只是引用
// 标准库的 Array、Dictionary、Set、String 全是 struct。所以 Swift 的数组和 JS 的数组行为不一样：
//   var a = [1, 2]; var b = a; b.append(3)   // a 还是 [1, 2]
// 复制看着很贵，实际是 copy-on-write：赋值时只是共享同一块存储，等到有一边真的要改，才复制
//
// let / var 的区别也跟着变了：
//   let s = SomeStruct()   s 整个不可变，连 s.varProperty = 1 都不行（编译错误）
//   let c = SomeClass()    c 不能指向别的对象，但 c.varProperty = 1 可以（和 TS 的 const 一样）
//   函数参数一律是 let：在函数里改不了传进来的 struct；要改得声明成 inout，调用时写 &x
//
// struct 的方法默认不能改自己的属性，要改得标 mutating（≈「这个方法会把 self 换成新值」）。
// mutating 方法只能在 var 上调用。enum 也可以有 mutating 方法，里面直接写 self = .xxx
//
// 什么时候用哪个：工程里数据（FileItem、ListState、Route）都是 struct / enum；
// 要「多处共享同一份、谁改了大家都看到」的（FileListModel、H5Controller、H5PageState）是 class。
// SwiftUI 的 View 是 struct，每次刷新都重新创建，状态存不住，所以要 @State（第 8 节讲它是怎么做到的）

/// 上传任务（S1 自己的类型，字段都是 var，方便演示）
struct UploadTask: Equatable {
    var name: String
    /// 0...1
    var progress: Double = 0
}

// 空 S1-5：进度增加 delta，最多到 1
// 提示 1：一行 progress = min(...)。写完看编译器报什么错，按它说的改
extension UploadTask {
    func advance(by delta: Double) {
        TODO("S1-5")
    }
}

/// 上传队列：class，界面和上传逻辑共享同一个队列
final class UploadQueue {
    private(set) var tasks: [UploadTask] = [] {
        didSet { changes += 1 }
    }
    /// tasks 被改了几次，测试用
    private(set) var changes = 0

    func add(_ name: String) {
        tasks.append(UploadTask(name: name))
    }

    // 空 S1-6：把名为 name 的任务进度推进 delta（用 S1-5 的 advance）；没有这个任务就什么都不做
    // 下面这种 TS / Kotlin 的思路在 Swift 里不生效，先想想为什么：
    //   if var task = tasks.first(where: { $0.name == name }) { task.advance(by: delta) }
    // 提示 1：要改数组里的元素，得通过下标改：tasks[i].advance(...)。先找到下标
    func advance(_ name: String, by delta: Double) {
        TODO("S1-6")
    }
}

/// 带撤销的列表编辑 ≈ 前端用 immer 做撤销
final class UndoableList {
    private(set) var files: [FileItem]
    private var history: [[FileItem]] = []

    init(_ files: [FileItem]) {
        self.files = files
    }

    var canUndo: Bool { !history.isEmpty }

    // 空 S1-7：先把当前的 files 存进 history，再让 change 原地修改 files
    // 调用方这样用：list.apply { $0.removeAll { $0.type == .folder } }
    // 提示 1：数组是值类型，history.append(files) 存下的就是快照；change 的参数是 inout，传的时候要写 &
    func apply(_ change: (inout [FileItem]) -> Void) {
        TODO("S1-7")
    }

    /// 撤销最近一次 apply，没有可撤销的就什么都不做
    func undo() {
        if let last = history.popLast() {
            files = last
        }
    }
}
