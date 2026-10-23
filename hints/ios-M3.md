# iOS M3 提示与答案

开始前：把 `Mobile3End/App/Stage.swift` 里的 `STAGE` 改成 `3`。STAGE ≥ 3 时：

- `scenePhase` 的变化交给 `LifecycleTracker`（M3-2），回前台超过 30s 刷新列表（M3-1）
- 列表页的 `.task` 改调 `loadIfNeeded()`（M3-3）
- 列表页右上角出现「主线程」菜单（M3-4）

这几处在 `STAGE = 3` 时一启动就会执行到，所以 **手动运行前先把 M3-1 ~ M3-3 填完**。M3-5 是给 M4 准备的。

建议顺序：M3-1 → M3-2 → M3-3 → M3-4 → M3-5，全部是纯逻辑单测，`./check.sh M3` 约 1 分钟。

---

## 先做：生命周期日志

不用写代码，日志已经埋好了（`M3ELog.d`，Xcode 控制台过滤 `M3E`）：

| 层级 | 位置 | 日志 |
|---|---|---|
| App（SwiftUI） | `Mobile3EndApp.init`、`scenePhase` | `App.init`、`scenePhase a → b` |
| App（UIKit） | `AppDelegate` + 通知 | `AppDelegate.didFinishLaunching`、`UIApplication.willResignActive` …… |
| 页面 | `FileListScreen` / `FileDetailScreen` / `H5Screen` 的 `onAppear` / `onDisappear` | `FileListScreen.onAppear` …… |

🔬 依次做下面的操作，把日志顺序抄进 `notes/ios-M3.md`：

1. 冷启动
2. 进详情页、返回
3. 按 Home 回桌面（模拟器 ⇧⌘H），再点图标回来
4. 从屏幕顶部下拉控制中心，再收起
5. 旋转屏幕（⌘← / ⌘→）
6. 多任务界面上滑杀掉 App

想一想：
- iOS 有三套生命周期：`UIApplicationDelegate`（App 级）、`UISceneDelegate` / `scenePhase`（窗口级，iPad 分屏时一个 App 有多个窗口）、视图的 `onAppear` / `onDisappear`。分别对应 Android 的什么？（Application、Activity 的 onStart / onResume……、Composable 进出组合）
- 第 4 步：`inactive` 是什么状态？Android 有对应的吗？（提示：`onPause` 但没有 `onStop`）
- 第 5 步：旋转后 `FileListScreen.onAppear` 触发了吗？`App.init` 呢？和 Android 的「旋转 = Activity 销毁重建」比，结论填 spec M3 第 2 条（「iOS 若不触发重建，记录原因」）
- 第 6 步：`willTerminate` 打出来了吗？为什么不能指望它做保存？
- 🔬 `STAGE = 2` 时（M3-3 还没生效），进详情页再返回，日志里是不是又发了一次请求？原因是 `.task` 和 `onAppear` 一样，每次页面重新出现都会执行。这就是 M3-3 要解决的问题

---

## M3-1 后台超过 30s 吗 · `Lifecycle/Lifecycle.swift`

<details><summary>提示 2</summary>

`backgroundAt` 是可选值，先 `guard let backgroundAt else { return false }`。`now.timeIntervalSince(backgroundAt)` 是秒数（`Double`）。注意边界：恰好 30s 算。
</details>

<details><summary>答案</summary>

```swift
guard let backgroundAt else { return false }
return now.timeIntervalSince(backgroundAt) >= threshold
```
</details>

想一想：为什么 `now` 要作为参数传进来，而不是在函数里直接 `Date()`？

---

## M3-2 scenePhase 状态变化 · `Lifecycle/Lifecycle.swift`

<details><summary>提示 2</summary>

```swift
log("scenePhase \(Self.describe(phase)) → \(Self.describe(newPhase))")
switch newPhase {
case .background: // 记时刻
case .active:     // 问 RefreshPolicy，要刷新就 onRefresh()；清掉 backgroundAt
default: break
}
phase = newPhase
```

`.inactive` 不要记时刻：下拉控制中心、来电界面都只会到 inactive，停多久都不算进了后台。
</details>

<details><summary>答案</summary>

```swift
log("scenePhase \(Self.describe(phase)) → \(Self.describe(newPhase))")
switch newPhase {
case .background:
    backgroundAt = now()
case .active:
    if RefreshPolicy.shouldRefresh(backgroundAt: backgroundAt, now: now()) {
        log("后台超过 \(Int(RefreshPolicy.threshold))s，刷新列表")
        onRefresh()
    }
    backgroundAt = nil
default:
    break
}
phase = newPhase
```
</details>

想一想：
- 🔬 手动验收：回桌面等 30s 以上再回来，日志里有 `后台超过 30s，刷新列表` 和一次新请求；10s 就回来则没有
- 切后台后 App 还在运行吗？iOS 一般几秒后就把 App 挂起（suspend），代码完全不跑；Android 的进程在后台还能跑一段时间。所以「后台 30s」在 iOS 上不能用定时器数，只能在回来时算时间差
- **对工作**：线上 App 的 H5 页面的 `visibilitychange` 事件，iOS 上是由什么触发的？和这里的 `scenePhase` 是一回事吗？（M4 的 appState 事件是另一条路）

