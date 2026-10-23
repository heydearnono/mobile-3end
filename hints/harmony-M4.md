# 鸿蒙 M4 提示与答案：WebView 容器（重点）

开始前：把 `entry/src/main/ets/common/Stage.ets` 改成 `STAGE = 4`。列表页顶部出现「打开 H5」。

分级提示、notes 记录规则同 `harmony-M1.md`。M4 不许跳。

这一端和 Android 最像：同样能拦截 `https://`，同样用 `NativeBridge.postMessage`。所以空集中在「ArkWeb 的 API 长什么样」和三块重点逻辑（拦截器、bridge 分发、白屏判定）。**离线包拦截（M4-1 ~ M4-4）已经写好**（spec M4「离线包 case」），读懂即可；bridge、白屏各有一个完整方法要你写。

## 直达 H5 页（不用先做完 M1–M3）

正常入口是列表页的「打开 H5」，要 `STAGE >= 4`，而那时列表页会跑到 M1–M3 的空。调试离线包时用 Want 参数 `m3e.h5` 直接打开 H5 页，不渲染列表页、不看 STAGE：

```sh
# hdc 在 DevEco 里：/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc
hdc shell aa start -a EntryAbility -b com.example.mobile3end --ps m3e.h5 normal    # 正常页
hdc shell aa start -a EntryAbility -b com.example.mobile3end --ps m3e.h5 missing   # 值就是 ?case=，还有 blank / slow
hdc shell aa force-stop com.example.mobile3end                                     # 想从冷启动开始就先杀掉
hdc hilog -T M3E                                                                   # 看日志
```

- 要先装好 HAP（DevEco 里 Run 一次就行；`--ps` 传的是字符串参数，`--pb` 是布尔，测试用的 `m3e.sample` 就是布尔）
- App 已经在跑时，再 `aa start` 走 `onNewWant`，会重新加载直达页，所以换个 case 直接再敲一遍即可
- 实现：`EntryAbility` 看到 `m3e.h5` 就 `loadContent('pages/H5Entry')` 代替 `pages/Index`，`H5Entry` 里套一层 Navigation 直接压入 `H5Page`

此时（bridge、白屏的空还没填）应该看到：标题「离线包测试页 case=normal」，`location: https://h5.offline.test/index.html`，`bridge: none`，getDeviceInfo 一栏显示 `{"code":"NO_BRIDGE",...}`（红色）。这就是离线包 case 的基线，App 不崩。

## 一进 H5 页就会执行到哪些空

| 时机 | 走到的代码 | 现状 |
|---|---|---|
| 每个请求 | `onInterceptRequest` → M4-4 → M4-3 → M4-2 → M4-1 | 已写好 |
| H5 mount 后立刻调 `getDeviceInfo` | `NativeBridgeProxy.postMessage`（M4-6）→ `BridgeDispatcher.handle`（M4-5） | 空，`M4_BRIDGE = false` 时不注册 bridge，走不到 |
| 主文档加载完成 `onPageEnd` | `WhiteScreenMonitor.onPageEnd`（M4-7，里面用 M4-9） | 空，`M4_WHITE_SCREEN = false` 时不检测，只打一行日志 |
| 资源加载失败 `onErrorReceive` | `WhiteScreenMonitor.onErrorReceive`（M4-8） | 同上 |
| H5 打 console | `h5ErrorLine`（M5-2） | M5 的空，`STAGE < 5` 时不调 |

TODO 会 throw。这些都是 ArkUI / ArkWeb 在主线程上的回调，ArkTS 里没接住的异常一般会变成 JS Crash、App 直接退出（M5 之前没注册 `errorManager`）；`javaScriptProxy` 方法里抛异常 ArkWeb 会怎么处理，文档没写，还没在设备上实测过（🔬 可以自己试：打开 `M4_BRIDGE` 但先不填 M4-6）。稳妥起见 `common/Stage.ets` 里有两个开关，默认关着：

