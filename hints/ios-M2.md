# iOS M2 提示与答案

开始前：把 `Mobile3End/App/Stage.swift` 里的 `STAGE` 改成 `2`。

`./check.sh M2` 会在 mock 服务没开时自动临时开一个（端口 8000）。手动运行 App 前自己开：

```sh
python3 -m http.server 8000 -d mock
```

建议顺序：M2-1 → M2-2 → M2-3 → 手工任务 ATS → M2-4 → M2-5 → M2-6 → M2-7。M2-6 是 get / set 两处，「未填的空」里会列两行。M2-7 的单测会先用到 M2-4（准备缓存）和 M2-6（model 初始化时读排序），所以放最后。UI 测试（`m2_7_*Shows*`、`m2_6_sortOrderSurvivesRelaunch`、`m2_e2e_*`）启动后会依次走到 M2-6（读排序）、M2-5、M2-7、M2-4、M2-1（读缓存时解码），要这几个都填完才会一起出结果，之前显示「运行到了未填的 M2-x」。

---

## M2-1 容错的枚举解码 · `Data/FileApi.swift`

<details><summary>提示 2</summary>

单个值（不是对象、不是数组）用 `decoder.singleValueContainer()`，再 `.decode(String.self)`。`FileType(rawValue:)` 返回可选值，`??` 给默认值。
</details>

<details><summary>答案</summary>

```swift
let raw = try decoder.singleValueContainer().decode(String.self)
self = FileType(rawValue: raw) ?? .doc
```
</details>

想一想：
- 不写这个 `init(from:)`，`String` 原始值的枚举也能自动解码。那遇到 `"audio"` 时会怎样？是丢掉这一条，还是整个列表都解析失败？对比前端：`JSON.parse` 之后用 TS 类型断言，有这个问题吗？
- Android 版用什么做 JSON 解析（kotlinx.serialization / Gson / Moshi）？它们遇到未知枚举值的默认行为分别是什么？
- 服务端接口新增一个文件类型时，老版本 App 会不会因此白屏？这和 H5 容器里「bridge 返回了 H5 不认识的字段」是同一类问题

---

## M2-2 解析接口返回 · `Data/FileApi.swift`

<details><summary>提示 2</summary>

`JSONDecoder().decode(类型.self, from: data)`。外层是 `{ "files": [...] }`，所以要解的类型是 `FilesResponse`，再取 `.files`。
</details>

<details><summary>答案</summary>

```swift
try JSONDecoder().decode(FilesResponse.self, from: data).files
```
</details>

想一想：接口字段是 `mtime`，如果后端改成 `modified_time`，Swift 里怎么映射？（`CodingKeys` / `keyDecodingStrategy`）

---

## M2-3 发请求 · `Data/FileApi.swift`

<details><summary>提示 2</summary>

```swift
let (data, response) = try await session.data(from: url)
```

`response` 是 `URLResponse`，`as? HTTPURLResponse` 才有 `statusCode`。注意：URLSession 和 `fetch` 一样，**4xx / 5xx 不算错误、不会 throw**，要自己判断。
</details>

<details><summary>答案</summary>

```swift
let (data, response) = try await session.data(from: url)
let status = (response as? HTTPURLResponse)?.statusCode ?? -1
guard (200..<300).contains(status) else { throw FileApiError.badStatus(status) }
return try decodeFiles(data)
```
</details>

想一想：
- `async throws` + `try await` 对应 JS 的什么？错误从哪里传到哪里？（`FileListModel.load` 里的 `catch`）
- 测试用 `StubURLProtocol` 拦下了 URLSession 的请求，不用真的起服务。前端有对应的做法吗？（MSW / Service Worker）这和 M4 的离线包拦截有什么相似和不同？

---

## 手工任务：ATS 放行明文 http · `Mobile3End/Info.plist`

Info.plist 不是代码，没法挖空。测试 `m2_task_atsAllowsLocalhost` 会检查你有没有做这一步。

