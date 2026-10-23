package com.example.mobile3end

import com.example.mobile3end.web.BridgeDispatcher
import com.example.mobile3end.web.BridgeJs
import com.example.mobile3end.web.CHECK_DELAY_MS
import com.example.mobile3end.web.CheckDecision
import com.example.mobile3end.web.DeviceInfo
import com.example.mobile3end.web.NativeBridgeInterface
import com.example.mobile3end.web.OFFLINE_ENTRY
import com.example.mobile3end.web.ROOT_CHILD_COUNT_JS
import com.example.mobile3end.web.SLOW_DEADLINE_MS
import com.example.mobile3end.web.WhiteScreenHost
import com.example.mobile3end.web.WhiteScreenMonitor
import com.example.mobile3end.web.appStateData
import com.example.mobile3end.web.appStateJs
import com.example.mobile3end.web.isOfflineOrigin
import com.example.mobile3end.web.mimeOf
import com.example.mobile3end.web.offlinePathOf
import com.example.mobile3end.web.parseChildCount
import com.example.mobile3end.web.resolveOffline
import com.example.mobile3end.web.singleCheckPolicy
import com.example.mobile3end.web.slowAwarePolicy
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** M4 纯逻辑检查，JVM 上跑，不需要模拟器。方法名前缀 = 覆盖的空 */
class M4LogicTest {

    private val logs = mutableListOf<String>()

    // ---------- 示例：MIME 表是写好的 ----------

    @Test
    fun m4_0_mimeByExtension() {
        assertEquals("text/html", mimeOf("index.html"))
        assertEquals("text/javascript", mimeOf("app.js"))
        assertEquals("text/css", mimeOf("sub/STYLE.CSS"))
        assertEquals("application/octet-stream", mimeOf("LICENSE"))
        assertEquals("目录名里的点不算扩展名", "application/octet-stream", mimeOf("v1.2/README"))
    }

    // ---------- M4-1 ----------

    @Test
    fun m4_1_offlineOriginAccepted() {
        assertTrue(isOfflineOrigin("https://h5.offline.test/index.html"))
        assertTrue(isOfflineOrigin("https://h5.offline.test/index.html?case=blank#x"))
        assertTrue("host 不区分大小写", isOfflineOrigin("https://H5.Offline.Test/"))
        assertTrue("443 就是 https 的默认端口", isOfflineOrigin("https://h5.offline.test:443/a.js"))
        assertTrue("没有路径也算", isOfflineOrigin("https://h5.offline.test"))
    }

    @Test
    fun m4_1_lookalikesRejected() {
        for (url in listOf(
            "http://h5.offline.test/index.html",          // scheme 不对
            "http://h5.offline.test:443/index.html",      // scheme 不对（端口碰巧对上）
            "https://h5.offline.test:8443/index.html",    // 端口不对
            "https://h5.offline.test.evil.com/index.html",// startsWith 会误放行
            "https://h5.offline.test@evil.com/index.html",// userinfo，真实 host 是 evil.com
            "https://evil.com/h5.offline.test/index.html",
            "https://offline.test/",
        )) {
            assertFalse("$url 不是离线包 origin", isOfflineOrigin(url))
        }
    }

    @Test
    fun m4_1_notHttpUrl() {
        for (url in listOf("", "about:blank", "file:///android_asset/h5/index.html", "javascript:alert(1)", "h5.offline.test/index.html")) {
            assertFalse("「$url」不是离线包 origin，也不能抛异常", isOfflineOrigin(url))
        }
    }

    // ---------- M4-2 ----------

    @Test
    fun m4_2_pathWithoutQueryAndFragment() {
        assertEquals("index.html", offlinePathOf("https://h5.offline.test/index.html"))
        assertEquals("index.html", offlinePathOf("https://h5.offline.test/index.html?case=blank"))
        assertEquals("app.js", offlinePathOf("https://h5.offline.test/app.js#top"))
        assertEquals("img/a.png", offlinePathOf("https://h5.offline.test/img/a.png?v=2"))
    }

