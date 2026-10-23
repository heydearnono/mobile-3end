# ArkTS 速查（只列和 TS 不一样的地方）

读线上 App 的鸿蒙容器代码时查。没列出来的就和 TS 一样（async / await、箭头函数、泛型、class、interface、模板字符串、`?.` / `??`……）。练习在 `harmony/entry/src/main/ets/a1/`，提示在 `hints/harmony-A1.md`。规则名（`arkts-no-xxx`）都在 SDK 26 上实测过，拿去搜官方文档「从 TypeScript 到 ArkTS 的适配规则」。

## 类型系统

| TS | ArkTS | 规则名 / 备注 |
|---|---|---|
| `any` / `unknown` | 具体类型；实在不知道用 `Object` | `arkts-no-any-unknown` |
| `const o = { a: 1 }` | 先声明 `interface O`，再 `const o: O = { a: 1 }` | `arkts-no-untyped-obj-literals` |
| `type P = { x: number }` | `interface P { x: number }` | `arkts-no-obj-literals-as-types`；`type A = B \| C` 这种别名可以 |
| 结构相同就能赋值（鸭子类型） | 必须有继承 / implements 关系 | `arkts-no-structural-typing` |
| `{ [k: string]: V }` | `Record<string, V>` 或 `Map<string, V>` | `arkts-no-indexed-signatures` |
| `Pick` / `Omit` / `A & B` / `typeof x`（类型位置） | 单独声明 interface；`Partial` / `Record` / `Readonly` 支持 | `arkts-no-utility-types`、`arkts-no-intersection-types`、`arkts-no-type-query` |
| `name!: string` | 给初始值或构造函数赋值 | `arkts-no-definite-assignment`（WARN） |
| `arr.map(f => ({ ... }))` | `arr.map((f: T): R => { ... })` | 回调返回对象字面量要有类型可对应 |
| `const p = new Promise(r => ...)` | `new Promise<void>((r: () => void) => ...)` | `arkts-no-inferred-generic-params` |

## 动态对象操作

| TS | ArkTS | 备注 |
|---|---|---|
| `obj['name']`（class / interface 字段） | `obj.name` | `arkts-no-props-by-index`；Record 可以 `r['k']` |
| `const r: Record<string, number> = { a: 1 }` | `{ 'a': 1 }` | Record 字面量的键要加引号 |
| `'k' in obj` / `delete obj.k` / `for (k in obj)` | `map.has` / `map.delete` / `Object.keys(r)` | `arkts-no-in`、`arkts-no-delete`、`arkts-no-for-in` |
| `const { a } = o` / `const [x, y] = arr` | 一个个取 | `arkts-no-destruct-decls`、`arkts-no-destruct-assignment` |
| `{ ...o, name: 'x' }` | 字段一个个写 | `arkts-no-spread`；数组展开 `[...arr]` 可以 |
| `Object.assign`、`hasOwnProperty` | 手动赋值、`Object.keys(r).indexOf(k)` | `arkts-limited-stdlib` |
| `f.call` / `f.apply`、独立函数里的 `this` | 直接调用 | `arkts-no-func-apply-call`、`arkts-no-standalone-this` |

Record 和 Map：Record 底下是普通对象，`JSON.stringify` 正常；Map 的 `get` 返回 `V | undefined`（更安全），但 `JSON.stringify(map)` 是 `"{}"`。

## 语句

| TS | ArkTS | 规则名 |
|---|---|---|
| `var` | `let` | `arkts-no-var` |
| `function () {}`（函数表达式） | 箭头函数 | `arkts-no-func-expressions` |
| `catch (e: Error)` | `catch (e)` 再 `e as Error` | `arkts-no-types-in-catch` |
| `throw 'oops'` | `throw new Error('oops')` | `arkts-limited-throw` |

## JSON

