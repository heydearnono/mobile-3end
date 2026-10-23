# 鸿蒙 A1 ArkTS 语言专项：提示与答案

插在 M0 和 M1 之间，约 1 小时。ArkTS ≈ TS，这里只练和 TS 不一样的地方，外加 ArkUI 的状态刷新规则。全是本地单测，不用开模拟器：

```sh
cd harmony
./check.sh A1     # 几秒出结果
```

代码在 `entry/src/main/ets/a1/`，按 5 节分文件。每个文件开头的注释是这一节的讲解，**先读注释再填空**，里面标了对应的 TS / Kotlin 写法。速查表在 `notes/arkts-vs-ts.md`。

格式同 `harmony-M1.md`：提示 1 在代码注释里，提示 2 和答案折叠在下面。展开过答案的在 `notes/harmony-A1.md` 记一笔。带 🔬 的要动手实测。

| 节 | 文件 | 空 | 后面在哪会遇到 |
|---|---|---|---|
| 1 严格模式 | `Strict.ets` | A1-1、A1-2 + 🔬 实验 | 所有地方，M1 起的编译报错 |
| 2 class / enum 与 JSON | `Json.ets` | A1-3、A1-4 | M2-1 解析接口、M4-5 解析 bridge 消息 |
| 3 空安全 | `NullSafety.ets` | A1-5、A1-6 | M1-4 路由参数、M2-3 读 KV |
| 4 装饰器与状态 | `State.ets`、`StateDemo.ets` | A1-7、A1-8 | M1-2 `@State`、M2 的 `listState` |
| 5 async 与 TaskPool | `Async.ets` | A1-9、A1-10 | M2-5 `await`、M3-4 TaskPool、M4 白屏检测 |

DevEco 里多用：光标停在变量上看推断出来的类型；⌘ 点 `@State`、`taskpool.execute` 跳到 SDK 的声明。ArkTS 的报错在编辑器里直接是红线，不用等编译。

注意：本地单测只编译测试 import 到的文件。`StateDemo.ets` 没有测试引用，它的编译错误只在 DevEco 编辑器 / 预览器里看得到。

---

## 第 1 节 🔬 实验：严格模式（不算空，约 10 分钟）

下面每条都是合法的 TS。粘到 `Strict.ets` 末尾，看 DevEco 的红线或者跑 `./check.sh A1`（编译失败时会列出错误），记下规则名，再改成右边的写法。试完删掉。报错都是在 SDK 26 上实测的。

| # | TS 写法 | 报错的规则名 | ArkTS 写法 |
|---|---|---|---|
| 1 | `function f(a: any) {}` | `arkts-no-any-unknown` | 写具体类型，实在不知道用 `Object` |
| 2 | `const o = { a: 1 }` | `arkts-no-untyped-obj-literals` | 先 `interface O { a: number }`，再 `const o: O = { a: 1 }` |
| 3 | `type P = { x: number }` | `arkts-no-obj-literals-as-types` | `interface P { x: number }` |
| 4 | `class A { x = 0 }` `class B { x = 0 }` `const a: A = new B()` | `arkts-no-structural-typing` | `B extends A`，或者都 implements 同一个 interface |
| 5 | `p['x']`（p 是 class 实例） | `arkts-no-props-by-index` | `p.x`；真要动态键名就用 Record / Map |
| 6 | `interface D { [k: string]: number }` | `arkts-no-indexed-signatures` | `Record<string, number>` |
| 7 | `const r: Record<string, number> = { a: 1 }` | `arkts-no-untyped-obj-literals` | `{ 'a': 1 }`：Record 字面量的键要加引号 |
| 8 | `'id' in f`、`delete r['a']`、`for (const k in r)` | `arkts-no-in`、`arkts-no-delete`、`arkts-no-for-in` | Map 的 `has` / `delete` / `forEach`，或 `Object.keys(r)` |
| 9 | `const { id, name } = f`、`const [k, v] = s.split('=')` | `arkts-no-destruct-decls` | 一个个取 |
| 10 | `const g: FileItem = { ...f, name: 'x' }` | `arkts-no-spread` | 字段一个个写（A1-7）；数组展开 `[...arr, x]` 可以 |
| 11 | `catch (e: Error)` | `arkts-no-types-in-catch` | `catch (e)`，再 `e as Error` |
| 12 | `Object.assign(a, b)`、`r.hasOwnProperty('a')` | `arkts-limited-stdlib` | 手动赋值；`Object.keys(r).indexOf('a') >= 0`，或者用 Map |
| 13 | `throw 'oops'` | `arkts-limited-throw` | `throw new Error('oops')` |
| 14 | `var x = 1`、`const f = function () {}` | `arkts-no-var`、`arkts-no-func-expressions` | `let`、箭头函数 |
| 15 | `type T = Pick<FileItem, 'id'>`、`A & B`、`type N = typeof x` | `arkts-no-utility-types`、`arkts-no-intersection-types`、`arkts-no-type-query` | 单独声明一个 interface；`Partial` / `Record` / `Readonly` 是支持的 |
| 16 | `class C { name!: string }` | `arkts-no-definite-assignment`（只是 WARN） | 给初始值，或在构造函数里赋值 |

