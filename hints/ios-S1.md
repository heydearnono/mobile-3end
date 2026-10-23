# S1 Swift 语言专项：提示与答案

插在 M0 和 M1 之间，约 2 小时。全是纯逻辑单测，`STAGE` 不用改：

```sh
cd ios
./check.sh S1     # 首次编译 1–2 分钟，之后十几秒
```

代码在 `Mobile3End/S1/`，按 8 节分文件。每个文件开头的注释是这一节的讲解，**先读注释再填空**，里面都标了对应的 TS 和 Kotlin 写法（Kotlin 就是你在 K1 里写过的）。速查表在 `notes/swift-for-ts-kotlin.md`。

格式同 `hints/ios-M1.md`：提示 1 在代码注释里，提示 2 和答案折叠在下面。展开过答案的在 `notes/ios-S1.md` 记一笔。

| 节 | 文件 | 空 | 在 M1–M5 里会遇到的地方 |
|---|---|---|---|
| 1 可选类型 | `Optionals.swift` | S1-1、S1-2 | `if let file`、M2-5 的 `try?`、M4-5 一层层 `as? [String: Any]` |
| 2 闭包、@escaping | `Closures.swift` | S1-3、S1-4 | M1-1 的 `sorted { }`、M3 的 `onRefresh: @escaping` |
| 3 值类型 vs 引用类型 | `ValueTypes.swift` | S1-5 ~ S1-7 | `View` 是 struct、`SortStore` 的 `nonmutating set`、`@State` |
| 4 enum + 模式匹配 | `Enums.swift` | S1-8、S1-9 | `ListState`、`Route`、M3-5 的 `switch` |
| 5 protocol + extension | `Protocols.swift` | S1-10、S1-11 | `FileRemote`、M2-1 的 `extension FileType`、`some View` |
| 6 错误处理 | `Errors.swift` | S1-12、S1-13 | M2-2 / M2-3 的 `throws`、M4-10 的 `as NSError` |
| 7 并发 | `Concurrency.swift` | S1-14、S1-15 | M2-7 / M3-3 的 `async`、M3-4 的 `Task.detached`、M4-9 的延迟检测 |
| 8 property wrapper | `PropertyWrappers.swift` | S1-16 | `@State`、`@Binding`、`@Environment`、M2-6 |

几点和 Android 不一样的：

- **测试还是要模拟器**：iOS 的单测是 hosted 的（跑在 App 进程里），只能在模拟器 / 真机上跑。check.sh 会自动挑一个 iPhone 模拟器，没启动就启动
- **撞到空会崩整个测试进程**，模拟器重启它要 20 多秒。所以 check.sh 对 S1 做了一件事：只覆盖还没填的空的测试，直接显示 `⬜ 还没填，没有运行`，不去撞。填一个跑一个就很快
- S1-4、S1-5 挖空时**签名也改了**（删了 `@escaping` / `mutating`），填完函数体会编译失败，按编译器的提示改签名就是这两题的考点
- S1-6 的测试会调 S1-5，S1-13 会调 S1-12，所以按顺序做

做题时多用 Xcode 的两个操作：⌥ 点变量名看推断出来的类型（`Int64?` 还是 `Int64`，一眼就清楚）；⌘ 点函数名跳到定义，`Optional`、`Result`、`first(where:)` 都能点进去看声明。

---

## S1-1 可选链 · `Optionals.swift`

<details><summary>提示 2</summary>

`files?.first { ... }` 的类型是 `FileItem?`：`files` 是 nil 时整条链是 nil，没找到图片时 `first` 本身返回 nil。再 `?.size` 得到 `Int64?`，`?? 0` 变回 `Int64`。`first { }` 是 `first(where:)` 的尾随闭包写法。
</details>

<details><summary>答案</summary>

```swift
files?.first { $0.type == .image }?.size ?? 0
```
</details>

