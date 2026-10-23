# iOS M4 提示与答案（重点）

开始前：把 `Mobile3End/App/Stage.swift` 里的 `STAGE` 改成 `4`。列表页右上角出现「H5」按钮；H5 页右上角「用例」菜单可以切换 `?case=`，顶部状态条显示 `OFFLINE_404` 次数和白屏检测结果。

M4 是项目目标本身，不许跳。时间盒 8h。

## 离线包 case（基线，已写好）

离线包拦截（M4-1、M4-2、M4-3）已经写好，读懂即可。不用做 M1–M3，现在就能打开离线包页面：看到「离线包测试页 case=normal」标题、`location: appoffline://h5/index.html`，App 不崩。此时 bridge、白屏检测的空还没填，页面上 `bridge: none`、`getDeviceInfo` 显示 `NO_BRIDGE` 失败、状态条「白屏检测：未开启」都是正常的。

**直达入口**：启动参数 `-M3EH5Case <case>`（值见 `Web/H5Case.swift`：`normal`、`blank`、`missing`、`slow`……）。带了它就只显示 H5 页，不看 `STAGE`、不渲染列表页、不碰 M1–M3 的空（`STAGE = 0` 也行）。

- Xcode：Product → Scheme → Edit Scheme…（⌘<）→ 左侧 Run → Arguments → Arguments Passed On Launch 点 `+`，填 `-M3EH5Case normal`，勾上。不用时取消勾选即可回到正常入口
- 命令行（模拟器已启动、App 已经用 Xcode 装过一次）：

```bash
xcrun simctl launch booted com.example.mobile3end -M3EH5Case normal
# 换用例 / 临时打开开关（-M3EBridge、-M3EWhiteScreen 覆盖下面两个常量，只对这一次启动生效）
xcrun simctl launch --terminate-running-process booted com.example.mobile3end -M3EH5Case missing
xcrun simctl launch --terminate-running-process booted com.example.mobile3end -M3EH5Case normal -M3EBridge YES
```

**两个开关**（`App/Stage.swift`）：iOS 的空是 `fatalError`，一进 H5 页就会碰到 bridge（H5 一启动就调 `getDeviceInfo` → M4-6）和白屏检测（加载完成 → M4-9），切前后台会碰到 M4-7，App 直接崩。所以先关着：

| 常量 | 关着时 | 什么时候打开 |
|---|---|---|
| `M4_BRIDGE` | 不注入 `NativeBridge`（M5 的 `M3EError` 照常注入），不推 appState | 填完 M4-4、M4-5、M4-6、M4-7（M4-7 用到 M3-5 的 `appStateName`，没做 M3 的话先把 M3-5 填了） |
| `M4_WHITE_SCREEN` | 加载完成 / 加载失败都不判定白屏，打一行日志「白屏检测开关 M4_WHITE_SCREEN 关着」 | 填完 M4-8、M4-9、M4-10 |

UI 测试用启动参数 `-M3EBridge YES/NO`、`-M3EWhiteScreen YES/NO` 显式指定，不受这两个常量影响。

---

整体结构（逻辑和胶水分开，逻辑都有单测）：

| 文件 | 内容 | 空 |
|---|---|---|
| `Web/OfflinePackage.swift` | URL → (状态码, MIME, 数据)，纯逻辑 | M4-1、M4-2（已写好） |
| `Web/OfflineSchemeHandler.swift` | `WKURLSchemeHandler`，把上面的结果回给 WebView | M4-3（已写好，完整方法） |
| `Web/Bridge.swift` | 来源校验、消息分发，纯逻辑 | M4-4、M4-5（完整方法） |
| `Web/H5Controller.swift` | WKWebView 接线：bridge 收发、导航回调、白屏检测 | M4-6、M4-7、M4-9（完整方法） |
| `Web/WhiteScreen.swift` | 白屏判定，纯逻辑 | M4-8、M4-10 |

建议顺序：先读懂 M4-1 → M4-2 → M4-3（已写好，用直达入口看页面）→ M4-4 → M4-5 → M4-6 → M4-7（bridge 通了，打开 `M4_BRIDGE`）→ M4-8 → M4-9 → M4-10（打开 `M4_WHITE_SCREEN`）→ 手工任务。