能编过、但容易误会的，也试一下：

- `files.map(f => ({ id: f.id, ... }))`：箭头函数参数能推断，但回调返回的对象字面量没有类型可对应，报 `arkts-no-untyped-obj-literals`。写成 `(f: FileItem): FileItem => ...` 就过了
- `const p = new Promise(resolve => setTimeout(resolve, 100))` 报 `arkts-no-inferred-generic-params`：推不出 T。直接 `return new Promise(...)` 能从函数返回类型推出来，不报
- `JSON.parse(s) as Point` 编得过，但 `p instanceof Point` 是 false（第 2 节）

想一想：
- ArkTS 为什么要禁这些？（提示：方舟编译器会把 ArkTS 提前编译成字节码 / 机器码，对象的字段布局在编译期确定，属性访问可以编译成固定偏移。TS 只做类型检查，运行时还是 V8 靠 hidden class 去猜）
- 对工作：线上 App 的 H5 是 TS，鸿蒙容器是 ArkTS。bridge 消息的类型定义能不能两边共用一份？（H5 那边的 `type Msg = {...}` 要改成 interface，联合类型、`any` 都不能有。更现实的做法是两边各写各的，靠 JSON 协议对齐）

---
## A1-1 Record 代替索引签名 · `Strict.ets`

<details><summary>提示 2</summary>

`count[f.type] ?? 0`：没有这个键时读到 undefined，当成 0，再 +1 写回。读出来的类型写的是 number，但运行时可能是 undefined，编译器不会提醒（第 3 节讲为什么）。
</details>

<details><summary>答案</summary>

```ts
const count: Record<string, number> = {};
for (const f of files) {
  count[f.type] = (count[f.type] ?? 0) + 1;
}
return count;
```
</details>

想一想：
- 🔬 把 `?? 0` 去掉，测试报什么？编译器为什么没拦住？（`count[f.type]` 的类型是 `number`，不是 `number | undefined`）
- 换成 `Map<string, number>` 写一遍：`get` 返回 `number | undefined`，编译器会逼你处理，比 Record 安全。代价是 `JSON.stringify(map)` 得到 `{}`。返回值要通过 JSBridge 交给 H5 的时候选哪个？

---

## A1-2 不能解构时怎么拆字符串 · `Strict.ets`

<details><summary>提示 2</summary>

`const eq = part.indexOf('=')`。`eq < 0` 时整段是键、值是 `''`；否则键是 `part.substring(0, eq)`，值是 `part.substring(eq + 1)`。Map 对同一个键 `set` 两次，后一次覆盖前一次，「后面的覆盖前面的」不用额外写。
</details>

<details><summary>答案</summary>

```ts
const params = new Map<string, string>();
for (const part of query.split('&')) {
  if (part === '') {
    continue;
  }
  const eq = part.indexOf('=');
  const key = eq < 0 ? part : part.substring(0, eq);
  const value = eq < 0 ? '' : part.substring(eq + 1);
  params.set(decodeURIComponent(key), decodeURIComponent(value));
}
return params;
```
</details>

