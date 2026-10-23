package com.example.mobile3end.data

import com.example.mobile3end.model.FileItem
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import java.io.IOException

/** 列表数据从哪来。测试里换成假的，不用起服务 */
fun interface RemoteFiles {
    suspend fun fetch(): List<FileItem>
}

/** 服务端返回了非 2xx。OkHttp 不会因为 404 / 500 抛异常，要自己判断 */
class HttpStatusException(val code: Int) : IOException("HTTP $code")

class FileApi(
    private val baseUrl: String,
    private val client: OkHttpClient = OkHttpClient(),
    /** 阻塞 IO 放到哪个线程池。测试会传别的进来 */
    private val io: CoroutineDispatcher = Dispatchers.IO,
) : RemoteFiles {

    // 空 M2-2：GET $baseUrl/api/files.json，返回解析好的列表
    // - 非 2xx：抛 HttpStatusException(code)
    // - 网络不通：OkHttp 自己会抛 IOException，不用管
    // - client.newCall(request).execute() 是阻塞调用，必须切到 io 上执行，不能占着调用方的线程
    // - Response 用完要关（它占着连接），Kotlin 里用 .use { } 自动关，类似 try-with-resources
    // 提示 1：withContext(io) { ... }；Request.Builder().url(...).build()；response.isSuccessful / response.code / response.body.string()
    override suspend fun fetch(): List<FileItem> {
        return withContext(io) {
            val request = Request.Builder()
                .url("$baseUrl/api/files.json")
                .build()

            client.newCall(request).execute().use { response ->
                if (!response.isSuccessful) {
                    throw HttpStatusException(response.code)
                }
                parseFiles(response.body.string())
            }
        }
    }
}
