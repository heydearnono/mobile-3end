package com.example.mobile3end.k1

import com.example.mobile3end.data.parseFiles
import com.example.mobile3end.model.FileItem
import com.example.mobile3end.model.formatSize
import com.example.mobile3end.model.iconOf
import kotlinx.serialization.SerializationException

// K1 第 1 节：表达式 vs 语句
//
// TS 里 if / switch / try 都是「语句」，不产生值；Kotlin 里它们都是「表达式」，能直接赋值、直接 return。
// 函数有两种写法：
//   fun f(): Int { return 1 }   块函数体：必须写 return（M2-2 的 Missing return statement 就是这个）
//   fun f(): Int = 1            表达式函数体：= 后面的值就是返回值，类比 TS 的 () => 1
// lambda 永远是「最后一个表达式就是返回值」，里面不写 return，类比 TS 的 () => { ...; return x } 但省掉 return

// 空 K1-1：按字节数给大小文案。0 → "—"；小于 1024 → "<n> B"；其他 → formatSize(bytes)
// 要求：用表达式函数体（= 开头）+ when 表达式，不写 return
// 提示 1：when { 条件 -> 值 ... else -> 值 }，when 后面可以不带参数
fun sizeLabel(bytes: Long): String =
    // 批注 K1-1 ✅：表达式函数体 + 无参 when，0L 写对了（bytes 是 Long，写 0 会类型不匹配）
    when {
        bytes == 0L -> "—"
        bytes < 1024 -> "$bytes B"
        else -> formatSize(bytes)
    }

// 空 K1-2：解析 JSON，格式坏了返回 null 而不是抛异常
// 要求：块函数体里只写一行 return，把 try / catch 整个当成值
// 提示 1：return try { ... } catch (e: SerializationException) { ... }
fun parseOrNull(json: String): List<FileItem>? {
    // 批注 K1-2 ✅：try 整体当值 return。也可以改成表达式函数体：fun parseOrNull(json: String) = try { ... } catch ...
    return try {
        parseFiles(json)
    } catch (e: SerializationException) {
        null
    }
}

// 空 K1-3：一个 lambda，把文件变成「图标 + 空格 + 名称」，如 "📁 工作资料"
// 要求：lambda 里先用 val 存图标，再拼字符串。注意 lambda 里不能写 return
// 提示 1：{ file -> 第一行; 第二行就是返回值 }
val describe: (FileItem) -> String = { file ->
    // 批注 K1-3 ✅：lambda 最后一行就是返回值，没写 return，正好是 M2-2 卡住的那个点的反面
    val icon = iconOf(file.type)
    "$icon ${file.name}"
}