想一想：
- 🔬 写成 `const [k, v] = part.split('=')` 看报错。就算 TS 里能解构，`split('=')` 遇到 `sig=x==` 会怎样？
- `decodeURIComponent('%E5%')` 会抛 `URIError`。H5 传了个坏参数，这个函数会让整个 bridge 调用抛异常。该在这里 try / catch，还是交给调用方？
- 对工作：JSBridge 传参常见两种：URL scheme（`myapp://bridge?method=...`，要解析 query，就是这道题）和 postMessage 传 JSON（本项目 spec 用的）。各自有什么长度、编码上的坑？

---

## A1-3 JSON → 有类型的对象 · `Json.ets`

<details><summary>提示 2</summary>

三层检查，每层不过就 `return undefined`：
1. `JSON.parse` 会抛异常 → 放进 try / catch
2. 解出来是 `null` 或基本类型（`'null'`、`'3'`）→ `raw === null || typeof raw !== 'object'`
3. 逐个字段 `typeof`。`mode` 不能写 `raw.mode as PackageMode`，要过一遍 `toPackageMode`

检查过的值先存进局部变量，`typeof name !== 'string'` 这类判断之后它自动收窄成 string，可以直接传给构造函数。files 用 `Object.keys(raw.files)` 遍历，`typeof value === 'string'` 的才放进 Map。
</details>

<details><summary>答案</summary>

```ts
let raw: RawManifest | null = null;
try {
  raw = JSON.parse(text) as RawManifest | null;
} catch (e) {
  return undefined;
}
if (raw === null || typeof raw !== 'object') {
  return undefined;
}
const name = raw.name;
const version = raw.version;
const entry = raw.entry;
const mode = toPackageMode(raw.mode);
if (typeof name !== 'string' || name === '' || typeof entry !== 'string' || entry === '' ||
  typeof version !== 'number' || mode === undefined) {
  return undefined;
}
const files = new Map<string, string>();
const rawFiles = raw.files;
if (typeof rawFiles === 'object' && rawFiles !== null) {
  for (const path of Object.keys(rawFiles)) {
    const hash = rawFiles[path];
    if (typeof hash === 'string') {
      files.set(path, hash);
    }
  }
}
return new PackageManifest(name, version, entry, mode, files);
```
</details>

想一想：
- 🔬 先跑一下 `a1_0` 示例测试（不依赖任何空，一开始就是绿的），再看它的代码：`JSON.parse(...) as PackageManifest` 之后 `instanceof` 是 false。在 A1-3 里写 `return JSON.parse(text) as PackageManifest` 试试，`a1_3_parsesManifest` 挂在 `instanceof` 那一行；把那行临时注释掉再跑，报错变成 `hashOf is not callable`，是什么意思？
- 为什么 `version` 检查 `typeof === 'number'` 就够了？`{"version":"3"}` 在 Kotlin 的 kotlinx.serialization 里会怎样，在 Swift 的 Codable 里会怎样？（都是抛异常。ArkTS 手写检查时，「宽松还是严格」是你自己决定的）
- 对工作：离线包的 manifest 是从 CDN 下载的。manifest 解析失败时，容器应该「用旧包」「走线上」还是「白屏报错」？这和 M4 白屏检测的 `load_error` 是同一类问题吗？

---

## A1-4 Map 不能直接 JSON.stringify · `Json.ets`

<details><summary>提示 2</summary>

`this.files.forEach((hash: string, path: string) => { ... })`：Map 的 forEach 回调参数是 **(值, 键)**，顺序和直觉相反。拼对象时字段写的顺序就是 JSON 里的顺序。
</details>

<details><summary>答案</summary>

```ts
const files: Record<string, string> = {};
this.files.forEach((hash: string, path: string) => {
  files[path] = hash;
});
const json: ManifestJson = {
  name: this.name,
  version: this.version,
  entry: this.entry,
  mode: this.mode,
  files: files
};
return JSON.stringify(json);
```
</details>

想一想：
- 🔬 写成 `return JSON.stringify(this)`，测试里看到的 `files` 是什么？
- `mode: this.mode` 放进 JSON 的是 `'offline'` 还是 `'OFFLINE'`？字符串枚举的值和名字分别是什么？数字枚举（`enum E { A, B }`）序列化出来又是什么？
- 对比 M4 的 `Bridge.ets` 里 `callbackOk`：为什么那里先声明 `OkPayload` 再 `JSON.stringify`，不直接拼字符串？（转义：`message` 里有 `"` 或换行时，K1-11 的想一想）