- `M4_BRIDGE`：**填完 M4-5、M4-6 后改成 `true`**。关着时 `onControllerAttached` 里不调 `registerJavaScriptProxy`，H5 看到 `bridge: none`
- `M4_WHITE_SCREEN`：**填完 M4-7 ~ M4-9 后改成 `true`**。关着时不建 `WhiteScreenMonitor`，`onPageEnd` 打 `M4_WHITE_SCREEN 关着，不做白屏检测`

本地单测直接测纯逻辑，不看这两个开关；`H5Page` 的 `bridgeEnabled` / `whiteScreenEnabled` 也可以显式传。

## 检查范围

- M4-1 ~ M4-3（已写好）、M4-5、M4-7 ~ M4-9 是纯逻辑（`web/` 目录），本地单测
- M4-4（已写好，`WebResourceResponse`）、M4-6（bridge 胶水）在 `view/H5Page.ets` 里，ArkWeb 在本地单测里是空壳，靠下面的手工验收
- 设备测试 `m4_0_offlinePageLoads`（ohosTest，示例）：用直达入口打开离线包页，断言 `#app` 有子元素、`location.href` 以 `https://h5.offline.test/index.html` 开头。需要模拟器 / 真机且已签名，`check.sh M4` 会自动跑
- 建议顺序：先读 M4-1 → M4-4（已写好），用直达入口确认页面能打开 → M4-5 → M4-6 → 打开 `M4_BRIDGE`（bridge 通了）→ M4-7 → M4-8 → M4-9 → 打开 `M4_WHITE_SCREEN`

---

## 手工任务 A：离线包从哪来

rawfile 只能放在 `entry/src/main/resources/rawfile/` 里，不能引用工程外的文件（Android 的 assets 也一样）。所以 `harmony/sync-h5.sh` 用 rsync 把 `mock/h5/` 同步到 `rawfile/h5/`：

- `check.sh` 每次都会先同步
- 在 DevEco 里直接点 Run 的话，改过 `mock/h5` 先手动跑一次 `./sync-h5.sh`
- `rawfile/h5/` 在 `.gitignore` 里，**`mock/h5` 是唯一来源**，不要改同步过来的那份

想一想：🔬 用 `unzip -l entry/build/default/outputs/default/*.hap` 看看 HAP 里 rawfile 放在哪、是不是原样打进去的。线上 App 的离线包是打进安装包，还是运行时下载到沙箱？如果是后者，读文件那一步要换成什么 API？

---

## M4-1 取 origin · `web/OfflinePackage.ets`（已写好，读懂即可）

思路：用正则 `^([a-zA-Z][a-zA-Z0-9+.-]*)://([^/?#]*)` 取出 scheme 和 authority。authority 里如果有 `@`，前面是 userinfo（`user:pass@`），真正的 host 在最后一个 `@` 后面。最后整体转小写。

为什么不用 `url.URL.parseURL`：本地单测里系统 API 是空壳，跑不起来；另外手写一遍才知道 origin 校验有哪些坑。

代码（已在 `originOf` 里）：

```ts
const m = url.match(new RegExp('^([a-zA-Z][a-zA-Z0-9+.-]*)://([^/?#]*)'));
if (m === null) {
  return '';
}
let authority = m[2];
const at = authority.lastIndexOf('@');
if (at >= 0) {
  authority = authority.substring(at + 1);
}
return `${m[1]}://${authority}`.toLowerCase();
```

想一想：
- 测试 `m4_1_originOfLookalikes` 里的三个 URL，如果用 `url.startsWith('https://h5.offline.test')` 判断，哪几个会被误放行？线上 App 的容器里校验来源用的是 startsWith、host 白名单，还是别的？
- 端口：`https://h5.offline.test:443/` 的 origin 应该是什么？这份实现会返回什么？要不要管？

---

## M4-2 离线包 URL → 包内路径 · `web/OfflinePackage.ets`（已写好，读懂即可）

步骤：

1. `originOf(url) !== OFFLINE_ORIGIN` → `undefined`
2. 去掉 `scheme://host`，剩下的部分从第一个 `/`、`?`、`#` 开始
3. 切掉 `?` 和 `#` 之后的内容，去掉开头的 `/`
4. 空串或以 `/` 结尾 → 补 `index.html`
5. `decodeURIComponent`，抛异常就返回未解码的

