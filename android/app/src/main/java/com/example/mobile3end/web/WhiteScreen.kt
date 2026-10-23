package com.example.mobile3end.web

/*
 * 白屏检测，规则见 spec.md「白屏检测」。纯逻辑：定时、执行 JS、上报都通过 WhiteScreenHost 注入，
 * H5Container 里接到 Handler.postDelayed / evaluateJavascript / Log，测试里接到假的。
 *
 * 三个信号对应 WebViewClient 的三个回调：
 * - onPageFinished → onPageFinished：延迟 1s 探测 #app 有没有子元素
 * - onReceivedError → onReceivedError：只有主文档失败才算
 * - onRenderProcessGone → onRenderProcessGone：渲染进程没了，页面一定是白的
 */

const val ROOT_CHILD_COUNT_JS = "(document.getElementById('app') || {}).childElementCount || 0"
const val CHECK_DELAY_MS = 1_000L

enum class WhiteReason(val code: String) {
    EMPTY_ROOT("empty_root"),
    RENDER_GONE("render_gone"),
    LOAD_ERROR("load_error"),
}

fun whiteScreenLog(reason: WhiteReason, url: String?) = "[WHITE_SCREEN] reason=${reason.code} url=$url"

/**
 * evaluateJavascript 的回调拿到的是「结果的 JSON 字符串」：数字 3 → "3"，字符串 → "\"abc\""，
 * 脚本抛异常 / 页面正在跳转 → "null"。拿不到数字都按 0 算
 */
fun parseChildCount(jsResult: String?): Int = jsResult?.trim()?.toDoubleOrNull()?.toInt() ?: 0

enum class CheckDecision { OK, RETRY, WHITE }

/** 检测策略：主文档加载完成后过了 elapsedMs，#app 有 childCount 个子元素，现在怎么判 */
typealias WhitePolicy = (elapsedMs: Long, childCount: Int) -> CheckDecision

/** spec 的基础规则：1s 时为 0 就是白屏。case=slow 会误报 */
fun singleCheckPolicy(elapsedMs: Long, childCount: Int): CheckDecision =
    if (childCount == 0) CheckDecision.WHITE else CheckDecision.OK

const val SLOW_DEADLINE_MS = 5_000L

// 空 M4-11：你给 case=slow 设计的检测时机。WhiteScreenMonitor 每隔 CHECK_DELAY_MS 问一次，返回 RETRY 就再等一轮
// 测试只卡三条底线：有子元素一定 OK；1s 时为空不能判白屏（slow 3s 才渲染）；到 SLOW_DEADLINE_MS 还为空必须判白屏
// 提示 1：最简单的方案是「轮询到截止时间」；想换别的方案，先在 notes 写理由，再改这里和测试
fun slowAwarePolicy(elapsedMs: Long, childCount: Int): CheckDecision {
    TODO("M4-11")
}

/** 白屏检测要用到的外部能力。H5Container 里接到真的 WebView，测试里接到假的 */
interface WhiteScreenHost {
    /** delayMs 后在主线程执行 task */
    fun schedule(delayMs: Long, task: () -> Unit)

    /** 在当前页面执行 JS，结果（JSON 字符串）交给 callback，同样在主线程 */
    fun evaluate(js: String, callback: (String?) -> Unit)

    /** 上报一行白屏日志 */
    fun report(line: String)
}

/**
 * 一个 WebView 配一个，所有方法都在主线程调用。
 * 每次主文档开始加载（onPageStarted）算一「轮」：上一轮还没跑完的检测在新一轮开始后要作废；同一轮最多报一次白屏
 */
class WhiteScreenMonitor(
    private val host: WhiteScreenHost,
    private val policy: WhitePolicy = ::slowAwarePolicy,
) {
    private var round = 0
    private var reported = false

    fun onPageStarted(url: String?) {
        round++
        reported = false
    }

    private fun report(reason: WhiteReason, url: String?) {
        if (reported) return
        reported = true
        host.report(whiteScreenLog(reason, url))
    }

    /**
     * 主文档加载完成。CHECK_DELAY_MS 后执行 ROOT_CHILD_COUNT_JS，结果（parseChildCount）交给 policy：
     * - WHITE → 报 EMPTY_ROOT
     * - RETRY → 再等 CHECK_DELAY_MS 查一次（elapsed 累加）
     * - OK → 结束
     * 等待期间、或者等 JS 结果期间开始了新一轮（onPageStarted），这次检测作废，什么都不做
     */
    fun onPageFinished(url: String?) {
        // 空 M4-8：按上面的规则实现整个方法
        // 提示 1：在 schedule 之前记下当前 round，回调里对比；写一个「过了 elapsed 毫秒，查一次」的局部函数，RETRY 时让它自己再排一次
        TODO("M4-8")
    }

    /**
     * 资源加载失败（WebViewClient.onReceivedError，API 23 起对每个失败的请求都回调）。
     * 子资源（图片、脚本、iframe）失败不算白屏，只有主文档失败才报 LOAD_ERROR
     */
    fun onReceivedError(url: String?, isForMainFrame: Boolean) {
        // 空 M4-9：按上面的规则实现
        // 提示 1：一个 if
        TODO("M4-9")
    }

    /**
     * 渲染进程没了（崩溃，或者内存不够被系统杀掉）。报 RENDER_GONE，并返回给 WebViewClient.onRenderProcessGone 的返回值
     * @return 是否已经处理。返回 false 时系统会把整个 App 一起杀掉
     */
    fun onRenderProcessGone(url: String?, didCrash: Boolean): Boolean {
        // 空 M4-10：报 RENDER_GONE，返回值见上面的注释
        // 提示 1：处理（销毁旧 WebView、换新的）由 H5Container 负责，这里只决定返回什么
        TODO("M4-10")
    }
}
