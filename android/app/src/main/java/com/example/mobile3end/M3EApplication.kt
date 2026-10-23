package com.example.mobile3end

import android.app.Application
import android.content.pm.ApplicationInfo
import android.util.Log
import com.example.mobile3end.crash.CrashReporter
import com.example.mobile3end.lifecycle.AppLifecycle
import com.example.mobile3end.lifecycle.enableStrictMode
import java.io.File

/**
 * 进程里第一个被创建的组件（比任何 Activity 都早），一个进程只有一个。
 * 在 AndroidManifest.xml 的 <application android:name> 里登记。类比 Vue 的 main.ts：createApp 之前的全局初始化放这里
 */
class M3EApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "Application.onCreate stage=$STAGE")

        // M5：越早装越好，装之前发生的崩溃采集不到
        if (STAGE >= 5) {
            val reporter = CrashReporter(File(filesDir, "crash-last.txt"))
            TodoGuard.run(Unit) { reporter.install() }
            TodoGuard.run(null) { reporter.reportPrevious() }
        }

        // M3：进程级前后台监听。装得越早，Process.ON_START 这些日志的顺序越接近真实（App.kt 里也会调，重复调用只装一次）
        if (STAGE >= 3) AppLifecycle.install()

        // M3：主线程上读写磁盘、访问网络都在 logcat 里报一行 StrictMode。只在 debug 包里开
        val debuggable = applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0
        if (STAGE >= 3 && debuggable) enableStrictMode()
    }
}
