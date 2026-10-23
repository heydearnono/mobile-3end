package com.example.mobile3end.web

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Bitmap
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.ViewGroup
import android.webkit.ConsoleMessage
import android.webkit.JavascriptInterface
import android.webkit.RenderProcessGoneDetail
import android.webkit.WebChromeClient
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.Toast
import androidx.annotation.RequiresApi
import androidx.webkit.WebViewCompat
import androidx.webkit.WebViewFeature
import com.example.mobile3end.TAG
import com.example.mobile3end.TodoGuard
import com.example.mobile3end.crash.H5_ERROR_HOOK_JS
import com.example.mobile3end.crash.h5ErrorLine
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import java.io.ByteArrayInputStream
import java.io.IOException

/**
 * H5 容器：一个 WebView + 离线包拦截 + bridge + 白屏检测。必须在主线程创建和使用。
 *
 * 和 FE 的对应关系：WebView ≈ 一个 iframe，WebViewClient ≈ 导航 / 网络相关的事件（load、error、fetch 拦截），
 * WebChromeClient ≈ 浏览器 UI 相关的事件（console、alert、进度条、标题）
 *
 * @param captureH5Errors M5：把 H5 的未捕获异常转到原生日志（STAGE ≥ 5）
 * @param onRenderGone 渲染进程没了、WebView 已经销毁之后调用，H5Screen 收到后换一个新的容器
 */
