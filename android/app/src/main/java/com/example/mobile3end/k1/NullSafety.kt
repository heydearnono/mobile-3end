package com.example.mobile3end.k1

import com.example.mobile3end.data.ListUiState
import com.example.mobile3end.model.FileItem
import com.example.mobile3end.model.FileType

// K1 第 2 节：空安全
//
// 类型后面带 ? 才能是 null：String 一定不是 null，String? 可能是。编译器会逼你处理 String?
//   a?.b        a 是 null 就整体得 null，否则取 a.b         ≈ TS 的 a?.b
//   a ?: b      a 是 null 就用 b（Elvis 运算符）             ≈ TS 的 a ?? b
//   a!!         断言不是 null，是 null 就抛 NPE              ≈ TS 的 a!，但 TS 只骗编译器，Kotlin 运行时真会崩
//   a as? T     能转就转，转不了得 null                       ≈ TS 没有，类似 a instanceof T ? a : null
// 判断过 a is T / a != null 之后，后面的代码里 a 自动当 T / 非空用，叫 smart cast ≈ TS 的类型收窄
//
// 原则：能用 ?. 和 ?: 就不用 !!。M2-2 的 response.body!! 就属于多余（body 的类型本来就不是可空的）

// 空 K1-4：file 为 null 时返回「文件不存在」，否则返回文件名
// 要求：一个表达式，不用 if
// 提示 1：?. 和 ?: 连用
fun displayName(file: FileItem?): String =
    // 批注 K1-4 ✅
    file?.name ?: "文件不存在"

// 空 K1-5：第一个图片的大小；列表是 null、或者里面没有图片，都返回 0
// 提示 1：files?.firstOrNull { ... }?.size ?: 0，一路 ?. 下去
fun firstImageSize(files: List<FileItem>?): Long =
    // 批注 K1-5 ✅：firstOrNull 后面也接了 ?.，链上每一环都处理了 null
    files?.firstOrNull { it.type == FileType.IMAGE }?.size ?: 0

// 空 K1-6：失败态返回错误文案，其他状态返回 null
// 提示 1：两种写法都行：if (state is ...) state.message else null；或者 (state as? ...)?.message
fun failedMessage(state: ListUiState): String? =
    // 批注 K1-6 ❌ 编译失败：Unresolved reference 'Error'
    //   ListUiState 只有 Loading / Failed / Loaded 三个子类（定义在 data/FileListLoader.kt），没有 Error
    //   思路（is 判断 → smart cast → 取 message）是对的，只是类名记错了
    //   习惯：打 `ListUiState.` 等补全列出来，或 ⌘ 点 ListUiState 跳到定义看。sealed 的好处之一就是子类能全列出来
    if (state is ListUiState.Error) state.message else null
