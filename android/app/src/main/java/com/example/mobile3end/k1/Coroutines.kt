package com.example.mobile3end.k1

import com.example.mobile3end.model.FileItem
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.withTimeoutOrNull

// K1 第 6 节：suspend 和协程（最小心智模型）
//
// suspend fun ≈ TS 的 async function，但调用时不写 await：在 suspend 函数里直接调另一个 suspend 函数，就是「等它完成」
//   TS：const files = await api.fetch()
//   Kt：val files = api.fetch()
// 所以 Kotlin 默认是「顺序执行」，想并发要显式写出来：
//   coroutineScope { val a = async { f() }; val b = async { g() }; a.await() + b.await() }  ≈ Promise.all
//   withTimeoutOrNull(1000) { f() }   超时返回 null                                       ≈ Promise.race + 定时器
//   withContext(io) { ... }           换一个线程池执行，执行完回到原来的线程（M2-2）           TS 没有对应物，JS 是单线程
//   launch { ... }                    起一个不等结果的协程                                  ≈ 不 await 的 promise，但有作用域，作用域取消它就取消
//
// 结构化并发：coroutineScope / viewModelScope 里起的协程，作用域结束前必须都完成，作用域取消它们全部取消。
// 这就是为什么页面关了 viewModelScope 被取消，M2-7 里会收到 CancellationException

// 空 K1-14：同时请求两个来源，结果按 first 在前、second 在后拼起来
// 测试会让两个来源各花 1 秒，总耗时必须是 1 秒而不是 2 秒
// 提示 1：coroutineScope { async { } ... await() }
suspend fun loadBoth(
    first: suspend () -> List<FileItem>,
    second: suspend () -> List<FileItem>,
): List<FileItem> =
    // 批注 K1-14 ✅：两个 async 先都启动再 await，测试确认总耗时 1 秒而不是 2 秒
    //   如果写成 val a = first(); val b = second() 就退化成顺序执行，这是 TS 用户最常见的坑，你避开了
    coroutineScope {
        val firstResult = async { first() }
        val secondResult = async { second() }
        firstResult.await() + secondResult.await()
    }

// 空 K1-15：执行 block，超过 timeoutMs 毫秒就放弃并返回 null
// 对应 M4 的白屏检测：等 H5 渲染，等不到就判定
// 提示 1：kotlinx.coroutines 里有现成的函数，名字就是这句话
suspend fun <T> fetchOrNull(timeoutMs: Long, block: suspend () -> T): T? =
    // 批注 K1-15 ✅：超时时 block 是被取消的（内部收到 CancellationException），和 M2-7 为什么要把它原样抛出是一回事
    withTimeoutOrNull(timeoutMs) {
        block()
    }