想一想：
- 和 K1-5 的 `files?.firstOrNull { it.type == FileType.IMAGE }?.size ?: 0` 逐个符号对照：`firstOrNull` ↔ `first`、`it` ↔ `$0`、`?:` ↔ `??`。Swift 的 `first` 为什么不需要叫 `firstOrNull`？（提示：Swift 里「可能没有」一定体现在返回类型上，`Array.first` 本来就是可选的）
- 函数体只有一个表达式，没写 `return` 也能编译。为什么 S1-2 必须写 `return`？

---

## S1-2 guard let · `Optionals.swift`

<details><summary>提示 2</summary>

```swift
guard let a = ... as? 类型,
      let b = ... as? 类型,
      条件
else { return nil }
return b
```
逗号分隔的每一项都要成立；`let` 绑定和 Bool 条件可以混着写。`message["params"]` 的类型是 `Any?`，`as? [String: Any]` 同时做了「非 nil」和「类型对」两件事。
</details>

<details><summary>答案</summary>

```swift
guard let params = message["params"] as? [String: Any],
      let text = params["text"] as? String,
      !text.isEmpty
else { return nil }
return text
```
</details>

想一想：
- 换成 `if let` 写一遍，对比嵌套层数。为什么 Swift 社区偏爱 `guard`？（提示：「提前返回」，主逻辑不用缩进）
- 换成 `(message["params"] as? [String: Any])?["text"] as? String` 一行能写吗？`!text.isEmpty` 那个条件放哪？
- 🔬 把 `as?` 改成 `as!`，再用测试里的 `["params": "text=hi"]` 跑一次，看 Xcode 停在哪、报什么。M4-5 收的是 H5 发来的消息，H5 想发什么就发什么：bridge 代码里出现 `as!` 意味着一个写错的 H5 页面就能让 App 崩溃

---

## S1-3 闭包链 · `Closures.swift`

<details><summary>提示 2</summary>

三步：`filter { 是不是图片 }` → `sorted { $0 是否该排在 $1 前面 }` → `map(\.name)`。从大到小就是 `$0.size > $1.size`。多行链式调用每行以 `.` 开头，Swift 能认出来是接着上一行。
</details>

<details><summary>答案</summary>

```swift
files
    .filter { $0.type == .image }
    .sorted { $0.size > $1.size }
    .map(\.name)
```
</details>

想一想：
- `\.name` 叫 key path，`map(\.name)` 等于 `map { $0.name }`。工程里 `list.map(\.id)`、`ForEach(H5Case.allCases)` 背后的 `id` 都是这个
- `sorted(by:)` 要的是「a 是否排在 b 前面」，和 JS 的 `arr.sort((a, b) => b.size - a.size)` 返回数字不一样。哪个更容易写反？回去看 M1-1

---

## S1-4 @escaping · `Closures.swift`

<details><summary>提示 2</summary>

函数体就是 `handlers[event, default: []].append(handler)`（`default:` 是找不到 key 时用的默认值，可以直接在上面 append）。写完编译器会报：

```
converting non-escaping parameter 'handler' to generic parameter 'Element' may allow it to escape
```

意思是：你把 `handler` 存进了数组，函数返回后它还活着，这就叫「逃逸」，必须在参数类型前标 `@escaping`。
</details>

<details><summary>答案</summary>

```swift
func on(_ event: String, _ handler: @escaping (String) -> Void) {
    handlers[event, default: []].append(handler)
}
```
</details>

想一想：
- 为什么 `sorted { }`、`filter { }`、`first { }` 的闭包都不用标 `@escaping`？它们和 `on` 的区别在哪？
- 回去看 `Lifecycle/Lifecycle.swift` 的 `LifecycleTracker.init` 和 `Web/Bridge.swift` 的 `BridgeDispatcher.init`，`@escaping` 都是因为什么？
- 存起来的闭包会强引用它用到的对象。M4 的 `H5Controller` 里，WebKit 的 `userContentController.add(handler, ...)` 也会强引用 handler，所以代码里多包了一层 `WeakScriptMessageHandler`。真实容器里 WebView 页面关了内存不释放，常见原因就是这一类循环引用。🔬 M4 做完后在 Xcode 的 Debug Memory Graph 里看看关掉 H5 页之后 `H5Controller` 还在不在