---

## A1-5 ?. 和 ?? · `NullSafety.ets`

<details><summary>提示 2</summary>

`files.get(id)` 的类型是 `FileItem | undefined`，`?.name` 之后是 `string | undefined`，再 `?? '文件不存在'` 变回 `string`。
</details>

<details><summary>答案</summary>

```ts
return files.get(id)?.name ?? '文件不存在';
```
</details>

想一想：
- 🔬 去掉 `?.` 写成 `files.get(id).name`，编译器报什么？这是 ArkTS 比「默认配置的 TS」严的地方：`strictNullChecks` 永远开着
- 🔬 `??` 换成 `||`，哪个测试挂？为什么？（`''` 是 falsy。FE 老代码里 `a || b` 很常见，迁移到 ArkTS 时要逐个想清楚）
- 对比 K1-4：Kotlin 的 `?:` 只看 null，和 `??` 一样，没有 `||` 这个坑

---

## A1-6 `!` 不检查 · `NullSafety.ets`

<details><summary>提示 2</summary>

```ts
const file = files.get(id);
if (file === undefined) {
  throw ...;
}
return file;   // 这里 file 已经收窄成 FileItem
```
`files.get(id)` 调两次（`if (files.get(id) === undefined) ... return files.get(id)`）编不过：编译器不知道两次调用返回的是同一个东西。
</details>

<details><summary>答案</summary>

```ts
const file = files.get(id);
if (file === undefined) {
  throw new Error(`找不到文件 ${id}`);
}
return file;
```
</details>

想一想：
- 🔬 写成 `return files.get(id)!`，测试里显示「没抛异常，拿到了 undefined」：`!` 让编译器闭嘴了，运行时什么都没做。对比 Kotlin 的 `!!`：是 null 就立刻抛 `NullPointerException`
- 🔬 `const a: FileItem[] = []; a[3].name` 编得过吗？运行时呢？Kotlin 的 `list[3]` 呢？（ArkTS 运行时是 `TypeError: Cannot read property name of undefined`，Kotlin 是 `IndexOutOfBoundsException`，崩在越界那一刻）
- 对工作：鸿蒙崩溃日志里最常见的 `TypeError: Cannot read property xxx of undefined`，往上找的时候要找「这个 undefined 是从哪来的」，常常是某个 `!` 或 `as`，而不是报错的那一行。M5 看崩溃堆栈时留意一下

---

## A1-7 不可变更新 · `State.ets`

<details><summary>提示 2</summary>

先用 `files.some(...)` 判断 id 在不在，不在就原样 `return files`。在的话 `files.map(...)`：不是目标的直接返回原对象 `f`，是目标的 new 一个对象，五个字段都写出来，只把 name 换掉。map 回调要写返回类型 `(f: FileItem): FileItem =>`，不然对象字面量报 `arkts-no-untyped-obj-literals`。
</details>

<details><summary>答案</summary>

```ts
if (!files.some((f: FileItem) => f.id === id)) {
  return files;
}
return files.map((f: FileItem): FileItem => {
  if (f.id !== id) {
    return f;
  }
  const renamed: FileItem = { id: f.id, name: newName, type: f.type, size: f.size, mtime: f.mtime };
  return renamed;
});
```
</details>

想一想：
- 为什么「其他元素保持同一个对象」重要？（`ForEach` 的 key 没变、对象也没变，这一行就不用重新创建。M1-1 想一想里的 `JSON.stringify(item)` 当 key 时，每次都是新对象会怎样？）
- `FileItem` 加一个字段（比如 `thumb`），这里会怎样？TS 的 `{ ...f, name }` 自动带上新字段；ArkTS 手写的版本编译器会报缺字段，不会悄悄丢掉，这算优点还是缺点？
- 对比 K1-10 的 `file.copy(name = newName)`、Swift 的 `var f = file; f.name = newName`（struct 是值类型，改的是副本）：三端都在做同一件事，只是 ArkTS 要手写

---

