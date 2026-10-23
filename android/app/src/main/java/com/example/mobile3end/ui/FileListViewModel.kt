package com.example.mobile3end.ui

import android.content.Context
import androidx.datastore.preferences.preferencesDataStore
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.example.mobile3end.MOCK_BASE_URL
import com.example.mobile3end.data.FileApi
import com.example.mobile3end.data.FileCache
import com.example.mobile3end.data.FileListLoader
import com.example.mobile3end.data.ListUiState
import com.example.mobile3end.data.SettingsStore
import com.example.mobile3end.model.SortOrder
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.emptyFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import java.io.File

// DataStore 同一个文件全进程只能有一个实例，所以挂在 Context 的扩展属性上，由委托保证单例
private val Context.settingsDataStore by preferencesDataStore(name = "settings")

/**
 * 列表页的 ViewModel：活得比 Composable 长（旋转屏幕不重建），比 Activity 被系统杀掉短。
 * 类比 Pinia store，但作用域是一个页面的返回栈条目，页面彻底退出时 onCleared，viewModelScope 里的协程全部取消
 */
class FileListViewModel(
    private val loader: FileListLoader,
    private val settings: SettingsStore,
    /** M3：回前台、在后台待满 30s 时来一次（AppLifecycle.refreshRequests）。M2 用不到，默认是空的 */
    private val refreshRequests: Flow<Unit> = NO_REFRESH,
) : ViewModel() {

    val state: StateFlow<ListUiState> = loader.state

    /** Flow → StateFlow：Compose 里要一个「当前值」。DataStore 读出来之前先当 NAME */
    val order: StateFlow<SortOrder> =
        settings.order.stateIn(viewModelScope, SharingStarted.Eagerly, SortOrder.NAME)

    init {
        // ViewModel 创建时加载一次；旋转屏幕 ViewModel 不重建，所以不会重复请求
        viewModelScope.launch { loader.load() }
        // M2 / 测试里没传 refreshRequests 就不订阅（M3-6 没填时 STAGE 2 的 App 照常能跑）
        if (refreshRequests !== NO_REFRESH) watchRefreshRequests()
    }

    // 空 M3-6：每收到一次 refreshRequests，刷新一次列表（refresh()）
    // - 只在 init 里调用一次。ViewModel 旋转屏幕不重建，所以旋转后不会重复订阅、重复请求
    // - 页面彻底退出（ViewModel onCleared）时要自动停止收集
    // 提示 1：collect 是挂起函数，会一直等下去，要单独起一个协程；用哪个 scope 决定了它什么时候停
    private fun watchRefreshRequests() {
        TODO("M3-6")
    }

    fun retry() {
        viewModelScope.launch { loader.load() }
    }

    /** M3：回前台刷新。和重试是同一件事，loader 已经保证了「手上有数据时不闪回 Loading」 */
    fun refresh() {
        viewModelScope.launch { loader.load() }
    }

    fun setOrder(order: SortOrder) {
        viewModelScope.launch { settings.setOrder(order) }
    }

    companion object {
        private val NO_REFRESH: Flow<Unit> = emptyFlow()

        /** 手动依赖注入：真实工程里一般交给 Hilt / Koin */
        fun factory(
            context: Context,
            baseUrl: String = MOCK_BASE_URL,
            refreshRequests: Flow<Unit> = NO_REFRESH,
        ): ViewModelProvider.Factory {
            val app = context.applicationContext
            return viewModelFactory {
                initializer {
                    FileListViewModel(
                        loader = FileListLoader(
                            remote = FileApi(baseUrl),
                            cache = FileCache(File(app.filesDir, "files_cache.json")),
                        ),
                        settings = SettingsStore(app.settingsDataStore),
                        refreshRequests = refreshRequests,
                    )
                }
            }
        }
    }
}
