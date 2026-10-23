# 鸿蒙 M1 提示与答案

**先做 A1**（ArkTS 语言专项，约 1 小时，`./check.sh A1`，见 `harmony-A1.md`）：M1 起的编译报错大多是 ArkTS 和 TS 不一样的地方，以及 `@State` 改了不刷新，A1 都先练过一遍。

开始前：`entry/src/main/ets/common/Stage.ets` 里 `STAGE = 1`（默认就是）。

每个空分三级：**提示 1** 在代码注释里；**提示 2** 和 **答案** 在下面，折叠着，卡住超过 10 分钟再展开。展开过答案的，在 `notes/harmony-M1.md` 记一笔。

「想一想」不算分，答案写进 notes。带 🔬 的是要动手实测的。

这一端是「迁移」：排序、格式化这些 Android 学过的通用逻辑已经写好了，空集中在 ArkUI 和 Android 不一样的地方（`@State`、`ForEach` 的 key、`NavPathStack`）。

关于检查：
- M1-1、M1-3 ~ M1-5 有本地单测，不开模拟器也能检查
- M1-2、M1-6 在组件里，只有 UI 测试（`entry/src/ohosTest`）能查，要开模拟器并按 `harmony-M0.md` 配好签名
- 列表页一渲染就会执行到 M1-1，所以先填 M1-1，App 才能跑起来

ArkTS 报错看不懂时：它是 TS 的严格子集，最常见的三条是不能用 `any` / `unknown`、对象字面量必须标注类型、不能用结构类型（鸭子类型）赋值。错误信息里括号中的 `arkts-no-xxx` 是规则名，拿去搜官方文档「从 TypeScript 到 ArkTS 的适配规则」。

---

## M1-1 ForEach 的 key · `model/FileItem.ets`

<details><summary>提示 2</summary>

`ForEach(数组, 渲染函数, 键值生成函数)`，第三个参数就是 Vue 的 `:key`。返回值要在列表内唯一，并且同一个文件始终返回同一个值，哪怕它改了名、改了时间。
</details>

<details><summary>答案</summary>

```ts
export function fileKey(item: FileItem): string {
  return item.id;
}
```
</details>

想一想：
- 🔬 不传第三个参数时，ArkUI 默认的 key 是什么？（查文档「ForEach 键值生成规则」，默认是 `index + '__' + JSON.stringify(item)`）切换排序时会发生什么？和 Compose 默认用下标当 key 有什么不同？
- 🔬 把答案换成 `JSON.stringify(item)`，测试为什么会挂？M2 列表从网络刷新、某个文件的 `mtime` 变了，界面上会发生什么？

---

## M1-2 切换排序 · `pages/Index.ets`

<details><summary>提示 2</summary>

`@State` 字段的语义就是 Vue 的 `ref`：给 `this.order` 赋一个新值，`build()` 里读了它的部分就会重新执行。`nextOrder` 只是算出下一个值，不会改任何东西。
</details>

<details><summary>答案</summary>

```ts
this.order = nextOrder(this.order);
```
</details>

想一想：
- Android 用 `rememberSaveable` 让排序活过「旋转屏幕导致的 Activity 重建」。🔬 鸿蒙上旋转模拟器（模拟器侧边栏的旋转按钮；`module.json5` 里 Ability 默认跟随传感器还是锁竖屏？），看 Log 里有没有 `aboutToAppear` 再打一次。没重建的话，记下原因（提示：Android 是「配置变化 → 默认销毁重建」，鸿蒙是「默认只回调 `onConfigurationUpdate`」）
- `order` 上还挂了 `@Watch('onOrderChange')`，`STAGE < 2` 时它直接 return。M2 你会用到它

---

## M1-3 跳到详情页 · `nav/Routes.ets`

<details><summary>提示 2</summary>

`NavPathStack` 就是路由栈，按名字入栈的方法叫 `pushPathByName(name, param)`。名字用上面的常量 `ROUTE_DETAIL`，param 只传 `id`。
</details>

<details><summary>答案</summary>

```ts
stack.pushPathByName(ROUTE_DETAIL, file.id);
```
</details>

想一想：
- 为什么只传 `id` 而不是整个 `file` 对象？（提示：页面被系统回收后恢复、或者以后做「从通知直接打开某个文件」时，param 从哪来？和 Android 只能往路由里塞字符串的设计对照一下）
- 🔬 快速连点同一行两次，再按返回，会怎样？查一下 `pushPathByName` 带 `LaunchMode` 的重载，和 Android 的 `launchSingleTop` 对照

---

## M1-4 取路由参数 · `nav/Routes.ets`

<details><summary>提示 2</summary>

`navDestination` 的构建函数拿到的 `param` 静态类型是 `Object`，ArkTS 不允许把它当 `any` 用，也不能直接 `as string` 了事（不是字符串时会把错误的值带下去）。用 `typeof` 判断后再返回，TS 的类型收窄在 ArkTS 里同样有效。
</details>

<details><summary>答案</summary>

```ts
return typeof param === 'string' ? param : undefined;
```
</details>

想一想：
- `Index.ets` 的 `pageMap` 是一个 `@Builder`，按名字决定渲染哪个页面。这和 vue-router 的路由表比，少了什么？（提示：路由表在哪声明、类型检查在哪做）新版鸿蒙推荐的「系统路由表」（`route_map.json`）解决的是哪个问题？
- 🔬 `param` 传一个数字（如 `pushPathByName(ROUTE_DETAIL, 10)`），详情页显示什么？

---

## M1-5 返回 · `nav/Routes.ets`

<details><summary>提示 2</summary>

返回不是「再跳到列表页」，而是把栈顶页面弹出去。列表页是 `Navigation` 的首页，本来就不在栈里：栈空 = 在列表页。
</details>

<details><summary>答案</summary>

```ts
stack.pop();
```
</details>

想一想：测试 `m1_5` 先压了 H5 页再压详情页，为什么不直接用 `clear()`？在线上 App 的场景里，什么时候会「从 H5 页打开文件详情」？

---

## M1-6 详情页的返回按钮 · `view/FileDetailView.ets`

<details><summary>提示 2</summary>

`@Consume('pathStack')` 拿到的就是 `Index` 里 `@Provide('pathStack')` 的同一个栈对象（类似 Vue 的 provide / inject），把它交给 M1-5 写好的函数。
</details>

<details><summary>答案</summary>

```ts
goBack(this.pathStack);
```
</details>

想一想：
- 🔬 系统返回手势 / 返回键走的是哪条路？你写的 `goBack` 会被调用吗？看 `Index.onBackPress` 的日志，详情页打开时它会触发吗？
- 🔬 滚到中间 → 进详情 → 返回，滚动位置还在（`m1_e2e` 测的就是这一条）。Android 靠 `NavHost` 给每个页面一个 `SaveableStateHolder`；鸿蒙这里你什么都没做，为什么也没丢？（提示：进详情页时，列表页的组件被销毁了吗？在 `Index.aboutToDisappear` 打断点看看）
- 对工作：线上 App 的 H5 页面如果是一个 `NavDestination`，从 H5 进入原生页再返回，WebView 会重新加载吗？
