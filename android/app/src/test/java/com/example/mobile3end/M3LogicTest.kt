package com.example.mobile3end

import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.ViewModelStore
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.example.mobile3end.data.FileListLoader
import com.example.mobile3end.data.LocalFiles
import com.example.mobile3end.data.SettingsStore
import com.example.mobile3end.lifecycle.APP_BACKGROUND
import com.example.mobile3end.lifecycle.APP_FOREGROUND
import com.example.mobile3end.lifecycle.AppLifecycleTracker
import com.example.mobile3end.lifecycle.MainThreadDemo
import com.example.mobile3end.lifecycle.RefreshPolicy
import com.example.mobile3end.lifecycle.appStateOf
import com.example.mobile3end.model.FileItem
import com.example.mobile3end.model.FileType
import com.example.mobile3end.ui.FileListViewModel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.asCoroutineDispatcher
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File
import java.util.concurrent.CountDownLatch
import java.util.concurrent.ExecutionException
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.TimeoutException

/** M3 纯逻辑检查，JVM 上跑，不需要模拟器。方法名前缀 = 覆盖的空 */
class M3LogicTest {

    // ---------- M3-1 ----------

    @Test
    fun m3_1_neverInBackground_noRefresh() {
        assertFalse("没进过后台（冷启动的第一次 ON_START）不刷新", RefreshPolicy.shouldRefresh(null, 100_000))
    }

    @Test
    fun m3_1_thresholdIs30sInclusive() {
        assertFalse(RefreshPolicy.shouldRefresh(1_000, 1_000 + 29_999))
        assertTrue("正好 30s 也算", RefreshPolicy.shouldRefresh(1_000, 1_000 + 30_000))
        assertTrue(RefreshPolicy.shouldRefresh(1_000, 1_000 + 120_000))
    }

    // ---------- M3-2 ----------

    private var clock = 0L
    private val logs = mutableListOf<String>()
    private var refreshes = 0
    private val tracker = AppLifecycleTracker(now = { clock }, log = { logs += it }, onRefresh = { refreshes++ })

    /** 按真实顺序走一遍：退到后台 ON_PAUSE → ON_STOP，回来 ON_START → ON_RESUME */
    private fun goBackgroundFor(ms: Long) {
        tracker.onEvent(Lifecycle.Event.ON_PAUSE)
        tracker.onEvent(Lifecycle.Event.ON_STOP)
        clock += ms
        tracker.onEvent(Lifecycle.Event.ON_START)
        tracker.onEvent(Lifecycle.Event.ON_RESUME)
    }

    @Test
    fun m3_2_coldStartDoesNotRefresh() {
        tracker.onEvent(Lifecycle.Event.ON_CREATE)
        tracker.onEvent(Lifecycle.Event.ON_START)
        tracker.onEvent(Lifecycle.Event.ON_RESUME)
        assertEquals(0, refreshes)
    }

    @Test
    fun m3_2_backFor35s_refreshesOnceWithLog() {
        goBackgroundFor(35_000)
        assertEquals(1, refreshes)
        assertTrue("刷新时要打日志，验收时靠它确认", logs.any { "刷新列表" in it })
    }

    @Test
    fun m3_2_backFor10s_noRefresh() {
        goBackgroundFor(10_000)
        assertEquals(0, refreshes)
    }

    @Test
    fun m3_2_recordClearedAfterForeground() {
        goBackgroundFor(35_000)
        // 回前台以后在前台待了很久，又来一次 ON_START（比如多窗口模式下的重复事件），不该再刷新
        clock += 60_000
        tracker.onEvent(Lifecycle.Event.ON_START)
        assertEquals("回前台后要清掉进后台的时刻，否则下次 ON_START 会重复刷新", 1, refreshes)
    }

    @Test
    fun m3_2_pauseIsNotBackground() {
        // 下拉通知栏 / 弹出系统对话框：只有 ON_PAUSE → ON_RESUME，没有 ON_STOP
        tracker.onEvent(Lifecycle.Event.ON_PAUSE)
        clock += 60_000
        tracker.onEvent(Lifecycle.Event.ON_RESUME)
        tracker.onEvent(Lifecycle.Event.ON_START)
        assertEquals("ON_PAUSE 不算进后台", 0, refreshes)
    }

    @Test
    fun m3_2_eachLongBackgroundRefreshes() {
        goBackgroundFor(31_000)
        goBackgroundFor(5_000)
        goBackgroundFor(40_000)
        assertEquals(2, refreshes)
    }

    // ---------- M3-4 ----------

    private val mainExecutor = Executors.newSingleThreadExecutor { r -> Thread(r, "m3e-main") }
    private val ioExecutor = Executors.newSingleThreadExecutor { r -> Thread(r, "m3e-io") }
    private val mainScope = CoroutineScope(SupervisorJob() + mainExecutor.asCoroutineDispatcher())

    @After
    fun shutdown() {
        mainScope.cancel()
        mainExecutor.shutdownNow()
        ioExecutor.shutdownNow()
    }

    /** 在假主线程上执行 block 并等它返回。block 里抛的异常（包括未填的 TODO）原样抛到测试里 */
    private fun onMain(timeoutMs: Long = 2_000, block: () -> Unit) {
        try {
            mainExecutor.submit(block).get(timeoutMs, TimeUnit.MILLISECONDS)
        } catch (e: ExecutionException) {
            throw e.cause!!
        }
    }