一进 H5 页就会执行到 M4-3（加载资源，已写好）、M4-6（H5 一启动就调 getDeviceInfo）、M4-9（加载完成），scenePhase 变化（H5 页出现时、切前后台）执行到 M4-7。开关关着时后三个都碰不到，页面照常渲染。`./check.sh M4` 里示例 `m4_0_offlinePageLoads` 和 M4-1 ~ M4-3 的测试一开始就是 ✅（它们显式关着开关跑）；其余 UI 测试显式打开两个开关，要等对应的空填完才变绿，之前显示「运行到了未填的 M4-x」。注意 App 启动时 scenePhase 会从 inactive 变成 active，H5 页一出现就会调到 M4-7，所以 M4-4 ~ M4-7 没填完之前，这些 UI 测试（包括白屏检测的）大多显示「运行到了未填的 M4-7」。纯逻辑单测（`m4_4_onlyOfflineOriginTrusted` 等）不受开关影响，先盯着它们做。每撞到一个未填的空，测试进程重启要等 20 多秒，空多的时候 `./check.sh M4` 要好几分钟；只想看某几个测试可以直接用 xcodebuild 的 `-only-testing:Mobile3EndUITests/M4UiTests/<测试名>`。

调 H5 时同时开着 Xcode 控制台（过滤 `M3E`）和 Safari Web Inspector（见手工任务），一个看原生日志，一个看 H5 的 Console / Network。

---

## M4-1 MIME 表 · `Web/OfflinePackage.swift`（已写好，读懂即可）

`UTType(filenameExtension: "png")?.preferredMIMEType` 就是 `"image/png"`。系统表里的扩展名是小写的。

```swift
UTType(filenameExtension: ext.lowercased())?.preferredMIMEType ?? "application/octet-stream"
```

自己写表也可以：`["html": "text/html", "js": "text/javascript", "css": "text/css", ...][ext.lowercased()] ?? "application/octet-stream"`。

想一想：
- MIME 给错了会怎样？🔬 临时把 `.js` 返回成 `text/plain`，页面还能跑吗？（浏览器对 `<script>` 的 MIME 检查比对 `<link rel=stylesheet>` 宽松，可以都试一下；`type="module"` 的脚本呢？）
- 线上 App 的离线包如果有 `.wasm`、`.woff2`，系统表能认出来吗？自己写表的话容易漏什么？

---

## M4-2 URL → 包内文件 · `Web/OfflinePackage.swift`（已写好，读懂即可）

思路：

1. `guard Self.owns(url)`
2. `url.path` 是 `/index.html`（不含查询串、已经 percent-decode），去掉开头的 `/`，拼到 `root` 上
3. `.standardizedFileURL` 把 `..` 消掉，消完检查路径是不是还以 `root` 开头（注意要比 `root + "/"`，否则 `h5-secret/` 也会被当成在 `h5/` 里）
4. `try? Data(contentsOf:)` 读不到（不存在 / 是目录）就 404

```swift
guard Self.owns(url) else { return notFound(url) }
let relative = String(url.path.drop { $0 == "/" })
let rootPath = root.standardizedFileURL.path
let file = root.appending(path: relative).standardizedFileURL
guard file.path.hasPrefix(rootPath + "/"),
      let data = try? Data(contentsOf: file) else {
    return notFound(url)
}
return OfflineResponse(status: 200, mime: Self.mimeType(forExtension: file.pathExtension), data: data)
```

想一想：
- `m4_2_pathTraversalBlocked` 防的是什么攻击？谁能构造出 `appoffline://h5/../xxx` 这样的请求？（页面里任何一个 `<img src>`、`fetch`）读到包外文件能拿到什么？
- 线上 App 的离线包是下载到沙盒里的，不是打在 App 包里的。这时 `root` 指向哪里？包更新到一半时有请求进来会怎样？
- **对工作**：「离线包同源资源 404」在这个实现里会出现在哪一步？日志长什么样？（这是 spec M4 最后一条，答案写进 notes）

---

## M4-3 WKURLSchemeHandler · `Web/OfflineSchemeHandler.swift`（已写好，完整方法，读懂即可）

`WKURLSchemeTask` 的三个方法必须按顺序调：`didReceive(URLResponse)` → `didReceive(Data)`（可以多次）→ `didFinish()`。响应用 `HTTPURLResponse(url:statusCode:httpVersion:headerFields:)`，头里放 `Content-Type`。