代码（已在 `offlinePathOf` 里）：

```ts
if (originOf(url) !== OFFLINE_ORIGIN) {
  return undefined;
}
const rest = url.substring(url.indexOf('://') + 3);
const slash = rest.search(new RegExp('[/?#]'));
let path = slash < 0 ? '' : rest.substring(slash);
const cut = path.search(new RegExp('[?#]'));
if (cut >= 0) {
  path = path.substring(0, cut);
}
if (path.startsWith('/')) {
  path = path.substring(1);
}
if (path === '' || path.endsWith('/')) {
  path += 'index.html';
}
try {
  return decodeURIComponent(path);
} catch (e) {
  return path;
}
```

想一想：`?case=blank` 被切掉了，页面怎么还能读到 `case`？（拦截器只管「返回哪个文件」，`location.search` 是浏览器从地址栏 URL 上读的）

---

## M4-3 决定怎么回答 · `web/OfflinePackage.ets`（已写好，读懂即可）

规则：

- `offlinePathOf` 返回 `undefined` → 返回 `undefined`（放行）
- `path.split('/')` 里有 `'..'` → 404，**不要调用 read**
- `read(\`${RAWFILE_DIR}/${path}\`)` 为 `undefined` → 404，log 里放**完整的 url**（带 query），排查时才知道是哪个页面、哪个版本请求的
- 否则 200，`mimeOf(path)`

代码（已在 `resolveOffline` 里）：

```ts
const path = offlinePathOf(url);
if (path === undefined) {
  return undefined;
}
const notFound = new OfflineResponse(404, 'Not Found', 'text/plain', undefined, `${LOG_OFFLINE_404} ${url}`);
if (path.split('/').indexOf('..') >= 0) {
  return notFound;
}
const data = read(`${RAWFILE_DIR}/${path}`);
if (data === undefined) {
  return notFound;
}
return new OfflineResponse(200, 'OK', mimeOf(path), data, '');
```

想一想：
- `%2e%2e` 解码后就是 `..`。测试 `m4_3_pathTraversalIsBlocked` 第二个 URL 能被挡住，是因为 M4-2 先解码了。如果先判 `..` 再解码呢？
- 拦截失效（返回 null）时，`https://h5.offline.test` 会被当成真实域名去 DNS 解析，`.test` 是保留域名解析不到，页面直接白屏。线上 App 真实的离线包域名是真实可解析的吗？拦截失效时用户看到的是什么？

---

## M4-4 组装 WebResourceResponse · `view/H5Page.ets`（已写好，读懂即可）

完整方法，没有单测（ArkWeb 在本地单测里是空壳，`new WebResourceResponse()` 能创建但方法都是 undefined），设备测试 `m4_0_offlinePageLoads` 和直达入口能看到它的效果。

步骤：

1. `event.request.getRequestUrl()` 拿 URL
2. `resolveOffline(url, (p: string) => this.readRawfile(p))`，`undefined` → `return null`
3. `result.log` 非空 → `Log.w(result.log)`
4. `new WebResourceResponse()`，依次 `setResponseData`（`ArrayBuffer`；404 时没有数据，给空串）、`setResponseEncoding('utf-8')`、`setResponseMimeType`、`setResponseCode`、`setReasonMessage`、`setResponseIsReady(true)`

代码（已在 `interceptRequest` 里）：

```ts
const url = event.request.getRequestUrl();
const result = resolveOffline(url, (p: string) => this.readRawfile(p));
if (result === undefined) {
  return null;
}
if (result.log !== '') {
  Log.w(result.log);
}
const resp = new WebResourceResponse();
resp.setResponseData(result.data ?? '');
resp.setResponseEncoding('utf-8');
resp.setResponseMimeType(result.mime);
resp.setResponseCode(result.status);
resp.setReasonMessage(result.reason);
resp.setResponseIsReady(true);
return resp;
```