class H5Container(
    context: Context,
    private val log: (String) -> Unit = { Log.d(TAG, it) },
    private val logError: (String) -> Unit = { Log.e(TAG, it) },
    private val captureH5Errors: Boolean = false,
    private val onRenderGone: () -> Unit = {},
) {
    private val appContext = context.applicationContext
    private val main = Handler(Looper.getMainLooper())
    val webView: WebView = WebView(context)

    private val _offline404 = MutableStateFlow(0)
    /** 这个容器里出现过几次 OFFLINE_404，H5 页顶部状态条显示 */
    val offline404: StateFlow<Int> = _offline404.asStateFlow()

    private val _whiteScreen = MutableStateFlow<String?>(null)
    /** 当前页面的白屏结论（empty_root / load_error / render_gone），null 表示还没报过 */
    val whiteScreen: StateFlow<String?> = _whiteScreen.asStateFlow()

    /** 最近一次开始加载的主文档 URL。渲染进程没了以后 webView.url 不能再用，要靠它 */
    private var pageUrl: String? = null
    private var destroyed = false

    // 白屏检测要的三样能力，接到这个 WebView 上。回调里可能碰到没填的空，统一用 TodoGuard 接住
    private val host = object : WhiteScreenHost {
        override fun schedule(delayMs: Long, task: () -> Unit) {
            main.postDelayed({ if (!destroyed) TodoGuard.run(Unit, task) }, delayMs)
        }

        override fun evaluate(js: String, callback: (String?) -> Unit) {
            if (destroyed) return
            // evaluateJavascript 只能在主线程调，回调也回到主线程
            webView.evaluateJavascript(js) { result -> TodoGuard.run(Unit) { callback(result) } }
        }

        override fun report(line: String) {
            log(line)
            _whiteScreen.value = line.substringAfter("reason=").substringBefore(' ')
        }
    }
    val monitor = WhiteScreenMonitor(host)

    private val dispatcher = BridgeDispatcher(
        deviceInfo = { deviceInfoOf(appContext) },
        toast = { Toast.makeText(appContext, it, Toast.LENGTH_SHORT).show() },
        log = log,
    )

    /** 注册给 H5 的对象 */
    private val bridge = NativeBridgeInterface(
        mainThread = { task -> main.post { if (!destroyed) TodoGuard.run(Unit, task) } },
        currentUrl = { webView.url },
        dispatcher = dispatcher,
        evaluate = { js -> if (!destroyed) webView.evaluateJavascript(js, null) },
    )
    private var bridgeInjected = false

    init {
        // 默认关着 JS。打开 JS 之后 addJavascriptInterface 才有意义，也才有安全问题
        @SuppressLint("SetJavaScriptEnabled")
        webView.settings.javaScriptEnabled = true
        // localStorage / sessionStorage，默认也是关的
        webView.settings.domStorageEnabled = true
        // M4 手工任务：在这里打开 WebView 远程调试，见 hints/M4.md「手工任务 2」

        webView.webViewClient = Client()
        webView.webChromeClient = Chrome()

        // M5：H5 异常钩子要在页面脚本执行前就位（case=blank 在 app.js 一执行就抛），onPageStarted 里再 evaluateJavascript 就晚了
        if (captureH5Errors && WebViewFeature.isFeatureSupported(WebViewFeature.DOCUMENT_START_SCRIPT)) {
            WebViewCompat.addDocumentStartJavaScript(webView, H5_ERROR_HOOK_JS, setOf(OFFLINE_ORIGIN))
        }
    }

    private fun readAsset(path: String): ByteArray? =
        try {
            appContext.assets.open(path).use { it.readBytes() }
        } catch (e: IOException) {
            null // 包里没有这个文件（或者是个目录）
        }

    /** 离线包 404：打日志 + 计数 */
    private fun reportOffline404(line: String) {
        log(line)
        _offline404.update { it + 1 }
    }

    // 已写好（原空 M4-4）：离线包拦截。读懂即可，想一想见 hints/M4.md
    // 不是离线包的请求返回 null（放行，WebView 自己走网络）；
    // 是的话用 resolveOffline 的结果组装 WebResourceResponse，有 log 就交给 reportOffline404
    // - 这个方法跑在 WebView 的后台线程上，不是主线程（所以这里不能碰 webView）
    // - 读文件用写好的 readAsset
    // 要点：3 个参数的构造函数状态码固定是 200，所以用 6 个参数的那个（能带状态码和原因短语，原因短语不能是空串）；
    //      data 要的是 InputStream
    fun interceptRequest(request: WebResourceRequest): WebResourceResponse? {
        val url = request.url.toString()
        val result = resolveOffline(url, ::readAsset) ?: return null
        result.log?.let(::reportOffline404)
        return WebResourceResponse(
            result.mime,
            "utf-8",
            result.status,
            result.reason,
            emptyMap(),
            ByteArrayInputStream(result.data),
        )
    }

    /**
     * spec「加载其他页面时不注入」。addJavascriptInterface / removeJavascriptInterface 要到「下一次加载」才生效，
     * 所以在每次主文档开始加载之前（我们自己 load，或者 H5 里点链接跳转）按目标地址决定注入还是移除。
     * 这只管主文档：页面里的 iframe 照样能看到 NativeBridge，见 hints/M4.md M4-6 的想一想
     */
    private fun prepareBridge(url: String) {
        val want = TodoGuard.run(false) { isOfflineOrigin(url) }
        if (want == bridgeInjected) return
        if (want) {
            webView.addJavascriptInterface(GuardedBridge(bridge), BRIDGE_NAME)
        } else {
            webView.removeJavascriptInterface(BRIDGE_NAME)
        }
        bridgeInjected = want
        log("[BRIDGE] ${if (want) "注入" else "移除"} $BRIDGE_NAME，目标 $url")
    }

    fun load(url: String) {
        if (destroyed) return
        prepareBridge(url)
        webView.loadUrl(url)
    }

    /** 不联网的「外部页面」：以 https://evil.test 为 origin 加载一段内联 HTML，看 bridge 有没有暴露 */
    fun loadForeign() {
        if (destroyed) return
        prepareBridge(FOREIGN_BASE_URL)
        webView.loadDataWithBaseURL(FOREIGN_BASE_URL, FOREIGN_HTML, "text/html", "utf-8", null)
    }

    /** App 前后台变化，推给 H5（M4-7 决定推不推） */
    fun pushAppState(state: String?) {
        if (destroyed) return
        val js = TodoGuard.run(null) { appStateJs(state, webView.url) } ?: return
        log("[BRIDGE] → appState $state")
        webView.evaluateJavascript(js, null)
    }

    /** 页面离开时调用。WebView 不会自己释放，不 destroy 会一直占着内存和渲染进程 */
    fun destroy() {
        if (destroyed) return
        destroyed = true
        main.removeCallbacksAndMessages(null)
        (webView.parent as? ViewGroup)?.removeView(webView)
        webView.destroy()
    }

    private inner class Client : WebViewClient() {
        override fun shouldInterceptRequest(view: WebView, request: WebResourceRequest): WebResourceResponse? =
            TodoGuard.run(null) { interceptRequest(request) }

        /** H5 自己发起的跳转（点链接、location.href = ...）会先到这里。返回 false = 让 WebView 照常加载 */
        override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean {
            if (request.isForMainFrame) prepareBridge(request.url.toString())
            return false
        }

        override fun onPageStarted(view: WebView, url: String?, favicon: Bitmap?) {
            log("onPageStarted $url")
            pageUrl = url
            _whiteScreen.value = null
            monitor.onPageStarted(url)
        }

        override fun onPageFinished(view: WebView, url: String?) {
            log("onPageFinished $url")
            TodoGuard.run(Unit) { monitor.onPageFinished(url) }
        }

        override fun onReceivedError(view: WebView, request: WebResourceRequest, error: WebResourceError) {
            log("onReceivedError ${error.errorCode} ${error.description} ${request.url} mainFrame=${request.isForMainFrame}")
            TodoGuard.run(Unit) { monitor.onReceivedError(request.url.toString(), request.isForMainFrame) }
        }

        /** 拿到了 HTTP 响应但状态码 ≥ 400（包括离线包拦截器回的 404）。不算 onReceivedError */
        override fun onReceivedHttpError(view: WebView, request: WebResourceRequest, response: WebResourceResponse) {
            log("onReceivedHttpError ${response.statusCode} ${request.url} mainFrame=${request.isForMainFrame}")
        }

        /**
         * 渲染进程没了。返回 true 之后这个 WebView 就不能再用了（再调它的方法会崩），只能销毁换新的；
         * 返回 false（默认实现）系统会把整个 App 进程杀掉
         */
        @RequiresApi(Build.VERSION_CODES.O)
        override fun onRenderProcessGone(view: WebView, detail: RenderProcessGoneDetail): Boolean {
            log("onRenderProcessGone didCrash=${detail.didCrash()} priority=${detail.rendererPriorityAtExit()}")
            val handled = TodoGuard.run(true) { monitor.onRenderProcessGone(pageUrl, detail.didCrash()) }
            if (handled) {
                destroy()
                onRenderGone()
            }
            return handled
        }
    }

    private inner class Chrome : WebChromeClient() {
        override fun onConsoleMessage(message: ConsoleMessage): Boolean {
            if (captureH5Errors) {
                val line = TodoGuard.run(null) {
                    h5ErrorLine(
                        isError = message.messageLevel() == ConsoleMessage.MessageLevel.ERROR,
                        message = message.message(),
                        source = message.sourceId(),
                        line = message.lineNumber(),
                    )
                }
                if (line != null) logError(line)
            }
            // false：继续交给系统打到 logcat（tag 是 chromium）
            return false
        }
    }

    companion object {
        const val FOREIGN_BASE_URL = "https://evil.test/"

        /** 页面上显示 bridge 是否暴露、是否响应 */
        val FOREIGN_HTML = """
            <!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
            <body><div id="app"><h1>外部页面 evil.test</h1><p id="r">bridge: …</p></div>
            <script>
              var r = document.getElementById('r');
              var b = window.NativeBridge;
              if (!b) {
                r.textContent = 'bridge: none';
              } else {
                r.textContent = 'bridge: exposed, waiting';
                window.__bridgeCallback = function () { r.textContent = 'bridge: responded'; };
                b.postMessage(JSON.stringify({ id: '1', method: 'getDeviceInfo', params: {} }));
                setTimeout(function () { if (r.textContent.indexOf('waiting') > 0) r.textContent = 'bridge: exposed, no response'; }, 1500);
              }
            </script></body></html>
        """.trimIndent()
    }
}

/**
 * 填空期间的保护层：postMessage 里碰到未填的空时，不让异常抛进 JS（H5 那边只会看到一句「Java exception was raised」），
 * 而是记到 TodoGuard 里。真实工程直接 addJavascriptInterface(NativeBridgeInterface(...), "NativeBridge")
 */
private class GuardedBridge(private val inner: NativeBridgeInterface) {
    @JavascriptInterface
    fun postMessage(message: String) = TodoGuard.run(Unit) { inner.postMessage(message) }
}

fun deviceInfoOf(context: Context): DeviceInfo = DeviceInfo(
    platform = "android",
    osVersion = "Android ${Build.VERSION.RELEASE} (API ${Build.VERSION.SDK_INT})",
    appVersion = context.packageManager.getPackageInfo(context.packageName, 0).versionName ?: "?",
)