---

## S1-5 mutating · `ValueTypes.swift`

<details><summary>提示 2</summary>

`progress = min(1, progress + delta)`。写完报 `cannot assign to property: 'self' is immutable`：struct 的方法默认把 `self` 当 `let`，要改属性就在 `func` 前面加 `mutating`。

另外留意：挖空状态下测试文件第 83 行有一个警告 `variable 'task' was never mutated`，因为 `advance` 不是 `mutating`，编译器认为调它不会改 `task`。加上 `mutating` 警告就没了。
</details>

<details><summary>答案</summary>

```swift
mutating func advance(by delta: Double) {
    progress = min(1, progress + delta)
}
```
</details>

想一想：
- 🔬 在测试里把 `var task = UploadTask(name: "a")` 改成 `let`，看编译器怎么说。再对比 `let queue = UploadQueue()` 之后 `queue.add("a")` 为什么可以
- `Data/FileCache.swift` 的 `SortStore.order` 写了 `nonmutating set`：SortStore 是 struct，为什么它的 setter 可以不是 mutating？（提示：它改的是 `defaults` 指向的那个对象，没改 SortStore 自己的任何字段。`UserDefaults` 是 class）

---

## S1-6 改数组里的 struct · `ValueTypes.swift`

<details><summary>提示 2</summary>

`tasks.first(where:)` 拿到的是元素的**副本**，改副本对数组没影响（这就是注释里那段 TS / Kotlin 思路不生效的原因）。用 `firstIndex(where:)` 拿到下标，再 `tasks[i].advance(by: delta)` 原地改。没找到时 `firstIndex` 返回 nil，`guard let` 提前返回。
</details>

<details><summary>答案</summary>

```swift
guard let i = tasks.firstIndex(where: { $0.name == name }) else { return }
tasks[i].advance(by: delta)
```
</details>

想一想：
- 测试断言了 `changes` 会 +1：只改了数组里一个元素，`tasks` 的 `didSet` 也触发了。值类型的「改一个字段 = 整个值换了新的」。这正是 SwiftUI / `@Observable` 能发现变化的原因：对比 Vue 3 要靠 Proxy 去拦截深层属性的修改
- `UploadTask` 改成 `class` 的话，注释里那段 `if var task = ...` 写法就能生效了。那 `didSet` 还会触发吗？`@Observable` 的 model 里放 class 数组，界面会刷新吗？

---

## S1-7 快照与 inout · `ValueTypes.swift`

<details><summary>提示 2</summary>

两行：先 `history.append(files)`，再 `change(&files)`。`files` 是值类型，append 进去的那份和之后被修改的这份互不影响，不用手动深拷贝。`inout` 参数传的时候要写 `&`，表示「这个变量会被改」。
</details>

<details><summary>答案</summary>

```swift
history.append(files)
change(&files)
```
</details>

想一想：
- 前端做撤销要 `structuredClone` 或者 immer，Swift 里一行 `append` 就是快照。每次都复制整个数组不贵吗？（提示：copy-on-write，append 时只是多了一个引用，`change` 真正修改时才复制）
- 如果 `FileItem` 是 class，`history` 里存的快照还可靠吗？`change` 里改了某个 `FileItem` 的字段会怎样？

---

## S1-8 带关联值的 switch · `Enums.swift`

<details><summary>提示 2</summary>

```swift
switch state {
case .loading: ...
case .failed(let message): ...
case .loaded(let files) where files.isEmpty: ...
case .loaded(let files): ...
}
```
`switch` 是表达式，每个 case 后面直接写字符串就是返回值。带 `where` 的要放在不带的前面，否则永远匹配不到。
</details>

<details><summary>答案</summary>

