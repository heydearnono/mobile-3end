package com.example.mobile3end.lifecycle

import android.os.StrictMode
import android.util.Log
import android.widget.Toast
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import com.example.mobile3end.MOCK_BASE_URL
import com.example.mobile3end.TAG
import com.example.mobile3end.TodoGuard
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request

/**
 * M3：主线程上做阻塞操作会怎样。STAGE ≥ 3 时列表页右上角「⋮」菜单里有三项：
 * - 主线程 sleep 2s：界面冻住 2s
 * - 主线程网络请求：直接抛 NetworkOnMainThreadException
 * - 后台网络请求：M3-4
 *
 * 和 JS 对照：JS 只有一个线程，阻塞它（同步 XHR、死循环）页面就卡；Android 的主线程（UI 线程）也一样，
 * 但 Android 有多个线程可用，阻塞操作要自己挪到别的线程上，结果再回主线程更新界面
 *
 * @param scope 在哪个协程作用域里启动。界面上用 rememberCoroutineScope()，它跑在主线程
 * @param onResult 收到结果后调用（更新界面 / 弹 toast），必须在 scope 的线程（主线程）上调
 */
class MainThreadDemo(
    private val scope: CoroutineScope,
    private val io: CoroutineDispatcher = Dispatchers.IO,
    private val log: (String) -> Unit = { Log.d(TAG, it) },
    private val onResult: (String) -> Unit,
) {
    /** 执行 work，把结果或异常变成一行文字。在哪个线程调，work 就在哪个线程跑 */
    private fun outcome(work: () -> String): String {
        val thread = Thread.currentThread().name
        return try {
            work().also { log("[M3] thread=$thread 成功：$it") }
        } catch (e: Exception) {
            log("[M3] thread=$thread 失败：$e")
            "失败：${e.javaClass.simpleName}"
        }
    }

    /** 直接在当前线程（点按钮时就是主线程）执行。主线程网络请求就是在这里抛的 */
    fun runOnCurrentThread(work: () -> String) {
        onResult(outcome(work))
    }

    // 空 M3-4：在 io 线程上执行 work（用 outcome 包一下，异常也变成文字），拿到结果后回到 scope 的线程调 onResult
    // - 这个函数本身要立刻返回，不能等 work 跑完（调用方是主线程，等就等于卡住了）
    // 提示 1：scope.launch { }，里面用 withContext(io) { } 切线程，withContext 结束后自动回到原来的线程
    fun runInBackground(work: () -> String) {
        TODO("M3-4")
    }
}

/** 阻塞 2s，模拟耗时计算 / 同步读大文件 */
fun sleepTwoSeconds(): String {
    Thread.sleep(2_000)
    return "sleep 2s 完成"
}

/**
 * fastFallback(false)：OkHttp 5 默认开着 fast fallback（同时尝试 IPv4 / IPv6，谁先连上用谁），连接是在它自己的线程上建的。
 * 那样服务没开时，连接失败发生在 OkHttp 的线程上，主线程上看到的是 ConnectException 而不是 NetworkOnMainThreadException。
 * 关掉以后连接在调用线程上建，主线程网络一定会被拦下来，现象更稳定。见 hints/M3.md M3-4 的想一想
 */
private val demoClient by lazy { OkHttpClient.Builder().fastFallback(false).build() }

/** 同步网络请求（execute 是阻塞的），和 M2 的 FileApi 一样，只是没有 withContext */
fun fetchFilesBlocking(baseUrl: String = MOCK_BASE_URL): String {
    val request = Request.Builder().url("$baseUrl/api/files.json").build()
    return demoClient.newCall(request).execute().use { "HTTP ${it.code}，${it.body.string().length} 字符" }
}

/** 「⋮」菜单里的三项。点了先关菜单（onPicked），结果用 toast 显示 */
@Composable
fun ThreadDemoItems(onPicked: () -> Unit) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val demo = remember(scope) {
        MainThreadDemo(scope, onResult = { Toast.makeText(context, it, Toast.LENGTH_SHORT).show() })
    }
    DropdownMenuItem(
        text = { Text("主线程 sleep 2s") },
        onClick = { onPicked(); demo.runOnCurrentThread(::sleepTwoSeconds) },
        modifier = Modifier.testTag("demo-main-sleep"),
    )
    DropdownMenuItem(
        text = { Text("主线程网络请求") },
        onClick = { onPicked(); demo.runOnCurrentThread { fetchFilesBlocking() } },
        modifier = Modifier.testTag("demo-main-network"),
    )
    DropdownMenuItem(
        text = { Text("后台网络请求") },
        onClick = { onPicked(); TodoGuard.run(Unit) { demo.runInBackground { fetchFilesBlocking() } } },
        modifier = Modifier.testTag("demo-bg-network"),
    )
}

/**
 * STAGE ≥ 3 时 M3EApplication.onCreate 调用：主线程上的磁盘读写、网络都打 StrictMode 日志（logcat 搜 StrictMode）。
 * 只在 debug 包里开。注意是在系统原有策略的基础上加（Builder(getThreadPolicy())），见 hints/M3.md M3-4 的想一想
 */
fun enableStrictMode() {
    StrictMode.setThreadPolicy(
        StrictMode.ThreadPolicy.Builder(StrictMode.getThreadPolicy())
            .detectDiskReads()
            .detectDiskWrites()
            .detectNetwork()
            .penaltyLog()
            .build(),
    )
}
