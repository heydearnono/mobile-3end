# 统一需求（spec）

三端实现同一个「迷你文件管理器」。每个里程碑的验收项全部打勾才算完成，三端分别勾。

## 公共约定

### 数据接口（M2 起）

- 启动 mock 服务见 `README.md`
- `GET /api/files.json` → `{ "files": [ { "id", "name", "type", "size", "mtime" } ] }`
  - `type`：`folder` | `doc` | `image` | `video`
  - `size`：字节，文件夹为 0；`mtime`：秒级时间戳
- 用 http 明文是故意的：三端默认都限制明文请求，配置放行本身就是学习点

### 离线包（M4）

内容为 `mock/h5/` 整个目录，打包进 App：

| 端 | 放置位置 | 页面地址 |
|---|---|---|
| Android | `app/src/main/assets/h5/` | `https://h5.offline.test/index.html` |
| iOS | 以 folder reference 加入 bundle | `appoffline://h5/index.html` |
| 鸿蒙 | `entry/src/main/resources/rawfile/h5/` | `https://h5.offline.test/index.html` |

- Android / 鸿蒙：拦截该 host 的所有请求，从包内读文件
- iOS：`WKURLSchemeHandler` 不能接管 http/https，所以改用自定义 scheme。这个差异本身要记进 `compare.md`
- 包内有该文件 → 200，按扩展名给 MIME；没有 → 404，并打日志 `[OFFLINE_404] <url>`
- `.test` 是保留域名，不会被真实解析。拦截失效时页面会直接加载失败，便于发现

### JSBridge 协议（M4）

同一份 H5 跑在三端，端差异收敛在 `mock/h5/app.js` 的 `postToNative` 里。

**H5 → Native**：消息体是 JSON 字符串 `{"id":"1","method":"getDeviceInfo","params":{}}`

| 端 | Native 暴露方式 | H5 调用 |
|---|---|---|
| Android | `addJavascriptInterface(obj, "NativeBridge")`，方法加 `@JavascriptInterface` | `window.NativeBridge.postMessage(str)` |
| iOS | `userContentController.add(handler, name: "NativeBridge")` | `window.webkit.messageHandlers.NativeBridge.postMessage(str)` |
| 鸿蒙 | `javaScriptProxy` / `registerJavaScriptProxy`，name 为 `NativeBridge` | `window.NativeBridge.postMessage(str)` |

**Native → H5**：执行 JS（Android `evaluateJavascript` / iOS `evaluateJavaScript` / 鸿蒙 `runJavaScript`）

- 回调：`window.__bridgeCallback({ id, ok: true, data })` 或 `{ id, ok: false, error: { code, message } }`
- 推送：`window.__bridgeEvent({ event, data })`

Native 必须实现的方法：

| method | params | 返回 data |
|---|---|---|
| `getDeviceInfo` | — | `{ platform: "android" \| "ios" \| "harmony", osVersion, appVersion }` |
| `toast` | `{ text }` | `{}`，同时弹原生 toast |
| 其他任意 | — | `ok: false`，`code: "METHOD_NOT_FOUND"` |

Native 主动推送的事件：`appState`，`data: { state: "foreground" | "background" }`。

**安全**：只处理来自离线包 origin 的消息；加载其他页面时不注入、不响应。

### 白屏检测（M4）

| 触发 | 判定 | 日志 |
|---|---|---|
| 主文档加载完成后延迟 1s，执行 `(document.getElementById('app') \|\| {}).childElementCount \|\| 0` | 结果为 0 | `[WHITE_SCREEN] reason=empty_root url=...` |
| 渲染进程异常退出 | 回调触发即判定 | `[WHITE_SCREEN] reason=render_gone url=...` |
| 主文档加载失败 | 回调触发即判定 | `[WHITE_SCREEN] reason=load_error url=...` |

### H5 测试用例

在页面地址后加 `?case=<name>`：

