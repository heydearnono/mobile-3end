# 鸿蒙 M0 提示：环境、签名、日志、断点

M0 没有空，全是手工步骤。结果记到 `notes/harmony-M0.md`。

本机实测过的版本（2026-10-21）：DevEco Studio 26.0.0（DS-261.23567.138.36.2600851）、SDK HarmonyOS 26.0.0（API 26）、hvigor 6.26.8、ohpm 26.0.0.630、DevEco 自带 node v24.14.1、hdc 3.2.0f。

---

## 1. 打开工程

DevEco → Open → 选 `harmony/`。第一次打开会自动 `ohpm install` 和 Sync。

工程是照 DevEco「Empty Ability」模板手工搭的，和 IDE 新建出来的结构一样，对照 Android：

| 鸿蒙 | Android | 作用 |
|---|---|---|
| `AppScope/app.json5` | `AndroidManifest.xml` 的 `<manifest>` / `<application>` | bundleName、版本号、应用图标 |
| `entry/src/main/module.json5` | `AndroidManifest.xml` 的组件部分 | Ability 列表、权限、设备类型 |
| `build-profile.json5`（根） | `settings.gradle.kts` + 签名配置 | 模块列表、签名、targetSdk |
| `entry/build-profile.json5` | `app/build.gradle.kts` | 模块构建选项、混淆 |
| `oh-package.json5` | `libs.versions.toml` | 依赖（ohpm ≈ pnpm） |
| `hvigorfile.ts` | `build.gradle.kts` 里的插件 | 构建脚本，hvigor ≈ Gradle |

## 2. 命令行环境

命令行工具都在 DevEco 包里，不在 PATH 上。`check.sh` 已经设好了，自己在终端用的话：

```sh
export DEVECO=/Applications/DevEco-Studio.app/Contents
export NODE_HOME=$DEVECO/tools/node                 # hvigorw 是个 node 脚本，靠它找 node
export DEVECO_SDK_HOME=$DEVECO/sdk                  # 不设会报 00303217 Invalid value of 'DEVECO_SDK_HOME'
export JAVA_HOME=$DEVECO/jbr/Contents/Home          # 打包 / 签名调 java，不设会报 Unable to locate a Java Runtime
export PATH=$NODE_HOME/bin:$DEVECO/tools/ohpm/bin:$DEVECO/tools/hvigor/bin:$DEVECO_SDK_HOME/default/openharmony/toolchains:$PATH

hvigorw --mode module -p product=default assembleHap   # 编译出 entry/build/default/outputs/default/*.hap
hdc list targets                                         # 列出设备，[Empty] 就是没有
```

`hdc` 就是鸿蒙的 `adb`。

## 3. 模拟器

Tools → Device Manager → 新建手机模拟器（要先登录华为账号才能下载镜像）→ 启动。`hdc list targets` 能看到它就行。

## 4. 签名（模拟器和真机都要）

设备只能安装签名过的 HAP。命令行编出来的是 `*-unsigned.hap`，`check.sh` 会提示找不到签名包。

1. File → Project Structure → Project → Signing Configs
2. 勾选 Automatically generate signature，按提示登录华为账号
3. 真机要先连上（开发者模式 + USB 调试），自动签名会把设备 UDID 注册进调试证书

完成后根目录 `build-profile.json5` 的 `signingConfigs` 会被自动填上（证书默认生成在 `~/.ohos/config/` 下，以实际为准；密码是加密后的）。**这几行带着本机路径，不要提交**：提交前用 `git diff` 看一眼，或者干脆把这个改动留在本地。

想一想：
- 🔬 Android 的 debug 包用的是 SDK 自带的 debug.keystore，不用登录任何账号就能装。鸿蒙为什么连 debug 包都要绑华为账号和设备 UDID？（查「调试证书」「Profile」）
- 对工作：线上 App 的鸿蒙包被测试同学反馈「装不上」时，第一步该看什么？

## 5. 跑起来

工具栏选设备 → 绿色三角 Run。看到「我的文件」列表页会崩，因为 M1 的空还没填（这正常，Log 里能看到 `An operation is not implemented: M1-1`）。只想验证环境的话，先把 `model/FileItem.ets` 里 M1-1 的 `return TODO('M1-1');` 临时换成 `return item.id;`。

## 6. 日志

全工程用 `common/Log.ets` 打日志，tag 是 `M3E`。

- IDE：底部 Log → HiLog，选中设备和 `com.example.mobile3end` 进程，搜索框输入 `M3E`
- 命令行：`hdc hilog | grep M3E`

想一想：
- 🔬 把 `Log.ets` 里某个 `%{public}s` 改成 `%s`，debug 包和 release 包里分别打出来什么？鸿蒙为什么默认把日志参数当隐私？
- 对工作：线上 App 的鸿蒙端的线上日志里看到 `<private>`，是谁的问题？

## 7. 断点

在 `entryability/EntryAbility.ets` 的 `onCreate` 第一行打断点 → 工具栏的 Debug（小虫子）→ 停住后 F8 单步。

想一想：
- 🔬 断点打在 `pages/Index.ets` 的 `build()` 里，会停几次？切一次排序再停几次？对比 Compose 的重组
- ArkTS 编译成方舟字节码（.abc）跑在 ArkCompiler 上，断点是怎么对回 `.ets` 源码的？（M5 的 sourcemap 是同一件事）

## 下一步

环境通了之后先做 A1（ArkTS 语言专项，`./check.sh A1`，提示在 `harmony-A1.md`），再做 M1。A1 全是本地单测，不用模拟器和签名，这一节卡住的话也可以先做 A1。
