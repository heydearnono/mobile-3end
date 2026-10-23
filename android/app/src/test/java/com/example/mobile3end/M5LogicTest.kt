package com.example.mobile3end

import com.example.mobile3end.crash.CrashReporter
import com.example.mobile3end.crash.H5_UNCAUGHT_HOOK_PREFIX
import com.example.mobile3end.crash.crashRecord
import com.example.mobile3end.crash.h5ErrorLine
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File

/**
 * M5 纯逻辑检查，JVM 上跑，不需要模拟器。方法名前缀 = 覆盖的空。
 * 不会真的让测试进程崩：直接拿到装好的钩子，手动调它的 uncaughtException
 */
class M5LogicTest {

    @get:Rule
    val tmp = TemporaryFolder()

    private val logs = mutableListOf<String>()
    private fun file() = File(tmp.root, "crash-last.txt")
    private fun reporter(f: File = file()) = CrashReporter(f) { logs += it }

    private var original: Thread.UncaughtExceptionHandler? = null
    /** 假装是「系统默认的钩子」：记下收到了哪些异常 */
    private val previousGot = mutableListOf<Throwable>()

    @Before
    fun saveHandler() {
        original = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { _, e -> previousGot += e }
    }

    @After
    fun restoreHandler() {
        Thread.setDefaultUncaughtExceptionHandler(original)
    }

    private fun boom() = IllegalStateException("配置解析失败", NumberFormatException("For input string: \"oops\""))

    private fun crash(e: Throwable, thread: Thread = Thread.currentThread()) =
        Thread.getDefaultUncaughtExceptionHandler()!!.uncaughtException(thread, e)

    // ---------- 示例 ----------

    @Test
    fun m5_0_recordHasSummaryAndCause() {
        val text = crashRecord("main", boom())
        assertTrue(text.startsWith("[CRASH] 线程 main 未捕获异常 java.lang.IllegalStateException: 配置解析失败"))
        assertTrue("要有 Caused by，真正的原因常常在这里", text.contains("Caused by: java.lang.NumberFormatException"))
    }

    // ---------- M5-1 ----------

    @Test
    fun m5_1_installReplacesDefaultHandler() {
        val before = Thread.getDefaultUncaughtExceptionHandler()
        reporter().install()
        assertFalse("install 之后进程默认的钩子应该换成你的", before === Thread.getDefaultUncaughtExceptionHandler())
    }

    @Test
    fun m5_1_m5_2_crashIsHandledThenChained() {
        reporter().install()
        val e = boom()
        crash(e, Thread(Runnable {}, "m3e-worker"))
        assertTrue("钩子里要调 handle，打出崩溃记录：$logs", logs.any { it.startsWith("[CRASH] 线程 m3e-worker") })
        assertEquals("处理完要交还给之前的钩子（系统的那个负责弹窗、杀进程）", 1, previousGot.size)
        assertSame(e, previousGot[0])
    }

    @Test
    fun m5_1_noPreviousHandler() {
        Thread.setDefaultUncaughtExceptionHandler(null)
        reporter().install()
        crash(boom()) // 之前没有钩子，不能 NPE
        assertTrue(logs.any { it.startsWith("[CRASH]") })
    }

    @Test
    fun m5_1_installTwiceHandlesOnce() {
        val r = reporter()
        r.install()
        r.install()
        crash(boom())
        assertEquals("重复 install 会把自己串两遍，一个异常处理两次", 1, logs.count { it.startsWith("[CRASH] 线程") })
        assertEquals(1, previousGot.size)
    }

    @Test
    fun m5_1_previousStillCalledIfHandleFails() {
        // 处理过程中又出了异常（这里让打日志就抛），之前的钩子也必须照常被调到，否则进程不会退出、系统也不知道崩过
        CrashReporter(file()) { throw IllegalStateException("日志系统也坏了") }.install()
        try {
            crash(boom())
        } catch (e: IllegalStateException) {
            // 处理时的异常往外抛不要紧，进程反正要退出了
        }
        assertEquals(1, previousGot.size)
    }

    // ---------- M5-2 ----------

    @Test
    fun m5_2_writesRecordToFile() {
        val e = boom()
        reporter().handle(Thread.currentThread(), e)
        assertEquals(crashRecord(Thread.currentThread().name, e), file().readText())
        assertTrue(logs.contains(crashRecord(Thread.currentThread().name, e)))
    }

    @Test
    fun m5_2_overwritesPrevious() {
        file().writeText("上上次的崩溃")
        reporter().handle(Thread.currentThread(), boom())
        assertFalse(file().readText().contains("上上次"))
    }

    @Test
    fun m5_2_writeFailureDoesNotThrow() {
        val dir = tmp.newFolder("crash-last.txt")
        CrashReporter(dir) { logs += it }.handle(Thread.currentThread(), boom())
        assertTrue("写失败要打一行日志：$logs", logs.size >= 2)
    }

    // ---------- M5-3 ----------

    @Test
    fun m5_3_nothingToReport() {
        assertNull(reporter().reportPrevious())
        assertTrue(logs.isEmpty())
    }

    @Test
    fun m5_2_m5_3_reportNextLaunchOnlyOnce() {
        val e = boom()
        reporter().handle(Thread.currentThread(), e)
        logs.clear()

        val next = reporter() // 下次启动
        assertEquals(crashRecord(Thread.currentThread().name, e), next.reportPrevious())
        assertTrue(logs.single().startsWith("[CRASH] 上次运行崩溃了"))
        assertTrue("日志里要带上记录内容", logs.single().contains("配置解析失败"))
        assertFalse("报完要删掉", file().exists())
        assertNull("只报一次", reporter().reportPrevious())
    }

    // ---------- M5-4 ----------

    @Test
    fun m5_4_browserUncaught() {
        assertEquals(
            "[H5_ERROR] Uncaught Error: [case=blank] simulated crash before mount @ https://h5.offline.test/app.js:9",
            h5ErrorLine(true, "Uncaught Error: [case=blank] simulated crash before mount", "https://h5.offline.test/app.js", 9),
        )
    }

    @Test
    fun m5_4_hookWithStack() {
        val msg = "$H5_UNCAUGHT_HOOK_PREFIX Error: x\n    at https://h5.offline.test/app.js:9:11"
        assertEquals("[H5_ERROR] $msg @ https://h5.offline.test/index.html:1", h5ErrorLine(true, msg, "https://h5.offline.test/index.html", 1))
    }

    @Test
    fun m5_4_businessLogsAreNotErrors() {
        assertNull("普通的 console.error 不是异常", h5ErrorLine(true, "missing.js load failed (expected)", "app.js", 140))
        assertNull("不是 error 级别的不算", h5ErrorLine(false, "Uncaught Error: x", "app.js", 9))
        assertNull(h5ErrorLine(false, "$H5_UNCAUGHT_HOOK_PREFIX Error: x", "app.js", 9))
        assertNull("开头才算", h5ErrorLine(true, "接口返回 Uncaught Error", "app.js", 1))
    }
}
