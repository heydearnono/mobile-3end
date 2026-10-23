package com.example.mobile3end.web

import android.util.Log
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.example.mobile3end.TAG
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.drop

/** H5 页的测试用例，对应 spec「H5 测试用例」，外加几个值得看的场景。H5 页右上角「用例」菜单切换 */
enum class H5Case(val key: String, val title: String) {
    NORMAL("normal", "正常"),
    BLANK("blank", "blank：挂载前抛异常"),
    MISSING("missing", "missing：引用不存在的 js"),
    SLOW("slow", "slow：3s 后才渲染"),
    NOT_FOUND("not-found", "不存在的离线页"),
    EXTERNAL("external", "外部页面 example.com"),
    FOREIGN("foreign", "外部页面（内联，evil.test）"),
    LOAD_ERROR("load-error", "主文档加载失败（nope.invalid）"),
    RENDER_CRASH("render-crash", "模拟渲染进程崩溃"),
    ;

    /** FOREIGN 走 loadForeign，没有 url */
    val url: String?
        get() = when (this) {
            NORMAL -> OFFLINE_ENTRY
            BLANK, MISSING, SLOW -> "$OFFLINE_ENTRY?case=$key"
            NOT_FOUND -> "$OFFLINE_ORIGIN/nope.html"
            EXTERNAL -> "https://example.com/"
            FOREIGN -> null
            // .invalid 是保留域名，一定解析不到，而且不归离线包管
            LOAD_ERROR -> "https://nope.invalid/"
            // WebView 内置的调试地址：让渲染进程自己崩掉
            RENDER_CRASH -> "chrome://crash"
        }

    companion object {
        fun of(key: String?) = entries.firstOrNull { it.key == key } ?: NORMAL
    }
}

fun H5Container.open(case: H5Case) {
    val url = case.url
    if (url == null) loadForeign() else load(url)
}

/**
 * 全屏 H5 页。WebView 是传统 View，用 AndroidView 嵌进 Compose。
 * @param appState App 前后台（M3 的 AppLifecycle.appState），变化时推给 H5
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun H5Screen(
    initialCase: H5Case,
    onBack: () -> Unit,
    appState: StateFlow<String?> = remember { MutableStateFlow(null) },
    captureH5Errors: Boolean = false,
) {
    val context = LocalContext.current
    var currentCase by rememberSaveable { mutableStateOf(initialCase) }
    // 渲染进程没了以后旧的 WebView 不能再用，换一个新的。generation 变了 remember 就重新创建
    var generation by remember { mutableIntStateOf(0) }
    val container = remember(generation) {
        H5Container(context, captureH5Errors = captureH5Errors, onRenderGone = { generation++ })
            .also { it.open(if (generation == 0) currentCase else H5Case.NORMAL) }
    }
    DisposableEffect(container) {
        Log.d(TAG, "H5Screen 进入组合 generation=$generation")
        onDispose {
            Log.d(TAG, "H5Screen 离开组合")
            container.destroy()
        }
    }

    // 只推「变化」，不推当前值：页面刚开始加载时 app.js 还没执行，__bridgeEvent 还不存在。
    // 直接 collect 而不是 collectAsStateWithLifecycle：切到后台时页面的 Lifecycle 已经 STOP，那样就收不到 background 了
    LaunchedEffect(container, appState) {
        appState.drop(1).collect { container.pushAppState(it) }
    }

    val offline404 by container.offline404.collectAsStateWithLifecycle()
    val white by container.whiteScreen.collectAsStateWithLifecycle()
    var menu by remember { mutableStateOf(false) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("H5") },
                navigationIcon = { TextButton(onClick = onBack) { Text("← 返回") } },
                actions = {
                    TextButton(onClick = { menu = true }, modifier = Modifier.testTag("h5-cases")) { Text("用例") }
                    DropdownMenu(expanded = menu, onDismissRequest = { menu = false }) {
                        H5Case.entries.forEach { c ->
                            DropdownMenuItem(
                                text = { Text(c.title) },
                                onClick = {
                                    menu = false
                                    currentCase = c
                                    container.open(c)
                                },
                            )
                        }
                        DropdownMenuItem(text = { Text("重新加载") }, onClick = { menu = false; container.webView.reload() })
                    }
                },
            )
        },
    ) { innerPadding ->
        Column(Modifier.padding(innerPadding).fillMaxSize()) {
            Surface(color = MaterialTheme.colorScheme.surfaceVariant) {
                Row(Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 6.dp)) {
                    Text("case=${currentCase.key}", style = MaterialTheme.typography.labelSmall)
                    Spacer(Modifier.weight(1f))
                    Text(
                        "OFFLINE_404 ×$offline404  白屏检测：${white ?: "—"}",
                        style = MaterialTheme.typography.labelSmall,
                        modifier = Modifier.testTag("h5-status"),
                    )
                }
            }
            // factory 只在第一次执行；container 换了（generation 变了）用 key 让 AndroidView 也跟着重建
            androidx.compose.runtime.key(container) {
                AndroidView(
                    factory = { container.webView },
                    modifier = Modifier.fillMaxSize().testTag("h5-web"),
                )
            }
        }
    }
}
