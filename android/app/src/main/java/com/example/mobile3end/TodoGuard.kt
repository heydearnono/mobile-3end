package com.example.mobile3end

import android.util.Log
import java.util.concurrent.CopyOnWriteArrayList

/**
 * 填空期间专用，真实工程里不要这样吞异常。
 *
 * M3 起有些空是被系统回调调用的（进程前后台、WebView 拦截请求、渲染进程退出……）。
 * 这些回调里抛出的异常没人接，会让整个 App 崩掉；跑仪器测试时连测试进程一起崩，后面的测试全都跑不了。
 * 所以在「系统回调 → 你写的代码」的边界上包一层：碰到未填的 TODO 就打日志、记下来、返回默认值。
 * 测试据此报「运行到了未填的 M4-x」（见 androidTest 里的 failOnTodo）
 */
object TodoGuard {
    /** 运行中碰到过的未填空，形如 "An operation is not implemented: M4-4" */
    val hits: MutableList<String> = CopyOnWriteArrayList()

    inline fun <T> run(default: T, block: () -> T): T =
        try {
            block()
        } catch (e: NotImplementedError) {
            val message = e.message ?: "An operation is not implemented"
            if (message !in hits) hits += message
            Log.e(TAG, "$message（还没填，先返回默认值）")
            default
        }
}
