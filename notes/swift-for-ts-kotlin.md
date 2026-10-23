# Swift 速查（给 TS / Kotlin 用户）

读线上 App 的 iOS 容器代码时查。中间一列 Kotlin 是你在 K1 里写过的，当桥梁用。练习在 `ios/Mobile3End/S1/`，提示在 `hints/ios-S1.md`。

## 变量、函数

| TS | Kotlin | Swift | 备注 |
|---|---|---|---|
| `const x = 1` | `val x = 1` | `let x = 1` | 修饰 struct 时整个不可变，见「值类型」 |
| `let x = 1` | `var x = 1` | `var x = 1` | |
| `function f(a: number): string` | `fun f(a: Int): String` | `func f(a: Int) -> String` | |
| `f(1)` | `f(1)` / `f(a = 1)` | `f(a: 1)` | Swift 默认要写参数标签 |
| — | — | `func f(_ a: Int)` → `f(1)` | `_` 去掉标签 |
| — | — | `func load(from url: URL)` → `load(from: u)` | 外部标签 / 内部名分开 |
| `` `${a} b` `` | `"$a b"` | `"\(a) b"` | 字符串插值 |
| `` `多行` `` | `"""多行"""` | `"""` 换行写 `"""` | 工程里内联 HTML / JS 都这么写 |
| `void` | `Unit` | `Void` / `()` | |
| `never` | `Nothing` | `Never` | `TODO()`、`fatalError` 的返回类型 |
| `any` | `Any` | `Any` | 字典取值、JSONSerialization 出来都是 Any |
| 单表达式箭头函数 | `fun f() = x` | `func f() -> T { x }` | 函数体只有一个表达式时可省 `return` |

## 可选类型

| TS | Kotlin | Swift |
|---|---|---|
| `string \| null` | `String?` | `String?`（其实是 `Optional<String>` 枚举） |
| `a?.b` | `a?.b` | `a?.b` |
| `a ?? b` | `a ?: b` | `a ?? b` |
| `a!`（只骗编译器） | `a!!` | `a!`（nil 就崩，SIGTRAP） |
| `if (a != null) use(a)` | smart cast | `if let a { use(a) }` |
| `if (!a) return` | `val x = a ?: return` | `guard let x = a else { return }` |
| — | `a?.let { f(it) }` | `a.map { f($0) }` / `a.flatMap(f)` |
| `a instanceof T ? a : null` | `a as? T` | `a as? T` |
| — | `a as T` | `a as! T`（转不了就崩） |
| `parseInt` 得 NaN | `toIntOrNull()` | `Int("x")` 返回 `Int?` |

## 闭包

| TS | Kotlin | Swift | 备注 |
|---|---|---|---|
| `(a) => a + 1` | `{ a -> a + 1 }` | `{ a in a + 1 }` | |
| — | `{ it + 1 }` | `{ $0 + 1 }` | 两个参数 `$0`、`$1` |
| `(f: T) => void` | `(T) -> Unit` | `(T) -> Void` | 函数类型 |
| `f => f.name` | `{ it.name }` | `\.name` | key path，`map(\.name)` |
| — | `f(a) { }` | `f(a) { }` | 尾随闭包，两边一样 |
| — | — | `@escaping` | 闭包要存起来以后再调时必须标 |
| — | — | `{ [weak self] in }` | 捕获列表，打破循环引用 |
| 多行箭头函数最后一行 | lambda 最后一行就是返回值 | 多行闭包要写 `return` | 和 Kotlin 不同 |

## 值类型 vs 引用类型（最大的差异）

| | TS | Kotlin | Swift |
|---|---|---|---|
| 数组 / 字典赋值 | 共享 | 共享 | **复制**（copy-on-write） |
| 自定义数据类型 | 对象，共享 | `data class`，共享 | `struct`，复制 |
| 共享、有身份的对象 | class | class | `class` / `actor` |
| `const` / `val` / `let` 修饰的对象改字段 | 可以 | 可以 | struct 不行，class 可以 |
| 方法改自己的字段 | 直接改 | 直接改 | struct 要 `mutating func` |
| 函数里改参数并影响调用方 | 改对象字段 | 改对象字段 | `inout` 参数 + 调用时 `&x` |
| `{ ...obj, name }` | — | `copy(name = )` | `var c = obj; c.name = x`（就是复制） |
| 引用相等 | `===` | `===` | `===`（只有 class） |
| 值相等 | 自己写 | `==`（data class） | `==`（声明 `Equatable` 自动生成） |

改数组里的 struct：`tasks[i].progress = 1` 有效；`var t = tasks.first!; t.progress = 1` 改的是副本。

## enum 与模式匹配

| TS | Kotlin | Swift |
|---|---|---|
| `{ kind: 'failed'; message }` 联合 | `sealed` + `data class Failed(val message)` | `case failed(String)` 关联值 |
| `switch (s.kind)` | `when (s) { is Failed -> s.message }` | `switch s { case .failed(let m): }` |
| `if (s.kind === 'loaded')` | `if (s is Loaded)` | `if case .loaded(let files) = s` |
| — | `when { 条件 -> }` | `case .loaded(let f) where f.isEmpty:` |
| `enum E { A = 'a' }` | `enum class` | `enum E: String { case a }` + `E(rawValue:)` 返回可选 |
| — | `entries` | `CaseIterable` → `E.allCases` |
| 三元表达式 | `if` / `when` 是表达式 | `switch` / `if` 是表达式（Swift 5.9+） |
| `default` | `else` | `default` / 系统枚举用 `@unknown default` |

