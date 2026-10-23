import Foundation
import SwiftUI

/// 切后台多久再回来要刷新列表
enum RefreshPolicy {
    static let threshold: TimeInterval = 30

    // 空 M3-1：backgroundAt 是进后台的时刻（没进过后台为 nil），判断回前台时要不要刷新：≥ 30s 刷新
    // 提示 1：Date 相减用 timeIntervalSince，单位是秒
    static func shouldRefresh(backgroundAt: Date?, now: Date) -> Bool {
        TODO("M3-1")
    }
}

/// 把 scenePhase 的变化翻译成「打日志 + 回前台判断要不要刷新」
final class LifecycleTracker {
    private let now: () -> Date
    private let log: (String) -> Void
    private let onRefresh: () -> Void
    private var backgroundAt: Date?
    private(set) var phase: ScenePhase?

    init(now: @escaping () -> Date = Date.init,
         log: @escaping (String) -> Void = M3ELog.d,
         onRefresh: @escaping () -> Void) {
        self.now = now
        self.log = log
        self.onRefresh = onRefresh
    }

    // 空 M3-2：
    // 1. 打日志：从哪个 phase 变到哪个 phase（用 Self.describe）
    // 2. 进 .background 时记下时刻；回到 .active 时问 RefreshPolicy，需要就调 onRefresh()，然后清掉记录
    // 3. 更新 phase
    // 提示 1：从后台回来的顺序是 background → inactive → active，下拉控制中心是 active → inactive → active
    func scenePhaseChanged(_ newPhase: ScenePhase) {
        TODO("M3-2")
    }

    static func describe(_ phase: ScenePhase?) -> String {
        switch phase {
        case .active: "active"
        case .inactive: "inactive"
        case .background: "background"
        case nil: "nil"
        @unknown default: "unknown"
        }
    }
}

// 空 M3-5：M4 要给 H5 推 appState 事件，把 scenePhase 翻译成协议里的值：
// active → "foreground"，background → "background"，其他（inactive）返回 nil，表示不推
// 提示 1：switch 三个 case，别忘了 @unknown default
func appStateName(for phase: ScenePhase) -> String? {
    TODO("M3-5")
}