**先做实验，再配置：**

1. 🔬 什么都不配，`STAGE = 2` 运行，列表能加载出来吗？
2. 🔬 把 `App/Mobile3EndApp.swift` 里 `AppConfig.filesURL` 临时改成 `http://example.com/api/files.json`（需要联网），再运行，看 Xcode 控制台：会出现 `[ATS] 明文 http 被 App Transport Security 拦截` 和错误码 `-1022`。看完改回来
3. 配置：在 Xcode 里打开 `Info.plist`（右键 → Open As → Source Code 可以看到原文），在注释的位置加入 `NSAppTransportSecurity`

<details><summary>提示 2</summary>

只给一个域名开例外用 `NSExceptionDomains`，键是域名，值是一个字典，里面 `NSExceptionAllowsInsecureHTTPLoads` 设为 `true`。不要用 `NSAllowsArbitraryLoads` 全局放开（测试会拦）。
</details>

<details><summary>答案</summary>

```xml
<key>NSAppTransportSecurity</key>
<dict>
	<key>NSExceptionDomains</key>
	<dict>
		<key>localhost</key>
		<dict>
			<key>NSExceptionAllowsInsecureHTTPLoads</key>
			<true/>
		</dict>
	</dict>
</dict>
```

也可以用 `NSAllowsLocalNetworking = true`（放行 localhost、`.local` 域名和不带点的主机名）。
</details>

想一想：
- 🔬 第 1 步的结果和 spec 说的「三端默认都限制明文请求」一致吗？如果 localhost 不配也能通，原因是什么？（查 Apple 文档里 ATS 对 `localhost`、IP 地址的规定）。真机连 Mac 的局域网 IP（如 `http://192.168.x.x:8000`）需要配吗？结论记进 notes 和 compare.md「明文 http 放行」一行
- Android 用 `network_security_config.xml` 的 `domain-config cleartextTrafficPermitted`，iOS 用 Info.plist。两边分别在什么时候生效（编译期 / 安装时 / 运行时）？
- **对工作**：WKWebView 里 H5 发的 http 请求受不受 App 的 ATS 配置影响？（提示：查 `NSAllowsArbitraryLoadsInWebContent`）线上 App 的 H5 页面里的图片如果是 http 的，iOS 上会怎样？

---

## M2-4 写缓存 · `Data/FileCache.swift`

<details><summary>提示 2</summary>

`JSONEncoder().encode(files)` 得到 `Data`，`data.write(to: fileURL, options: .atomic)`。两个都 throw，放进 `do { } catch { log(...) }`。
</details>

<details><summary>答案</summary>

```swift
do {
    let data = try JSONEncoder().encode(files)
    try data.write(to: fileURL, options: .atomic)
    log("缓存已写入 \(files.count) 条")
} catch {
    log("缓存写入失败：\(error)")
}
```
</details>

想一想：
- `.atomic` 是怎么做到「写到一半被杀也不会留下半个文件」的？（先写临时文件再 rename）不加的话，下次启动读到半个 JSON 会怎样？M2-5 的测试 `m2_5_corruptCacheIsNil` 模拟的就是这种情况
- 缓存放在 Caches 目录，和放在 Documents 目录有什么区别？（iCloud 备份、系统清理、文件 App 可见性）Android 的 `cacheDir` / `filesDir` 对应哪个？
- 🔬 在模拟器上找到这个文件：`xcrun simctl get_app_container booted com.example.mobile3end data`，再进 `Library/Caches/`

---

## M2-5 读缓存 · `Data/FileCache.swift`

<details><summary>提示 2</summary>

`try? 表达式` 出错时得到 `nil`。`Data(contentsOf: fileURL)` 读文件，`JSONDecoder().decode([FileItem].self, from: data)` 解析。
</details>

<details><summary>答案</summary>

```swift
guard let data = try? Data(contentsOf: fileURL) else { return nil }
return try? JSONDecoder().decode([FileItem].self, from: data)
```
</details>

