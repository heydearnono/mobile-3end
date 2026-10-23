package com.example.mobile3end

import androidx.activity.ComponentActivity
import androidx.compose.material3.MaterialTheme
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.example.mobile3end.data.FileListLoader
import com.example.mobile3end.data.LocalFiles
import com.example.mobile3end.data.SettingsStore
import com.example.mobile3end.model.FileItem
import com.example.mobile3end.model.FileType
import com.example.mobile3end.ui.FileListViewModel
import com.example.mobile3end.web.OFFLINE_ENTRY
import com.example.mobile3end.web.OFFLINE_ORIGIN
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.MutableStateFlow
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File
import java.util.UUID

/**
 * M4 WebView 行为检查，需要模拟器：真的加载离线包、真的走 bridge。方法名前缀 = 覆盖的空，m4_0_ 是示例。
 * 离线包拦截（M4-1 ~ M4-4）已写好，页面能打开；一进页面还会用到 M4-5、M4-6（H5 立刻调 getDeviceInfo），
 * 所以 bridge 没填完之前，依赖 bridge 的测试会报「运行到了未填的 M4-x」
 */
@RunWith(AndroidJUnit4::class)
class M4UiTest {

    @get:Rule
    val rule = createAndroidComposeRule<ComponentActivity>()

    private lateinit var web: WebHarness

    private fun open(url: String = OFFLINE_ENTRY, captureH5Errors: Boolean = false): WebHarness {
        web = WebHarness(rule, captureH5Errors).start()
        web.load(url)
        return web
    }

    @After
    fun tearDown() {
        if (::web.isInitialized) web.onMain { web.container.destroy() }
    }

    // ---------- 示例：离线包页面能打开（M4-1 ~ M4-4 已写好） ----------

    /**
     * 离线包 case 的基线：页面渲染出来、地址是离线包地址。
     * 这时 bridge（M4-5、M4-6）和白屏（M4-8 ~ M4-11）的空可能还没填，页面一打开就会碰到，被 TodoGuard 接住，
     * 所以这里不看 TodoGuard.hits，只看页面本身
     */
    @Test
    fun m4_0_offlinePageLoads() {
        open()
        val end = System.currentTimeMillis() + 8_000
        var count = 0
        while (System.currentTimeMillis() < end) {
            count = web.eval("(document.getElementById('app') || {}).childElementCount || 0")?.toIntOrNull() ?: 0
            if (count > 0) break
            Thread.sleep(100)
        }
        assertTrue("离线包页面没有渲染出来（#app 为空）。日志：${web.logs.takeLast(8)}", count > 0)
        val href = web.eval("location.href").orEmpty()
        assertTrue("location 应该是离线包地址，实际是 $href", href.startsWith("$OFFLINE_ORIGIN/"))
        assertTrue(web.eval("document.querySelector('#app h1').textContent").orEmpty().startsWith("离线包测试页"))
    }

    // ---------- M4-4 离线包拦截 ----------

    @Test
    fun m4_1_m4_2_m4_3_m4_4_offlinePageLoads() {
        open()
        web.waitMounted()
        assertEquals("https://h5.offline.test/index.html", web.eval("location.href"))
        assertTrue("style.css 要以 text/css 返回才会生效", web.eval("getComputedStyle(document.body).margin") == "0px")
    }

    @Test
    fun m4_3_m4_4_statusAndMime() {
        open()
        web.waitMounted()
        assertTrue(web.fetchStatus("/app.js").startsWith("200 text/javascript"))
        assertTrue(web.fetchStatus("/style.css").startsWith("200 text/css"))
        assertTrue(web.fetchStatus("/index.html?case=blank").startsWith("200 text/html"))
    }

    @Test
    fun m4_3_m4_4_missingIs404AndLogged() {
        open("$OFFLINE_ENTRY?case=missing")
        web.waitMounted()
        waitFor(3_000, "case=missing 里 missing.js 应该加载失败（H5 日志出现 load failed）") {
            "missing.js load failed" in web.h5Log()
        }
        assertTrue(web.logs.any { it == "[OFFLINE_404] https://h5.offline.test/missing.js" })
        // 浏览器还会自己请求一次 /favicon.ico，所以不止 1 次，见 hints/M4.md M4-4 的想一想
        assertTrue(web.container.offline404.value >= 1)
        assertTrue(web.fetchStatus("/nope.json").startsWith("404"))
    }

    // ---------- M4-5 / M4-6 bridge ----------

    @Test
    fun m4_5_m4_6_deviceInfoShownOnPage() {
        open()
        web.waitMounted()
        waitFor(4_000, "页面上的 getDeviceInfo 应该显示 platform: android") {
            web.eval("document.querySelectorAll('pre')[0].textContent").orEmpty().contains("\"platform\": \"android\"")
        }
        assertEquals("bridge: android-or-harmony", web.eval("document.querySelectorAll('section')[0].children[1].textContent"))
    }

