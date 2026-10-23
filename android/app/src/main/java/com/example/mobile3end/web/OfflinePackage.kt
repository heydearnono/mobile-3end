package com.example.mobile3end.web

import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull

/*
 * M4 离线包：H5 访问 https://h5.offline.test/...，在 WebViewClient.shouldInterceptRequest 里拦下来，
 * 从 assets/h5/ 读文件返回（spec「离线包」）。`.test` 是保留域名，拦截失效时 DNS 解析不到，页面直接加载失败，便于发现。
 *
 * 这个文件只放纯逻辑（URL → 状态码 / MIME / 数据），不碰 WebView，JVM 单测覆盖；
 * 和 WebResourceResponse 打交道的胶水在 H5Container.kt（M4-4）。
 *
 * 解析 URL 用的是 OkHttp 的 HttpUrl，不是 android.net.Uri：android.net.Uri 在 JVM 单测里用不了（android.jar 里只有空壳），
 * HttpUrl 是纯 Kotlin，按浏览器的规则解析（host 转小写、默认端口、消掉 . 和 ..），和 WebView 看到的一致。
 * 真实容器里一般直接用 request.url（android.net.Uri）的 host / path，道理一样
 */

const val OFFLINE_HOST = "h5.offline.test"
const val OFFLINE_ORIGIN = "https://$OFFLINE_HOST"
const val OFFLINE_ENTRY = "$OFFLINE_ORIGIN/index.html"

/** assets 下的目录名。由 app/build.gradle.kts 的 syncH5 任务从 mock/h5 同步过来 */
const val ASSET_DIR = "h5"

const val LOG_OFFLINE_404 = "[OFFLINE_404]"

private val MIME_TABLE = mapOf(
    "html" to "text/html",
    "htm" to "text/html",
    "js" to "text/javascript",
    "mjs" to "text/javascript",
    "css" to "text/css",
    "json" to "application/json",
    "map" to "application/json",
    "txt" to "text/plain",
    "png" to "image/png",
    "jpg" to "image/jpeg",
    "jpeg" to "image/jpeg",
    "gif" to "image/gif",
    "webp" to "image/webp",
    "svg" to "image/svg+xml",
    "ico" to "image/x-icon",
    "woff" to "font/woff",
    "woff2" to "font/woff2",
    "ttf" to "font/ttf",
    "wasm" to "application/wasm",
)

/** 按扩展名给 MIME，不认识的给 application/octet-stream */
fun mimeOf(path: String): String =
    MIME_TABLE[path.substringAfterLast('/').substringAfterLast('.', "").lowercase()] ?: "application/octet-stream"

// 空 M4-1：这个 URL 是不是离线包 origin（https://h5.offline.test）。scheme、host、端口三样都要对上
// 不是合法的 http(s) URL（比如 file:///、about:blank、乱写的字符串）返回 false
// 提示 1：url.toHttpUrlOrNull() 解析失败返回 null；HttpUrl 有 scheme / host / port，https 没写端口时 port 是 443
fun isOfflineOrigin(url: String): Boolean {
    TODO("M4-1")
}

/**
 * 离线包 URL → 包内相对路径（已 URL 解码，不含查询串和 #）。
 * - 不是离线包 origin → null（不归我们管，放行）
 * - 路径为空或以 / 结尾 → 补 index.html
 * 例：https://h5.offline.test/index.html?case=blank → index.html；https://h5.offline.test/img/%E5%9B%BE.png → img/图.png
 */
fun offlinePathOf(url: String): String? {
    // 空 M4-2：按上面的规则实现
    // 提示 1：先用 M4-1 判 origin；HttpUrl 的 pathSegments 是已经解码、按 / 切好的路径段（不含查询串），
    //        "https://h5.offline.test/" 的 pathSegments 是 [""]
    TODO("M4-2")
}

/** 离线包对一个请求的回答 */
class OfflineResponse(
    val status: Int,
    /** HTTP 原因短语，如 OK、Not Found。WebResourceResponse 要求不能为空 */
    val reason: String,
    val mime: String,
    val data: ByteArray,
    /** 要打的日志，null 表示不打 */
    val log: String?,
) {
    override fun toString() = "OfflineResponse($status $reason, $mime, ${data.size} bytes, log=$log)"
}

/** 404 的回答。log 里放完整的 url（带查询串）：排查时要知道是哪个页面、哪个版本请求的 */
fun notFound(url: String) = OfflineResponse(404, "Not Found", "text/plain", ByteArray(0), "$LOG_OFFLINE_404 $url")

/**
 * 决定离线包怎么回答这个请求。
 * - 不是离线包 origin → null（放行，交给网络）
 * - 路径里有 `..` 段（想跳出 h5 目录）→ 404，不去读文件
 * - read("h5/<path>") 返回 null（包里没有）→ 404
 * - 读到了 → 200，reason 为 OK，按扩展名给 MIME，不打日志
 * @param read 按 assets 里的路径读文件，没有返回 null。真实的实现在 H5Container 里（AssetManager.open），测试里是假的
 */
fun resolveOffline(url: String, read: (assetPath: String) -> ByteArray?): OfflineResponse? {
    // 空 M4-3：按上面的规则实现整个方法
    // 提示 1：路径来自 M4-2；404 用写好的 notFound(url)；read 的参数要带上 ASSET_DIR 前缀
    TODO("M4-3")
}
