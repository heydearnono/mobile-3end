# 鸿蒙 M5 提示与答案：打包、异常采集

开始前：把 `entry/src/main/ets/common/Stage.ets` 改成 `STAGE = 5`。`EntryAbility.onCreate` 会调用 `installCrashReporter()`，列表页出现红色的「Native 崩溃」按钮。

分级提示、notes 记录规则同 `harmony-M1.md`。

只有 2 个空，都在 `crash/CrashReporter.ets`。M5-2 有本地单测；M5-1 依赖 `errorManager`，只能在设备上手工验。其余全是手工任务。

---

## M5-1 Native 未捕获异常钩子 · `crash/CrashReporter.ets`

<details><summary>提示 2</summary>

- `errorManager.on('error', observer)` 返回一个 observerId，存到模块级的 `observerId`；已经 >= 0 就直接 return
- `observer` 的类型是 `errorManager.ErrorObserver`，两个回调：`onUnhandledException(message: string)` 和 `onException(err: Error)`（后者有 `name` / `message` / `stack`）
- 用 `crashLog(...)` 拼日志，`Log.e` 打出来
</details>

<details><summary>答案</summary>

```ts
if (observerId >= 0) {
  return;
}
const observer: errorManager.ErrorObserver = {
  onUnhandledException(message: string): void {
    Log.e(`[CRASH] onUnhandledException ${message}`);
  },
  onException(err: Error): void {
    Log.e(crashLog(err.name, err.message, err.stack ?? ''));
  },
};
observerId = errorManager.on('error', observer);
Log.i(`CrashReporter: installed id=${observerId}`);
```
</details>

手工验收：
- [ ] 🔬 点「Native 崩溃」：日志里有 `[CRASH] Error: [M5] 故意抛出的 Native 异常` 和堆栈。App 还活着吗？（和 Android 的 `Thread.setDefaultUncaughtExceptionHandler` 对比：那边处理完进程照样会死）
- [ ] 🔬 不注册钩子时（临时把 `STAGE` 改回 4）再点一次：App 闪退，DevEco 的 FaultLog 面板（或 `hdc shell hidumper -s 1201 -a '-p Faultlogger'`，以实际为准）里能看到 `JS_ERROR` 记录

想一想：
- `errorManager.on('error')` 只管 ArkTS 主线程的异常。TaskPool 里抛的异常去哪了？（`taskpool.execute` 返回的 Promise 会 reject）Promise 没人 catch 的呢？查 `errorManager.on('unhandledRejection')`
- 对工作：线上 App 的鸿蒙端用的崩溃采集 SDK（如果有）是在哪一步注册的？比 `onCreate` 还早吗？为什么越早越好？

---

## M5-2 H5 未捕获异常 · `crash/CrashReporter.ets`

<details><summary>提示 2</summary>

`onConsole` 回调对页面里每一条 console 输出都会触发。浏览器内核对未捕获异常会自己打一条 error 级别、以 `Uncaught` 开头的消息；`H5_ERROR_HOOK_JS`（页面脚本执行前注入）会再打一条 `[H5_UNCAUGHT]` 开头、带堆栈的消息。其他 `console.error` 都是业务日志，不算异常。
</details>

<details><summary>答案</summary>

```ts
if (!isError || !(message.startsWith('Uncaught') || message.startsWith(H5_UNCAUGHT_PREFIX))) {
  return undefined;
}
return `[H5_ERROR] ${message} @ ${source}:${line}`;
```
</details>

手工验收：
- [ ] 🔬 打开 H5 → 点 blank：日志里有 `[H5_ERROR] Uncaught Error: [case=blank] simulated crash before mount @ https://h5.offline.test/app.js:9`，还有一条 `[H5_UNCAUGHT]` 带完整堆栈的
- [ ] 🔬 `missing.js load failed (expected)` 那条（`case=missing`）不应该被当成异常

