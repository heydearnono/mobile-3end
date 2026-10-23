# 鸿蒙 M3 提示与答案

开始前：把 `entry/src/main/ets/common/Stage.ets` 改成 `STAGE = 3`。列表页顶部会出现「主线程卡 2s」「TaskPool 2s」两个按钮，切后台 30s 回前台会自动刷新。

分级提示、notes 记录规则同 `harmony-M1.md`。

检查范围：M3-1 ~ M3-3 有本地单测；M3-4（TaskPool）在本地单测里是空壳，放在设备测试里；M3-5 在页面里，靠手工验收。

---

## 手工任务 A：生命周期日志

日志已经全部打好了（tag `M3E`），你只需要操作 + 记录顺序。涉及的回调：

| 层级 | 回调 | 文件 |
|---|---|---|
| 应用（UIAbility） | `onCreate` / `onWindowStageCreate` / `onForeground` / `onBackground` / `onWindowStageDestroy` / `onDestroy` / `onNewWant` / `onConfigurationUpdate` | `entryability/EntryAbility.ets` |
| 窗口 | `windowStageEvent`（SHOWN / ACTIVE / INACTIVE / HIDDEN，打印的是枚举数字） | 同上 |
| 页面（@Entry） | `onPageShow` / `onPageHide` / `onBackPress` | `pages/Index.ets` |
| 组件 | `aboutToAppear` / `aboutToDisappear` | `pages/Index.ets`、`view/H5Page.ets` |
| 路由页（NavDestination） | `onShown` / `onHidden` | `view/FileDetailView.ets`、`view/H5Page.ets` |

🔬 分别做下面几件事，把日志顺序抄进 `notes/harmony-M3.md`：

1. 冷启动
2. 进详情 → 返回
3. 上滑回桌面 → 再点图标回来
4. 旋转屏幕（模拟器侧边栏）。spec 要求「旋转后列表数据和排序不丢、不重新请求」：看有没有 `aboutToAppear` / `FileRepository` 的请求日志，没有重建的话写下原因
5. 最近任务里划掉

想一想：
- Android 的 Activity 生命周期和这里哪一层对应？`onPageShow` 对应 Android 的什么？为什么进详情页时 `onPageHide` 不触发？（提示：Navigation 里的跳转不是「换页面」）
- 🔬 鸿蒙默认旋转不重建。如果想让它像 Android 一样「配置变化就重建」，要怎么做？反过来，Android 怎么做到不重建？（`android:configChanges`）
- 对工作：线上 App 的 H5 容器如果放在一个 `NavDestination` 里，`onHidden` 时该不该给 H5 推 `appState: background`？

## 手工任务 B：主线程卡顿

🔬 点「主线程卡 2s」：旁边的转圈停了吗？2s 内点排序有反应吗？如果连着点几次，会不会弹「应用无响应」？（鸿蒙的 AppFreeze 阈值：主线程 6s 无响应会被判定，日志里搜 `THREAD_BLOCK` / `APP_INPUT_BLOCK`；以实测为准）

再点「TaskPool 2s」对比。结果写进 notes。

想一想：Android 主线程做网络会直接抛 `NetworkOnMainThreadException`。🔬 鸿蒙主线程调 `http.request` 会怎样？（提示：它本身就是异步的，回调回到主线程；真正卡主线程的是同步计算和 `xxxSync` 系列 API，比如 M2 的 `flushSync`）

---

## M3-1 记下进后台的时间 · `lifecycle/ForegroundRefresher.ets`

<details><summary>提示 2</summary>

时间是调用方传进来的 `now`，不要自己调 `Date.now()`（测试传的是假时间）。
</details>

<details><summary>答案</summary>

```ts
this.backgroundAt = now;
```
</details>

想一想：为什么把「现在几点」做成参数，而不是在函数里调 `Date.now()`？前端写单测时你怎么处理 `Date.now()`？

---

## M3-2 回前台要不要刷新 · `lifecycle/ForegroundRefresher.ets`