想一想：「文件不存在」和「文件损坏」都返回 `nil`，调用方区分不出来。什么场景需要区分？

---

## M2-6 排序持久化 · `Data/FileCache.swift`

<details><summary>提示 2</summary>

读：`defaults.string(forKey:)` 返回 `String?`，`.flatMap(SortOrder.init(rawValue:))` 转成 `SortOrder?`，`?? .name`。
写：`defaults.set(newValue.rawValue, forKey: Self.key)`。
</details>

<details><summary>答案</summary>

```swift
get {
    defaults.string(forKey: Self.key).flatMap(SortOrder.init(rawValue:)) ?? .name
}
nonmutating set {
    defaults.set(newValue.rawValue, forKey: Self.key)
}
```
</details>

想一想：
- `UserDefaults` 是同步的，Android 的 DataStore 是异步的（Flow）。各有什么好处？哪个更像 `localStorage`？
- 为什么存 `rawValue` 字符串，而不是存枚举的序号（0 / 1）？
- SwiftUI 有 `@AppStorage("sortOrder")`，一行就能把 `@State` 换成 UserDefaults 持久化。这个工程为什么没用它？（提示：测试里要换成独立的 `UserDefaults`）

---

## M2-7 加载状态机 · `Data/FileListModel.swift`

这是 M2 最大的空。先在纸上画出四种情况：有 / 无缓存 × 成功 / 失败，每种情况下 `state` 依次是什么。

<details><summary>提示 2</summary>

分两段：

1. 请求前：`cache.load()` 有值 → `.loaded(缓存)`；没有 → `.loading`（已经是 `.loaded` 的话保持不动，避免回前台刷新时闪一下 loading）
2. `do { let fresh = try await remote.fetch(); 写缓存; state = .loaded(fresh) } catch { ... }`：失败时如果当前 `state` 是 `.loaded`（来自缓存），只打日志；否则 `.failed(Self.message(for: error))`

判断枚举当前是哪个 case：`if case .loaded = state { ... }`
</details>

<details><summary>答案</summary>

```swift
if let cached = cache.load() {
    state = .loaded(cached)
} else if case .loaded = state {
    // 已经有数据（比如回前台刷新）：不闪 loading
} else {
    state = .loading
}
do {
    let fresh = try await remote.fetch()
    cache.save(fresh)
    state = .loaded(fresh)
} catch {
    if case .loaded = state {
        log("刷新失败，继续显示缓存：\(error)")
    } else {
        state = .failed(Self.message(for: error))
    }
}
```
</details>

想一想：
- `load()` 没有切线程，`await remote.fetch()` 期间主线程卡住了吗？为什么？（M3 会专门做这个实验）
- `@Observable` 的 model 改了 `state`，SwiftUI 怎么知道要刷新哪个视图？和 Vue 的响应式（Proxy + 依赖收集）比，原理像不像？
- 🔬 关掉 mock 服务，分别在「有缓存」「无缓存（启动参数 `-M3EReset YES`）」两种情况下启动 App，对照 spec 验收最后一条
- **对工作**：线上 App 的 H5 页面「先显示缓存再刷新」通常是谁做的，H5 自己（localStorage / IndexedDB）还是容器（离线包 / 预请求）？

---

## 验收（手动）

在 Xcode 的 Product → Scheme → Edit Scheme → Run → Arguments 里可以加启动参数，切换假数据源，不用真的开关服务：

| 参数 | 效果 |
|---|---|
| `-M3EFake ok` / `empty` / `fail` / `slow` | 假数据：正常 / 空列表 / 失败 / 3s 后才返回 |
| `-M3EReset YES` | 启动时清掉缓存和排序设置 |
| `-M3EStage 2` | 临时覆盖 `STAGE` |

勾掉不用的参数即可恢复，别忘了最后要用真实的 mock 服务走一遍。
