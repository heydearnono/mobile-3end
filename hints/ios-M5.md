# iOS M5 提示与答案

开始前：把 `Mobile3End/App/Stage.swift` 里的 `STAGE` 改成 `5`。STAGE ≥ 5 时：

- 启动时安装异常钩子（`CrashReporter.install()`），并把上次崩溃留下的记录打出来
- 列表页右上角出现「崩溃」菜单

M5 只有 2 个空（两个异常钩子），其余是手工任务。`STAGE = 5` 一启动就会执行到 M5-1、M5-2，**先填空再手动运行**。`./check.sh M5` 不到 1 分钟。

---

## M5-1 NSException 钩子 · `Crash/CrashReporter.swift`

<details><summary>提示 2</summary>

```swift
NSSetUncaughtExceptionHandler { exception in ... }
```

参数类型是 `@convention(c) (NSException) -> Void`：闭包里只能用全局 / 静态的东西（`CrashReporter.handle`），不能捕获局部变量或 `self`。
</details>

<details><summary>答案</summary>

```swift
NSSetUncaughtExceptionHandler { exception in
    CrashReporter.handle(exception)
}
```
</details>

想一想：
- 🔬 写一个捕获了局部变量的闭包（如 `let tag = "x"; NSSetUncaughtExceptionHandler { _ in print(tag) }`），编译器报什么？为什么 C 函数指针不能带上下文？
- `NSSetUncaughtExceptionHandler` 只能设一个。App 里同时接了两个崩溃 SDK（比如公司自研的 + 第三方的），后装的会把先装的覆盖掉。怎么做才能都不丢？（先 `NSGetUncaughtExceptionHandler()` 存下旧的，自己处理完再调它）对应 Android 的 `Thread.setDefaultUncaughtExceptionHandler`，是同一个问题吗？

---

## M5-2 信号钩子 · `Crash/CrashReporter.swift`

<details><summary>提示 2</summary>

`for sig in signals { signal(sig, crashSignalHandler) }`。`crashSignalHandler` 是同一个文件里的全局函数，签名正好是 `(Int32) -> Void`。
</details>

<details><summary>答案</summary>

```swift
for sig in signals {
    signal(sig, crashSignalHandler)
}
```
</details>

想一想：
- 为什么 iOS 要两个钩子，Android（Java / Kotlin 层）一个就够？Swift 的数组越界、强解包 nil、`fatalError` 走的是哪一个？（提示：Swift 运行时错误不是异常，是 `brk` 指令 → `SIGTRAP`）Android 的 native（C++）崩溃又是怎么采集的？
- `crashSignalHandler` 最后为什么要 `signal(sig, SIG_DFL); raise(sig)`？不这么做会怎样？
- 注释里说信号处理函数里只能调 async-signal-safe 的函数，这里用了 `String`、`Thread.callStackSymbols`、文件写入，可能出什么问题？（死锁：崩溃时 malloc 的锁可能正被持有）

---

## 手工任务 1：刻意崩溃，看到堆栈

**不要连着 Xcode 测**：调试器会先接住异常 / 信号，停在崩溃那一行，钩子不执行。

1. `STAGE = 5`，⌘R 装到模拟器，然后点 Xcode 的 ■ 停止
2. 开命令行日志：`xcrun simctl spawn booted log stream --level debug --predicate 'category == "M3E"'`
3. 在模拟器里点图标启动，「崩溃」菜单 →「抛 NSException」：日志里有 `[CRASH] 未捕获的 NSException M3EDemoException` 和堆栈
4. 再启动一次：日志里有 `[CRASH] 上次运行崩溃了，现场记录`
5. 「Swift 数组越界」重复 3、4：这次是哪个钩子接住的？信号是几号？

想一想：
- 🔬 第 3 步之后，`~/Library/Logs/DiagnosticReports/` 里多了一个 `Mobile3End-*.ips`，这是系统生成的崩溃报告。打开看 `exception`、`termination`、出事线程的堆栈，和你自己记的比，多了什么？
- 为什么要写文件、下次启动再报，而不是崩溃时直接发网络请求？

## 手工任务 2：H5 侧异常

H5 里的 `window.onerror` / `unhandledrejection` 已经由 `Web/H5ErrorCapture.swift` 在页面脚本执行前注入（`.atDocumentStart`），转发到原生日志 `[H5_ERROR]`。

1. 「崩溃」菜单 →「H5 抛错（case=blank）」
2. Xcode 控制台：`[H5_ERROR] Error: [case=blank] simulated crash before mount @ appoffline://h5/app.js:9` + 堆栈
3. Safari Web Inspector 的 Console 里也有同一条