```swift
switch state {
case .loading: "loading"
case .failed(let message): "failed: \(message)"
case .loaded(let files) where files.isEmpty: "empty"
case .loaded(let files): "loaded \(files.count)"
}
```
</details>

想一想：
- 🔬 把两个 `.loaded` 的顺序对调，编译器会给警告吗？测试是怎么发现的？
- `UI/FileListScreen.swift` 的 `content` 就是这个 switch，只是每个分支返回的是 View。`ListState.files` 里那句 `if case .loaded(let files) = self` 现在读得懂了吗？
- 对照 K1-11 的 `when (result) { is BridgeResult.Ok -> ... }`：Kotlin 靠 smart cast 拿字段，Swift 靠模式里的 `let` 绑定

---

## S1-9 enum 的 init · `Enums.swift`

<details><summary>提示 2</summary>

`switch` 能直接匹配字符串字面量。enum 的 `init` 里给 `self` 赋值。toast 的文本：`params["text"] as? String ?? ""`（`as?` 比 `??` 先算）。
</details>

<details><summary>答案</summary>

```swift
switch method {
case "getDeviceInfo": self = .getDeviceInfo
case "toast": self = .toast(text: params["text"] as? String ?? "")
default: self = .unknown(method: method)
}
```
</details>

想一想：
- 字符串 `switch` 必须写 `default`，`BridgeCall` 的 `switch` 却可以不写。这就是「先把字符串变成 enum」的好处：M4-5 的分发逻辑如果在 `BridgeCall` 上 `switch`，以后加一个 bridge 方法漏处理了，编译器会报错
- 测试里 `"GetDeviceInfo"` 是 `.unknown`。真实容器里 H5 和端上方法名大小写对不上，H5 拿到的就是 `METHOD_NOT_FOUND`。排查 bridge 调用失败时第一步先看什么？

---

## S1-10 带约束的 extension · `Protocols.swift`

<details><summary>提示 2</summary>

`reduce(0) { sum, file in sum + file.size }`，简写成 `$0 + $1.size`。`0` 会被推断成 `Int64`，因为返回类型是 `Int64`。计算属性只有 getter 时可以省掉 `get { }`。
</details>

<details><summary>答案</summary>

```swift
reduce(0) { $0 + $1.size }
```
</details>

想一想：
- `extension Array where Element == FileItem`：只有 `[FileItem]` 才有 `totalSize`，`[Int]` 没有。对比 K1-13 的 `val List<FileItem>.totalSize`
- 🔬 在 `UI/FileListScreen.swift` 里直接写 `files.totalSize`，不 import 任何东西也能用。Kotlin 要 import，Swift 同一个 target 里全局可见。好处和坏处各是什么？（提示：大型工程里，两个模块各给 `String` 加了一个同名 extension 会怎样）

---

## S1-11 协议默认实现 · `Protocols.swift`

<details><summary>提示 2</summary>

`bytes == 0 ? "—" : formatSize(bytes)`。在 `extension Listable` 里能直接用 `bytes`，因为任何遵守 `Listable` 的类型都一定有它。`FileItem` 没写 `subtitle`，就用这个默认实现；`TrashSummary` 自己写了，就用自己的。
</details>

<details><summary>答案</summary>

```swift
bytes == 0 ? "—" : formatSize(bytes)
```
</details>

想一想：
- `extension FileItem: Listable` 是给一个已经写好的类型「补签」协议，`FileItem` 的定义一行没改。TS 的 interface 是结构化的（形状对上就算实现了），Swift 的 protocol 要显式声明。哪种更适合读大工程？
- SwiftUI 的 `View` 就是一个 protocol，`.padding()` 是 `extension View` 里的默认实现。⌘ 点一下 `.padding` 看看它的声明
- 测试里 `[any Listable]` 混装了 `FileItem` 和 `TrashSummary`。`var body: some View` 能不能换成 `any View`？（试一下，看报错。`some` 是「一个确定的类型」，SwiftUI 靠它在编译期知道视图结构）

