# iOS M1 提示与答案

**先做 S1**（Swift 语言专项，`hints/ios-S1.md`，约 2 小时）。M1 里的 `sorted { a, b in }`、`if let`、`@Binding`、`$path` 都在 S1 里讲过，没做 S1 直接做 M1 容易卡在语法上。

开始前：把 `Mobile3End/App/Stage.swift` 里的 `STAGE` 改成 `1`。

每个空分三级：**提示 1** 在代码注释里；**提示 2** 和 **答案** 在下面，折叠着，卡住超过 10 分钟再展开。展开过答案的，在 `notes/ios-M1.md` 记一笔。

「想一想」不算分，答案写进 notes。带 🔬 的是要动手实测的。

这一端是「迁移」：Android 上学过的排序规则、key、返回栈，这里不再挖空，空集中在 SwiftUI 和 Compose 不一样的地方。

```sh
cd ios
./check.sh M1     # 首次编译 1–2 分钟，之后约 1 分钟
```

列表页一显示就会调到 M1-1 和 M1-3，所以 **M1-1、M1-3 填完之前，所有 UI 测试都会显示「运行到了未填的 M1-1 / M1-3」**。建议顺序：M1-1 → M1-3 → M1-2 → M1-4 → M1-5 → M1-6。

Xcode 里函数名标红多半是拼错了，Swift 不需要像 Kotlin 那样逐个 import 函数。按 ⌘B 编译看报错，⌘R 运行。

---

## M1-1 文件夹在前 + 按名称 / 时间排序 · `Model/FileItem.swift`

<details><summary>提示 2</summary>

`sorted { a, b in ... }` 的闭包返回「a 是否应该排在 b 前面」。先判断两个是不是一个文件夹一个文件：是的话，文件夹在前；不是的话，再按 `order` 比名称（`<`）或时间（`>`）。
</details>

<details><summary>答案</summary>

```swift
files.sorted { a, b in
    let aFolder = a.type == .folder
    let bFolder = b.type == .folder
    if aFolder != bFolder { return aFolder }
    switch order {
    case .name: return a.name < b.name
    case .time: return a.mtime > b.mtime
    }
}
```
</details>

想一想：
- Kotlin 用 `compareBy { }.then { }` 组合比较器，Swift 标准库没有这个，要手写。哪种更容易写错？测试 `m1_1_sampleData_sameAsAndroid` 是为了防什么？
- Swift 的 `sorted` 是稳定排序吗？（查文档，结论和 Kotlin 的 `sortedWith` 对比一下）
- `a.name < b.name` 按什么规则比？为什么「会议录音.m4a」排在「budget-2026.xlsx」后面？线上 App 的文件列表按名称排序用的是这种规则吗？（提示：`localizedStandardCompare`）

---

## M1-2 切换排序 · `UI/FileListScreen.swift`

<details><summary>提示 2</summary>

`order` 是 `@Binding var`，在 `View` 里可以直接赋值，像普通变量一样。两个值之间切换，三元表达式一行写完。
</details>

<details><summary>答案</summary>

```swift
order = order == .name ? .time : .name
```
</details>

想一想：
- 状态的主人在哪？M1 是 `RootView` 的 `@State private var m1Order`，`FileListScreen` 只借了一个 `@Binding`。对应 Compose 里的什么写法？（提示：状态提升，`value` + `onValueChange`）
- 🔬 把 `RootView` 里的 `@State` 去掉，只写 `private var m1Order: SortOrder = .name`，能编译吗？为什么 SwiftUI 的 View 是 struct，却能「改状态」？
- Android 的 `rememberSaveable` 在 Activity 重建后保持排序，iOS 上对应要考虑的场景是什么？（旋转屏幕不会重建，见 M3；被系统杀掉后恢复要用 `@SceneStorage`）

---

## M1-3 排好序的列表 · `UI/FileListScreen.swift`

<details><summary>提示 2</summary>

就是调一下 M1-1 写的函数。SwiftUI 会在 `order` 变化时重新执行 `body`，`body` 里调了这个函数，所以列表自然就更新了。
</details>

