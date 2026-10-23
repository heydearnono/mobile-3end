package com.example.mobile3end.lifecycle

import android.os.SystemClock
import android.util.Log
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.ProcessLifecycleOwner
import com.example.mobile3end.TAG
import com.example.mobile3end.TodoGuard
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow

/*
 * M3：生命周期。Android 有三层，对照 iOS（AppDelegate / scenePhase / onAppear）、鸿蒙（UIAbility / WindowStage / 组件）：
 *
 * - 应用级：ProcessLifecycleOwner。整个 App 只有一份：第一个 Activity onStart → ON_START，
 *   最后一个 Activity onStop 之后约 700ms → ON_STOP（延迟是为了让旋转屏幕这种「停一下马上又起来」不算进后台）。
 *   永远不会发 ON_DESTROY：进程是被系统直接杀掉的，没有回调
 * - Activity 级：onCreate / onStart / onResume / onPause / onStop / onDestroy（MainActivity 里已经打了日志）
 * - Composable 级：进入 / 离开组合（M3-3），以及每个导航目的地自己的 Lifecycle（CompositionLog.kt 里的 LogLifecycle）
 *
 * 这个文件是纯逻辑（时间、事件都从外面传进来），JVM 单测覆盖；接到 ProcessLifecycleOwner 上的胶水在最下面的 AppLifecycle
 */

/** 切后台多久再回来要刷新列表 */
object RefreshPolicy {
    const val THRESHOLD_MS = 30_000L

    // 空 M3-1：backgroundAtMs 是进后台的时刻（没进过后台为 null），判断回前台时要不要刷新：在后台待满 30s 就刷新（正好 30s 也算）
    // 提示 1：Long? 要先处理 null；两个时刻相减就是毫秒数
    fun shouldRefresh(backgroundAtMs: Long?, nowMs: Long): Boolean {
        TODO("M3-1")
    }
}

/**
 * 把进程级生命周期事件翻译成「回前台判断要不要刷新」。
 * @param now 当前时刻（ms）。默认用开机以来的时间 elapsedRealtime：不受用户改系统时间影响，≈ 浏览器的 performance.now()
 */
class AppLifecycleTracker(
    private val now: () -> Long = SystemClock::elapsedRealtime,
    private val log: (String) -> Unit = { Log.d(TAG, it) },
    private val onRefresh: () -> Unit,
) {
    private var backgroundAtMs: Long? = null

    // 空 M3-2：处理一个进程级生命周期事件
    // - ON_STOP（整个 App 退到后台）：记下时刻
    // - ON_START（回到前台）：问 RefreshPolicy，要刷新就打一条日志「后台超过 30s，刷新列表」并调 onRefresh()；不管刷不刷新都清掉记录
    // - 其他事件不管。ON_PAUSE 不算进后台：下拉通知栏、弹出别的 App 的对话框、分屏时点了另一边，都只到 ON_PAUSE，App 还看得见
    // 提示 1：when (event) { Lifecycle.Event.ON_STOP -> ...  Lifecycle.Event.ON_START -> { ... }  else -> {} }
    fun onEvent(event: Lifecycle.Event) {
        TODO("M3-2")
    }
}

/** spec JSBridge 协议里 appState 事件的两个取值 */
const val APP_FOREGROUND = "foreground"
const val APP_BACKGROUND = "background"

// 空 M3-5：M4 要给 H5 推 appState 事件，把进程级生命周期事件翻译成协议里的值：
// ON_START → "foreground"，ON_STOP → "background"，其他返回 null，表示不推
// 提示 1：when 可以直接当表达式返回值，else -> null
fun appStateOf(event: Lifecycle.Event): String? =
    TODO("M3-5")

/**
 * 胶水（已写好）：接到 ProcessLifecycleOwner 上，全进程一份。
 * - refreshRequests：回前台、在后台待满 30s 时发一次，App.kt 里的列表收到就刷新
 * - appState：当前前后台状态，M4 的 H5 页收到变化就推给 H5
 *
 * STAGE ≥ 3 时在 M3EApplication.onCreate 里安装；测试里由 App(stage = 3) 安装。重复调用只装一次
 */
object AppLifecycle {
    private val _refreshRequests = MutableSharedFlow<Unit>(extraBufferCapacity = 1)
    val refreshRequests: SharedFlow<Unit> = _refreshRequests.asSharedFlow()

    private val _appState = MutableStateFlow<String?>(null)
    val appState: StateFlow<String?> = _appState.asStateFlow()

    private var installed = false

    /** 只能在主线程调（addObserver 的要求） */
    fun install(log: (String) -> Unit = { Log.d(TAG, it) }) {
        if (installed) return
        installed = true
        val tracker = AppLifecycleTracker(log = log, onRefresh = { _refreshRequests.tryEmit(Unit) })
        ProcessLifecycleOwner.get().lifecycle.addObserver(
            LifecycleEventObserver { _, event ->
                log("Process.$event")
                TodoGuard.run(Unit) { tracker.onEvent(event) }
                TodoGuard.run(null) { appStateOf(event) }?.let { _appState.value = it }
            },
        )
    }
}
