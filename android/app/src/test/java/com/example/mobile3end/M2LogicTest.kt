package com.example.mobile3end

import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import androidx.datastore.preferences.core.stringPreferencesKey
import com.example.mobile3end.data.FileApi
import com.example.mobile3end.data.FileCache
import com.example.mobile3end.data.FileListLoader
import com.example.mobile3end.data.HttpStatusException
import com.example.mobile3end.data.ListUiState
import com.example.mobile3end.data.LocalFiles
import com.example.mobile3end.data.RemoteFiles
import com.example.mobile3end.data.SettingsStore
import com.example.mobile3end.data.encodeFiles
import com.example.mobile3end.data.parseFiles
import com.example.mobile3end.model.FileItem
import com.example.mobile3end.model.FileType
import com.example.mobile3end.model.SortOrder
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.asCoroutineDispatcher
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.runTest
import mockwebserver3.MockResponse
import mockwebserver3.MockWebServer
import okhttp3.OkHttpClient
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File
import java.io.IOException
import java.util.concurrent.Executors

/** M2 纯逻辑检查，JVM 上跑，不需要模拟器。方法名前缀 = 覆盖的空 */
class M2LogicTest {

    @get:Rule
    val tmp = TemporaryFolder()

    private val a = FileItem("a", "a.txt", FileType.DOC, 1, 10)
    private val b = FileItem("b", "B", FileType.FOLDER, 0, 20)
    private val c = FileItem("c", "c.mp4", FileType.VIDEO, 300, 30)

    private val logs = mutableListOf<String>()
    private val log: (String) -> Unit = { logs += it }

    // ---------- 示例：encodeFiles 是写好的，parseFiles 要和它对得上 ----------

    @Test
    fun m2_0_encodeFormatMatchesApi() {
        val json = encodeFiles(listOf(a))
        assertEquals("""{"files":[{"id":"a","name":"a.txt","type":"doc","size":1,"mtime":10}]}""", json)
    }

    // ---------- M2-1 ----------

    @Test
    fun m2_1_parsesMockApiShape() {
        val json = """
            { "files": [
              { "id": "f001", "name": "工作资料", "type": "folder", "size": 0, "mtime": 1760500000 },
              { "id": "f005", "name": "白屏率看板截图.png", "type": "image", "size": 356210, "mtime": 1760860000 },
              { "id": "f007", "name": "发布会录屏.mp4", "type": "video", "size": 268435456, "mtime": 1758900000 }
            ] }
        """
        assertEquals(
            listOf(
                FileItem("f001", "工作资料", FileType.FOLDER, 0, 1760500000),
                FileItem("f005", "白屏率看板截图.png", FileType.IMAGE, 356210, 1760860000),
                FileItem("f007", "发布会录屏.mp4", FileType.VIDEO, 268435456, 1758900000),
            ),
            parseFiles(json),
        )
    }

    @Test
    fun m2_1_unknownTypeFallsBackToDoc_extraFieldsIgnored() {
        val json = """{"files":[{"id":"x","name":"x.pdf","type":"pdf","size":5,"mtime":1,"owner":"me"}],"total":1}"""
        assertEquals(listOf(FileItem("x", "x.pdf", FileType.DOC, 5, 1)), parseFiles(json))
    }

    @Test
    fun m2_1_roundTripsWithEncode() {
        val files = listOf(a, b, c)
        assertEquals(files, parseFiles(encodeFiles(files)))
    }

    @Test
    fun m2_1_brokenJsonThrows() {
        for (bad in listOf("", "<html>502</html>", """{"files":[{"id":"x"}]}""")) {
            try {
                parseFiles(bad)
                fail("「$bad」应该抛异常")
            } catch (e: IllegalArgumentException) {
                // SerializationException 是 IllegalArgumentException 的子类
            }
        }
    }

    // ---------- M2-2 ----------

    private lateinit var server: MockWebServer

    @Before
    fun startServer() {
        server = MockWebServer()
        server.start()
    }

    @After
    fun stopServer() {
        server.close()
    }

    private fun baseUrl() = server.url("/").toString().trimEnd('/')

    @Test
    fun m2_2_getsFilesJson() = runTest {
        server.enqueue(MockResponse(body = encodeFiles(listOf(a, b))))

        val files = FileApi(baseUrl()).fetch()

        assertEquals(listOf(a, b), files)
        val request = server.takeRequest()
        assertEquals("GET", request.method)
        assertEquals("/api/files.json", request.url.encodedPath)
    }