    @Test
    fun m4_2_directoryGetsIndexHtml() {
        assertEquals("index.html", offlinePathOf("https://h5.offline.test/"))
        assertEquals("index.html", offlinePathOf("https://h5.offline.test"))
        assertEquals("docs/index.html", offlinePathOf("https://h5.offline.test/docs/"))
    }

    @Test
    fun m4_2_percentDecoded() {
        assertEquals("img/图.png", offlinePathOf("https://h5.offline.test/img/%E5%9B%BE.png"))
        assertEquals("a b.js", offlinePathOf("https://h5.offline.test/a%20b.js"))
    }

    @Test
    fun m4_2_otherOriginIsNull() {
        assertNull(offlinePathOf("https://example.com/index.html"))
        assertNull(offlinePathOf("http://10.0.2.2:8000/api/files.json"))
    }

    // ---------- M4-3 ----------

    private val pkg = mapOf(
        "h5/index.html" to "<html>".toByteArray(),
        "h5/app.js" to "var a".toByteArray(),
        "h5/style.css" to "body{}".toByteArray(),
        "h5/img/图.png" to byteArrayOf(1, 2, 3),
        "secret.txt" to "token".toByteArray(),
    )
    private val reads = mutableListOf<String>()
    private val read: (String) -> ByteArray? = { path -> reads += path; pkg[path] }

    @Test
    fun m4_3_hit200WithMime() {
        val r = resolveOffline("https://h5.offline.test/index.html?case=blank", read)!!
        assertEquals(200, r.status)
        assertEquals("OK", r.reason)
        assertEquals("text/html", r.mime)
        assertArrayEquals("<html>".toByteArray(), r.data)
        assertNull("200 不打日志", r.log)
        assertEquals("read 的参数要带 h5/ 前缀", listOf("h5/index.html"), reads)

        assertEquals("text/javascript", resolveOffline("https://h5.offline.test/app.js", read)!!.mime)
        assertEquals("image/png", resolveOffline("https://h5.offline.test/img/%E5%9B%BE.png", read)!!.mime)
    }

    @Test
    fun m4_3_miss404WithFullUrlInLog() {
        val url = "https://h5.offline.test/missing.js?v=3"
        val r = resolveOffline(url, read)!!
        assertEquals(404, r.status)
        assertEquals("Not Found", r.reason)
        assertEquals("[OFFLINE_404] $url", r.log)
    }

    @Test
    fun m4_3_otherOriginPassesThrough() {
        assertNull("不归离线包管的请求返回 null，交给网络", resolveOffline("https://example.com/app.js", read))
        assertTrue("不归离线包管的请求不要去读包", reads.isEmpty())
    }

    @Test
    fun m4_3_pathTraversalBlocked() {
        // 浏览器（和 HttpUrl）解析 URL 时会消掉 ../ 和 %2e%2e/，但 %2f 不算路径分隔符，
        // 「..%2f」在解析时是一个普通的路径段，解码以后才变成 ../
        for (url in listOf(
            "https://h5.offline.test/..%2fsecret.txt",
            "https://h5.offline.test/img/..%2f..%2fsecret.txt",
            "https://h5.offline.test/%2e%2e%2fsecret.txt",
        )) {
            val r = resolveOffline(url, read)
            assertEquals("$url 应该 404", 404, r?.status)
        }
        assertTrue("路径里有 .. 就直接 404，不要去读文件：$reads", reads.none { ".." in it })
    }

    @Test
    fun m4_3_dotSegmentsResolvedLikeBrowser() {
        // 字面的 ../ 和 %2e%2e/ 在 URL 解析时就被消掉了（浏览器发出来的请求也是这样），到不了根目录之外
        assertEquals(200, resolveOffline("https://h5.offline.test/img/../app.js", read)?.status)
        assertEquals(200, resolveOffline("https://h5.offline.test/img/%2e%2e/app.js", read)?.status)
        assertEquals("消到根目录为止，还是在 h5/ 里", 404, resolveOffline("https://h5.offline.test/../secret.txt", read)?.status)
        assertTrue(reads.none { it == "secret.txt" })
    }

