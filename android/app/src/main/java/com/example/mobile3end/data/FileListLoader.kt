package com.example.mobile3end.data

import android.util.Log
import com.example.mobile3end.TAG
import com.example.mobile3end.model.FileItem
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.withContext
import kotlinx.serialization.SerializationException

/** 列表页要显示什么。sealed = 只有这三种，when 不写 else 编译器也知道穷尽了，类比 TS 的联合类型 */
sealed interface ListUiState {
    data object Loading : ListUiState
    data class Failed(val message: String) : ListUiState
    /** files 为空就是「空列表」状态 */
    data class Loaded(val files: List<FileItem>) : ListUiState
}

/**
 * 先缓存后网络：
 * 1. 有缓存 → 立刻显示缓存
 * 2. 再请求网络，成功 → 显示新数据并写缓存
 * 3. 网络失败：手上已经有数据（缓存或上一次的结果）→ 继续显示，只打日志；什么都没有 → 失败态
 */
class FileListLoader(
    private val remote: RemoteFiles,
    private val cache: LocalFiles,
    private val io: CoroutineDispatcher = Dispatchers.IO,
    private val log: (String) -> Unit = { Log.d(TAG, it) },
) {
    private val _state = MutableStateFlow<ListUiState>(ListUiState.Loading)
    /** 对外只读。类比 Pinia 里 state 只能通过 action 改 */
    val state: StateFlow<ListUiState> = _state.asStateFlow()

    // 读写缓存是文件 IO，同样不能放在调用方（主线程）上
    private suspend fun readCache(): List<FileItem>? = withContext(io) { cache.load() }
    private suspend fun writeCache(files: List<FileItem>) = withContext(io) { cache.save(files) }

    // 空 M2-7：实现上面注释里的 1–3，状态都写进 _state.value
    // - 没有缓存时显示 Loading；但如果已经是 Loaded（比如 M3 回前台刷新时），不要闪回 Loading
    // - 失败文案用 messageOf(e)
    // - 协程被取消（页面关了）会以 CancellationException 的形式抛出来，它不是失败，要原样抛出去
    // 提示 1：readCache() / remote.fetch() / writeCache()；try { } catch (e: CancellationException) { throw e } catch (e: Exception) { }
    suspend fun load() {
        // 1. 先读缓存，有就立刻显示
        val cached = readCache()
        if (cached != null) {
            _state.value = ListUiState.Loaded(cached)
        } else if (_state.value !is ListUiState.Loaded) {
            _state.value = ListUiState.Loading
        }

        // 2. 请求网络，成功则更新并写缓存
        try {
            val files = remote.fetch()
            _state.value = ListUiState.Loaded(files)
            writeCache(files)
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            // 3. 失败：手上已有数据就静默，什么都没有才失败态
            if (_state.value is ListUiState.Loaded) {
                log("刷新失败：${messageOf(e)}")
            } else {
                _state.value = ListUiState.Failed(messageOf(e))
            }
        }
    }

    companion object {
        /** 失败文案带上异常类名：没放行明文 / 没加网络权限时，一眼能看出是哪种 */
        fun messageOf(e: Exception): String = when (e) {
            is HttpStatusException -> "服务器错误（HTTP ${e.code}）"
            is SerializationException -> "数据格式错误：${e.message}"
            else -> "${e.javaClass.simpleName}: ${e.message}"
        }
    }
}
