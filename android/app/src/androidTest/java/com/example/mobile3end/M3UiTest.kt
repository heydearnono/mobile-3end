package com.example.mobile3end

import android.os.NetworkOnMainThreadException
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.example.mobile3end.data.FileListLoader
import com.example.mobile3end.data.LocalFiles
import com.example.mobile3end.data.SettingsStore
import com.example.mobile3end.lifecycle.LogComposition
import com.example.mobile3end.lifecycle.fetchFilesBlocking
import com.example.mobile3end.model.FileItem
import com.example.mobile3end.model.FileType
import com.example.mobile3end.ui.FileListViewModel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File
import java.util.UUID
import java.util.concurrent.atomic.AtomicInteger

/** M3 UI 检查，需要模拟器。方法名前缀 = 覆盖的空 */
@RunWith(AndroidJUnit4::class)
class M3UiTest {

    @get:Rule
    val rule = createAndroidComposeRule<ComponentActivity>()

    // ---------- 示例：主线程网络请求 ----------

    @Test
    fun m3_0_networkOnMainThreadThrows() {
        var thrown: Throwable? = null
        InstrumentationRegistry.getInstrumentation().runOnMainSync {
            try {
                fetchFilesBlocking("http://10.0.2.2:1")
            } catch (e: Throwable) {
                thrown = e
            }
        }
        // 检查发生在 socket 操作之前，所以 mock 服务开没开都一样（端口 1 上什么都没有）
        assertTrue("主线程上发网络请求应该直接抛 NetworkOnMainThreadException，实际：$thrown", thrown is NetworkOnMainThreadException)
    }

    // ---------- M3-3 进出组合 ----------

    @Test
    fun m3_3_enterAndLeaveLoggedOnce() {
        val logs = mutableListOf<String>()
        var show by mutableStateOf(true)
        var counter by mutableIntStateOf(0)
        rule.setContent {
            if (show) {
                // 每次 counter 变都给一个新的 log 对象：LogComposition 的参数变了，它本身一定会重组，而不是被跳过
                val c = counter
                val log: (String) -> Unit = remember(c) { { logs += it } }
                LogComposition("Probe", log = log)
                Text("count=$c")
            }
        }
        rule.waitForIdle()
        assertEquals(listOf("Probe 进入组合"), logs)

        repeat(3) { counter++; rule.waitForIdle() }
        rule.onNodeWithText("count=3").assertExists()
        assertEquals("重组不是进出组合，不能重复打 $logs", listOf("Probe 进入组合"), logs)

        show = false
        rule.waitForIdle()
        assertEquals(listOf("Probe 进入组合", "Probe 离开组合"), logs)
    }

    // ---------- 综合：旋转屏幕（Activity 重建）不重新请求 ----------

    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    @After
    fun closeDataStore() = scope.cancel()

    @Test
    fun m3_e2e_recreateDoesNotRefetch() {
        val fetches = AtomicInteger()
        val noCache = object : LocalFiles {
            override fun load(): List<FileItem>? = null
            override fun save(files: List<FileItem>) {}
        }
        val settings = SettingsStore(
            PreferenceDataStoreFactory.create(scope = scope) {
                File(rule.activity.cacheDir, "m3-test-${UUID.randomUUID()}.preferences_pb")
            },
        )
        val factory = viewModelFactory {
            initializer {
                FileListViewModel(
                    FileListLoader({ fetches.incrementAndGet(); listOf(FileItem("a", "接口返回.md", FileType.DOC, 1, 1)) }, noCache),
                    settings,
                )
            }
        }
        // 和 MainActivity.onCreate 做的事一样：每次 Activity 创建都 setContent 一次
        val show: (ComponentActivity) -> Unit = { it.setContent { MaterialTheme { App(stage = 3, listViewModelFactory = factory) } } }
        rule.activityRule.scenario.onActivity(show)
        rule.waitUntil(5_000) { fetches.get() == 1 }
        rule.onNodeWithText("接口返回.md").assertExists()
        val before = rule.activity.hashCode()

        // 旋转屏幕 = 配置变化 = Activity 销毁重建。recreate() 走的是同一条路
        rule.activityRule.scenario.recreate()
        rule.activityRule.scenario.onActivity(show)
        rule.waitForIdle()
        var after = 0
        rule.activityRule.scenario.onActivity { after = it.hashCode() }
        if (after == before) fail("Activity 应该是新的实例")

        rule.onNodeWithText("接口返回.md").assertExists()
        Thread.sleep(500)
        assertEquals("重建后 ViewModel 还是原来那个，不应该再请求", 1, fetches.get())
    }
}