---

## S1-12 throws 和 guard · `Errors.swift`

<details><summary>提示 2</summary>

`try? JSONSerialization.jsonObject(with: Data(text.utf8))` 把 NSError 变成 nil，和 `as? [String: Any]` 一起放进第一个 `guard let`，失败就 `throw BridgeParseError.notJSON`。然后 id、method 各一个 `guard let ... as? String else { throw ... }`，顺序别反。
</details>

<details><summary>答案</summary>

```swift
guard let object = try? JSONSerialization.jsonObject(with: Data(text.utf8)),
      let dict = object as? [String: Any]
else { throw BridgeParseError.notJSON }
guard let id = dict["id"] as? String else { throw BridgeParseError.missingField("id") }
guard let method = dict["method"] as? String else { throw BridgeParseError.missingField("method") }
return BridgeRequest(id: id, method: method)
```
</details>

想一想：
- `{"id":1,...}` 也算缺 id：`as? String` 对数字返回 nil。H5 那边 `id` 是字符串还是数字，决定了这里能不能取到。去 `mock/h5/app.js` 的 `call` 函数看一眼 id 是怎么生成的
- 这里 `try?` 丢掉了 JSONSerialization 的错误原因。线上排查 bridge 消息解析失败时，你希望日志里有什么？M4-5 打日志时把原始 body 也打出来

---

## S1-13 do-catch 按 case 匹配 · `Errors.swift`

<details><summary>提示 2</summary>

```swift
do {
    let request = try parseRequest(text)
    return ...
} catch BridgeParseError.missingField(let field) {
    return ...
} catch {
    return ...
}
```
`catch` 后面的模式和 `switch` 的 case 一样写。最后那个不带模式的 `catch` 不能省：编译器不知道 `parseRequest` 只会抛 `BridgeParseError`。
</details>

<details><summary>答案</summary>

```swift
do {
    let request = try parseRequest(text)
    return .ok(data: ["method": request.method])
} catch BridgeParseError.missingField(let field) {
    return .err(code: "MISSING_FIELD", message: field)
} catch {
    return .err(code: "BAD_JSON", message: "")
}
```

`Result` 版：

```swift
switch Result(catching: { try parseRequest(text) }) {
case .success(let request): return .ok(data: ["method": request.method])
case .failure(BridgeParseError.missingField(let field)): return .err(code: "MISSING_FIELD", message: field)
case .failure: return .err(code: "BAD_JSON", message: "")
}
```
</details>

想一想：
- 🔬 把 `parseRequest` 的签名改成 `throws(BridgeParseError)`（Swift 6 的 typed throws），catch 里就能简写成 `catch .missingField(let f)`，不带模式的 `catch` 里 `error` 的类型也直接是 `BridgeParseError`。把最后那个 `catch` 换成 `catch .notJSON`，两个 case 都写全了，能编译吗？（实测 Xcode 27 不能：catch 不像 switch 那样做穷尽检查，最后还是要一个兜底的 `catch`）
- `TestSupport.swift` 的 `FakeRemote` 里存的是 `Result<[FileItem], any Error>`，`fetch()` 里 `try result.get()`。现在能读懂 M2 的测试是怎么让请求「失败」的了吗？

---

## S1-14 async let · `Concurrency.swift`

<details><summary>提示 2</summary>

`async let a = first()` 立刻启动一个子任务，不等它；两行都写完之后 `await a + b` 一起等。如果写 `let a = await first()` 就是顺序的，测试会报总耗时 0.8 秒。
</details>

<details><summary>答案</summary>

```swift
async let a = first()
async let b = second()
return await a + b
```
</details>