    // ---------- M4-5 ----------

    private val toasts = mutableListOf<String>()
    private val dispatcher = BridgeDispatcher(
        deviceInfo = { DeviceInfo("android", "Android 17 (API 37)", "0.1.0") },
        toast = { toasts += it },
        log = { logs += it },
    )

    /** 把 window.__bridgeCallback({...}) 里的参数解析出来 */
    private fun callbackPayload(js: String?): JsonObject {
        assertNotNull("应该回一段 JS", js)
        val prefix = "window.__bridgeCallback("
        assertTrue("回调要调 window.__bridgeCallback：$js", js!!.startsWith(prefix) && js.endsWith(")"))
        return Json.parseToJsonElement(js.removePrefix(prefix).removeSuffix(")")).jsonObject
    }

    private fun JsonObject.str(key: String) = get(key)?.jsonPrimitive?.content

    @Test
    fun m4_5_getDeviceInfo() {
        val p = callbackPayload(dispatcher.handle("""{"id":"1","method":"getDeviceInfo","params":{}}""", OFFLINE_ENTRY))
        assertEquals("1", p.str("id"))
        assertEquals("true", p.str("ok"))
        val data = p["data"]!!.jsonObject
        assertEquals("android", data.str("platform"))
        assertEquals("Android 17 (API 37)", data.str("osVersion"))
        assertEquals("0.1.0", data.str("appVersion"))
    }

    @Test
    fun m4_5_toastCallsNativeAndReturnsEmptyObject() {
        val p = callbackPayload(dispatcher.handle("""{"id":"7","method":"toast","params":{"text":"来自 H5 的 toast"}}""", "$OFFLINE_ENTRY?case=slow"))
        assertEquals(listOf("来自 H5 的 toast"), toasts)
        assertEquals("7", p.str("id"))
        assertEquals("true", p.str("ok"))
        assertEquals(JsonObject(emptyMap()), p["data"])
    }

    @Test
    fun m4_5_toastWithoutTextUsesEmptyString() {
        callbackPayload(dispatcher.handle("""{"id":"8","method":"toast"}""", OFFLINE_ENTRY))
        callbackPayload(dispatcher.handle("""{"id":"9","method":"toast","params":{"text":42}}""", OFFLINE_ENTRY))
        callbackPayload(dispatcher.handle("""{"id":"10","method":"toast","params":"oops"}""", OFFLINE_ENTRY))
        assertEquals(listOf("", "", ""), toasts)
    }

    @Test
    fun m4_5_unknownMethodIsMethodNotFound() {
        val p = callbackPayload(dispatcher.handle("""{"id":"3","method":"notExist","params":{}}""", OFFLINE_ENTRY))
        assertEquals("3", p.str("id"))
        assertEquals("false", p.str("ok"))
        val error = p["error"]!!.jsonObject
        assertEquals("METHOD_NOT_FOUND", error.str("code"))
        assertTrue("message 里带上方法名，H5 那边好排查", error.str("message")!!.contains("notExist"))

        val noMethod = callbackPayload(dispatcher.handle("""{"id":"4"}""", OFFLINE_ENTRY))
        assertEquals("METHOD_NOT_FOUND", noMethod["error"]!!.jsonObject.str("code"))
    }

    @Test
    fun m4_5_untrustedPageIgnored() {
        for (page in listOf("https://example.com/", "https://evil.test/", "https://h5.offline.test.evil.com/", null)) {
            assertNull("来自 $page 的消息不响应", dispatcher.handle("""{"id":"1","method":"toast","params":{"text":"x"}}""", page))
        }
        assertTrue("不可信来源的消息不能执行任何能力", toasts.isEmpty())
        assertTrue("拒绝时要打日志，排查时才知道发生过", logs.any { "example.com" in it })
    }

