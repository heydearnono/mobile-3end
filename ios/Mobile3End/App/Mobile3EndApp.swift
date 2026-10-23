import SwiftUI
import UIKit

@main
struct Mobile3EndApp: App {
    // App 级生命周期：SwiftUI 没有 AppDelegate，要 UIKit 的回调就用这个适配器接进来
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    // App 里读到的 scenePhase 是所有窗口合起来的状态
    @Environment(\.scenePhase) private var scenePhase
    // App 结构体整个进程只初始化一次，适合放全局对象
    @State private var services = AppServices.make()

    init() {
        M3ELog.d("App.init stage=\(LaunchOptions.stage)")
    }

    var body: some Scene {
        WindowGroup {
            if LaunchOptions.isUnitTestHost {
                Text("单测宿主：不渲染真实页面")
            } else {
                RootView(services: services)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            services.lifecycle?.scenePhaseChanged(newPhase)
        }
    }
}

/// 所有阶段相关的接线都在这里，按 STAGE 决定创建什么
final class AppServices {
    let stage: Int
    let model: FileListModel?
    let lifecycle: LifecycleTracker?

    private init(stage: Int, model: FileListModel?, lifecycle: LifecycleTracker?) {
        self.stage = stage
        self.model = model
        self.lifecycle = lifecycle
    }

    static func make() -> AppServices {
        guard !LaunchOptions.isUnitTestHost else { return AppServices(stage: 0, model: nil, lifecycle: nil) }
        // 调试直达 H5 页：不依赖 STAGE，也不创建列表数据和生命周期对象（M2 / M3 的空）
        if let h5Case = LaunchOptions.h5Case {
            M3ELog.d("直达 H5 页 case=\(h5Case.rawValue)，跳过 STAGE 接线")
            return AppServices(stage: 0, model: nil, lifecycle: nil)
        }
        let stage = LaunchOptions.stage

        if LaunchOptions.reset {
            FileCache.standard.clear()
            UserDefaults.standard.removeObject(forKey: SortStore.key)
        }

        if stage >= 5 {
            CrashReporter.reportPrevious()
            CrashReporter.install()
        }

        var model: FileListModel?
        if stage >= 2 {
            let remote: any FileRemote = LaunchOptions.fake.map { DebugRemote(mode: $0) }
                ?? URLSessionFileRemote(url: AppConfig.filesURL)
            model = FileListModel(remote: remote, cache: .standard, sortStore: SortStore(defaults: .standard))
        }

        var lifecycle: LifecycleTracker?
        if stage >= 3, let model {
            lifecycle = LifecycleTracker(onRefresh: { Task { await model.refresh() } })
        }
        return AppServices(stage: stage, model: model, lifecycle: lifecycle)
    }
}

enum AppConfig {
    /// iOS 模拟器和 Mac 共用网络，localhost 就是 Mac。真机要换成 Mac 的局域网 IP
    static let filesURL = URL(string: "http://localhost:8000/api/files.json")!
}

/// UIKit 的 App 级回调，M3 用来和 scenePhase 对比触发顺序
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        M3ELog.d("AppDelegate.didFinishLaunching")
        let center = NotificationCenter.default
        let names: [(Notification.Name, String)] = [
            (UIApplication.willEnterForegroundNotification, "willEnterForeground"),
            (UIApplication.didBecomeActiveNotification, "didBecomeActive"),
            (UIApplication.willResignActiveNotification, "willResignActive"),
            (UIApplication.didEnterBackgroundNotification, "didEnterBackground"),
            (UIApplication.willTerminateNotification, "willTerminate"),
            (UIApplication.didReceiveMemoryWarningNotification, "didReceiveMemoryWarning"),
            (UIDevice.orientationDidChangeNotification, "orientationDidChange"),
        ]
        for (name, label) in names {
            center.addObserver(forName: name, object: nil, queue: .main) { _ in
                M3ELog.d("UIApplication.\(label)")
            }
        }
        return true
    }
}
