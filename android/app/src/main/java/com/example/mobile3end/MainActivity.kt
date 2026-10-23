package com.example.mobile3end

import android.content.res.Configuration
import android.os.Build
import android.os.Bundle
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.material3.MaterialTheme

// 全工程统一的日志 tag，Logcat 里用 `tag:M3E` 过滤
const val TAG = "M3E"

/**
 * M3：Activity 的生命周期回调都打了日志，Logcat 过滤 `tag:M3E`，切前后台、旋转屏幕时看顺序。
 * 每个回调都要先调 super，否则运行时直接抛 SuperNotCalledException
 */
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d(TAG, "MainActivity.onCreate sdk=${Build.VERSION.SDK_INT} restored=${savedInstanceState != null} @${hashCode()}")

        enableEdgeToEdge()
        setContent {
            MaterialTheme { App() }
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