想一想：
- 「Uncaught」那一条只有一行，为什么还要注入 `H5_ERROR_HOOK_JS`？`javaScriptOnDocumentStart` 和在 `onPageEnd` 里 `runJavaScript` 注入，时机差在哪？（`case=blank` 在 app.js 一执行就抛，晚了就抓不到）
- 跨域脚本（比如 CDN 上的 js）抛的异常，`e.error` 和 `message` 是什么？（`Script error.`，查 `crossorigin` 属性）
- 对工作：线上 App 的 H5 异常是 H5 自己上报（Sentry 之类）还是 Native 从 console 里捞？两者能对上吗？

---

## 手工任务 A：release 包 + 真机

1. DevEco：Build → Build Hap(s)/APP(s) → Build Hap(s)，右上角 Build Mode 选 release；或者命令行：

   ```sh
   hvigorw --mode module -p product=default -p buildMode=release assembleHap
   ```

2. 签名：release 包也要签名。自动签名生成的是调试证书，能装到注册过的真机上；上架要用 AppGallery Connect 申请的发布证书，学习项目不需要
3. 装到真机：`hdc install entry/build/default/outputs/default/entry-default-signed.hap`

## 手工任务 B：release 堆栈和还原

1. 🔬 release 包里点「Native 崩溃」，看 `[CRASH]` 日志里的堆栈：文件名、行号是 `.ets` 源码的吗？
2. 打开混淆再试：`entry/build-profile.json5` 里 release 的 `obfuscation.ruleOptions.enable` 改成 `true`（规则在 `entry/obfuscation-rules.txt`，模板默认开了属性、顶层、文件名、导出名混淆），重新打 release。🔬 堆栈里的函数名、文件名变成什么样了？
3. 还原：构建产物里有 sourcemap 和混淆名映射

   | 产物 | 位置（本机实测） |
   |---|---|
   | sourcemap | `entry/build/default/outputs/default/symbol/release/entry-sourceMaps.map`（release）、`.../mapping/sourceMaps.map` |
   | 混淆名映射 | 开了混淆后在 `entry/build/default/cache/default/default@CompileArkTS/esmodule/release/obfuscation/` 下的 nameCache（以实际为准） |

   DevEco 的 FaultLog 面板对本机构建的包会自动用这些文件还原堆栈；线上崩溃要把它们上传到 AGC（AppGallery Connect）的崩溃服务，或者用 hstack 工具（DevEco 命令行工具里，以你的版本为准）手动还原。

   🔬 记录：混淆前后的堆栈各贴一段，以及你用什么方法把混淆后的还原回来

想一想：
- 对照 Android 的 R8 + `mapping.txt` / iOS 的 dSYM：鸿蒙需要同时保留哪几样东西才能还原线上堆栈？每次发版都要存档吗？
- 混淆开了以后，`javaScriptProxy` 注册的 `postMessage` 方法名会被改掉吗？H5 那边还能调通吗？（提示：`-keep-property-name`，这是这类容器开混淆时最常见的线上事故）

## 手工任务 C：release 和 debug 的体积

本机实测（未签名，STAGE 不影响体积）：

| 包 | 大小 | `ets/modules.abc` | `ets/sourceMaps.map` |
|---|---|---|---|
| debug | 约 275 KB | 约 113 KB | 约 50 KB，打在包里 |
| release | 约 183 KB | 约 70 KB | 不在包里，单独放在 `symbol/` |

🔬 自己用 `unzip -l` 再量一遍（加了签名、开了混淆后数字会变），把差异和原因写进 notes：debug 的 abc 为什么大那么多？（提示：调试信息、字节码优化级别）sourcemap 为什么 release 不打进包？

想一想：
- 🔬 debug 包里开着 `setWebDebuggingAccess(true)`（M4 手工任务）。release 包里也开着吗？怎么做到只在 debug 开？（查 `BuildProfile.DEBUG` / `BuildProfile.BUILD_MODE_NAME`，hvigor 在编译时生成的常量）
- 对工作：线上包能连 DevTools 吗？测试同学排查白屏时用的是什么包？

---

## 收尾

M5 做完，更新 `compare.md` 的「M5 发布」四行（签名、混淆 / 符号、未捕获异常钩子）和 M4 里鸿蒙那一列。
