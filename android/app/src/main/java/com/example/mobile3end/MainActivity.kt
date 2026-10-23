package com.example.mobile3end

import android.content.res.Configuration
import android.os.Build
import android.os.Bundle
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.material3.MaterialTheme
import com.example.mobile3end.lifecycle.AppLifecycle
import com.example.mobile3end.web.H5Case
import com.example.mobile3end.web.H5Screen

// 全工程统一的日志 tag，Logcat 里用 `tag:M3E` 过滤
const val TAG = "M3E"

/** M4 直达入口的 intent extra 名，见 onCreate */
const val EXTRA_H5 = "m3e.h5"

/**
 * M3：Activity 的生命周期回调都打了日志，Logcat 过滤 `tag:M3E`，切前后台、旋转屏幕时看顺序。
 * 每个回调都要先调 super，否则运行时直接抛 SuperNotCalledException
 */
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d(TAG, "MainActivity.onCreate sdk=${Build.VERSION.SDK_INT} restored=${savedInstanceState != null} @${hashCode()}")

        enableEdgeToEdge()
        // M4 直达入口（调试用）：adb shell am start -S -n com.example.mobile3end/.MainActivity --es m3e.h5 normal
        // 带了这个 extra 就只显示 H5 页：不渲染列表页、不看 STAGE、不碰 M1–M3 的空。值是 H5Case 的 key（normal / blank / missing / slow ……）
        val directH5 = intent.getStringExtra(EXTRA_H5)
        if (directH5 != null) Log.d(TAG, "直达 H5 页 case=$directH5，跳过列表页")
        setContent {
            MaterialTheme {
                if (directH5 != null) {
                    H5Screen(
                        initialCase = H5Case.of(directH5),
                        // 没有列表页可回，返回就是关掉这个 Activity
                        onBack = ::finish,
                        // 只读当前值，不调 AppLifecycle.install()：STAGE < 3 时一直是 null，不推 appState
                        appState = AppLifecycle.appState,
                        captureH5Errors = STAGE >= 5,
                    )
                } else {
                    App()
                }
            }
        }
    }

    override fun onStart() {
        super.onStart()
        Log.d(TAG, "MainActivity.onStart @${hashCode()}")
    }

    override fun onResume() {
        super.onResume()
        Log.d(TAG, "MainActivity.onResume @${hashCode()}")
    }

    override fun onPause() {
        super.onPause()
        Log.d(TAG, "MainActivity.onPause @${hashCode()}")
    }

    override fun onStop() {
        super.onStop()
        Log.d(TAG, "MainActivity.onStop @${hashCode()}")
    }

    /** 系统可能要销毁这个 Activity（旋转、后台被回收）之前，存状态的时机。rememberSaveable 存的东西就在这一步写进 Bundle */
    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        Log.d(TAG, "MainActivity.onSaveInstanceState @${hashCode()}")
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "MainActivity.onDestroy isChangingConfigurations=$isChangingConfigurations @${hashCode()}")
    }

    /** 只有 Manifest 里声明了 android:configChanges 的变化才会走到这里（不重建），见 hints/M3.md 的想一想 */
    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        Log.d(TAG, "MainActivity.onConfigurationChanged orientation=${newConfig.orientation}")
    }
}