## protocol 与 extension

| TS | Kotlin | Swift | 备注 |
|---|---|---|---|
| `interface I { f(): void }` | `interface I { fun f() }` | `protocol P { func f() }` | |
| `class A implements I` | `class A : I` | `struct A: P` | struct / enum 也能遵守 |
| — | interface 里写方法体 | `extension P { func f() { } }` | 协议默认实现 |
| 改 prototype | `fun String.f()` | `extension String { func f() }` | Swift 不用 import，同 target 全局可见 |
| — | `fun List<FileItem>.f()` | `extension Array where Element == FileItem` | 带约束的扩展 |
| — | — | `extension FileItem: P { }` | 给已有类型补签协议 |
| `I` 当类型 | `I` 当类型 | `any P` | 运行时才知道具体类型 |
| — | — | `some P` | 编译期确定的具体类型（`some View`） |
| 结构化类型（形状对上就行） | 名义类型 | 名义类型，必须显式声明 | |
| 泛型 `<T extends I>` | `<T : I>` | `<T: P>` / `where T: P` | |

## 错误处理

| TS | Kotlin | Swift |
|---|---|---|
| 不声明 | 不声明 | `func f() throws -> T` |
| `f()` | `f()` | `try f()`（必须写 `try`） |
| `try { } catch (e) { }` | `try { } catch (e: E) { }` | `do { try f() } catch E.x(let v) { } catch { error }` |
| — | `runCatching { }.getOrNull()` | `try? f()` |
| — | — | `try! f()`（出错就崩） |
| — | `Result<T>` | `Result<T, E>`，`Result { try f() }`、`.get()` |
| `throw new Error()` | `throw E()` | `throw MyError.x`（任何遵守 `Error` 的类型，通常是 enum） |
| — | — | `error as NSError` 看 `domain` / `code`（系统 API 的错误） |

## 并发

| TS | Kotlin | Swift | 备注 |
|---|---|---|---|
| `async function f()` | `suspend fun f()` | `func f() async` | |
| `await f()` | `f()` | `await f()` | |
| `Promise.all([a(), b()])` | `coroutineScope { async {}; async {} }` | `async let x = a(); async let y = b(); await (x, y)` | 默认顺序，并发要显式写 |
| `Promise.all(list.map(f))` | `list.map { async { f(it) } }.awaitAll()` | `withTaskGroup(of:) { group in }` | |
| 不 await 的 promise | `scope.launch { }` | `Task { }` | 继承当前 actor |
| — | `launch(Dispatchers.Default)` | `Task.detached { }` | 不继承 actor，M3-4 |
| `AbortController` | `job.cancel()` | `task.cancel()` | 协作式取消 |
| `AbortError` | `CancellationException` | `CancellationError` | |
| — | `isActive` | `Task.isCancelled` | |
| `setTimeout` + Promise | `delay(ms)` | `try await Task.sleep(for: .seconds(1))` | |
| — | `withTimeoutOrNull` | 没有现成的，TaskGroup + sleep 自己拼 | |
| 单线程 | `Dispatchers.Main` / `withContext(Main)` | `@MainActor` / `await MainActor.run { }` | 编译器检查 |
| — | — | `nonisolated` | 不属于任何 actor，可以在后台跑 |
| — | — | `@Sendable` / `Sendable` | 能安全跨线程的标记，Swift 6 编译期检查 |
| — | `Mutex` / `synchronized` | `actor` | 自带串行队列的 class |
| 回调转 Promise | `suspendCancellableCoroutine` | `withCheckedContinuation` | `TestSupport.swift` 的 `GatedRemote` |

## property wrapper 与状态

| Vue | Compose | SwiftUI | 背后是什么 |
|---|---|---|---|
| `ref()` | `var x by remember { mutableStateOf() }` | `@State var x` | property wrapper，存储在视图外 |
| `x.value` | `x`（by 委托） | `x`（`_x.wrappedValue`） | |
| `v-model` / props + emit | `value` + `onValueChange` | `@Binding var x`，传 `$x` | `$x` 是 `_x.projectedValue` |
| `provide` / `inject` | `CompositionLocal` | `@Environment(\.dismiss)` | property wrapper |
| `useLocalStorage` | DataStore | `@AppStorage("key")` | property wrapper |
| Pinia store | ViewModel + StateFlow | `@Observable class` | **宏**，不是 property wrapper |
| `storeToRefs` | — | `@Bindable var model` → `$model.order` | property wrapper |
| — | `by lazy { }` | `lazy var x = ...` | 语言关键字 |
| `watch` | `snapshotFlow` / `LaunchedEffect(key)` | `.onChange(of:)` | 框架修饰符 |
| `watch` 单个属性 | 自定义 setter / `Delegates.observable` | `var x { didSet { } }` | 属性观察器，语言自带 |

## 看着像语法，其实不是

- 库（标准库 / Concurrency）：`Task`、`Task.sleep`、`withTaskGroup`、`Result`、`map` / `filter` / `reduce` / `first(where:)`
- 框架（SwiftUI）：`VStack { }`、`.task { }`、`.toolbar { }`（尾随闭包 + `@ViewBuilder` 结果构建器）；`@State`、`@Binding`、`@Environment`、`@AppStorage`（property wrapper）
- 宏：`@Observable`、`#Preview`。右键 → Expand Macro 能看到展开结果
- 编译器标注：`@MainActor`、`@escaping`、`@Sendable`、`@main`、`@objc`、`nonisolated`

⌘ 点进去：库和框架的东西能看到声明；宏能展开；编译器标注点不进去。
