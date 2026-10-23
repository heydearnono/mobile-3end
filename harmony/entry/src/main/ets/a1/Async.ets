import { taskpool } from '@kit.ArkTS';
import { TODO } from '../common/Todo';

// A1 第 5 节：async / Promise 与 TaskPool
//
// async / await / Promise / setTimeout 和 TS 完全一样，也是单线程 + 事件循环：await 让出的是「当前这段代码」，不是线程。
// 只有一处要注意：泛型推断不出来时 TS 会给 unknown，ArkTS 不允许 unknown，所以
//   const p = new Promise(resolve => setTimeout(resolve, 100))   ✗ 推断成 Promise<unknown>（arkts-no-inferred-generic-params）
//   const p = new Promise<void>((resolve: () => void) => { ... })  ✓ 类型参数写出来（回调参数类型也写上更稳）
// 直接 return new Promise(...) 时编译器能从函数返回类型推出 T，不写也能过；赋给变量时就推不出了
//
// TaskPool 是鸿蒙的库（@kit.ArkTS 里的 taskpool），不是语言特性。≈ 浏览器的 Web Worker：
//   - worker 是另一个 JS 虚拟机实例，和主线程不共享内存，参数和返回值是复制过去的（序列化）
//   - 所以丢过去的函数必须标 @Concurrent，而且函数体里只能用「参数、自己的局部变量、import 进来的东西」：
//     同一个文件里的顶层常量、函数、class 都不行，编译时报
//     Concurrent function should only use import variable or local variable, 'xxx' is not one of them
//   - 参数是普通 class 实例时，到了 worker 里只剩字段，方法没了（和 JSON.parse 后 as 成 class 一样）；
//     要传「带方法的对象」或者共享内存，得用 @Sendable class（API 11+）
// 对照 Kotlin：withContext(Dispatchers.Default) { } 是同一个进程里换线程，共享内存，lambda 随便捕获变量；
// TaskPool 更像 Android 的跨进程，或者浏览器 postMessage
//
// 本地单测里 taskpool 是空壳（execute 直接返回 {}），所以 A1-10 只测 @Concurrent 函数本身（它也能当普通函数直接调），
// 真的丢到 TaskPool 跑要在设备上，见 hints 的想一想

// 空 A1-9：给一个 Promise 加超时：task 在 ms 毫秒内完成就返回它的结果，超时就返回 fallback；task reject 就照样 reject
// 白屏检测、JSBridge 等 H5 回应都会用到「等一会儿，等不到就算了」
// 提示 1：Promise.race 两个 Promise：task 和一个 ms 毫秒后 resolve(fallback) 的 Promise。new Promise 要写类型参数
export function withTimeout<T>(task: Promise<T>, ms: number, fallback: T): Promise<T> {
  return TODO('A1-9');
}

// 空 A1-10：在 TaskPool 里算离线包文件的校验和（第 2 节 manifest 里 files 的值就是它），大文件算起来慢，不能卡主线程
// 算法是 32 位 FNV-1a，按 UTF-16 码元（charCodeAt）逐个处理：
//   hash 初始 0x811c9dc5；每个码元 c：hash = hash ^ c，然后 hash = hash * 0x01000193（只保留低 32 位）
// 输出 8 位小写十六进制，不足 8 位前面补 0
// 要求：所有常量写在函数体里（@Concurrent 不能用文件里的顶层常量）
// 提示 1：Math.imul(a, b) 是 32 位整数乘法；位运算结果是有符号的，>>> 0 转成无符号；toString(16) + padStart
@Concurrent
export function checksum(text: string): string {
  return TODO('A1-10');
}

/** 真正丢到 TaskPool 执行（已写好）。execute 返回 Promise<Object>，要自己收窄成 string */
export async function checksumOffMain(text: string): Promise<string> {
  const result = await taskpool.execute(checksum, text);
  return result as string;
}
