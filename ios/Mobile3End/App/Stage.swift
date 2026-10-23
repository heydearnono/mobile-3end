import Foundation

/// 当前做到第几个里程碑，决定 App 怎么接线。开始新的里程碑时把它改成对应数字（每份 hints 开头有提醒）
/// - 0：M0 空白页
/// - 1：M1 写死的 20 条数据
/// - 2：M2 网络 + 缓存 + 排序持久化
/// - 3：M3 生命周期日志、回前台刷新、主线程实验
/// - 4：M4 列表页出现 H5 入口
/// - 5：M5 安装异常钩子、出现崩溃测试菜单
let STAGE = 0

/// 启动参数。UI 测试靠它把 App 固定在某个阶段、换成假数据，保证测 M<n> 时只走 M<n> 的代码。
/// 也可以在 Xcode 的 Product → Scheme → Edit Scheme → Arguments 里手动加，如 `-M3EStage 2 -M3EFake fail`
/// （`-键 值` 形式的启动参数会自动进 UserDefaults，所以这里用 UserDefaults 读）
enum LaunchOptions {
    private static let defaults = UserDefaults.standard

    static var stage: Int {
        defaults.string(forKey: "M3EStage").flatMap(Int.init) ?? STAGE
    }

    /// 假数据源：ok / empty / fail / slow，见 DebugRemote
    static var fake: DebugRemote.Mode? {
        defaults.string(forKey: "M3EFake").flatMap(DebugRemote.Mode.init(rawValue:))
    }

    /// 启动时清掉缓存和排序设置
    static var reset: Bool { defaults.bool(forKey: "M3EReset") }

    /// 启动后直接进 H5 页，值是 H5Case 的 rawValue
    static var h5Case: H5Case? {
        defaults.string(forKey: "M3EH5Case").flatMap(H5Case.init(rawValue:))
    }

    /// 单测宿主：单测跑在 App 进程里，这时不渲染真实页面，免得 App 启动就撞上没填的空
    static var isUnitTestHost: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}
