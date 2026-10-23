package com.example.mobile3end.k1

import com.example.mobile3end.model.FileItem
import com.example.mobile3end.model.iconOf

// K1 第 3 节：尾随 lambda 和作用域函数
//
// 函数的最后一个参数是函数时，可以把 lambda 写在括号外面；只有这一个参数时括号也能省：
//   withContext(io, { ... })  →  withContext(io) { ... }
//   files.map({ it.name })    →  files.map { it.name }
// 所以 use { }、withContext { }、remember { }、Column { } 看着像关键字，其实全是普通函数调用。
//
// 「带接收者的 lambda」：lambda 里的 this 是某个对象，调它的方法可以省掉 this.
//   buildString { append("a") }   这里的 this 是 StringBuilder
//   Column { Text("a") }          Compose 的 DSL 就是这么写出来的
//
// 标准库的作用域函数（都在 Kotlin 自带的 Standard.kt 里，不是语法）：
//   x.let { it ... }    返回 lambda 的结果，常配合 ?. 用：x?.let { ... } 只在非空时执行
//   x.also { it ... }   返回 x 本身，用来顺手做点事（打日志）
//   x.apply { this ... } 返回 x 本身，用来配置对象
//   x.use { it ... }    返回 lambda 的结果，结束时自动 close（M2-2 的 Response）

// 空 K1-7：自己写一个「高阶函数」：执行 block 前往 logs 里加 "start <name>"，结束后加 "end <name>"，返回 block 的结果
// block 抛异常时也要加 "end <name>"，异常照常往外抛
// 写完看测试是怎么调用它的：withLog(logs, "x") { 42 }，和 withContext(io) { ... } 是同一种语法
// 提示 1：try { return block() } finally { ... }
fun <T> withLog(logs: MutableList<String>, name: String, block: () -> T): T {
    // 批注 K1-7 ✅：finally 保证异常时也打 end，return block() 会先跑完 finally 再返回
    //   小点：start 放在 try 外面语义更准（start 都没加成功时不该补 end），这里结果一样
    //   logs.add(x) 和 logs += x 等价，+= 是 Kotlin 的运算符重载（plusAssign）
    try {
        logs.add("start $name")
        return block()
    } finally {
        logs.add("end $name")
    }
}

// 空 K1-8：每个文件一行「图标 + 空格 + 名称」，每行以 \n 结尾
// 要求：用 buildString { }，在里面直接调 appendLine（不写 this.）
// 提示 1：buildString { files.forEach { file -> appendLine(...) } }
fun summary(files: List<FileItem>): String =
    buildString {
        files.forEach { file ->
            // 批注 K1-8 ❌ 编译失败：Unresolved reference 'iconOf'
            //   iconOf 定义是 fun iconOf(type: FileType)（model/FileItem.kt），是普通函数，不是 FileItem 的扩展函数
            //   所以只能 iconOf(file.type)，不能 file.iconOf()。import 已经有了，缺的不是 import
            //   对照第 5 节：只有写成 fun FileItem.xxx() 的才能 file.xxx() 调用，比如你写的 K1-12 isMedia()
            //   buildString { } 里直接 appendLine（this 是 StringBuilder）这部分是对的
            appendLine("${file.iconOf()} ${file.name}")
        }
    }

// 空 K1-9：把秒级时间戳字符串转成毫秒。raw 是 null 或不是数字，返回 null
// 提示 1：raw?.toLongOrNull()?.let { ... }
fun parseMtimeMs(raw: String?): Long? =
    // 批注 K1-9 ✅
    raw?.toLongOrNull()?.let { it * 1000 }