想一想：
- 三种写法对照：TS 的 `Promise.all`、K1-14 的 `coroutineScope { async { } }`、Swift 的 `async let`。哪个最短？Swift 和 Kotlin 共同的地方是什么？（结构化：函数返回前子任务一定已经结束，不会有「游离的 promise」）
- 参数上的 `@Sendable` 是因为 `async let` 可能把 `first()` 放到别的线程跑。🔬 删掉它看编译器报什么（`sending 'first' risks causing data races`），这就是 Swift 6 严格并发在检查的东西
- 数量不固定（比如离线包要并发下载 N 个文件）时用 `withTaskGroup`。查一下它的写法，记进速查表

---

## S1-15 Task 与取消 · `Concurrency.swift`

<details><summary>提示 2</summary>

```swift
task?.cancel()
task = Task {
    try? await Task.sleep(for: delay)
    guard !Task.isCancelled else { return }
    action()
}
```
`try?` 吞掉了 sleep 被取消时抛的 `CancellationError`，代码会继续往下走，所以要再查一次 `Task.isCancelled`。另一种写法：`do { try await Task.sleep(for: delay) } catch { return }`。
</details>

<details><summary>答案</summary>

```swift
task?.cancel()
task = Task {
    try? await Task.sleep(for: delay)
    guard !Task.isCancelled else { return }
    action()
}
```
</details>

想一想：
- 对照 `Web/H5Controller.swift` 的 `H5PageState.showToast`：同一个模式，多了 `[weak self]`。为什么那里要 weak，这里的 `Debouncer` 不用？（提示：这里的 Task 闭包里没用 `self` 的属性……真的吗？`delay` 是 `self.delay`）
- M4-9 的白屏检测：`didFinish` 后 1s 探测，期间开始了新导航就作废。哪一行对应 `task?.cancel()`？
- 类里标了 `@MainActor`，`Task { }` 继承它，所以 `action()` 在主线程执行，可以直接改 UI 状态。M3-4 要的是相反的效果：用什么？

---

## S1-16 写一个 property wrapper · `PropertyWrappers.swift`

<details><summary>提示 2</summary>

get：`defaults.object(forKey: key) as? Value ?? defaultValue`。`object(forKey:)` 返回 `Any?`，`as? Value` 同时处理「没存过」和「存的类型不对」。set：`defaults.set(newValue, forKey: key)`，`newValue` 是 setter 里自动有的名字。
</details>

<details><summary>答案</summary>

```swift
get {
    defaults.object(forKey: key) as? Value ?? defaultValue
}
set {
    defaults.set(newValue, forKey: key)
}
```
</details>

想一想：
- 写完之后 `prefs.launchCount += 1` 就是 `prefs._launchCount.wrappedValue += 1`，`prefs.$launchCount` 就是 `prefs._launchCount.projectedValue`。拿这个对照 `RootView` 里的 `@State private var m1Order` 和传给 `FileListScreen` 的 `$m1Order`：`$` 取的是什么？
- `Stored` 是 struct，`set` 为什么可以不写 `mutating`？（`wrappedValue` 的 setter 默认就是 mutating，但改的其实是 `UserDefaults` 那个对象……试试加上 `nonmutating`，看 `S1Prefs` 用起来有没有区别）
- 这个 wrapper 和 SwiftUI 的 `@AppStorage` 只差一件事：改了值界面不会刷新。`@State` 多做的就是这一半。对照 Kotlin 的 `var order by orderState`：读写转给委托对象，Compose 的 State 对象在被写入时通知重组，是同一个设计
- M2-6 的 `SortStore.order` 手写了 get / set，能改成 `@Stored` 吗？为什么工程里没这么做？（提示：SortOrder 是 enum，UserDefaults 不认识它，要存 rawValue）

---

## 做完之后

1. 把 `notes/swift-for-ts-kotlin.md` 里你还没完全理解的行标出来
2. 回头读 `UI/RootView.swift`、`UI/FileListScreen.swift`、`Data/FileListModel.swift`，把每一处 `if let`、尾随闭包、`switch` 模式匹配、`@State` / `@Binding` / `$`、`extension` 认出来。读得通了 S1 就算完成，开始 M1
