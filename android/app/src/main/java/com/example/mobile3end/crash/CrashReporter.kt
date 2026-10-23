package com.example.mobile3end.crash

import android.util.Log
import com.example.mobile3end.TAG
import java.io.File

/*
 * M5：异常采集。M5 不留提示：下面每个 TODO 都是一整个函数体，注释里只有要求，方向和答案在 hints/M5.md。
 *
 * Android 上「崩溃」分两层：
 * - Java / Kotlin 层：没人 catch 的异常一路抛到线程顶上，交给 Thread 的 UncaughtExceptionHandler。
 *   不设的话，默认的那个（系统在进程启动时装好的）会打出 FATAL EXCEPTION 日志、弹「应用已停止」、杀进程。
 *   这一层这里来做
 * - Native（C / C++）层：SIGSEGV 之类的信号，要用 signal handler（Breakpad / Crashpad），这里不做，见 hints 的想一想
 *
 * H5 层的异常不会让 App 崩，但页面坏了，同样要采集：见最下面的 h5ErrorLine
 */

/** 崩溃记录的格式：第一行是摘要，后面是完整堆栈（含 Caused by） */
fun crashRecord(threadName: String, e: Throwable): String =
    "[CRASH] 线程 $threadName 未捕获异常 ${e.javaClass.name}: ${e.message}\n${e.stackTraceToString()}"

/**
 * @param file 崩溃现场写到哪。真实工程是 filesDir 下的一个文件，测试里是临时目录
 * @param log 打日志。真实工程是 Log.e，测试里收集起来
 */
class CrashReporter(
    private val file: File,
    private val log: (String) -> Unit = { Log.e(TAG, it) },
) {
    // 空 M5-1：安装进程级的未捕获异常钩子，所有线程（主线程、协程的线程池、自己 new 的 Thread）没人接的异常都要经过它
    // - 异常发生时交给 handle(thread, e)
    // - 处理完以后，交还给安装之前的那个钩子（没有就算了）：系统默认的钩子负责弹窗、杀进程，其他崩溃 SDK 也可能装过自己的，不能把它们吞掉
    // - 同一个 CrashReporter 重复调用 install 只能装一次（否则一个异常会被处理两遍）
    fun install() {
        TODO("M5-1")
    }

    // 空 M5-2：处理一个未捕获异常
    // - 用 crashRecord 生成记录，打日志
    // - 把记录写进 file，覆盖上一次的（进程马上就要死了，日志不一定来得及刷出去，文件留到下次启动再报）
    // - 写文件本身失败也不能再抛异常（在崩溃处理里再崩一次，原来的现场就丢了），打一行日志就行
    fun handle(thread: Thread, e: Throwable) {
        TODO("M5-2")
    }

    // 空 M5-3：启动时调用，把上次崩溃留下的记录报出来
    // - 没有记录：什么都不做，返回 null
    // - 有记录：打一条以「[CRASH] 上次运行崩溃了」开头的日志，后面跟着记录内容；删掉文件（只报一次）；返回记录内容
    fun reportPrevious(): String? {
        TODO("M5-3")
    }
}

/**
 * 页面任何脚本执行之前注入的 JS（H5Container 里用 WebViewCompat.addDocumentStartJavaScript，只对离线包 origin 生效）：
 * 把 H5 的未捕获异常连同堆栈打到 console。浏览器内核自己打的「Uncaught Error: ...」只有一行，没有堆栈
 */
const val H5_ERROR_HOOK_JS =
    "window.addEventListener('error', function (e) {" +
        " console.error('[H5_UNCAUGHT] ' + ((e.error && e.error.stack) || e.message));" +
        " });"

/** 浏览器内核报未捕获异常的 console 消息开头 */
const val H5_UNCAUGHT_BROWSER_PREFIX = "Uncaught"

/** H5_ERROR_HOOK_JS 打的消息开头 */
const val H5_UNCAUGHT_HOOK_PREFIX = "[H5_UNCAUGHT]"

// 空 M5-4：WebChromeClient.onConsoleMessage 收到的每一条 H5 console 消息都会走到这里（H5Container 里已经接好，STAGE ≥ 5 生效）。
// 判断它是不是 H5 的未捕获异常，是就返回要打的日志行，不是返回 null
// - 只看 error 级别（isError），且消息以 H5_UNCAUGHT_BROWSER_PREFIX 或 H5_UNCAUGHT_HOOK_PREFIX 开头的才算。
//   H5 自己 console.error('xxx') 打的是业务日志，不算
// - 日志行格式：[H5_ERROR] <message> @ <source>:<line>
fun h5ErrorLine(isError: Boolean, message: String, source: String, line: Int): String? {
    TODO("M5-4")
}