<details><summary>答案</summary>

```swift
sortFiles(files, order)
```
</details>

想一想：
- Compose 用 `remember(files, order) { }` 缓存排序结果，SwiftUI 没有对应的东西。每次 `body` 执行都重新排一遍，代价大吗？什么时候需要优化，怎么优化？（提示：把排好序的结果放进 `@Observable` 的 model 里）
- `List(sorted(files))` 没写 key，SwiftUI 用什么区分每一行？（提示：`FileItem` 声明了 `Identifiable`）。对比 Android M1-5 的 `key = { it.id }`

---

## M1-4 跳到详情页 · `UI/RootView.swift`

<details><summary>提示 2</summary>

`NavigationStack(path: $path)` 把返回栈交给了一个数组。往数组里 `append` 一个 `Route.detail(id:)`，栈上就多了一页；`.navigationDestination(for: Route.self)` 负责把 `Route` 变成页面。
</details>

<details><summary>答案</summary>

```swift
path.append(.detail(id: file.id))
```
</details>

想一想：
- Android 是 `navController.navigate("detail/${id}")`，字符串路由；这里是 `enum Route`，编译期类型检查。类比 vue-router：哪个像 `router.push('/detail/1')`，哪个像 `router.push({ name: 'detail', params: { id } })`？
- 🔬 快速连点同一行两次，会进两层详情页吗？和 Android 的结果（`launchSingleTop`）对比
- 为什么只传 `id` 而不是整个 `FileItem`？（提示：路由要能被持久化 / 从外部链接打开。线上 App 的 H5 页里的 `scheme://` 跳转也是同一个道理）

---

## M1-5 按 id 找文件 · `UI/RootView.swift`

<details><summary>提示 2</summary>

`Array` 上有 `first(where:)`，尾随闭包写法是 `xs.first { ... }`，找不到返回 `nil`。
</details>

<details><summary>答案</summary>

```swift
currentFiles.first { $0.id == id }
```
</details>

想一想：Android 版直接用 `SampleData.find(id)`，这里从 `currentFiles` 里找（M2 起是网络数据）。如果详情页打开期间列表刷新了、这个文件被删了，详情页会显示什么？

---

## M1-6 返回 · `UI/FileListScreen.swift`

<details><summary>提示 2</summary>

`FileDetailScreen` 里有 `@Environment(\.dismiss) private var dismiss`。它是一个可以直接调用的值（`callAsFunction`）。
</details>

<details><summary>答案</summary>

```swift
dismiss()
```
</details>

想一想：
- 另一种写法：把 `path` 的 Binding 传进详情页，调 `path.removeLast()`。两种写法各适合什么场景？`dismiss` 对 sheet 弹出的页面也有效吗？
- 🔬 左上角系统自带的返回按钮和右滑返回手势，会调你写的 `back()` 吗？那它们改的是什么？（提示：断点打在 `RootView` 里，看 `path`）
- Android 的 M1-8 测试查的是返回栈；这里测试检查的是「导航栏上没有返回按钮了」，为什么能说明回到了根页面？

---

## 验收（手动）

`STAGE = 1`，⌘R 运行，对照 spec M1 逐条：

- 20 条数据、图标 / 名称 / 大小 / 时间都在
- 点一行进详情，详情页字段完整，右上角「返回列表」和左上角返回都能回去
- 切排序，列表即时刷新
- 滑到中间 → 进详情 → 返回，位置不丢（`m1_e2e_backKeepsScrollPosition`）

想一想：
- 🔬 Android 上滚动位置能保持，靠的是 `rememberLazyListState` + `NavHost` 保存状态。iOS 上你什么都没写，为什么位置也在？（提示：push 详情页时，列表页的 UIKit 视图还在不在内存里）
- 🔬 旋转屏幕（模拟器 ⌘← / ⌘→），排序和滚动位置丢了吗？和 Android 的 Activity 重建对比，结论记到 notes，M3 还会再看一次