    @Test
    fun m2_2_non2xxThrowsHttpStatus() = runTest {
        server.enqueue(MockResponse(code = 404, body = "not found"))
        try {
            FileApi(baseUrl()).fetch()
            fail("404 应该抛 HttpStatusException")
        } catch (e: HttpStatusException) {
            assertEquals(404, e.code)
        }
    }

    @Test
    fun m2_2_blockingCallRunsOnIoDispatcher() = runTest {
        server.enqueue(MockResponse(body = encodeFiles(listOf(a))))
        var callThread = ""
        val client = OkHttpClient.Builder()
            .addInterceptor { chain -> callThread = Thread.currentThread().name; chain.proceed(chain.request()) }
            .build()
        val executor = Executors.newSingleThreadExecutor { r -> Thread(r, "m3e-io") }
        try {
            FileApi(baseUrl(), client, executor.asCoroutineDispatcher()).fetch()
        } finally {
            executor.shutdown()
        }
        assertEquals("execute() 是阻塞调用，应该在传进来的 io 上执行", "m3e-io", callThread)
    }

    @Test
    fun m2_2_serverDownThrowsIOException() = runTest {
        val url = baseUrl()
        server.close()
        try {
            FileApi(url).fetch()
            fail("服务没开应该抛 IOException")
        } catch (e: IOException) {
        }
    }

    // ---------- M2-3 / M2-4 ----------

    private fun cacheFile() = File(tmp.root, "files_cache.json")

    @Test
    fun m2_3_m2_4_saveThenLoad() {
        val cache = FileCache(cacheFile(), log)
        cache.save(listOf(a, b, c))
        assertEquals(listOf(a, b, c), FileCache(cacheFile(), log).load())
    }

    @Test
    fun m2_3_writesApiFormatAndLeavesNoTempFile() {
        FileCache(cacheFile(), log).save(listOf(a))
        assertEquals(encodeFiles(listOf(a)), cacheFile().readText())
        assertEquals("目录里只应该剩缓存文件本身", listOf("files_cache.json"), tmp.root.list()!!.toList())
    }

    @Test
    fun m2_3_overwritesOldCache() {
        val cache = FileCache(cacheFile(), log)
        cache.save(listOf(a, b, c))
        cache.save(listOf(c))
        assertEquals(listOf(c), cache.load())
    }

    @Test
    fun m2_4_missingFileIsNull() {
        assertNull(FileCache(cacheFile(), log).load())
    }

    @Test
    fun m2_4_corruptFileIsNullAndLogged() {
        cacheFile().writeText("""{"files":[{"id":"a","na""")
        assertNull(FileCache(cacheFile(), log).load())
        assertTrue("缓存坏了要打日志，排查时才知道发生过", logs.isNotEmpty())
    }

    // ---------- M2-5 / M2-6 ----------

    private fun settings(scope: CoroutineScope) = SettingsStore(
        PreferenceDataStoreFactory.create(scope = scope) { File(tmp.root, "settings.preferences_pb") },
    )

    /** DataStore 同一个文件同时只能有一个实例：模拟「重启 App」要先关掉上一个 scope */
    private fun <T> withSettings(block: suspend (SettingsStore) -> T): T {
        val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
        try {
            return runBlocking { block(settings(scope)) }
        } finally {
            scope.cancel()
            Thread.sleep(50)
        }
    }

    @Test
    fun m2_5_defaultIsName() {
        assertEquals(SortOrder.NAME, withSettings { it.order.first() })
    }

    @Test
    fun m2_5_m2_6_survivesRestart() {
        withSettings { it.setOrder(SortOrder.TIME) }
        assertEquals("重新打开 DataStore（相当于重启）后应该还是 TIME", SortOrder.TIME, withSettings { it.order.first() })
        withSettings { it.setOrder(SortOrder.NAME) }
        assertEquals(SortOrder.NAME, withSettings { it.order.first() })
    }

    @Test
    fun m2_5_unknownStoredValueIsName() {
        val file = File(tmp.root, "settings.preferences_pb")
        val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
        runBlocking {
            val ds = PreferenceDataStoreFactory.create(scope = scope) { file }
            ds.updateData { prefs ->
                prefs.toMutablePreferences().apply {
                    set(stringPreferencesKey("sort_order"), "SIZE")
                }
            }
        }
        scope.cancel()
        Thread.sleep(50)
        assertEquals(SortOrder.NAME, withSettings { it.order.first() })
    }

    // ---------- M2-7 ----------

    /** 内存版缓存 */
    private class MemCache(var files: List<FileItem>? = null) : LocalFiles {
        var saves = 0
        override fun load() = files
        override fun save(files: List<FileItem>) {
            saves++
            this.files = files
        }
    }