想一想：
- `onInterceptRequest` 是同步回调，`readRawfile` 用的是 `getRawFileContentSync`，在哪个线程执行？大文件（几 MB 的 js）会卡什么？（提示：查 `setResponseIsReady(false)` 的用法，以及 ArkWeb 的 `WebSchemeHandler`）
- Android 的 `shouldInterceptRequest` 跑在 WebView 的 IO 线程，鸿蒙这里呢？差异记进 compare.md
- 对工作：「离线包同源资源 404」，在你的实现里会在哪一步出现、日志长什么样？（spec M4 最后一条，答案写进 notes）

---

## M4-5 bridge 分发 · `web/Bridge.ets`

完整方法。

<details><summary>提示 2</summary>

顺序很重要：
1. `!isTrustedPage(pageUrl)` → 打 warn，返回 `undefined`。**先校验来源，再碰消息内容**
2. `JSON.parse` 放 try / catch 里；`req === null`（消息是 `"null"`）或 `typeof req.id !== 'string'` → 返回 `undefined`
3. `switch (req.method)`：
   - `'getDeviceInfo'` → `callbackOk(req.id, this.env.deviceInfo())`
   - `'toast'` → `req.params?.['text']`，不是字符串就用 `''`，调 `this.env.toast`，`callbackOk(req.id, {})`（空对象也要有类型，文件里有 `ToastResult`）
   - 其他 → `callbackError(req.id, ERR_METHOD_NOT_FOUND, \`method ${req.method} not found\`)`
</details>

<details><summary>答案</summary>

```ts
if (!isTrustedPage(pageUrl)) {
  Log.w(`bridge: 忽略来自 ${pageUrl} 的消息`);
  return undefined;
}
let req: BridgeRequest;
try {
  req = JSON.parse(raw) as BridgeRequest;
} catch (e) {
  Log.w(`bridge: 消息不是 JSON ${raw}`);
  return undefined;
}
if (req === null || typeof req.id !== 'string') {
  Log.w(`bridge: 消息没有 id ${raw}`);
  return undefined;
}
switch (req.method) {
  case 'getDeviceInfo':
    return callbackOk(req.id, this.env.deviceInfo());
  case 'toast':
    const text = req.params?.['text'];
    this.env.toast(typeof text === 'string' ? text : '');
    const empty: ToastResult = {};
    return callbackOk(req.id, empty);
  default:
    return callbackError(req.id, ERR_METHOD_NOT_FOUND, `method ${req.method} not found`);
}
```
</details>

想一想：
- 返回值是「要执行的 JS 字符串」，而不是直接调 `runJavaScript`。这样拆的好处是什么？（看测试是怎么写的）
- `callbackOk` 里 `JSON.stringify` 的结果直接拼进 JS 源码。如果 `data` 里有用户输入的字符串（比如文件名里带 `</script>`，或者 U+2028 行分隔符），会出问题吗？

---

## M4-6 bridge 胶水 · `view/H5Page.ets`

<details><summary>提示 2</summary>

- 当前页面 URL：`this.controller.getUrl()`
- `this.dispatcher.handle(message, url)`，返回 `undefined` 就什么都不做
- 否则 `this.controller.runJavaScript(js)`，返回 Promise，`.catch` 打日志
</details>

<details><summary>答案</summary>

```ts
const js = this.dispatcher.handle(message, this.controller.getUrl());
if (js === undefined) {
  return;
}
this.controller.runJavaScript(js).catch((e: Error) => Log.e(`bridge: runJavaScript 失败 ${e.message}`));
```
</details>

