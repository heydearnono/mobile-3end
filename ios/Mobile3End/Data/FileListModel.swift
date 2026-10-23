import Foundation
import Observation

/// 列表页的数据和状态。@Observable ≈ Pinia store：属性被 body 读过，改了就自动刷新对应视图
@Observable
final class FileListModel {
    private(set) var state: ListState = .loading

    var order: SortOrder {
        didSet { sortStore.order = order }
    }

    @ObservationIgnored private let remote: any FileRemote
    @ObservationIgnored private let cache: FileCache
    @ObservationIgnored private let sortStore: SortStore
    @ObservationIgnored private let log: (String) -> Void
    @ObservationIgnored private var hasStarted = false

    init(remote: any FileRemote, cache: FileCache, sortStore: SortStore, log: @escaping (String) -> Void = M3ELog.d) {
        self.remote = remote
        self.cache = cache
        self.sortStore = sortStore
        self.log = log
        self.order = sortStore.order
    }

    // 空 M2-7：加载列表
    // - 有缓存：先显示缓存，再后台请求；请求失败继续显示缓存
    // - 没缓存：显示 loading；请求失败显示失败态（文案用 Self.message(for:)）
    // - 请求成功：显示新数据并写缓存（空数组也是成功）
    // 提示 1：state 有三种取值；先想清楚「失败时现在屏幕上有没有数据」
    func load() async {
        TODO("M2-7")
    }

    // 空 M3-3：只在第一次调用时 load()，之后再调直接返回（两次调用同时进来也只请求一次）
    // 提示 1：用 hasStarted 记一下；想想标记应该放在 await 之前还是之后
    func loadIfNeeded() async {
        TODO("M3-3")
    }

    /// 回前台刷新等场景：重新拉一次
    func refresh() async {
        log("refresh")
        await load()
    }

    static func message(for error: any Error) -> String {
        switch error {
        case FileApiError.badStatus(let code): return "服务器返回 \(code)"
        case let e as URLError: return "网络错误（\(e.code.rawValue)）：\(e.localizedDescription)"
        case is DecodingError: return "数据格式不对"
        default: return error.localizedDescription
        }
    }
}