    /** 每次 fetch 都等测试手动给结果，用来观察「网络还没回来」时的状态 */
    private class GatedRemote : RemoteFiles {
        private var gate = CompletableDeferred<List<FileItem>>()
        var calls = 0
        override suspend fun fetch(): List<FileItem> {
            calls++
            return gate.await()
        }
        fun succeed(files: List<FileItem>) = gate.complete(files).also { gate = CompletableDeferred() }
        fun fail(e: Exception) = gate.completeExceptionally(e).also { gate = CompletableDeferred() }
    }

    /** io 用和测试同一个调度器：不真的切线程，状态变化可以同步观察 */
    private fun TestScope.loader(remote: RemoteFiles, cache: LocalFiles) =
        FileListLoader(remote, cache, io = UnconfinedTestDispatcher(testScheduler), log = log)

    @Test
    fun m2_7_noCache_loadingThenLoaded_andCached() = runTest(UnconfinedTestDispatcher()) {
        val remote = GatedRemote()
        val cache = MemCache()
        val loader = loader(remote, cache)

        val job = launch { loader.load() }
        assertEquals(ListUiState.Loading, loader.state.value)

        remote.succeed(listOf(a, b))
        job.join()
        assertEquals(ListUiState.Loaded(listOf(a, b)), loader.state.value)
        assertEquals("成功后要写缓存", listOf(a, b), cache.files)
    }

    @Test
    fun m2_7_cacheShownBeforeNetworkReturns() = runTest(UnconfinedTestDispatcher()) {
        val remote = GatedRemote()
        val loader = loader(remote, MemCache(listOf(c)))

        val job = launch { loader.load() }
        assertEquals("网络还没回来，应该先显示缓存", ListUiState.Loaded(listOf(c)), loader.state.value)
        assertEquals("显示缓存后仍要发请求", 1, remote.calls)

        remote.succeed(listOf(a))
        job.join()
        assertEquals(ListUiState.Loaded(listOf(a)), loader.state.value)
    }

    @Test
    fun m2_7_networkFails_withCache_keepsCache() = runTest(UnconfinedTestDispatcher()) {
        val remote = GatedRemote()
        val loader = loader(remote, MemCache(listOf(c)))

        val job = launch { loader.load() }
        remote.fail(IOException("Failed to connect"))
        job.join()

        assertEquals(ListUiState.Loaded(listOf(c)), loader.state.value)
    }

    @Test
    fun m2_7_networkFails_noCache_failedWithMessage() = runTest(UnconfinedTestDispatcher()) {
        val remote = GatedRemote()
        val loader = loader(remote, MemCache())

        val job = launch { loader.load() }
        remote.fail(HttpStatusException(500))
        job.join()

        assertEquals(ListUiState.Failed(FileListLoader.messageOf(HttpStatusException(500))), loader.state.value)
    }

    @Test
    fun m2_7_reloadWhileLoaded_doesNotFlashLoading() = runTest(UnconfinedTestDispatcher()) {
        val remote = GatedRemote()
        // 缓存写不进去（比如磁盘满）：第二次加载时手上只有内存里的数据
        val cache = object : LocalFiles {
            override fun load(): List<FileItem>? = null
            override fun save(files: List<FileItem>) {}
        }
        val loader = loader(remote, cache)
        val first = launch { loader.load() }
        remote.succeed(listOf(a))
        first.join()

        val second = launch { loader.load() }
        assertEquals("已经有数据时再加载，不要闪回 Loading", ListUiState.Loaded(listOf(a)), loader.state.value)
        remote.fail(IOException("timeout"))
        second.join()
        assertEquals("刷新失败也不该把已有数据换成失败态", ListUiState.Loaded(listOf(a)), loader.state.value)
    }

    @Test
    fun m2_7_retryAfterFailureLoads() = runTest(UnconfinedTestDispatcher()) {
        val remote = GatedRemote()
        val loader = loader(remote, MemCache())
        val first = launch { loader.load() }
        remote.fail(IOException("down"))
        first.join()
        assertTrue(loader.state.value is ListUiState.Failed)

        val retry = launch { loader.load() }
        assertEquals("重试时没有数据，应该回到 Loading", ListUiState.Loading, loader.state.value)
        remote.succeed(listOf(b))
        retry.join()
        assertEquals(ListUiState.Loaded(listOf(b)), loader.state.value)
    }

    @Test
    fun m2_7_cancelIsNotFailure() = runTest(UnconfinedTestDispatcher()) {
        val remote = GatedRemote()
        val loader = loader(remote, MemCache())

        val job = launch { loader.load() }
        job.cancel()
        job.join()

        assertFalse("页面关了导致的取消不是加载失败", loader.state.value is ListUiState.Failed)
    }
}