想一想：
- `getUrl()` 拿到的是「发消息那一刻的页面 URL」吗？如果页面里嵌了一个 `https://example.com` 的 iframe，iframe 里调 `NativeBridge.postMessage`，`getUrl()` 返回什么？Android 的 `addJavascriptInterface` 有同样的问题吗？（这是 bridge 安全里最常见的洞）
- 已经有一层：`H5Page.ets` 的 `registerBridge` 里，`registerJavaScriptProxy` 的最后一个参数 `permission` 只允许 `https://h5.offline.test` 调用。🔬 把 `bridgePermission()` 里的 host 改错，H5 页面上点按钮会看到什么？日志里搜 `Jsb Permission Denied`
- spec 说「加载其他页面时不注入」。现在是在 `onControllerAttached` 里注册一次（和 Web 的 `.javaScriptProxy(...)` 属性效果一样），之后所有页面都有（包括 example.com），🔬 在 example.com 的 DevTools Console 里输入 `window.NativeBridge` 看看。要做到真正不注入，可以怎么改？（提示：`deleteJavaScriptRegister` + `onPageBegin` 里判断 URL，注意「注册 / 删除都是下次加载才生效」）

---

## M4-7 白屏检测主流程 · `web/WhiteScreen.ets`

完整方法。

<details><summary>提示 2</summary>

```ts
const round = this.round;
const check = async (elapsed: number): Promise<void> => {
  // 1. round 变了就 return（等待期间开始了新页面）
  // 2. await this.host.evaluate(ROOT_CHILD_COUNT_JS)，用 parseChildCount 转成数字
  // 3. await 期间 round 也可能变，再判一次
  // 4. this.policy(elapsed, count)：WHITE → this.report(REASON_EMPTY_ROOT, url)；RETRY → 再 schedule 一次 check(elapsed + CHECK_DELAY_MS)
};
this.host.schedule(CHECK_DELAY_MS, () => check(CHECK_DELAY_MS));
```
</details>

<details><summary>答案</summary>

```ts
const round = this.round;
const check = async (elapsed: number): Promise<void> => {
  if (round !== this.round) {
    return;
  }
  const count = parseChildCount(await this.host.evaluate(ROOT_CHILD_COUNT_JS));
  if (round !== this.round) {
    return;
  }
  const decision = this.policy(elapsed, count);
  if (decision === CheckDecision.WHITE) {
    this.report(REASON_EMPTY_ROOT, url);
  } else if (decision === CheckDecision.RETRY) {
    this.host.schedule(CHECK_DELAY_MS, () => check(elapsed + CHECK_DELAY_MS));
  }
};
this.host.schedule(CHECK_DELAY_MS, () => check(CHECK_DELAY_MS));
```
</details>

想一想：
- 🔬 `onPageEnd` 对 `?case=missing` 会触发几次？对一个 302 重定向的页面呢？如果 `onPageEnd` 触发了两次，这份实现会排两次检测吗？会报两次吗？
- `runJavaScript` 的结果为什么是字符串？`(document.getElementById('app') || {}).childElementCount || 0` 返回 `3` 时，`evaluate` 拿到的是 `"3"`；脚本抛异常时呢？
- 对工作：线上 App 的白屏检测是「Native 定时注入 JS 查 DOM」，还是「H5 自己上报首屏完成」？两种各在什么情况下漏报 / 误报？

---

## M4-8 只算主文档 · `web/WhiteScreen.ets`

<details><summary>提示 2</summary>

ArkWeb 的 `onErrorReceive` 对每个加载失败的请求都会回调，包括图片、脚本、iframe。`H5Page.ets` 已经用 `event.request.isMainFrame()` 把这个信息传进来了。
</details>

<details><summary>答案</summary>

```ts
if (isMainFrame) {
  this.report(REASON_LOAD_ERROR, url);
}
```
</details>

想一想：
- 🔬 `?case=missing` 时，`missing.js` 返回的是 404（拦截器给的），`onErrorReceive` 会触发吗？什么样的失败才算「error」？（试试点「不存在的离线页」和「example.com」并断网）还有一个回调 `onHttpErrorReceive`，它和 `onErrorReceive` 的分工是什么？
- Android 的 `onReceivedError(request, error)` 也是对所有资源都回调吗？（API 23 之前和之后不一样）

---

## M4-9 slow case 的检测时机 · `web/WhiteScreen.ets`

这个空没有唯一答案，先想清楚再写，方案和理由写进 notes。

<details><summary>提示 2</summary>