想一想：
- 🔬 如果 `app.js` 来自另一个 origin（比如 CDN），`window.onerror` 里拿到的 message 会变成什么？（`Script error.`，跨域脚本的错误信息被浏览器隐藏。要 `crossorigin` 属性 + CORS 头）这在线上 App 的 H5 的错误监控里遇到过吗？
- 原生崩溃和 H5 异常的区别：哪个会让 App 闪退？哪个只是页面坏了？对白屏率的影响分别是什么？

---

## 手工任务 3：Release 包与体积

```sh
cd ios
# Debug / Release 各构建一次（模拟器，不用签名）
xcodebuild -project Mobile3End.xcodeproj -scheme Mobile3End -configuration Debug   -destination 'generic/platform=iOS Simulator' -derivedDataPath build/size build
xcodebuild -project Mobile3End.xcodeproj -scheme Mobile3End -configuration Release -destination 'generic/platform=iOS Simulator' -derivedDataPath build/size build
du -sh build/size/Build/Products/*-iphonesimulator/Mobile3End.app
ls -la build/size/Build/Products/*-iphonesimulator/Mobile3End.app
```

想一想：
- 两个 `.app` 里各有哪些文件？Debug 包里的 `Mobile3End.debug.dylib`、`__preview.dylib` 是干什么的？（SwiftUI Preview 和「编辑后快速重新运行」用的）
- Release 小在哪：`-O` 优化、去掉调试用的 dylib、`DEBUG` 宏下的代码（`debugKillWebContentProcess`）没编进去……对比 Android：Debug APK 和 Release APK 的体积差主要来自 R8 混淆和压缩，iOS 有没有「混淆」这一步？
- 模拟器包是 arm64 的模拟器架构，和真机包不能通用。真机包（IPA）的体积要在 Archive 之后看，App Store 下载大小还会再经过 App Thinning

## 手工任务 4：真机 Archive（需要自己的 Apple ID）

免费个人证书可以 Archive，但不能导出 IPA 分发，只能装到自己登录了同一 Apple ID 的手机上。

1. 顶部设备选「Any iOS Device (arm64)」或你的手机
2. Product → Archive（用的是 Release 配置，见 `project.yml` 的 `archive.config`）
3. 完成后弹出 Organizer。免费账号的 Distribute App 里基本只有「Custom → Debugging」或「Release Testing」能用；最简单的装机方法是：Product → Scheme → Edit Scheme → Run → Build Configuration 改成 Release，然后 ⌘R 装到手机（别忘了改回 Debug）
4. 在手机上点开 App（不连 Xcode），触发「Swift 数组越界」，再打开一次 App

## 手工任务 5：符号化

1. 手机连 Mac，Xcode → Window → Devices and Simulators → 选手机 → View Device Logs，找到 Mobile3End 的崩溃
2. 看 App 自己记的 `[CRASH]` 堆栈（Mac 上「控制台」App 搜 `category:M3E`）：`Mobile3End` 那几行是函数名，还是 `0x... + 12345` 这样的地址？
3. 找到 dSYM：Organizer 里右键 Archive → Show in Finder → 显示包内容 → `dSYMs/Mobile3End.app.dSYM`
4. 手工符号化一行：

```sh
# 崩溃报告里 Binary Images 段 Mobile3End 那一行的起始地址 = load address
atos -arch arm64 -o Mobile3End.app.dSYM/Contents/Resources/DWARF/Mobile3End -l <load address> <帧地址>
# 查 dSYM 的 UUID，必须和崩溃报告里的 UUID 一致才能对得上
dwarfdump --uuid Mobile3End.app.dSYM
```

想一想：
- Release 包的 Native 堆栈是符号化之前的样子吗？（spec M5 第 3 条）`Thread.callStackSymbols` 在 Debug 包和 Release 包里打出来有什么不同？为什么？（Release 包安装时 strip 掉了符号表，`STRIP_INSTALLED_PRODUCT`）
- 系统的崩溃报告在 Xcode 里看是符号化好的，App 自己记的地址却不是。Xcode 做了什么？（本机有这次 Archive 的 dSYM，按 UUID 自动匹配）
- Android 的对应物：R8 的 `mapping.txt`（还原混淆的类名方法名）和 native 的带符号 `.so`。iOS 没有混淆，dSYM 对应的是哪一个？
- **对工作**：线上 App 每次发版的 dSYM 存在哪？崩溃平台按什么把崩溃和 dSYM 对上？Bitcode 时代 App Store 会重新编译，dSYM 要从 App Store Connect 下载，现在还需要吗？

---

## 验收

对照 spec M5，在 notes 里勾：

- release 包装到真机（或模拟器 Release 构建，真机做不了的写原因）
- Native 和 H5 各刻意抛一次，日志里有堆栈
- 符号化前后的堆栈对比，记录还原方法
- Debug / Release 体积差异及原因
- compare.md M5 表的 iOS 列补全