    @Test
    fun m4_5_badMessageIgnored() {
        for (raw in listOf("", "not json", "null", "[]", "1", """{"method":"toast"}""", """{"id":1,"method":"toast"}""")) {
            assertNull("「$raw」没法回，返回 null", dispatcher.handle(raw, OFFLINE_ENTRY))
        }
        assertTrue(toasts.isEmpty())
    }

    @Test
    fun m4_5_outputIsEscaped() {
        // id 是 H5 传来的，引号、换行都不能把生成的 JS 弄坏：用 BridgeJs（JSON 序列化）拼，不要手拼字符串
        for (method in listOf("getDeviceInfo", "toast", "x'y")) {
            val p = callbackPayload(dispatcher.handle("""{"id":"a\"b\n","method":"$method"}""", OFFLINE_ENTRY))
            assertEquals("$method 的回调", "a\"b\n", p.str("id"))
        }
    }

    // ---------- M4-6 ----------

    /** 假的主线程：任务先排队，测试手动 runAll，模拟「丢到主线程、稍后执行」 */
    private class FakeMain {
        val queue = ArrayDeque<() -> Unit>()
        fun post(task: () -> Unit) { queue += task }
        fun runAll() { while (queue.isNotEmpty()) queue.removeFirst()() }
    }

    @Test
    fun m4_6_dispatchesOnMainAndEvaluates() {
        val main = FakeMain()
        val evaluated = mutableListOf<String>()
        var urlReads = 0
        val bridge = NativeBridgeInterface(
            mainThread = main::post,
            currentUrl = { urlReads++; OFFLINE_ENTRY },
            dispatcher = dispatcher,
            evaluate = { evaluated += it },
        )

        bridge.postMessage("""{"id":"1","method":"getDeviceInfo","params":{}}""")
        assertEquals("在 JavaBridge 线程上不能碰 webView.url", 0, urlReads)
        assertTrue("在 JavaBridge 线程上不能 evaluateJavascript", evaluated.isEmpty())

        main.runAll()
        assertEquals(1, evaluated.size)
        assertEquals("1", callbackPayload(evaluated[0]).str("id"))
    }

    @Test
    fun m4_6_nothingToEvaluateWhenIgnored() {
        val main = FakeMain()
        val evaluated = mutableListOf<String>()
        val bridge = NativeBridgeInterface(main::post, { "https://example.com/" }, dispatcher) { evaluated += it }
        bridge.postMessage("""{"id":"1","method":"getDeviceInfo"}""")
        main.runAll()
        assertTrue("dispatcher 返回 null 时什么都不执行", evaluated.isEmpty())
    }

    // ---------- M4-7 ----------

    @Test
    fun m4_7_pushToOfflinePage() {
        assertEquals(BridgeJs.event("appState", appStateData("background")), appStateJs("background", "$OFFLINE_ENTRY?case=slow"))
        assertEquals("""window.__bridgeEvent({"event":"appState","data":{"state":"foreground"}})""", appStateJs("foreground", OFFLINE_ENTRY))
    }

    @Test
    fun m4_7_notPushedToOtherPagesOrUnknownState() {
        assertNull(appStateJs("background", "https://example.com/"))
        assertNull(appStateJs("background", null))
        assertNull(appStateJs(null, OFFLINE_ENTRY))
    }

    // ---------- M4-8 / M4-11 白屏检测 ----------

    /** 假的 host：schedule 只记下来，测试用 advance 推进时间；evaluate 的结果由测试指定 */
    private class FakeHost : WhiteScreenHost {
        var now = 0L
        val timers = mutableListOf<Pair<Long, () -> Unit>>()
        var childCount: () -> String? = { "0" }
        val evaluated = mutableListOf<String>()
        val reports = mutableListOf<String>()
        /** 不为 null 时，evaluate 的回调先存起来，模拟「JS 结果还没回来」 */
        var holdEvaluate: MutableList<() -> Unit>? = null