| 场景 | 写法 | Kotlin / Swift |
|---|---|---|
| 解析 | `JSON.parse(s) as RawX`（字段全可选的 interface）→ 逐字段 `typeof` → `new X(...)` | `decodeFromString<X>()` / `JSONDecoder().decode` |
| `as` 的含义 | 只骗编译器：`instanceof` 是 false，方法调不了，字段可能是 undefined | Kotlin 的 `as` 转不了会抛异常 |
| 字符串 → 枚举 | `switch` 一遍（字符串枚举没有反向映射） | `entries.firstOrNull { }` / `init?(rawValue:)` |
| 序列化含 Map 的对象 | 先转 Record，再拼一个声明过的 interface | 库自动处理 |

## 空安全

| 写法 | ArkTS | Kotlin 对照 |
|---|---|---|
| `strictNullChecks` | 永远开着，关不掉 | 没有开关 |
| `map.get(k).x` | 编译报 possibly 'undefined' | `map[k]` 是 `V?`，同样要处理 |
| `arr[100]`、`record['无']` | 编译器不查，运行时是 undefined | `list[100]` 抛越界 |
| `a!` | 只骗编译器，运行时不检查，晚些在 `.x` 处崩 | `a!!` 立刻抛 NPE |
| `a \|\| b` | `''`、`0` 也会被兜底，要的是 `??` | `?:` 只看 null |

## ArkUI 状态（V1，是框架不是语言）

| 装饰器 | 含义 | Vue / Compose / SwiftUI 对照 |
|---|---|---|
| `@State` | 组件自己的状态，观察**自身赋值 + 第一层属性 / 数组增删** | `ref` + 浅响应 / `mutableStateOf` / `@State` |
| `@Prop` | 父 → 子单向，子拿到拷贝 | props |
| `@Link` | 父子双向 | `v-model` / `Binding` |
| `@Provide` / `@Consume` | 跨层级，按名字配对 | provide / inject / `CompositionLocal` / `@Environment` |
| `@Observed` + `@ObjectLink` | 嵌套对象的属性变化，靠子组件逐层接 | `reactive` 深响应（但要手动拆组件） |
| `@Watch('fn')` | 变化后回调 | `watch` |
| `@StorageProp` / AppStorage | 应用级全局状态 | Pinia store |
| V2：`@ComponentV2`、`@Local`、`@Param`、`@ObservedV2` + `@Trace` | 属性级观察，多深都行 | Vue 3 `reactive` |

不刷新的三种典型写法：改第二层（`this.s.list.push(x)`、`this.arr[0].name = x`）、给自己赋自己（`this.s = this.s`，框架比 `===`）、`@Prop` 里改了以为父组件会变。修法：生成新对象整体赋值，或 `@Observed` + `@ObjectLink`。

注意和 Compose 反过来：Compose 比 `==`（字段相同的新对象不重组），ArkUI V1 比 `===`（字段相同的新对象也刷新）。

## 并发

| 写法 | 含义 | 对照 |
|---|---|---|
| `async` / `await` / `Promise` / `setTimeout` | 和 TS 完全一样，单线程事件循环 | Kotlin 的 `suspend` 默认顺序执行，TS 的 Promise 创建即开始 |
| `taskpool.execute(fn, ...args)` | 丢到 worker 线程，返回 `Promise<Object>`，要自己 `as` | 浏览器 Web Worker；Kotlin `withContext(Dispatchers.Default)` 但不共享内存 |
| `@Concurrent function` | 只能用参数、局部变量、import 进来的东西；同文件顶层常量 / 函数 / class 都不行 | Web Worker 的 `postMessage` 只能传可序列化数据 |
| 参数是普通 class 实例 | 到 worker 里只剩字段，方法没了 | 要带方法 / 共享用 `@Sendable class` |
| 本地单测里的 taskpool | 空壳，`execute` 返回 `{}` | 要在设备上测 |

## 不是语言、是框架 / 库的

`@Component`、`@Entry`、`@State` 等装饰器、`build()`、`ForEach`、`@Builder`（ArkUI）；`taskpool`、`@Concurrent`（ArkTS 基础库 `@kit.ArkTS`，`@Concurrent` 由编译器检查）；`AppStorage`、`NavPathStack`（ArkUI）；`http`、`preferences`（各个 Kit）。在 DevEco 里 ⌘ 点进去能看到 SDK 里的声明。