## A1-8 预测：改了 UI 刷不刷新 · `State.ets` + `StateDemo.ets`

这题本地单测只能对答案，刷新行为要到预览器里看：DevEco 打开 `a1/StateDemo.ets` → 右侧 Previewer（没有就 View → Tool Windows → Previewer），不需要模拟器。

建议做法：先填 `predictRefresh` 跑测试，测试会告诉你错了哪几题；再到预览器里点按钮，把每题「为什么」想清楚。

<details><summary>提示 2</summary>

只看一件事：**这行代码有没有给 `@State` 变量本身、或者它的第一层属性赋值**（数组的话，push / splice / `arr[i] = x` 也算第一层）。
- `this.listState.files.push(item)`：给 `files` 这个数组加元素，但 `files` 不是 `@State`，`listState` 才是。listState 的属性 `files` 没被赋值
- `this.listState = this.listState`：同一个对象，框架先比 `===`，相等就什么都不做
- 第 8 题：`FileRow` 是 `@Observed`，子组件用 `@ObjectLink` 接，属性变化能通知到**子组件**。父组件自己那行「直接读」的文字刷不刷新是另一回事，预览器里两个都看一下
- 第 9 题：`@Prop` 是拷贝；第 10 题：`@Link` 是同一个值
</details>

<details><summary>答案</summary>

```ts
return [true, true, true, false, false, true, false, true, false, true];
```

| # | 刷新 | 原因 |
|---|---|---|
| 1 | ✅ | @State 自身赋值 |
| 2 | ✅ | @State 对象的第一层属性赋值 |
| 3 | ✅ | 同上，`files` 属性被赋了新数组 |
| 4 | ❌ | 第二层：改的是 `files` 数组的内容，`listState.files` 没被赋值 |
| 5 | ❌ | 赋同一个对象，`===` 相等，框架直接跳过 |
| 6 | ✅ | @State 数组的增删 |
| 7 | ❌ | 第二层：数组元素的属性 |
| 8 | ✅ | `@Observed` + `@ObjectLink`，子组件刷新 |
| 9 | ❌ | `@Prop` 是拷贝，只有子组件自己变 |
| 10 | ✅ | `@Link` 双向 |
</details>

想一想：
- 🔬 第 4、7 题点完数据已经变了，只是界面没刷。点「tick + 1」之后呢？这就是「过一会儿突然对上」的 bug：别的状态一变，这块重新渲染，读到的是新数据。对比 Vue 2 的 `this.arr[0] = x` 不响应、`Vue.set` 才响应
- 🔬 第 8 题：子组件那行刷新了，父组件「直接读」那行呢？为什么？（`@Observed` 只负责通知用 `@ObjectLink` 接它的组件；父组件的 `@State rows` 观察的是数组第一层，`rows[0].name` 是第二层）
- 🔬 第 9 题点完，再点第 10 题，子组件 `@Prop` 那个按钮上的字会怎样？（父组件的值变了，会覆盖 @Prop 的本地修改）
- 回到 `data/FileRepository.ets`：`ListState` 注释里写「用 class 而不是对象字面量」。`Index.ets` 里每次都是 `this.listState = s` 整体换掉，从来不改 `this.listState.files`，现在知道为什么了
- V2 的 `@ObservedV2` + `@Trace` 是属性级观察，第 4、7 题那种写法也能刷新。线上 App 代码如果是 V2，读的时候规则要换一套，查官方文档「状态管理 V1 V2 迁移指导」
- 对比 K1-10 的想一想：Compose 判断重组靠 `==`（data class 比字段）；ArkUI V1 判断赋值靠 `===`（比引用）。所以 Kotlin 里 `copy()` 出一个字段相同的新对象不会重组，ArkUI 里 new 一个字段相同的新对象**会**刷新

---

## A1-9 Promise.race 做超时 · `Async.ets`

<details><summary>提示 2</summary>

```ts
const timer = new Promise<T>((resolve: (value: T) => void) => {
  setTimeout(() => resolve(fallback), ms);
});
return Promise.race<T>([task, timer]);
```
`race` 取最先「落定」的那个：task 先 resolve 就是它的值，先 reject 就 reject，timer 先到就是 fallback。
</details>