        override fun schedule(delayMs: Long, task: () -> Unit) {
            timers += (now + delayMs) to task
        }

        override fun evaluate(js: String, callback: (String?) -> Unit) {
            evaluated += js
            val result = childCount()
            val hold = holdEvaluate
            if (hold != null) hold += { callback(result) } else callback(result)
        }

        override fun report(line: String) {
            reports += line
        }

        fun advance(ms: Long) {
            val end = now + ms
            while (true) {
                val next = timers.filter { it.first <= end }.minByOrNull { it.first } ?: break
                timers.remove(next)
                now = next.first
                next.second()
            }
            now = end
        }
    }

    private val url = OFFLINE_ENTRY

    @Test
    fun m4_8_emptyRootReportedAfter1s() {
        val host = FakeHost()
        val m = WhiteScreenMonitor(host, ::singleCheckPolicy)
        m.onPageStarted(url)
        m.onPageFinished(url)
        assertTrue("onPageFinished 时不能立刻检测，要等 1s", host.evaluated.isEmpty())
        host.advance(CHECK_DELAY_MS - 1)
        assertTrue(host.evaluated.isEmpty())
        host.advance(1)
        assertEquals(listOf(ROOT_CHILD_COUNT_JS), host.evaluated)
        assertEquals(listOf("[WHITE_SCREEN] reason=empty_root url=$url"), host.reports)
    }

    @Test
    fun m4_8_renderedPageNotReported() {
        val host = FakeHost().apply { childCount = { "3" } }
        val m = WhiteScreenMonitor(host, ::singleCheckPolicy)
        m.onPageStarted(url)
        m.onPageFinished(url)
        host.advance(10_000)
        assertEquals(1, host.evaluated.size)
        assertTrue(host.reports.isEmpty())
    }

    @Test
    fun m4_8_retryUntilPolicySaysWhite() {
        val host = FakeHost()
        val elapsedSeen = mutableListOf<Long>()
        val m = WhiteScreenMonitor(host) { elapsed, _ ->
            elapsedSeen += elapsed
            if (elapsed >= 3_000) CheckDecision.WHITE else CheckDecision.RETRY
        }
        m.onPageStarted(url)
        m.onPageFinished(url)
        host.advance(10_000)
        assertEquals("RETRY 之后每隔 1s 再查一次，elapsed 累加", listOf(1_000L, 2_000L, 3_000L), elapsedSeen)
        assertEquals(1, host.reports.size)
    }

    @Test
    fun m4_8_newPageCancelsPendingCheck() {
        val host = FakeHost()
        val m = WhiteScreenMonitor(host, ::singleCheckPolicy)
        m.onPageStarted(url)
        m.onPageFinished(url)
        host.advance(500)
        m.onPageStarted("$url?case=slow") // 1s 还没到就开始加载下一个页面
        host.advance(5_000)
        assertTrue("上一页的检测要作废：${host.reports}", host.reports.isEmpty())
        assertTrue("作废的检测连 JS 都不用执行（页面已经换了）", host.evaluated.isEmpty())
    }

    @Test
    fun m4_8_newPageWhileWaitingForJsResult() {
        val host = FakeHost().apply { holdEvaluate = mutableListOf() }
        val m = WhiteScreenMonitor(host, ::singleCheckPolicy)
        m.onPageStarted(url)
        m.onPageFinished(url)
        host.advance(CHECK_DELAY_MS)
        assertEquals("已经发出探测 JS", 1, host.evaluated.size)
        m.onPageStarted("$url?case=slow") // JS 结果回来之前开始了新页面
        host.holdEvaluate!!.forEach { it() }
        assertTrue("结果回来时已经是新页面了，不能算到它头上：${host.reports}", host.reports.isEmpty())
    }

    @Test
    fun m4_8_jsFailureCountsAsEmpty() {
        assertEquals(0, parseChildCount("null"))
        assertEquals(0, parseChildCount(null))
        assertEquals(3, parseChildCount("3"))
        val host = FakeHost().apply { childCount = { "null" } }
        val m = WhiteScreenMonitor(host, ::singleCheckPolicy)
        m.onPageStarted(url)
        m.onPageFinished(url)
        host.advance(CHECK_DELAY_MS)
        assertEquals(1, host.reports.size)
    }

