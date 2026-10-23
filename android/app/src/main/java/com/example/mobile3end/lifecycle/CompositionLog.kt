package com.example.mobile3end.lifecycle

import android.util.Log
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.example.mobile3end.TAG

// 空 M3-3：这个 Composable 进入组合时打一条「<name> 进入组合」，离开组合时打一条「<name> 离开组合」
// 重组（状态变了、函数体重新执行）不算进出，不能重复打
// 提示 1：DisposableEffect(Unit) { ...; onDispose { ... } }，≈ Vue 的 onMounted + onUnmounted
@Composable
fun LogComposition(name: String, log: (String) -> Unit = { Log.d(TAG, it) }) {
    TODO("M3-3")
}

/**
 * 已写好：打出所在页面的 Lifecycle 事件。
 * Navigation Compose 里每个目的地（NavBackStackEntry）都是一个 LifecycleOwner：
 * 进详情页时列表页的 entry 会走到 ON_STOP，返回时再 ON_START。和 Activity 的生命周期是两回事，对比着看日志
 */
@Composable
fun LogLifecycle(name: String, log: (String) -> Unit = { Log.d(TAG, it) }) {
    val owner = LocalLifecycleOwner.current
    DisposableEffect(owner) {
        val observer = LifecycleEventObserver { _, event -> log("$name.lifecycle $event") }
        owner.lifecycle.addObserver(observer)
        onDispose { owner.lifecycle.removeObserver(observer) }
    }
}