<details><summary>提示 2</summary>

三件事：
- `backgroundAt < 0`（从没进过后台，比如冷启动时的第一次 `onForeground`）→ 不刷新
- `now - backgroundAt >= thresholdMs` 才刷新（正好 30s 也算）
- 不管刷不刷新，都把 `backgroundAt` 重置成 -1
</details>

<details><summary>答案</summary>

```ts
const should = this.backgroundAt >= 0 && now - this.backgroundAt >= this.thresholdMs;
this.backgroundAt = -1;
return should;
```
</details>

想一想：用户把系统时间往回调了，`now - backgroundAt` 会是负数。有没有不受系统时间影响的时钟？（查 `systemDateTime.getUptime`，和浏览器的 `performance.now()` 对照）

---

## M3-3 前后台状态从 Ability 传到页面 · `lifecycle/AppState.ets`

<details><summary>提示 2</summary>

`AppStorage.set` 只更新已经存在的 key，key 不存在时什么都不做（返回 false）；`AppStorage.setOrCreate` 不存在就创建。冷启动时第一次 `onForeground` 比页面的 `@StorageProp` 还早，key 还不存在。
</details>

<details><summary>答案</summary>

```ts
AppStorage.setOrCreate<string>(KEY_APP_STATE, state);
```
</details>

想一想：
- `@StorageProp` 和 `@StorageLink` 的区别是什么？类比 Vue：哪个像 `props`，哪个像 `v-model`？
- Android 这一步用的是什么（`ProcessLifecycleOwner` / `LifecycleEventObserver`）？鸿蒙也有不经过 AppStorage 的写法：`ApplicationContext.on('applicationStateChange')`，两者各适合什么场景？

---

## M3-4 丢到 TaskPool · `lifecycle/Threads.ets`

<details><summary>提示 2</summary>

`taskpool.execute(函数, ...参数)` 返回 `Promise<Object>`，`await` 之后 `as number`。函数必须是 `@Concurrent` 的，已经写好了：`busyWaitConcurrent`。
</details>

<details><summary>答案</summary>

```ts
const result = await taskpool.execute(busyWaitConcurrent, ms);
return result as number;
```
</details>

想一想：
- 🔬 把 `busyWaitConcurrent` 的函数体改成调用外面的 `busyWait(ms)`，编译会报什么？为什么 `@Concurrent` 函数不能用闭包？（提示：TaskPool 的 worker 是另一个 JS 虚拟机实例，内存不共享，参数是序列化过去的。和浏览器的 Web Worker 对照）
- Kotlin 协程 `withContext(Dispatchers.IO)` 里可以随便访问外面的变量，为什么？两边的线程模型根本差异是什么？
- 对工作：ArkWeb 的 H5 渲染和 JS 执行在哪个线程 / 进程？`javaScriptProxy` 注入的方法被 H5 调用时，跑在哪个线程？（M4 会用到）

---

## M3-5 切后台 30s 回前台刷新 · `pages/Index.ets`

<details><summary>提示 2</summary>

`@Watch('onAppStateChange')` 在 `this.appState` 变化时回调：
- `APP_BACKGROUND` → `this.refresher.onBackground(Date.now())`
- `APP_FOREGROUND` 且 `this.refresher.onForeground(Date.now())` 为 true → `this.reload()`
</details>

<details><summary>答案</summary>

```ts
if (this.appState === APP_BACKGROUND) {
  this.refresher.onBackground(Date.now());
} else if (this.appState === APP_FOREGROUND && this.refresher.onForeground(Date.now())) {
  Log.i('回前台：在后台超过 30s，刷新列表');
  this.reload();
}
```
</details>

手工验收：
- [ ] 🔬 切后台 10s 回来：不刷新（没有请求日志）
- [ ] 🔬 切后台 35s 回来：日志出现「回前台：在后台超过 30s，刷新列表」，mock 服务的终端里多一条 `GET /api/files.json`
