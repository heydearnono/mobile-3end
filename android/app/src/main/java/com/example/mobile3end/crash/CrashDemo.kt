package com.example.mobile3end.crash

import android.os.Handler
import android.os.Looper
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag

/** M5 刻意崩溃用的异常，名字好搜 */
class M3EDemoCrash(message: String, cause: Throwable? = null) : RuntimeException(message, cause)

/** 一个有几层调用的崩溃：release 包混淆后，看这几个方法名变成了什么 */
object CrashDemo {
    fun crashOnMainThread() {
        // post 一下再抛：直接在 onClick 里抛也行，这样堆栈更短、更好对照
        Handler(Looper.getMainLooper()).post { parseConfig("{oops") }
    }

    fun crashOnBackgroundThread() {
        Thread({ parseConfig("{oops") }, "m3e-worker").start()
    }

    private fun parseConfig(raw: String): Int =
        try {
            readVersion(raw)
        } catch (e: NumberFormatException) {
            throw M3EDemoCrash("M5 刻意抛出的异常：配置解析失败", e)
        }

    private fun readVersion(raw: String): Int = raw.removePrefix("{").toInt()
}

/** 列表页「⋮」菜单里的崩溃项（STAGE ≥ 5）。onOpenBlankH5：打开 H5 页的 blank 用例，H5 侧抛错 */
@Composable
fun CrashDemoItems(onPicked: () -> Unit, onOpenBlankH5: () -> Unit) {
    DropdownMenuItem(
        text = { Text("崩溃：主线程") },
        onClick = { onPicked(); CrashDemo.crashOnMainThread() },
        modifier = Modifier.testTag("crash-main"),
    )
    DropdownMenuItem(
        text = { Text("崩溃：后台线程") },
        onClick = { onPicked(); CrashDemo.crashOnBackgroundThread() },
        modifier = Modifier.testTag("crash-bg"),
    )
    DropdownMenuItem(
        text = { Text("H5 抛错（case=blank）") },
        onClick = { onPicked(); onOpenBlankH5() },
        modifier = Modifier.testTag("crash-h5"),
    )
}
