# 三端对照

> 每完成一个里程碑更新对应行。格式：具体 API / 类名 + 一句话差异。
> 预填项是起点，以实测为准，实测不符就改，并在 notes 里写明。

## M1–M3 基础

| 概念 | Vue（我熟悉的） | Android | iOS | 鸿蒙 |
|---|---|---|---|---|
| 语言 | TS | Kotlin | Swift | ArkTS |
| UI | SFC | Jetpack Compose | SwiftUI | ArkUI `@Component` |
| 组件内状态 | `ref` | `remember { mutableStateOf() }` | `@State` | `@State` |
| 跨页面状态 | Pinia | ViewModel + StateFlow | `@Observable` | `@Observed` / AppStorage |
| 列表 | `v-for` | `LazyColumn` | `List` | `List` + `ForEach` / `LazyForEach` |
| 路由 | vue-router | Navigation Compose | `NavigationStack` | `Navigation` + `NavPathStack` |
| 异步 | Promise | 协程 | async/await | Promise + TaskPool |
| 网络 | fetch | OkHttp / Retrofit | `URLSession` | `@ohos.net.http` |
| KV 存储 | localStorage | DataStore | `UserDefaults` | Preferences |
| 明文 http 放行 | — | | | |
| 应用生命周期 | — | | | |
| 页面生命周期 | `onMounted` / `onUnmounted` | | | |
| 主线程限制 | 单线程事件循环 | | | |
| 包管理 | pnpm | Gradle | SPM | ohpm |

## M4 WebView 容器

| 概念 | Android | iOS | 鸿蒙 |
|---|---|---|---|
| WebView 组件 | `WebView` | `WKWebView` | ArkWeb `Web` |
| 请求拦截 | `shouldInterceptRequest` | `WKURLSchemeHandler`（仅自定义 scheme） | `onInterceptRequest` |
| 能否拦截 http/https | | 否 | |
| H5 → Native | `addJavascriptInterface` | `WKScriptMessageHandler` | `javaScriptProxy` |
| Native → H5 | `evaluateJavascript` | `evaluateJavaScript` | `runJavaScript` |
| 注入时机（页面 JS 执行前是否可用） | | | |
| 页面加载完成回调 | | | |
| 主文档加载失败回调 | | | |
| 渲染进程退出回调 | | | |
| 远程调试 | Chrome `chrome://inspect` | Safari Web Inspector | |
| 校验消息来源 origin 的方式 | | | |

## M5 发布

| 概念 | Android | iOS | 鸿蒙 |
|---|---|---|---|
| 产物 | APK / AAB | IPA | HAP / APP |
| 签名 | | | |
| 代码混淆 / 符号 | | | |
| 未捕获异常钩子 | | | |
