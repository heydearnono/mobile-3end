# iOS M0 环境

M0 没有空，全是动手项。做完在 `notes/ios-M0.md` 记下版本号和卡点。

M0 做完、开始 M1 之前，先做 S1 Swift 语言专项（`hints/ios-S1.md`，约 2 小时，纯单测，`./check.sh S1`）。

开始前：`Mobile3End/App/Stage.swift` 里 `STAGE = 0`。

---

## 打开工程

```sh
open ios/Mobile3End.xcodeproj
```

- 工程由 `project.yml` 经 [xcodegen](https://github.com/yonaskolb/XcodeGen) 生成，两个都提交。日常只用 Xcode 改代码；**加 / 删文件、改 target 配置**时改 `project.yml`，再在 `ios/` 下执行 `xcodegen generate`（会覆盖 .xcodeproj 里手动改的配置）
- 对应关系：`project.yml` ≈ Android 的 `app/build.gradle.kts`；`.xcodeproj` 是 Xcode 真正读的东西，结构是一大坨 ID 引用，手改容易冲突，所以很多团队用 xcodegen / Tuist 生成
- 左侧蓝色文件夹 `h5` 是 `../mock/h5` 的 folder reference（M4 的离线包），黄色文件夹是 group

想一想：Android Studio 的 Gradle 工程和 Xcode 工程，哪个是「配置即代码」？线上 App 的 iOS 工程用的是哪种方式（CocoaPods / SPM / xcodegen / Tuist）？

---

## 模拟器上跑起来

顶部工具栏选 `Mobile3End` scheme + 一个 iPhone 模拟器，⌘R。看到「M0：工程跑起来了」即可。

命令行也行（`check.sh` 就是这么做的）：

```sh
xcodebuild -project Mobile3End.xcodeproj -scheme Mobile3End -destination 'platform=iOS Simulator,name=iPhone 17' build
```

想一想：🔬 冷启动耗时多少？Android 用 `am start -W`，iOS 可以在 Xcode 的 Instruments → App Launch 里看，或者先记个体感。

---

## 真机上跑起来（免费个人证书）

1. Xcode → Settings → Accounts，加自己的 Apple ID
2. 选中工程 → `Mobile3End` target → Signing & Capabilities → Team 选「你的名字 (Personal Team)」
3. 如果报 `Failed to register bundle identifier`：Bundle ID 全球唯一，`com.example.mobile3end` 可能已被别人的免费账号占了。临时改成 `com.example.mobile3end.<你的名字>`，**只在本机改，不提交**，并在 notes 记一笔
4. 手机：设置 → 隐私与安全性 → 开发者模式 → 打开（会重启）
5. 第一次装好后点图标会提示「不受信任的开发者」：设置 → 通用 → VPN 与设备管理 → 信任

免费证书的限制：签名 7 天过期（到期要重新 ⌘R 安装）、同时最多 3 个 App、不能用推送等能力。

想一想：
- Android 装 debug 包不需要任何账号，iOS 为什么连装到自己手机上都要签名？（提示：iOS 只运行 Apple 签过的代码，「开发证书 + 描述文件」是 Apple 给你的「这台设备上可以运行」的许可）
- 线上 App 的 iOS 的内测包是怎么分发的（TestFlight / 企业签 / Ad Hoc）？各自要什么条件？

---

## 自定义日志，按 tag 过滤

工程里统一用 `M3ELog.d("...")`（`App/Log.swift`），底层是 `os.Logger`，`category` 是 `M3E`，对应 Android 的 `Log.d(TAG, ...)`。

点「打一行日志」按钮，然后：

- **Xcode 控制台**：底部 Debug 区右下角的过滤框输入 `M3E`。Xcode 15 起控制台是结构化日志，可以点每行左边的 ⓘ 看 subsystem / category，过滤框也支持 `category:M3E`
- **命令行**（不连 Xcode 也能看，类似 `adb logcat -s M3E`）：

  ```sh
  xcrun simctl spawn booted log stream --level debug --predicate 'category == "M3E"'
  ```

- **真机**：Mac 上的「控制台」App，左侧选手机，搜索框输入 `category:M3E`

想一想：
- 🔬 把 `Log.swift` 里的 `privacy: .public` 删掉，用命令行或控制台 App 看，日志变成什么样？为什么 Xcode 里看还是正常的？（这就是线上排查时经常看到 `<private>` 的原因）
- `print()` 和 `os.Logger` 的区别：脱离 Xcode 后哪个还能看到？

---

## 断点单步

1. 打开 `UI/RootView.swift`，找到 `M0View` 里 `M3ELog.d("M0 button tapped ...")` 这一行，点行号打断点
2. ⌘R 运行，点按钮，停在断点上
3. 底部变量区看 `taps` 的值；在 `(lldb)` 里输入 `po taps`
4. F6 单步跳过（Step Over），F7 进入（Step Into），⌃⌘Y 继续

想一想：
- 🔬 断点右键 → Edit Breakpoint，加 Action「Log Message」并勾选「Automatically continue」：不停下来也能打日志，不用改代码重新编译。前端有对应的东西吗？（Chrome DevTools 的 logpoint）
- M4 里 Safari Web Inspector 调 H5 的断点，和这里 Xcode 调 Swift 的断点是同一个调试器吗？

---

## 命令行检查

```sh
cd ios
./check.sh M0
```

会自动挑一个 iPhone 模拟器（没启动就先启动），首次编译 1–2 分钟。M0 只有一个示例测试：App 能启动。
