package com.example.mobile3end

import android.security.NetworkSecurityPolicy
import androidx.compose.material3.MaterialTheme
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertTextContains
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.example.mobile3end.data.FileListLoader
import com.example.mobile3end.data.ListUiState
import com.example.mobile3end.data.LocalFiles
import com.example.mobile3end.data.SettingsStore
import com.example.mobile3end.model.FileItem
import com.example.mobile3end.model.FileType
import com.example.mobile3end.model.SortOrder
import com.example.mobile3end.ui.FileListScreen
import com.example.mobile3end.ui.FileListViewModel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File
import java.util.UUID

/** M2 UI / 配置检查，需要模拟器。方法名前缀 = 覆盖的空 */
@RunWith(AndroidJUnit4::class)
class M2UiTest {

    @get:Rule
    val rule = createComposeRule()

    private val context = InstrumentationRegistry.getInstrumentation().targetContext

    // ---------- M2-8 三种状态 ----------

    private fun setStatus(state: ListUiState, onRetry: () -> Unit = {}) = rule.setContent {
        MaterialTheme {
            FileListScreen(state = state, order = SortOrder.NAME, onOrderChange = {}, onOpen = {}, onRetry = onRetry)
        }
    }

    @Test
    fun m2_8_loadingShowsSpinner() {
        setStatus(ListUiState.Loading)
        rule.onNodeWithTag("loading").assertIsDisplayed()
    }

    @Test
    fun m2_8_failedShowsMessageAndRetry() {
        var retried = 0
        setStatus(ListUiState.Failed("ConnectException: Failed to connect"), onRetry = { retried++ })

        rule.onNodeWithText("加载失败").assertIsDisplayed()
        rule.onNodeWithText("ConnectException: Failed to connect").assertIsDisplayed()
        rule.onNodeWithTag("retry").performClick()

        assertEquals("点「重试」要调 onRetry", 1, retried)
    }

    @Test
    fun m2_8_emptyListShowsEmpty() {
        setStatus(ListUiState.Loaded(emptyList()))
        rule.onNodeWithTag("empty").assertTextContains("没有文件", substring = true)
    }

    // ---------- 手工任务 M2-10：AndroidManifest 配置 ----------
    // M2-9（INTERNET 权限）测不出来：OkHttp 自带的 Manifest 已经声明了，见 hints/M2.md

    @Test
    fun m2_10_cleartextOnlyForMockHost() {
        val policy = NetworkSecurityPolicy.getInstance()
        assertTrue("10.0.2.2 的明文 http 应该被放行，见 hints/M2.md", policy.isCleartextTrafficPermitted("10.0.2.2"))
        assertFalse("其他域名仍应禁止明文，不要全局放开 usesCleartextTraffic", policy.isCleartextTrafficPermitted("example.com"))
    }

    // ---------- 综合：App 在 STAGE 2 下接上 ViewModel ----------

    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    @After
    fun closeDataStore() = scope.cancel()

    private val remoteFiles = listOf(
        FileItem("r1", "接口返回的文件夹", FileType.FOLDER, 0, 100),
        FileItem("r2", "a-接口返回.md", FileType.DOC, 10, 300),
        FileItem("r3", "b-接口返回.png", FileType.IMAGE, 20, 200),
    )

    @Test
    fun m2_e2e_listComesFromRemote_sortIsPersisted() {
        val settings = SettingsStore(
            PreferenceDataStoreFactory.create(scope = scope) {
                File(context.cacheDir, "m2-test-${UUID.randomUUID()}.preferences_pb")
            },
        )
        val noCache = object : LocalFiles {
            override fun load(): List<FileItem>? = null
            override fun save(files: List<FileItem>) {}
        }
        val factory = viewModelFactory {
            initializer { FileListViewModel(FileListLoader({ remoteFiles }, noCache), settings) }
        }
        rule.setContent { MaterialTheme { App(stage = 2, listViewModelFactory = factory) } }

        rule.waitUntil(5_000) { rule.onAllNodesWithTagCount("file-list") > 0 }
        rule.onNodeWithText("a-接口返回.md").assertIsDisplayed()

        rule.onNodeWithTag("sort").performClick()
        rule.waitUntil(5_000) { runBlocking { settings.order.first() } == SortOrder.TIME }
        rule.onNodeWithTag("sort").assertTextContains("时间", substring = true)

        rule.onNodeWithText("a-接口返回.md").performClick()
        rule.onNodeWithTag("detail-name").assertTextContains("a-接口返回.md", substring = true)
    }

    private fun androidx.compose.ui.test.junit4.ComposeContentTestRule.onAllNodesWithTagCount(tag: String) =
        onAllNodes(androidx.compose.ui.test.hasTestTag(tag)).fetchSemanticsNodes().size
}