    @Test
    fun m4_5_m4_6_toastSucceeds() {
        open()
        web.waitMounted()
        web.eval("document.querySelectorAll('button')[0].click()")
        waitFor(4_000, "点 toast 按钮后 H5 应该收到成功回调") { "toast ok {}" in web.h5Log() }
    }

    @Test
    fun m4_5_m4_6_unknownMethodNotFound() {
        open()
        web.waitMounted()
        web.eval("document.querySelectorAll('button')[1].click()")
        waitFor(4_000, "调不存在的方法 H5 应该收到 METHOD_NOT_FOUND") { "METHOD_NOT_FOUND" in web.h5Log() }
    }

    @Test
    fun m4_6_foreignPageHasNoBridge() {
        open()
        web.waitMounted()
        web.onMain { web.container.loadForeign() }
        waitFor(4_000, "外部页面上不应该有 NativeBridge") { web.eval("document.getElementById('r').textContent") == "bridge: none" }

        web.load(OFFLINE_ENTRY)
        web.waitMounted()
        waitFor(4_000, "回到离线包后 bridge 要恢复") {
            web.eval("document.querySelectorAll('pre')[0].textContent").orEmpty().contains("android")
        }
    }

    // ---------- M4-7 appState ----------

    @Test
    fun m4_7_appStateEventReachesH5() {
        open()
        web.waitMounted()
        web.onMain { web.container.pushAppState("background") }
        web.onMain { web.container.pushAppState("foreground") }
        waitFor(3_000, "H5 日志里应该有 appState 事件") {
            val log = web.h5Log()
            "event appState {\"state\":\"background\"}" in log && "event appState {\"state\":\"foreground\"}" in log
        }
    }

    // ---------- M4-8 ~ M4-11 白屏 ----------

    private fun assertNoWhiteScreenFor(ms: Long) {
        Thread.sleep(ms)
        failOnTodo()
        assertEquals("不该报白屏。日志：${web.logs.filter { "WHITE" in it }}", null, web.container.whiteScreen.value)
    }

    @Test
    fun m4_8_m4_11_normalNotWhite() {
        open()
        web.waitMounted()
        assertNoWhiteScreenFor(6_500)
    }

    @Test
    fun m4_8_m4_11_blankIsEmptyRoot() {
        open("$OFFLINE_ENTRY?case=blank")
        waitFor(8_000, "case=blank 应该报 empty_root") { web.container.whiteScreen.value == "empty_root" }
        assertTrue(web.logs.any { it == "[WHITE_SCREEN] reason=empty_root url=https://h5.offline.test/index.html?case=blank" })
    }

    @Test
    fun m4_8_m4_9_missingNotWhite() {
        open("$OFFLINE_ENTRY?case=missing")
        web.waitMounted()
        assertNoWhiteScreenFor(6_500)
    }

    @Test
    fun m4_8_m4_11_slowNotWhite() {
        open("$OFFLINE_ENTRY?case=slow")
        web.waitMounted(6_000)
        assertNoWhiteScreenFor(4_000)
    }

    @Test
    fun m4_9_mainFrameErrorIsLoadError() {
        open("https://nope.invalid/")
        waitFor(10_000, "主文档加载失败应该报 load_error") { web.container.whiteScreen.value == "load_error" }
    }

    @Test
    fun m4_10_renderGoneHandledWithoutCrash() {
        open()
        web.waitMounted()
        web.load("chrome://crash")
        waitFor(10_000, "渲染进程崩溃应该报 render_gone") { web.container.whiteScreen.value == "render_gone" }
        assertTrue("处理完要通知页面换一个新的 WebView", web.renderGone.await(2, java.util.concurrent.TimeUnit.SECONDS))
        // 能走到这里说明 App 没跟着渲染进程一起被杀
    }

    // ---------- 综合：App 在 STAGE 4 下有 H5 入口 ----------

    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    @After
    fun closeDataStore() = scope.cancel()

    @Test
    fun m4_e2e_h5EntryFromList() {
        TodoGuard.hits.clear()
        val noCache = object : LocalFiles {
            override fun load(): List<FileItem>? = null
            override fun save(files: List<FileItem>) {}
        }
        val settings = SettingsStore(
            PreferenceDataStoreFactory.create(scope = scope) {
                File(rule.activity.cacheDir, "m4-test-${UUID.randomUUID()}.preferences_pb")
            },
        )
        val factory = viewModelFactory {
            initializer {
                FileListViewModel(FileListLoader({ listOf(FileItem("a", "a.md", FileType.DOC, 1, 1)) }, noCache), settings)
            }
        }
        rule.setContent { MaterialTheme { App(stage = 4, listViewModelFactory = factory, appState = MutableStateFlow(null)) } }

        rule.onNodeWithTag("open-h5").performClick()
        rule.onNodeWithTag("h5-web").assertIsDisplayed()
        rule.onNodeWithTag("h5-status").assertIsDisplayed()
        Thread.sleep(2_000)
        failOnTodo()
    }
}