```swift
guard let url = urlSchemeTask.request.url else {
    urlSchemeTask.didFailWithError(URLError(.badURL))
    return
}
let result = package.resolve(url)
let response = HTTPURLResponse(
    url: url,
    statusCode: result.status,
    httpVersion: "HTTP/1.1",
    headerFields: [
        "Content-Type": result.mime,
        "Content-Length": String(result.data.count),
    ]
)!
urlSchemeTask.didReceive(response)
urlSchemeTask.didReceive(result.data)
urlSchemeTask.didFinish()
```

想一想：
- 🔬 用例菜单选「Android 的离线包地址」（`https://h5.offline.test/index.html`）：页面能出来吗？状态条显示什么？为什么 iOS 不能像 Android 的 `shouldInterceptRequest` 那样直接拦 https？（提示：试试在 `H5Controller.init` 里 `setURLSchemeHandler(..., forURLScheme: "https")`，看崩溃信息）。这条差异记进 compare.md「能否拦截 http/https」
- 换成自定义 scheme 的代价：页面的 origin 变成了 `appoffline://h5`。H5 里的 `fetch('https://api.xxx.com')` 是跨域请求吗？cookie、localStorage 归哪个 origin？线上 App 的 iOS 的离线包是用自定义 scheme，还是别的方案（本地 HTTP server / `loadFileURL`）？
- 🔬 把 `statusCode` 写死成 200，`missing` 用例里 H5 的 `missing.js load failed` 还会出现吗？（测试 `m4_2_m4_3_missingResourceIs404` 查的就是这个）
- 页面里 `fetch('appoffline://h5/xxx.json', { method: 'POST', body })`，`urlSchemeTask.request.httpBody` 拿得到吗？（查一下，这是 iOS 离线包方案的一个著名的坑）

---

## M4-4 只信任离线包 origin · `Web/Bridge.swift`

<details><summary>提示 2</summary>

`WKSecurityOrigin.protocol` 是不带冒号的 scheme，离线包页面上是 `"appoffline"`，host 是 `"h5"`。两个都要比，用 `OfflinePackage.scheme` / `.host` 常量。
</details>

<details><summary>答案</summary>

```swift
origin.scheme == OfflinePackage.scheme && origin.host == OfflinePackage.host
```
</details>

想一想：
- 为什么用 `frameInfo.securityOrigin`，而不用 `webView.url`？（提示：消息可能来自 iframe；`webView.url` 是主文档的地址，而且在导航过程中会变）
- 离线包页面里嵌了一个 `https://evil.com` 的 iframe，iframe 里能调到 `window.webkit.messageHandlers.NativeBridge` 吗？（`add(_:name:)` 默认对所有 frame 生效，所以才要校验 origin）要不要也检查 `isMainFrame`？
- Android 的 `addJavascriptInterface` 拿得到调用方的 origin 吗？Android 端是怎么做来源校验的？（`WebViewCompat.addWebMessageListener` 的 `allowedOriginRules`）三端的做法记进 compare.md「校验消息来源 origin 的方式」

---

## M4-5 bridge 分发 · `Web/Bridge.swift`（完整方法）

<details><summary>提示 2</summary>

```swift
guard BridgeSecurity.isTrusted(origin) else { log(...); return nil }
guard let data = body.data(using: .utf8),
      let message = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
      let id = message["id"] as? String,
      let method = message["method"] as? String else { log(...); return nil }
let params = message["params"] as? [String: Any] ?? [:]
switch method { ... }
```

返回值用 `BridgeJS.success(id:data:)` / `BridgeJS.failure(id:code:message:)`。
</details>

<details><summary>答案</summary>

```swift
guard BridgeSecurity.isTrusted(origin) else {
    log("[BRIDGE] 拒绝来自 \(origin.scheme)://\(origin.host) 的消息")
    return nil
}
guard let data = body.data(using: .utf8),
      let message = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
      let id = message["id"] as? String,
      let method = message["method"] as? String else {
    log("[BRIDGE] 消息格式不对：\(body)")
    return nil
}
let params = message["params"] as? [String: Any] ?? [:]
log("[BRIDGE] ← \(method) id=\(id)")
switch method {
case "getDeviceInfo":
    return BridgeJS.success(id: id, data: deviceInfo.dict)
case "toast":
    showToast(params["text"] as? String ?? "")
    return BridgeJS.success(id: id, data: [:])
default:
    return BridgeJS.failure(id: id, code: "METHOD_NOT_FOUND", message: "unknown method: \(method)")
}
```
</details>

