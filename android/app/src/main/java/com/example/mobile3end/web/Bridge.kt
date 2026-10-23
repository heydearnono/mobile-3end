package com.example.mobile3end.web

import android.webkit.JavascriptInterface
import com.example.mobile3end.data.AppJson
import kotlinx.serialization.SerializationException
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

/*
 * JSBridge，协议见 spec.md「JSBridge 协议」：
 * - H5 → Native：window.NativeBridge.postMessage('{"id":"1","method":"getDeviceInfo","params":{}}')
 * - Native → H5：evaluateJavascript("window.__bridgeCallback({...})") / window.__bridgeEvent({...})
 *
 * 分三层，前两层是纯逻辑，JVM 单测覆盖：
 * - BridgeDispatcher：消息字符串 + 页面 URL → 要执行的 JS（M4-5）
 * - NativeBridgeInterface：注册给 H5 的对象，负责线程切换（M4-6）
 * - H5Container：addJavascriptInterface、evaluateJavascript 的胶水
 */

const val BRIDGE_NAME = "NativeBridge"
const val ERR_METHOD_NOT_FOUND = "METHOD_NOT_FOUND"

data class DeviceInfo(val platform: String, val osVersion: String, val appVersion: String) {
    fun toJson(): JsonObject = buildJsonObject {
        put("platform", platform)
        put("osVersion", osVersion)
        put("appVersion", appVersion)
    }
}

/**
 * 拼 Native → H5 要执行的 JS。JsonObject.toString() 就是转义好的 JSON，JSON 又是合法的 JS 对象字面量，直接拼进去。
 * 对比 K1-11 的 toJs：那里是手拼字符串、不转义，文案里有个 " 就坏了
 */
object BridgeJs {
    fun ok(id: String, data: JsonObject): String = call("__bridgeCallback", buildJsonObject {
        put("id", id)
        put("ok", true)
        put("data", data)
    })

    fun error(id: String, code: String, message: String): String = call("__bridgeCallback", buildJsonObject {
        put("id", id)
        put("ok", false)
        put("error", buildJsonObject {
            put("code", code)
            put("message", message)
        })
    })

    fun event(name: String, data: JsonObject): String = call("__bridgeEvent", buildJsonObject {
        put("event", name)
        put("data", data)
    })

    private fun call(function: String, payload: JsonObject) = "window.$function($payload)"
}

/** 取 JSON 对象里的字符串字段：没有这个字段、或者不是字符串（数字、对象、null）都返回 null */
fun JsonObject.string(key: String): String? =
    (get(key) as? JsonPrimitive)?.takeIf { it.isString }?.content

/** 消息字符串 → JsonObject。不是合法 JSON、或者不是对象（"null"、"[]"、"1"）返回 null */
fun parseJsonObject(raw: String): JsonObject? =
    try {
        AppJson.parseToJsonElement(raw) as? JsonObject
    } catch (e: SerializationException) {
        null
    }

/** appState 事件的 data */
fun appStateData(state: String): JsonObject = buildJsonObject { put("state", state) }

// 空 M4-7：App 前后台变化时，要给 H5 执行的 JS（推 appState 事件），null 表示不推
// - state 为 null（还不知道前后台）不推
// - 当前页面不是离线包（包括 null）不推：别的页面没有 __bridgeEvent，也不该知道 App 的状态
// - 否则用 BridgeJs.event 拼 appState 事件，data 是 appStateData(state)
// 提示 1：两个条件可以写进一个 if，也可以用 ?: return null
fun appStateJs(state: String?, pageUrl: String?): String? {
    TODO("M4-7")
}

/**
 * bridge 分发：输入「消息字符串 + 处理消息时主文档的 URL」，输出「要执行的 JS」（null 表示不回）。
 * 不碰 WebView，所以能在 JVM 上测
 */
class BridgeDispatcher(
    private val deviceInfo: () -> DeviceInfo,
    private val toast: (String) -> Unit,
    private val log: (String) -> Unit,
) {
    /**
     * - 页面不是离线包 origin（包括 null）→ 打日志「[BRIDGE] 忽略来自 <pageUrl> 的消息」，返回 null。先校验来源，再碰消息内容
     * - 不是 JSON 对象、或没有字符串类型的 id → 打日志，返回 null（没法回，H5 那边会等到超时）
     * - getDeviceInfo → ok，data 为 deviceInfo().toJson()
     * - toast → 调 toast(params.text)，text 没有或不是字符串时用空串；ok，data 为 {}
     * - 其他（包括没有 method）→ error，code 为 METHOD_NOT_FOUND，message 里带上方法名
     */
    fun handle(raw: String, pageUrl: String?): String? {
        // 空 M4-5：按上面的规则实现整个方法
        // 提示 1：来源用 M4-1 判；写好的 parseJsonObject、JsonObject.string(key) 直接用；params 本身也可能没有或不是对象
        TODO("M4-5")
    }
}

/**
 * 注册给 H5 的对象：webView.addJavascriptInterface(this, "NativeBridge")。
 * H5 里 window.NativeBridge.postMessage(str) 会调到下面的 postMessage：
 * - 只有加了 @JavascriptInterface 的 public 方法 H5 才看得见（Android 4.2 之前没有这个注解，所有 public 方法都暴露，是著名的远程代码执行漏洞）
 * - 参数只能是基本类型和 String，所以协议统一传 JSON 字符串
 * - 它跑在 WebView 自己的「JavaBridge」线程上，不是主线程
 *
 * @param mainThread 把任务丢到主线程执行。实际传的是主线程 Handler 的 post
 * @param currentUrl 当前主文档的 URL。实际是 webView.url，只能在主线程调
 * @param evaluate 执行 JS。实际是 webView.evaluateJavascript(js, null)，只能在主线程调
 */
class NativeBridgeInterface(
    private val mainThread: (task: () -> Unit) -> Unit,
    private val currentUrl: () -> String?,
    private val dispatcher: BridgeDispatcher,
    private val evaluate: (String) -> Unit,
) {
    // 空 M4-6：把消息交给 dispatcher（带上当前页面 URL），有返回的 JS 就执行回去
    // webView.url、evaluateJavascript、弹 Toast 都只能在主线程做，而这个方法被调用时在 JavaBridge 线程上
    // 提示 1：mainThread { ... }，要做的事全放进去；lambda 里提前结束用 return@mainThread
    @JavascriptInterface
    fun postMessage(message: String) {
        TODO("M4-6")
    }
}