| case | H5 行为 | 期望 |
|---|---|---|
| （无） | 正常渲染 | 不报白屏 |
| `blank` | 挂载前抛异常，`#app` 为空 | 报 `empty_root` |
| `missing` | 加载包内不存在的 `missing.js` | 报 `OFFLINE_404`，页面其余部分正常 |
| `slow` | 3s 后才渲染 | 1s 检测会误报。思考检测时机该怎么定，结论写进 notes |

---

## M0 环境

- [ ] 新建空工程，包名 / Bundle ID 统一为 `com.example.mobile3end`
- [ ] 模拟器上跑起来
- [ ] 真机上跑起来（iOS 用免费个人证书即可，鸿蒙需华为账号自动签名）
- [ ] 打一行自定义日志，并在 IDE 日志面板里按 tag 过滤出来
- [ ] 设一个断点，单步跑过去

## M1 UI、状态、路由

- [ ] 文件列表页：先用写死的 20 条数据，每行显示图标（按 `type`）、名称、大小、修改时间
- [ ] 点击一行跳到详情页，传 `id`；详情页显示完整字段，可返回
- [ ] 列表顶部有排序切换（名称 / 时间），切换后列表即时刷新
- [ ] 列表滚动到中间 → 进详情 → 返回，滚动位置不丢

## M2 网络、存储

- [ ] 列表数据改为请求 `/api/files.json`，放行明文 http
- [ ] 三种状态都有界面：加载中、失败（带重试按钮）、空列表
- [ ] 请求成功后把结果存到本地；下次启动先显示缓存，再后台刷新
- [ ] 排序选择持久化，重启 App 后保持
- [ ] 关掉 mock 服务启动 App：有缓存显示缓存，无缓存显示失败态

## M3 生命周期、线程

- [ ] 在页面 / 应用级各生命周期回调里打日志，切前后台、旋转屏幕，记录触发顺序到 notes
- [ ] 旋转屏幕（iOS / 鸿蒙若不触发重建，记录原因）后列表数据和排序不丢、不重新请求
- [ ] 刻意在主线程做一次网络或 sleep 2s 的操作，观察现象（崩溃 / 卡顿 / 警告），再改到后台线程
- [ ] 切后台 30s 再回前台，触发一次列表刷新

## M4 WebView 容器（重点）

- [ ] 新增 H5 页：从列表页入口进入，全屏 WebView，按上文的地址加载离线包
- [ ] **离线包 case（基线，三端已写好）**：离线包页面正常加载，能看到「离线包测试页」标题、`location` 是离线包地址，App 不崩。此时 bridge、白屏检测的空还没填，页面上 `getDeviceInfo` 显示失败是正常的
- [ ] 离线包拦截：包内资源 200 + 正确 MIME；包外资源 404 + `[OFFLINE_404]` 日志
- [ ] H5 页面显示 `getDeviceInfo` 的返回值，`platform` 正确
- [ ] H5 点按钮调 `toast`，弹出原生 toast，H5 收到成功回调
- [ ] 调一个不存在的方法，H5 收到 `METHOD_NOT_FOUND`
- [ ] App 切前后台，H5 页面上能看到 `appState` 事件
- [ ] 导航到非离线包页面（如 `https://example.com`），确认 bridge 不响应
- [ ] 白屏检测：`blank` / `missing` / 正常 三个 case 结果符合预期
- [ ] `slow` case：写出你认为合理的检测时机方案，并实现
- [ ] 开启 WebView 远程调试，用 Chrome DevTools / Safari Web Inspector / DevEco 调试工具连上，看到 Network 面板里的离线包请求
- [ ] 在 notes 回答：「离线包同源资源 404」这类问题，在我的实现里会在哪一步出现、日志长什么样

## M5 打包、异常采集

- [ ] 打出 release 包并安装到真机（Android APK / iOS 用 Xcode Archive 装到个人设备 / 鸿蒙 HAP）
- [ ] 捕获未处理异常：Native 侧和 H5 侧各刻意抛一次，日志里能看到堆栈
- [ ] release 包里的 Native 堆栈是混淆 / 符号化之前的样子吗？记录如何还原
- [ ] 记录 release 与 debug 包的体积差异及原因
