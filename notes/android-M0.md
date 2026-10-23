# Android M0

- 日期：2026-10-19
- 实际用时 / 时间盒：　h / 3h（Android 按 1.5 倍）
- 工具版本：Android Studio 2026.2（自带 JBR 25）、AGP 9.2.1、Gradle 9.4.1、Kotlin 2.2.10、Compose BOM 2026.09.00
- 设备：模拟器 `crab-api37`（Android 17 / API 37，arm64，google_apis）

## 验收

- [x] 新建空工程，包名 `com.example.mobile3end`
- [x] 模拟器上跑起来：冷启动 `am start -W` TotalTime 2895ms（debug 包、首次安装）
- [ ] 真机上跑起来
- [~] 自定义日志：命令行 `adb logcat -s M3E:D` 已看到 `MainActivity.onCreate sdk=37 restored=false`；IDE Logcat 面板用 `tag:M3E` 过滤待自己操作
- [ ] 断点单步：在 `MainActivity.onCreate` 的 `Log.d` 行打断点，Debug 运行

## 卡点

1. **命令行没有 Java** → `java -version` 报 Unable to locate a Java Runtime → 系统没装 JDK，只有 Android Studio 自带的 JBR → 命令行构建前 `export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"`。IDE 里不受影响。
2. **compileSdk 36.1 构建失败** → 报 `core-ktx:1.19.0 requires ... compile against version 37` → 新版 AndroidX 库会抬高 compileSdk 下限 → 改成 `release(37)`。targetSdk 保持 36 不动：compileSdk 只决定能调用哪些 API，targetSdk 才决定运行时行为。
3. **Compose UI 测试在 Android 17 上全挂**（搭 M1 检查脚本时遇到）→ `NoSuchMethodException: InputManager.getInstance` → `ui-test-junit4` 传递依赖的 Espresso 旧版用反射调了一个 Android 17 删掉的隐藏 API → 显式依赖 `espresso-core:3.7.0`。教训：依赖反射调隐藏 API 的库，在新系统版本上会直接坏掉，线上 App 的容器里的 WebView hack 也有同样风险。

## 和其他端的差异

- AGP 9 内置 Kotlin 编译，不再需要 `org.jetbrains.kotlin.android` 插件；但 Compose 编译器插件仍要单独加，版本必须等于 AGP 内置的 Kotlin 版本（2.2.10）
- 工程是 Gradle 多文件结构：`settings.gradle.kts`（仓库、模块）→ `build.gradle.kts`（插件声明）→ `app/build.gradle.kts`（真正的配置）→ `gradle/libs.versions.toml`（版本目录，类似 pnpm catalog）
- [ ] 同步到 compare.md

## 对工作的启发

- 线上 App 的 Android 包的 compileSdk / targetSdk 是多少？targetSdk 的升级会改变 WebView 的默认行为（如明文流量、文件访问），排查容器问题时要先看这两个值
