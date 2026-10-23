package com.example.mobile3end.k1

import com.example.mobile3end.model.FileItem

// K1 第 4 节：data class 和 sealed
//
// data class 自动生成 equals / hashCode / toString / copy：
//   - == 比较的是字段值（TS 的 === 比的是引用，Kotlin 比引用要写 ===）
//   - copy(name = "x") 生成一个只改了 name 的新对象，原对象不变 ≈ TS 的 { ...file, name: "x" }
//   - 调用时可以写参数名：copy(name = ...)，叫命名参数，可以跳过有默认值的参数
//
// sealed interface：子类只能写在同一个包里，编译器知道一共有哪几种。
// when 判断它时写全了所有子类就不用 else，以后加一种新的，所有没处理的 when 都会编译报错
// ≈ TS 的可辨识联合 type R = { kind: 'ok' } | { kind: 'err' } + switch 里 never 兜底

// 空 K1-10：返回一个改了名字的新文件，其他字段不变
// 提示 1：data class 自带的那个方法，配合命名参数
fun rename(file: FileItem, newName: String): FileItem =
    // 批注 K1-10 ✅：copy + 命名参数，原对象不变
    file.copy(name = newName)

/** JSBridge 的处理结果，M4 会用到同样的结构（见 spec 的 JSBridge 协议） */
sealed interface BridgeResult {
    /** dataJson 是已经序列化好的 JSON 字符串，原样拼进去 */
    data class Ok(val dataJson: String) : BridgeResult
    data class Err(val code: String, val message: String) : BridgeResult
}

// 空 K1-11：拼出 Native 回调 H5 的 JS 字符串（只拼字符串，不考虑转义）
// - Ok：window.__bridgeCallback({"id":"<id>","ok":true,"data":<dataJson>})
// - Err：window.__bridgeCallback({"id":"<id>","ok":false,"error":{"code":"<code>","message":"<message>"}})
// 要求：when (result) 不写 else
// 提示 1：字符串模板 "$id"、"${result.code}"；字符串里的 " 要写成 \"；is 分支里 result 已经 smart cast 了
fun toJs(id: String, result: BridgeResult): String {
    // 批注 K1-11 ✅：when 当值 return，没写 else，两个分支都 smart cast 了
    //   可以再收一收：两个分支都重复了 window.__bridgeCallback(...)，先用 when 算出 body，再拼外层，改协议时只改一处
    //   分支只有一个表达式时 { } 可以省：is BridgeResult.Ok -> "..."
    return when (result) {
        is BridgeResult.Ok -> {
            "window.__bridgeCallback({\"id\":\"$id\",\"ok\":true,\"data\":${result.dataJson}})"
        }
        is BridgeResult.Err -> {
            "window.__bridgeCallback({\"id\":\"$id\",\"ok\":false,\"error\":{\"code\":\"${result.code}\",\"message\":\"${result.message}\"}})"
        }
    }
}