    @Test
    fun m4_8_reportOncePerPage() {
        val host = FakeHost()
        val m = WhiteScreenMonitor(host, ::singleCheckPolicy)
        m.onPageStarted(url)
        m.onPageFinished(url)
        m.onPageFinished(url) // 有的页面 onPageFinished 会来两次
        host.advance(5_000)
        assertEquals("同一个页面最多报一次", 1, host.reports.size)

        m.onPageStarted(url) // 重新加载算新的一轮
        m.onPageFinished(url)
        host.advance(5_000)
        assertEquals(2, host.reports.size)
    }

    // ---------- M4-9 ----------

    @Test
    fun m4_9_onlyMainFrameErrorCounts() {
        val host = FakeHost()
        val m = WhiteScreenMonitor(host, ::singleCheckPolicy)
        m.onPageStarted(url)
        m.onReceivedError("https://h5.offline.test/missing.png", isForMainFrame = false)
        assertTrue("子资源失败不算白屏", host.reports.isEmpty())
        m.onReceivedError("https://nope.invalid/", isForMainFrame = true)
        assertEquals(listOf("[WHITE_SCREEN] reason=load_error url=https://nope.invalid/"), host.reports)
    }

    // ---------- M4-10 ----------

    @Test
    fun m4_10_renderGoneReportedAndHandled() {
        val host = FakeHost()
        val m = WhiteScreenMonitor(host, ::singleCheckPolicy)
        m.onPageStarted(url)
        assertTrue("返回 false 系统会把整个 App 杀掉", m.onRenderProcessGone(url, didCrash = true))
        assertEquals(listOf("[WHITE_SCREEN] reason=render_gone url=$url"), host.reports)
        assertTrue("被系统回收（didCrash=false）也一样", WhiteScreenMonitor(FakeHost(), ::singleCheckPolicy).onRenderProcessGone(url, didCrash = false))
    }

    // ---------- M4-11 ----------

    @Test
    fun m4_11_contentIsAlwaysOk() {
        for (t in listOf(1_000L, 3_000L, SLOW_DEADLINE_MS, 60_000L)) {
            assertEquals(CheckDecision.OK, slowAwarePolicy(t, 1))
        }
    }

    @Test
    fun m4_11_emptyAt1sIsNotWhiteYet() {
        assertTrue("slow 3s 才渲染，1s 时为空不能判白屏", slowAwarePolicy(1_000, 0) != CheckDecision.WHITE)
    }

    @Test
    fun m4_11_emptyAtDeadlineIsWhite() {
        assertEquals(CheckDecision.WHITE, slowAwarePolicy(SLOW_DEADLINE_MS, 0))
        assertEquals(CheckDecision.WHITE, slowAwarePolicy(SLOW_DEADLINE_MS + 1_000, 0))
    }

    @Test
    fun m4_e2e_slowCaseWithMonitor() {
        // slow：3s 后才渲染。用 M4-11 的策略跑一遍 M4-8 的流程，不该报白屏
        val host = FakeHost()
        host.childCount = { if (host.now >= 3_000) "5" else "0" }
        val m = WhiteScreenMonitor(host, ::slowAwarePolicy)
        m.onPageStarted("$url?case=slow")
        m.onPageFinished("$url?case=slow")
        host.advance(10_000)
        assertTrue("slow 不该报白屏：${host.reports}", host.reports.isEmpty())

        // blank：一直为空，到截止时间要报
        val blank = FakeHost()
        val m2 = WhiteScreenMonitor(blank, ::slowAwarePolicy)
        m2.onPageStarted("$url?case=blank")
        m2.onPageFinished("$url?case=blank")
        blank.advance(10_000)
        assertEquals(1, blank.reports.size)
    }
}