spec 的 1s 单次检测在 `case=slow`（3s 才渲染）下必然误报。思路有几种：
- 轮询到截止时间：每秒查一次，有内容就 OK，到 5s 还是空才判白屏（测试默认按这个写）
- H5 主动上报首屏完成，Native 只做兜底超时
- 用 `MutationObserver` 在页面里等 `#app` 有子节点
- 结合 `onFirstMeaningfulPaint` / `onLargestContentfulPaint` 之类的渲染回调（查 ArkWeb 有没有）

测试只卡三条底线，见代码注释。
</details>

<details><summary>参考答案（轮询到截止时间）</summary>

```ts
if (childCount > 0) {
  return CheckDecision.OK;
}
return elapsedMs >= SLOW_DEADLINE_MS ? CheckDecision.WHITE : CheckDecision.RETRY;
```
</details>

想一想：轮询方案下，`case=blank` 要 5s 才报出来，比 spec 的 1s 慢了。白屏率指标会因此变好还是变差？线上用的阈值是多少？

---

## 手工任务 B：远程调试

1. `view/H5Page.ets` 的 `aboutToAppear` 里，注释「M4 手工任务」那一行，加上：

   ```ts
   webview.WebviewController.setWebDebuggingAccess(true);
   ```

   和 Android 的 `WebView.setWebContentsDebuggingEnabled(true)` 一样，是全局开关，应该只在 debug 包里开（M5 想一想）。

2. 打开 H5 页，然后：

   ```sh
   hdc shell "cat /proc/net/unix | grep devtools"     # 找到 @webview_devtools_remote_<数字>
   hdc fport tcp:9222 localabstract:webview_devtools_remote_<数字>
   ```

3. Chrome 打开 `chrome://inspect/#devices`，Configure 里确认有 `localhost:9222`，Remote Target 里点 inspect
4. 🔬 Network 面板刷新，看离线包请求：状态码、MIME、`missing.js` 的 404。和 Android 那边看到的有什么不一样？

数字是 Web 所在进程的 pid，App 每次重启都会变，所以每次都要重新 fport。DevEco 也有内置的「ArkWeb 调试」入口，可以试试哪个顺手（以你的 DevEco 版本为准）。

---

## 手工验收（对照 spec M4）

- [ ] 离线包 case（基线，已写好）：直达入口 `--ps m3e.h5 normal` 打开，看到「离线包测试页」标题、`location` 是 `https://h5.offline.test/index.html`，App 不崩；`bridge: none`、getDeviceInfo 显示 `NO_BRIDGE` 是正常的（两个开关还关着）
- [ ] 列表页「打开 H5」→ 全屏 H5，地址是 `https://h5.offline.test/index.html`
- [ ] 以下 bridge 几条要先打开 `M4_BRIDGE`，白屏几条要先打开 `M4_WHITE_SCREEN`
- [ ] 离线包：DevTools 里 `index.html` / `app.js` / `style.css` 都是 200，MIME 正确；`?case=missing` 时日志有 `[OFFLINE_404] https://h5.offline.test/missing.js`，页面其余部分正常
- [ ] 页面上 getDeviceInfo 显示 `platform: "harmony"`，`bridge:` 一行显示 `android-or-harmony`
- [ ] 点 toast：弹原生 toast，H5 日志 `toast ok {}`
- [ ] 点「不存在的方法」：H5 日志 `METHOD_NOT_FOUND`
- [ ] 上滑回桌面再回来：H5 日志里有 `event appState {"state":"background"}` / `foreground`（需要 `STAGE >= 3`，M3-3 填过）
- [ ] 点 example.com：bridge 不响应（日志 `bridge: 忽略来自 ...` 或 `Jsb Permission Denied`）
- [ ] 白屏：`blank` 报 `[WHITE_SCREEN] reason=empty_root`，`missing` 和正常不报；「不存在的离线页」是 404，算不算白屏？记下你观察到的结果
- [ ] `slow`：按你在 M4-9 的方案不误报，并在 notes 写出理由
- [ ] 远程调试连上，Network 面板看到离线包请求
- [ ] notes：「离线包同源资源 404」在你的实现里出现在哪一步、日志长什么样