---

## M3-3 只加载一次 · `Data/FileListModel.swift`

<details><summary>提示 2</summary>

`guard !hasStarted else { return }`，然后 `hasStarted = true`，然后 `await load()`。顺序很重要：`await` 会让出主线程，另一个调用可能在这期间进来。
</details>

<details><summary>答案</summary>

```swift
guard !hasStarted else {
    log("loadIfNeeded：已经加载过，跳过")
    return
}
hasStarted = true
await load()
```
</details>

想一想：
- 把 `hasStarted = true` 挪到 `await load()` 后面，测试 `m3_3_concurrentCalls_fetchOnce` 会挂。整个 model 都跑在主线程（MainActor）上、没有多线程，为什么还会「并发」？（提示：`await` 是挂起点，和 JS 里 `await` 之后别的回调可以先跑一样，这叫 actor 重入）
- Android 用 ViewModel 的 `init { load() }` 天然只跑一次，因为 ViewModel 比 Composable 活得长。这里的 `FileListModel` 也比 View 活得长（在 `AppServices` 里），为什么还需要 `loadIfNeeded`？

---

## M3-4 挪到后台线程 · `Lifecycle/MainThreadDemo.swift`

先做实验：🔬 STAGE = 3，列表页右上角「主线程」菜单：

1. 点「主线程 sleep 2s」，立刻去滑列表：滑得动吗？日志里 `thread=` 是什么？
2. 点「主线程同步网络请求」（要开 mock 服务）：Xcode 里出现紫色的运行时警告了吗？说的是什么？
3. 填完 M3-4，点「后台执行」：滑得动吗？`thread=` 是什么？

<details><summary>提示 2</summary>

`Task { }` 会继承当前所在的 actor：在 MainActor 上创建，就还在主线程上跑。`Task.detached { }` 不继承。拿结果用 `.value`（要 `await`）。
</details>

<details><summary>答案</summary>

```swift
await Task.detached { blockingWork() }.value
```
</details>

想一想：
- 🔬 写成 `await Task { blockingWork() }.value`，测试会挂，日志里 `thread=main`。为什么加了 `Task`、加了 `await`，还是在主线程上？
- 🔬 把 `blockingWork` 前面的 `nonisolated` 删掉，再编译：`Task.detached` 那一行报什么错？这就是 Swift 6 严格并发：编译器知道这个函数属于主线程，不让你在别的线程调它。Android 上同样的错误（在后台线程碰 UI / 在主线程做网络）是在什么时候暴露的？（`NetworkOnMainThreadException` 是运行时崩溃）
- `URLSession.data(from:)` 为什么在主线程上 `await` 也不会卡？它和 `Thread.sleep` 有什么本质区别？（异步 IO vs 阻塞线程。和 JS 的 `await fetch()` vs 同步 `XMLHttpRequest` 一个道理）
- **对工作**：WKWebView 的 `evaluateJavaScript`、`WKScriptMessageHandler` 回调在哪个线程？bridge 方法里如果要读大文件，该怎么做？

### 语言模式：为什么选 Swift 6 + 默认 MainActor

工程用的是 `SWIFT_VERSION = 6.0`（严格并发，数据竞争是编译错误），App target 再加了 `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`（没标注的代码默认属于主线程，Xcode 26 起新建工程的默认值）。

- 好处：编译器替你检查「这段代码能不能在这个线程跑」，M3-4 的错误在编译期就暴露；默认 MainActor 让 M1–M2 的 UI 代码基本不用写并发标注，初学不会被编译错误卡住
- 代价：要放到后台跑的代码得显式写 `nonisolated`（`blockingWork`、`CrashReporter`），测试类要标 `@MainActor`

如果你在 M1–M2 被并发相关的编译错误卡住超过 15 分钟，记进 notes，可以临时在 `project.yml` 里把 `SWIFT_VERSION` 改成 `5.0`（再 `xcodegen generate`），错误会降级成警告。M3 时改回来对比一下。

---

## M3-5 scenePhase → appState · `Lifecycle/Lifecycle.swift`

<details><summary>提示 2</summary>

Swift 5.9 起 `switch` 可以直接当表达式返回值，每个 case 一行。`ScenePhase` 是系统枚举，以后可能加 case，所以要有 `default`（或 `@unknown default`）。
</details>

<details><summary>答案</summary>

```swift
switch phase {
case .active: "foreground"
case .background: "background"
default: nil
}
```
</details>

想一想：`inactive` 不推给 H5。如果推了，H5 会在下拉控制中心时收到 background 吗？线上 App 的 H5 里「切后台暂停视频」用哪个状态更合适？

---

## 验收（手动）

对照 spec M3：

- 生命周期日志顺序记进 notes（见最上面）
- 旋转屏幕：列表数据、排序都在，日志里没有新请求
- 主线程实验三步（见 M3-4）
- 后台 30s 回来刷新一次（见 M3-2）
