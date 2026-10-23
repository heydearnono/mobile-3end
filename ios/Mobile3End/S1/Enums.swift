import Foundation

// S1 第 4 节：带关联值的 enum + 模式匹配
//
// 三种「几选一」写法对照：
//   TS（可辨识联合）
//     type ListState = { kind: 'loading' } | { kind: 'failed'; message: string } | { kind: 'loaded'; files: FileItem[] }
//   Kotlin（sealed）
//     sealed interface ListUiState { data object Loading; data class Failed(val message: String); ... }
//   Swift（enum 的 case 可以带「关联值」）
//     enum ListState { case loading; case failed(String); case loaded([FileItem]) }   ← UI/FileListScreen.swift
//
// 取关联值靠模式匹配：
//   switch state {
//   case .loading: ...
//   case .failed(let message): ...                         ≈ Kotlin 的 is Failed -> state.message
//   case .loaded(let files) where files.isEmpty: ...       where 加额外条件，从上往下第一个匹配的生效
//   case .loaded(let files): ...
//   }
//   if case .loaded(let files) = state { ... }             只关心一种 case 时用，≈ Kotlin 的 if (state is Loaded)
//   guard case .failed(let message) = state else { return nil }
//
// - switch 必须穷尽所有 case，不写 default 时加了新 case 编译器会报错（和 Kotlin sealed + when 一样）。
//   系统的枚举（ScenePhase）以后可能加 case，所以要 @unknown default（M3-5）
// - case 之间不会贯穿（不用写 break），一个 case 可以匹配多个值：case .blank, .missing, .slow:
// - Swift 5.9 起 switch / if 可以直接当表达式：let label = switch order { case .name: "名称" case .time: "时间" }
// - 原始值枚举（enum FileType: String）是另一种：每个 case 对应一个固定的 String / Int，
//   FileType(rawValue: "doc") 返回可选值（字符串可能认不出来）。M2-1、M2-6 都用到
// - 别的语言里需要 if / else 一串判断的地方，Swift 常常在 switch 里一次匹配完，可以匹配元组：
//   switch (old, new) { case (.background, .active): ... }

// 空 S1-8：给列表状态生成一行描述，打日志用
// loading → "loading"；failed(msg) → "failed: msg"；loaded 空数组 → "empty"；loaded 有 n 条 → "loaded n"
// 提示 1：switch 四个 case，其中两个都是 .loaded，用 where 区分；注意顺序
func stateSummary(_ state: ListState) -> String {
    TODO("S1-8")
}

/// H5 调的 bridge 方法。字符串协议进来之后先变成 enum，后面的代码就不用再和字符串打交道，switch 漏了编译器会提醒
enum BridgeCall: Equatable {
    case getDeviceInfo
    case toast(text: String)
    case unknown(method: String)

    // 空 S1-9：从 method 名 + params 构造：
    // "getDeviceInfo" → .getDeviceInfo；"toast" → .toast(text: params["text"])，text 缺了或不是字符串就当 ""；
    // 其他 → .unknown(method: 原名)
    // 提示 1：enum 的 init 里给 self 赋值：self = .getDeviceInfo。switch 可以直接匹配字符串
    init(method: String, params: [String: Any]) {
        TODO("S1-9")
    }
}
