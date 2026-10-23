# Kotlin 速查（给 TS 用户）

读线上 App 的容器代码时查。左边是 TS 写法，右边是 Kotlin。练习在 `android/.../k1/`，提示在 `hints/K1.md`。

## 变量、函数

| TS | Kotlin | 备注 |
|---|---|---|
| `const x = 1` | `val x = 1` | 只读 |
| `let x = 1` | `var x = 1` | 可变 |
| `let x: number` | `val x: Int` | 类型写在后面，和 TS 一样 |
| `function f(a: number): string { return ... }` | `fun f(a: Int): String { return ... }` | 块函数体必须写 `return` |
| `const f = (a: number) => a + 1` | `fun f(a: Int) = a + 1` | 表达式函数体 |
| `(a: number) => string`（类型） | `(Int) -> String` | 函数类型 |
| `(a) => a + 1`（值） | `{ a -> a + 1 }` / `{ it + 1 }` | lambda 最后一个表达式就是返回值 |
| `f({ a: 1 })` 模拟具名参数 | `f(a = 1)` | 命名参数，可跳过有默认值的 |
| `` `${a} b` `` | `"$a b"` / `"${a.b} c"` | 字符串模板 |
| `void` | `Unit` | |
| `never` | `Nothing` | `TODO()`、`throw` 的类型 |

## 表达式

| TS | Kotlin |
|---|---|
| `c ? a : b` | `if (c) a else b`（Kotlin 没有三元运算符） |
| `switch` | `when (x) { 1 -> ...; else -> ... }`，能当值用 |
| `if / else if` 链 | `when { cond1 -> ...; cond2 -> ...; else -> ... }` |
| `try` 只能当语句 | `val r = try { ... } catch (e: E) { ... }` |

## 空安全

| TS | Kotlin |
|---|---|
| `string \| null` | `String?` |
| `a?.b` | `a?.b` |
| `a ?? b` | `a ?: b` |
| `a!`（只骗编译器） | `a!!`（运行时是 null 会抛 NPE） |
| `typeof a === 'string'` 后收窄 | `if (a is String)` 后 smart cast |
| `a instanceof T ? a : null` | `a as? T` |
| `if (a != null) { use(a) }` | `a?.let { use(it) }` |

## 类型

| TS | Kotlin | 备注 |
|---|---|---|
| `interface` / 纯数据对象 | `data class` | 自动 equals / copy / toString |
| `{ ...obj, name: 'x' }` | `obj.copy(name = "x")` | |
| `===`（引用） / 自己写的深比较 | `===` / `==` | Kotlin 的 `==` 调 equals，data class 比字段 |
| 可辨识联合 `A \| B` | `sealed interface` + 子类 | `when` 写全不用 else |
| `enum` | `enum class` | `entries` 拿全部，`name` 拿名字 |
| 单例模块 `export const x = {...}` | `object X { }` | |
| 类上的 static | `companion object { }` | |

## lambda 与作用域函数

| 写法 | 含义 |
|---|---|
| `f(a) { ... }` | 尾随 lambda：最后一个参数是函数时可以写在括号外面 |
| `f { ... }` | 只有一个 lambda 参数，括号也省了 |
| `buildString { append("a") }` | 带接收者的 lambda：里面的 `this` 是 StringBuilder |
| `x.let { it }` | 返回 lambda 结果；常用 `x?.let { }` |
| `x.also { it }` | 返回 x；顺手做点事（打日志） |
| `x.apply { this }` | 返回 x；配置对象 |
| `x.use { it }` | 返回 lambda 结果，结束后 close |
| `runCatching { }` | try / catch 包成 `Result` |

## 扩展、委托

| 写法 | 含义 |
|---|---|
| `fun String.shout() = ...` | 扩展函数，要 import 才能用，不能访问 private |
| `val List<T>.total get() = ...` | 扩展属性，不能存值 |
| `var x by state` | 属性委托：读写 x 转给 state 的 getValue / setValue（Compose 的 `by remember { }`） |
| `val x by lazy { }` | 第一次访问时才计算 |

## 协程

| TS | Kotlin | 备注 |
|---|---|---|
| `async function f()` | `suspend fun f()` | |
| `await f()` | `f()` | suspend 函数里直接调就是等 |
| `Promise.all([a(), b()])` | `coroutineScope { val x = async { a() }; val y = async { b() }; x.await() + y.await() }` | 默认是顺序的，要并发得显式写 |
| 不 await 的 promise | `scope.launch { }` | 有作用域，作用域取消它就取消 |
| — | `withContext(Dispatchers.IO) { }` | 换线程池执行，JS 没有对应物 |
| `AbortController` | 协程取消 → `CancellationException` | 不要吞掉，原样抛 |
| 可观察的 store | `StateFlow` / `Flow` | `collectAsStateWithLifecycle()` 接进 Compose |

## 不是语言、是库的

看着像语法，其实是函数：`remember`、`rememberSaveable`（Compose）；`withContext`、`launch`、`async`（kotlinx.coroutines）；`use`、`let`、`buildString`（标准库）；`dataStore.edit { }`（DataStore）。⌘ 点进去都能看到实现。