想一想：
- 为什么用 `JSONSerialization` 而不是 `Codable`？（`params` 每个方法都不一样）真实容器里方法有几百个，`switch` 会变成什么？（注册表：`[String: Handler]`）
- `BridgeJS` 为什么用 `JSONSerialization` 生成 JS，而不是字符串拼接 `"window.__bridgeCallback({id:'\(id)'...})"`？🔬 试试 toast 文案里带单引号和换行
- 不可信来源直接 `return nil`，H5 会等到 3s 超时。为什么不回一个 `ok: false`？

---

## M4-6 收 H5 消息 · `Web/H5Controller.swift`

<details><summary>提示 2</summary>

`message.frameInfo.securityOrigin` 有 `.protocol`、`.host`、`.port`；`message.frameInfo.isMainFrame`。`message.body` 是 `Any`：H5 传字符串就是 `String`，传对象就是 `[String: Any]`。拿到 dispatcher 返回的 JS 后调 `runJS`。
</details>

<details><summary>答案</summary>

```swift
let securityOrigin = message.frameInfo.securityOrigin
let origin = BridgeOrigin(
    scheme: securityOrigin.protocol,
    host: securityOrigin.host,
    port: securityOrigin.port,
    isMainFrame: message.frameInfo.isMainFrame
)
guard let body = message.body as? String else {
    M3ELog.d("[BRIDGE] 消息体不是字符串：\(type(of: message.body))")
    return
}
if let js = dispatcher.handle(body, origin: origin) {
    runJS(js)
}
```
</details>

想一想：
- iOS 的 `postMessage` 可以直接传 JS 对象（自动转成 `NSDictionary`），Android 的 `@JavascriptInterface` 只能传基本类型。spec 统一用 JSON 字符串是为了什么？
- iOS 14 起有 `WKScriptMessageHandlerWithReply`，H5 端 `postMessage` 直接返回 Promise，不用 `id` + `__bridgeCallback`。为什么这个项目（和很多真实容器）还用回调的方式？
- `H5Controller` 里 `add(WeakScriptMessageHandler(self), name:)` 为什么要包一层？🔬 改成 `add(self, name:)`，在 `H5Controller` 里加一个 `deinit { M3ELog.d("H5Controller deinit") }`，进出 H5 页几次，看日志

### 注入时机（compare.md「注入时机」一行）

`H5Controller` 在 `decidePolicyFor navigationAction` 里决定加不加 `NativeBridge`：主文档是离线包就加，否则移除（`M4_BRIDGE` 关着时只加 M5 的 `M3EError`，所以离线包页面上也是 `bridge: none`）。

想一想：
- 🔬 页面 `app.js` 的第一行就能看到 `window.webkit.messageHandlers.NativeBridge` 吗？（页面上 `bridge: ios` 那一行就是证据）Android 的 `addJavascriptInterface` 要在 `loadUrl` 之前调用才对第一个页面生效，两边对比一下
- `WKUserScript` 的 `.atDocumentStart` 是另一种注入方式（M5 的 H5 错误采集用的就是它），和 `messageHandlers` 有什么区别？
- 🔬 用例菜单选「外部页面（内联，evil.test）」：页面显示 `bridge: none`。再选「外部页面 example.com」（要联网），在 Safari Web Inspector 的 Console 里执行 `window.webkit.messageHandlers.NativeBridge`。最后回到「正常」，bridge 恢复了吗？对照 spec M4「导航到非离线包页面，确认 bridge 不响应」

---

## M4-7 推送 appState · `Web/H5Controller.swift`

M4-4 ~ M4-7 填完后，把 `App/Stage.swift` 的 `M4_BRIDGE` 改成 `true`：页面上变成 `bridge: ios`，getDeviceInfo 显示 `"platform": "ios"`。

<details><summary>提示 2</summary>

`guard bridgeInjected, let state = appStateName(for: phase) else { return }`，然后 `runJS(BridgeJS.event("appState", data: ["state": state]))`。
</details>

