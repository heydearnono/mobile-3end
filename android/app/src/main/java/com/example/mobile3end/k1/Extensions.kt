package com.example.mobile3end.k1

import com.example.mobile3end.model.FileItem
import com.example.mobile3end.model.FileType

// K1 第 5 节：扩展函数和扩展属性
//
// 给别人的类「加」方法，不用继承、不改源码：
//   fun String.shout() = uppercase() + "!"     之后 "hi".shout() 就能用；函数体里的 this 是那个 String
// 本质是静态函数的语法糖，编译后就是 shout(receiver: String)，不能访问 private 成员
// ≈ TS 里没有对应物，最接近的是往 prototype 上挂方法，但扩展函数不会污染全局，要 import 才能用
//
// M2 里见过的：Context.settingsDataStore（扩展属性）、FileItem.toDto()（扩展函数）

// 空 K1-12：图片和视频算「媒体」
// 提示 1：type in setOf(...)；in 就是调用 contains
fun FileItem.isMedia(): Boolean =
    // 批注 K1-12 ✅：type 就是 this.type，in 就是 contains
    type in setOf(FileType.IMAGE, FileType.VIDEO)

// 空 K1-13：列表里所有文件大小之和
// 扩展属性不能存值，只能写 get()，每次访问都现算
// 提示 1：this 是这个 List，sumOf { ... }
val List<FileItem>.totalSize: Long
    get() {
        // 批注 K1-13 ✅：也可以写成 val List<FileItem>.totalSize: Long get() = sumOf { it.size }
        return sumOf { it.size }
    }
