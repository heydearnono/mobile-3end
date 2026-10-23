package com.example.mobile3end

import androidx.activity.ComponentActivity
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.ui.Modifier
import androidx.compose.ui.test.junit4.AndroidComposeTestRule
import androidx.compose.ui.viewinterop.AndroidView
import androidx.test.ext.junit.rules.ActivityScenarioRule
import androidx.test.platform.app.InstrumentationRegistry
import com.example.mobile3end.web.H5Container
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonPrimitive
import org.junit.Assert.fail
import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/**
 * 碰到过未填的空就让测试按「运行到了未填的 M4-x」失败（check.sh 认这个格式）。
 * 系统回调里的 TODO 被 TodoGuard 接住了，不会自己抛到测试里，要在等待超时的时候问一下它
 */
fun failOnTodo() {
    val hit = TodoGuard.hits.firstOrNull() ?: return
    fail("$hit（在系统回调里碰到的，见 logcat）")
}

/** 每隔 100ms 检查一次 cond，超时先看是不是碰到了未填的空，再按 what 失败 */
fun waitFor(timeoutMs: Long, what: String, cond: () -> Boolean) {
    val end = System.currentTimeMillis() + timeoutMs
    while (System.currentTimeMillis() < end) {
        if (cond()) return
        Thread.sleep(100)
    }
    failOnTodo()
    fail("等了 ${timeoutMs}ms：$what")
}

/**
 * 在模拟器上真的跑一个 H5Container：WebView 放进一个空 Activity 里显示出来，测试线程通过 eval 往页面里执行 JS
 */
class WebHarness(
    private val rule: AndroidComposeTestRule<ActivityScenarioRule<ComponentActivity>, ComponentActivity>,
    private val captureH5Errors: Boolean = false,
) {
    val logs: MutableList<String> = CopyOnWriteArrayList()
    val renderGone = CountDownLatch(1)
    lateinit var container: H5Container

    fun start(): WebHarness {
        TodoGuard.hits.clear()
        rule.runOnUiThread {
            container = H5Container(
                rule.activity,
                log = { logs += it },
                logError = { logs += it },
                captureH5Errors = captureH5Errors,
                onRenderGone = { renderGone.countDown() },
            )
        }
        rule.setContent { AndroidView(factory = { container.webView }, modifier = Modifier.fillMaxSize()) }
        return this
    }

    fun onMain(block: () -> Unit) = InstrumentationRegistry.getInstrumentation().runOnMainSync(block)

    fun load(url: String) = onMain { container.load(url) }

    /** 执行 JS，等结果。字符串结果去掉 JSON 引号，null / undefined 返回 null */
    fun eval(js: String): String? {
        var raw: String? = null
        val done = CountDownLatch(1)
        onMain { container.webView.evaluateJavascript(js) { raw = it; done.countDown() } }
        if (!done.await(5, TimeUnit.SECONDS)) return null
        val element = runCatching { Json.parseToJsonElement(raw ?: "null") }.getOrNull() ?: return raw
        return when (element) {
            is JsonNull -> null
            is JsonPrimitive -> element.content
            else -> element.toString()
        }
    }

    /** 等页面挂载完成（#app 有子元素） */
    fun waitMounted(timeoutMs: Long = 8_000) =
        waitFor(timeoutMs, "页面没有渲染出来（#app 为空）。日志：${logs.takeLast(8)}") {
            (eval("(document.getElementById('app') || {}).childElementCount || 0")?.toIntOrNull() ?: 0) > 0
        }

    /** 页面上「日志（新的在上）」那一块的文字 */
    fun h5Log(): String = eval("(document.querySelectorAll('pre')[1] || {}).textContent || ''").orEmpty()

    /** 发一个 fetch，等它的「状态码 Content-Type」 */
    fun fetchStatus(path: String): String {
        eval("window.__probe = null; fetch('$path').then(function (r) { window.__probe = r.status + ' ' + r.headers.get('content-type'); }, function (e) { window.__probe = 'error ' + e; })")
        var result: String? = null
        waitFor(5_000, "fetch('$path') 没有结果") { eval("window.__probe").also { result = it } != null }
        return result!!
    }
}