    @Test
    fun m3_4_workOnIo_resultBackOnCallerThread() {
        var workThread = ""
        var resultThread = ""
        var result = ""
        val done = CountDownLatch(1)
        val demo = MainThreadDemo(mainScope, ioExecutor.asCoroutineDispatcher(), log = { logs += it }) {
            resultThread = Thread.currentThread().name
            result = it
            done.countDown()
        }
        onMain {
            demo.runInBackground {
                workThread = Thread.currentThread().name
                "ok"
            }
        }
        assertTrue("2s 内应该拿到结果", done.await(2, TimeUnit.SECONDS))
        // 测试里协程开了调试模式，线程名后面会带上「 @coroutine#n」，只比前缀
        assertEquals("work 应该在 io 上跑", "m3e-io", workThread.substringBefore(" @"))
        assertEquals("onResult 要回到调用方（主线程）上调，界面只能在主线程更新", "m3e-main", resultThread.substringBefore(" @"))
        assertEquals("ok", result)
    }

    @Test
    fun m3_4_returnsImmediately() {
        val release = CountDownLatch(1)
        val done = CountDownLatch(1)
        val demo = MainThreadDemo(mainScope, ioExecutor.asCoroutineDispatcher(), log = { logs += it }) { done.countDown() }
        try {
            onMain(timeoutMs = 1_000) {
                demo.runInBackground {
                    release.await(5, TimeUnit.SECONDS)
                    "slow"
                }
            }
        } catch (e: TimeoutException) {
            fail("runInBackground 不能等 work 跑完才返回（那样主线程就卡住了）")
        }
        release.countDown()
        assertTrue(done.await(2, TimeUnit.SECONDS))
    }

    @Test
    fun m3_4_exceptionBecomesText() {
        var result = ""
        val done = CountDownLatch(1)
        val demo = MainThreadDemo(mainScope, ioExecutor.asCoroutineDispatcher(), log = { logs += it }) {
            result = it
            done.countDown()
        }
        onMain { demo.runInBackground { throw java.io.IOException("down") } }
        assertTrue(done.await(2, TimeUnit.SECONDS))
        assertEquals("异常也要变成文字交给 onResult，不能让协程直接崩掉", "失败：IOException", result)
    }

    // ---------- M3-6 ----------

    @get:Rule
    val tmp = TemporaryFolder()

    private val files = listOf(FileItem("a", "a.txt", FileType.DOC, 1, 10))

    /** 建一个 ViewModel：数据来自数 fetch 次数的假 remote，没有缓存。viewModelScope 用 Dispatchers.Main，测试里换成 test 调度器 */
    private class VmFixture(val vm: FileListViewModel, val store: ViewModelStore, val requests: MutableSharedFlow<Unit>, val calls: () -> Int)

    private fun withViewModel(block: (VmFixture) -> Unit) {
        val main = UnconfinedTestDispatcher()
        Dispatchers.setMain(main)
        val dsScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
        val store = ViewModelStore()
        try {
            var calls = 0
            val noCache = object : LocalFiles {
                override fun load(): List<FileItem>? = null
                override fun save(files: List<FileItem>) {}
            }
            val loader = FileListLoader({ calls++; files }, noCache, io = main, log = { logs += it })
            val settings = SettingsStore(PreferenceDataStoreFactory.create(scope = dsScope) { File(tmp.root, "s.preferences_pb") })
            val requests = MutableSharedFlow<Unit>()
            val vm = ViewModelProvider.create(store, viewModelFactory {
                initializer { FileListViewModel(loader, settings, requests) }
            })[FileListViewModel::class]
            block(VmFixture(vm, store, requests) { calls })
        } finally {
            store.clear()
            dsScope.cancel()
            Dispatchers.resetMain()
        }
    }

    @Test
    fun m3_6_eachRequestRefreshesOnce() = withViewModel { f ->
        assertEquals("ViewModel 创建时加载一次（M2 就有）", 1, f.calls())
        runBlocking { f.requests.emit(Unit) }
        assertEquals("收到一次刷新请求，多请求一次", 2, f.calls())
        runBlocking { f.requests.emit(Unit) }
        assertEquals("每次都要刷新，不是只有第一次", 3, f.calls())
    }

    @Test
    fun m3_6_subscribedOnce_stopsAfterCleared() = withViewModel { f ->
        assertEquals("只订阅一次", 1, f.requests.subscriptionCount.value)
        f.store.clear() // 页面彻底退出 → onCleared → viewModelScope 取消
        assertEquals("ViewModel 销毁后要停止收集，否则 ViewModel 泄漏、还在后台发请求", 0, f.requests.subscriptionCount.value)
    }

    // ---------- M3-5 ----------

    @Test
    fun m3_5_startStopMapToAppState() {
        assertEquals(APP_FOREGROUND, appStateOf(Lifecycle.Event.ON_START))
        assertEquals(APP_BACKGROUND, appStateOf(Lifecycle.Event.ON_STOP))
    }

    @Test
    fun m3_5_otherEventsAreNotPushed() {
        for (e in listOf(Lifecycle.Event.ON_CREATE, Lifecycle.Event.ON_RESUME, Lifecycle.Event.ON_PAUSE, Lifecycle.Event.ON_DESTROY)) {
            assertNull("$e 不推给 H5", appStateOf(e))
        }
    }
}