<details><summary>答案</summary>

```swift
guard bridgeInjected, let state = appStateName(for: phase) else { return }
M3ELog.d("[BRIDGE] → appState \(state)")
runJS(BridgeJS.event("appState", data: ["state": state]))
```
</details>

想一想：
- 🔬 切后台时推的 `background` 事件，H5 是什么时候收到的？（App 挂起后 WebContent 进程也会被挂起，`evaluateJavaScript` 可能在回前台时才执行。看 H5 日志里两条事件的时间戳）
- 事件来自 `H5Screen` 的 `scenePhase`。如果改用 `UIApplication.didEnterBackgroundNotification`，有什么区别？（多窗口；视图不在屏幕上时还收不收得到）
- H5 自己的 `document.visibilitychange` 在 iOS 上切后台时触发吗？🔬 在 Web Inspector 里加个监听试试。有了它，还需要 Native 推 appState 吗？

---

## M4-8 白屏判定 · `Web/WhiteScreen.swift`

<details><summary>提示 2</summary>

`(probeResult as? NSNumber)?.intValue ?? 0`，拿不到当 0。0 → `.emptyRoot`，否则 `nil`。
</details>

<details><summary>答案</summary>

```swift
let count = (probeResult as? NSNumber)?.intValue ?? 0
return count == 0 ? .emptyRoot : nil
```
</details>

想一想：「没拿到结果」算白屏，是宁可误报还是宁可漏报？`evaluateJavaScript` 什么时候会拿不到结果？（WebContent 进程卡死、页面正在跳转）

---

## M4-9 主文档加载完成后检测 · `Web/H5Controller.swift`（完整方法）

方法开头的 `guard whiteScreenEnabled` 是开关，不用动，只替换 `TODO("M4-9")` 那一行。

<details><summary>提示 2</summary>

```swift
let url = webView.url
checkTask?.cancel()
checkTask = Task { [weak self] in
    try? await Task.sleep(for: WhiteScreen.checkDelay)
    guard let self, !Task.isCancelled else { return }
    let result = try? await webView.evaluateJavaScript(WhiteScreen.probeJS)
    ...
}
```

`url` 要在延迟之前取：1s 后 `webView.url` 可能已经是别的页了。
</details>

<details><summary>答案</summary>

```swift
let url = webView.url
checkTask?.cancel()
checkTask = Task { [weak self] in
    try? await Task.sleep(for: WhiteScreen.checkDelay)
    guard let self, !Task.isCancelled else { return }
    let result = try? await webView.evaluateJavaScript(WhiteScreen.probeJS)
    guard !Task.isCancelled else { return }
    self.page.detector.report(WhiteScreen.judge(probeResult: result), url: url)
}
```
</details>

想一想：
- `didFinish` 对应 DOM 的哪个事件？（`load`，不是 `DOMContentLoaded`）`missing` 用例里 `missing.js` 404 了，`didFinish` 还会触发吗？
- 不 `cancel` 上一次的 `checkTask`，快速切换用例时会出什么 bug？
- `[weak self]` 去掉会怎样？1s 内退出 H5 页，`H5Controller` 什么时候释放？
- 🔬 `blank` 用例：H5 抛了异常，Safari Web Inspector 的 Console 里看得到吗？Xcode 控制台呢？（M5 会把它转到原生日志）

---

## M4-10 主文档加载失败算不算白屏 · `Web/WhiteScreen.swift`

M4-8、M4-9、M4-10 填完后，把 `App/Stage.swift` 的 `M4_WHITE_SCREEN` 改成 `true`：状态条从「未开启」变成「正常」/ `empty_root` / `load_error`。

<details><summary>提示 2</summary>

```swift
let ns = error as NSError
ns.domain == NSURLErrorDomain && ns.code == NSURLErrorCancelled  // -999
ns.domain == WKError.errorDomain && ns.code == 102               // Frame load interrupted
```
</details>

<details><summary>答案</summary>

```swift
let ns = error as NSError
if ns.domain == NSURLErrorDomain && ns.code == NSURLErrorCancelled { return nil }
if ns.domain == WKError.errorDomain && ns.code == 102 { return nil }
return .loadError
```
</details>