<details><summary>答案</summary>

```ts
const timer = new Promise<T>((resolve: (value: T) => void) => {
  setTimeout(() => resolve(fallback), ms);
});
return Promise.race<T>([task, timer]);
```
</details>

想一想：
- 🔬 把 `new Promise<T>((resolve: (value: T) => void) => ...)` 改成 `new Promise(resolve => ...)`（类型参数和回调参数类型都去掉），赋给变量 `timer` 时报什么？（`arkts-no-any-unknown` + `arkts-no-inferred-generic-params`。只去掉 `<T>`、回调参数类型留着，能推出来，不报）
- 超时之后 task 还在跑吗？（还在。Promise 没有取消，只是没人等它的结果了。对比 K1-15 的 `withTimeoutOrNull`：协程超时会真的取消 block）timer 在 task 先完成时也没清掉，会有什么影响？怎么改？（`clearTimeout`，在 `task.finally` 里清）
- 对工作：M4 白屏检测是「页面加载完等 1s 再查」，用的是 `setTimeout`，不是 race。什么场景下要 race？（比如 bridge 调 H5 的方法，H5 一直不回）

---

## A1-10 @Concurrent 函数 · `Async.ets`

<details><summary>提示 2</summary>

```ts
let hash = 0x811c9dc5;
for (let i = 0; i < text.length; i++) {
  hash = hash ^ text.charCodeAt(i);
  hash = Math.imul(hash, 0x01000193);
}
return (hash >>> 0).toString(16).padStart(8, '0');
```
`hash * 0x01000193` 不行：JS 的 number 是 64 位浮点，乘出来超过 2^53 就丢精度。`Math.imul` 按 32 位整数乘，溢出部分直接截掉，和 C / Kotlin 的 `Int` 乘法一样。

常量要写在函数体里：`const prime = 0x01000193` 放到文件顶层，编译时报错。
</details>

<details><summary>答案</summary>

```ts
const offsetBasis = 0x811c9dc5;
const prime = 0x01000193;
let hash = offsetBasis;
for (let i = 0; i < text.length; i++) {
  hash = hash ^ text.charCodeAt(i);
  hash = Math.imul(hash, prime);
}
return (hash >>> 0).toString(16).padStart(8, '0');
```
</details>

想一想：
- 🔬 把 `prime` 挪到文件顶层（`const PRIME = 0x01000193`），跑 `./check.sh A1`：编译直接失败，`Concurrent function should only use import variable or local variable, 'PRIME' is not one of them`。注意这条不是 ArkTS linter 报的，是后面生成字节码（es2abc）时报的，所以 DevEco 编辑器里可能没有红线，要编译才看得到。试完挪回去
- 🔬 同一个文件里写一个普通函数 `helper()`，在 `checksum` 里调它，也报同样的错；把 `helper` 挪到别的文件再 import 进来就可以了。为什么「import 的可以，同文件顶层的不行」？（import 进来的模块在 worker 里会重新加载一份；同文件的顶层变量是主线程这个模块实例里的，worker 拿不到）
- 🔬 本地单测里 `checksumOffMain('a')` 返回什么？（`{}`：本地单测里 taskpool 是空壳，`execute` 不会真的跑。M3-4 的 TaskPool 也是因为这个放在设备测试里）
- 传给 `@Concurrent` 函数的参数如果是一个普通 class 的实例，worker 里拿到的对象还能调方法吗？（不能，序列化过去只剩字段，和 A1-3 的 `as` 一个道理。要传带方法的对象用 `@Sendable class`）
- 对工作：离线包解压、校验这类 CPU 活，线上 App 的鸿蒙容器是放 TaskPool 还是 Worker？两者的区别查官方文档「TaskPool 和 Worker 的对比」

---

## 做完之后

1. 把 `notes/arkts-vs-ts.md` 里你还没完全理解的行标出来
2. 在 DevEco 里打开 `pages/Index.ets`、`data/FilesJson.ets`、`web/Bridge.ets`，把每一处「TS 里不会这么写」的地方认出来：显式的 interface、`as` 之后逐字段检查、`Record`、`@State` 整体赋值。读得通了 A1 就算完成，接着做 M1
