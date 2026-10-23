package com.example.mobile3end

import androidx.activity.ComponentActivity
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.example.mobile3end.web.OFFLINE_ENTRY
import org.junit.After
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * M5 设备上的检查：H5 侧异常经 onConsoleMessage 转到原生日志。
 * Native 崩溃钩子（M5-1 ~ M5-3）在 JVM 单测里查；真的让 App 崩一次是手工任务（测试进程崩了就没法报结果了）
 */
@RunWith(AndroidJUnit4::class)
class M5UiTest {

    @get:Rule
    val rule = createAndroidComposeRule<ComponentActivity>()

    private lateinit var web: WebHarness

    @After
    fun tearDown() {
        if (::web.isInitialized) web.onMain { web.container.destroy() }
    }

    @Test
    fun m5_4_blankCaseErrorReachesNativeLog() {
        web = WebHarness(rule, captureH5Errors = true).start()
        web.load("$OFFLINE_ENTRY?case=blank")
        waitFor(5_000, "case=blank 的异常应该出现在原生日志里（[H5_ERROR] Uncaught Error: ...）。日志：${web.logs.takeLast(5)}") {
            web.logs.any { it.startsWith("[H5_ERROR] Uncaught Error: [case=blank] simulated crash before mount @ https://h5.offline.test/app.js:") }
        }
        waitFor(3_000, "页面脚本执行前注入的钩子应该打出带堆栈的 [H5_UNCAUGHT]") {
            web.logs.any { it.startsWith("[H5_ERROR] [H5_UNCAUGHT] Error: [case=blank]") && "app.js" in it }
        }
    }

    @Test
    fun m5_4_businessErrorNotCaptured() {
        web = WebHarness(rule, captureH5Errors = true).start()
        web.load("$OFFLINE_ENTRY?case=missing")
        web.waitMounted()
        web.eval("console.error('业务日志，不是异常')")
        Thread.sleep(1_000)
        failOnTodo()
        assertTrue("普通 console.error 不该被当成异常：${web.logs}", web.logs.none { it.startsWith("[H5_ERROR]") })
    }
}