想一想：
- `didFail` 和 `didFailProvisionalNavigation` 有什么区别？（provisional = 还没收到响应 / 还没 commit；`didFail` = commit 之后出错）`android-url` 用例走的是哪一个？
- 🔬 页面加载中快速切到另一个用例，日志里会出现 -999 吗？如果把它当成白屏上报，线上白屏率会怎样？
- **对工作**：线上的白屏率看板里，`load_error` 有没有过滤 -999？Android 的 `onReceivedError` 有没有类似的「取消」错误？

### 渲染进程退出（已写好，没有空）

`webViewWebContentProcessDidTerminate` 直接报 `render_gone`。🔬 用例菜单 →「模拟渲染进程崩溃」（调了私有 API `_killWebContentProcess`，只在 Debug 包里），看状态条和日志。然后点「重新加载」。

想一想：
- 进程退出后 WKWebView 不会自己恢复，页面一直是白的。真实容器一般怎么处理？（自动 `reload()`；记次数防止无限重载）
- iOS 上什么情况会触发？（内存压力最常见：H5 页面图片太多、长列表）Android 的对应回调是 `onRenderProcessGone`，它的返回值是什么意思？

---

## 手工任务 1：Safari Web Inspector 远程调试

`H5Controller.init` 里的 `webView.isInspectable = true` 是开关。

1. Mac 上 Safari → 设置 → 高级 → 勾选「显示网页开发者功能」
2. 运行 App，进 H5 页
3. Safari 菜单 → 开发 → 选模拟器（或手机）→ 选 `appoffline://h5/index.html`
4. Network 面板刷新页面（⌘R），看 `index.html`、`app.js`、`style.css` 的状态码和 MIME；`missing` 用例里的 `missing.js` 是什么样子

想一想：
- 🔬 把 `isInspectable = true` 注释掉再运行，Safari 的开发菜单里还能看到这个页面吗？iOS 16.4 之前不需要这一行（Debug 包默认可调试），为什么 Apple 要改成显式开启？线上 App 的 Release 包里这个开关是开还是关？
- Network 面板里离线包请求的「来源」显示的是什么？能区分出「从 scheme handler 回来的」和「从网络回来的」吗？

---

## 手工任务 2：`slow` 用例的检测时机

🔬 用例菜单选 `slow`：H5 3s 后才渲染，1s 时检测会误报 `empty_root`。

先自己想方案，写进 notes，再实现（改 `didFinish` 里的检测逻辑，或者加别的信号源）。

<details><summary>思路（展开前先自己想 10 分钟）</summary>

几种常见方案，各有取舍：

1. **多次采样**：1s 测一次，空就 2s、4s 再测，最后一次还空才报。简单，但「多久才算白屏」要定一个上限
2. **H5 主动上报**：H5 渲染完成后调一个 bridge 方法（如 `pageReady`），Native 在 N 秒内没收到就报白屏。最准，但要 H5 配合，H5 自己崩了（`blank`）恰好收不到——这正是想要的
3. **DOM 变化监听**：在 `.atDocumentStart` 注入 `MutationObserver` 监听 `#app`，有子元素时通过 bridge 通知 Native
4. **截图判色**：`takeSnapshot` 后看是不是纯白。不依赖 DOM 结构，但贵，且 loading 动画、骨架屏会干扰

真实容器一般是 1 / 2 结合：H5 有上报就用上报，没有就兜底采样。
</details>

想一想：线上的白屏检测是哪种？检测时机是多少秒？`slow` 这类「慢但最终正常」的页面会不会被算进白屏率？

---

## 验收（手动）

对照 spec M4，每条在 notes 里勾：

- 离线包：正常页面 200；`missing` 有 `[OFFLINE_404] appoffline://h5/missing.js`，页面其余部分正常
- `getDeviceInfo` 显示 `platform: "ios"`；toast 弹原生 toast + H5 收到成功；不存在的方法收到 `METHOD_NOT_FOUND`
- 切前后台，H5 日志里有 `appState` 事件
- 外部页面 bridge 不响应
- 白屏：正常不报、`blank` 报 `empty_root`、`missing` 不报、`slow` 按你的方案
- Safari Web Inspector 看到 Network 里的离线包请求
- notes 回答 A1 问题
- compare.md M4 表的 iOS 列补全
