import SwiftUI

/// 路由：NavigationStack 的 path 是一个 [Route] 数组，push = append，pop = removeLast。
/// 相当于把 vue-router 的 history 栈直接摊开成一个状态
enum Route: Hashable {
    case detail(id: String)
    case h5(H5Case)
}

struct RootView: View {
    let services: AppServices

    @State private var path: [Route] = LaunchOptions.h5Case.map { [.h5($0)] } ?? []
    /// M1 阶段的排序状态。M2 起改由 FileListModel 持有并持久化
    @State private var m1Order: SortOrder = .name

    var body: some View {
        if services.stage == 0 {
            M0View()
        } else {
            NavigationStack(path: $path) {
                list
                    .toolbar { stageToolbar }
                    .navigationDestination(for: Route.self) { route in
                        switch route {
                        case .detail(let id):
                            FileDetailScreen(file: lookup(id))
                        case .h5(let testCase):
                            H5Screen(initialCase: testCase)
                        }
                    }
            }
        }
    }

    @ViewBuilder
    private var list: some View {
        if let model = services.model {
            ModelListScreen(model: model, stage: services.stage, onOpen: open)
        } else {
            FileListScreen(state: .loaded(SampleData.files), order: $m1Order, onOpen: open)
        }
    }

    /// 后面里程碑才出现的入口
    @ToolbarContentBuilder
    private var stageToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            if services.stage >= 3 {
                Menu("主线程") {
                    Button("主线程 sleep 2s") { MainThreadDemo.tapRunOnMain() }
                    Button("主线程同步网络请求") { MainThreadDemo.tapSyncNetworkOnMain() }
                    Button("后台执行（M3-4）") { MainThreadDemo.tapRunOffMain() }
                }
                .accessibilityIdentifier("main-thread-menu")
            }
            if services.stage >= 5 {
                Menu("崩溃") {
                    Button("抛 NSException") { CrashDemo.raiseObjCException() }
                    Button("Swift 数组越界") { CrashDemo.swiftOutOfRange() }
                    Button("H5 抛错（case=blank）") { path.append(.h5(.blank)) }
                }
                .accessibilityIdentifier("crash-menu")
            }
            if services.stage >= 4 {
                Button("H5") { path.append(.h5(.normal)) }
                    .accessibilityIdentifier("open-h5")
            }
        }
    }

    private var currentFiles: [FileItem] {
        services.model?.state.files ?? SampleData.files
    }

    // 空 M1-4：点一行，跳到这个文件的详情页
    // 提示 1：path 是 @State 数组，往里放一个 Route
    private func open(_ file: FileItem) {
        TODO("M1-4")
    }

    // 空 M1-5：详情页只拿到 id，按 id 找到文件；找不到返回 nil
    // 提示 1：在 currentFiles 里找
    private func lookup(_ id: String) -> FileItem? {
        TODO("M1-5")
    }
}

/// M2 起的列表页：状态来自 FileListModel
private struct ModelListScreen: View {
    /// @Bindable：从 @Observable 对象上取 $model.order 这样的 Binding
    @Bindable var model: FileListModel
    let stage: Int
    let onOpen: (FileItem) -> Void

    var body: some View {
        FileListScreen(
            state: model.state,
            order: $model.order,
            onOpen: onOpen,
            onRetry: { Task { await model.load() } }
        )
        // .task：视图出现时启动，消失时自动取消。类比 onMounted 里发请求 + onUnmounted 里 abort
        .task {
            if stage >= 3 {
                await model.loadIfNeeded()
            } else {
                await model.load()
            }
        }
    }
}

/// M0：只验证工程能跑、日志能过滤、断点能停
struct M0View: View {
    @State private var taps = 0

    var body: some View {
        VStack(spacing: 16) {
            Text("M0：工程跑起来了")
                .font(.title2)
                .accessibilityIdentifier("m0-title")
            Button("打一行日志（已点 \(taps) 次）") {
                taps += 1
                // M0：在这一行打断点，单步跑过去
                M3ELog.d("M0 button tapped taps=\(taps)")
            }
            .buttonStyle(.borderedProminent)
        }
        .onAppear {
            M3ELog.d("M0View.onAppear iOS \(UIDevice.current.systemVersion)")
        }
    }
}
