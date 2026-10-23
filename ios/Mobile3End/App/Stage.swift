import Foundation

/// 当前做到第几个里程碑，决定 App 怎么接线。开始新的里程碑时把它改成对应数字（每份 hints 开头有提醒）
/// - 0：M0 空白页
/// - 1：M1 写死的 20 条数据
/// - 2：M2 网络 + 缓存 + 排序持久化
/// - 3：M3 生命周期日志、回前台刷新、主线程实验
/// - 4：M4 列表页出现 H5 入口
/// - 5：M5 安装异常钩子、出现崩溃测试菜单
let STAGE = 0

/// M4 的两个开关。没填的空是 fatalError，一进 H5 页就会碰到 bridge 和白屏检测的空，App 直接崩，
/// 所以先关着：只看离线包页面能不能加载（见 hints/ios-M4.md 开头）。
/// - M4_BRIDGE：填完 M4-4、M4-5、M4-6 后改成 true。关着时不注入 NativeBridge（H5 显示 `bridge: none`，
///   getDeviceInfo 显示 NO_BRIDGE 失败），也不推 appState（M4-7）。M5 的 H5 错误采集（M3EError）不受影响
/// - M4_WHITE_SCREEN：填完 M4-8、M4-9、M4-10 后改成 true。关着时加载完成 / 加载失败都不做白屏判定，只打一行日志
/// UI 测试用启动参数 `-M3EBridge YES/NO`、`-M3EWhiteScreen YES/NO` 显式指定，不受这两个常量影响
let M4_BRIDGE = false
let M4_WHITE_SCREEN = false

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

    /// 调试直达：启动后只显示 H5 页，值是 H5Case 的 rawValue（如 `-M3EH5Case normal`）。
    /// 带了它就不看 STAGE：不渲染列表页、不创建 M2 / M3 的数据和生命周期对象，不会碰到 M1–M3 的空
    static var h5Case: H5Case? {
        defaults.string(forKey: "M3EH5Case").flatMap(H5Case.init(rawValue:))
    }

    /// M4 开关，启动参数优先，没传就用上面的常量
    static var m4Bridge: Bool { flag("M3EBridge") ?? M4_BRIDGE }
    static var m4WhiteScreen: Bool { flag("M3EWhiteScreen") ?? M4_WHITE_SCREEN }

    /// 没传返回 nil；`-键 YES` / `-键 NO` 读成 Bool
    private static func flag(_ key: String) -> Bool? {
        defaults.object(forKey: key) == nil ? nil : defaults.bool(forKey: key)
    }

    /// 单测宿主：单测跑在 App 进程里，这时不渲染真实页面，免得 App 启动就撞上没填的空
    static var isUnitTestHost: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}
