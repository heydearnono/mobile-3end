package com.example.mobile3end.model

import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

enum class FileType { FOLDER, DOC, IMAGE, VIDEO }

data class FileItem(
    val id: String,
    val name: String,
    val type: FileType,
    /** 字节，文件夹为 0 */
    val size: Long,
    /** 秒级时间戳 */
    val mtime: Long,
)

enum class SortOrder(val label: String) {
    NAME("名称"),
    TIME("时间"),
}

/**
 * 文件夹永远排在前面；同类之间：
 * - NAME：按名称升序
 * - TIME：按修改时间倒序（新的在上）
 */
fun sortFiles(files: List<FileItem>, order: SortOrder): List<FileItem> {
    val folderFirst = compareBy<FileItem> { it.type != FileType.FOLDER }
    val byOrder: Comparator<FileItem> = when (order) {
        SortOrder.NAME -> compareBy { it.name }
        // 空 M1-1：按 mtime 倒序。提示 1：看看 compareBy 的兄弟函数
        // SortOrder.TIME -> TODO("M1-1")
        SortOrder.TIME -> compareByDescending { it.mtime }
    }
    return files.sortedWith(folderFirst.then(byOrder))
}

fun iconOf(type: FileType): String = when (type) {
    FileType.FOLDER -> "📁"
    FileType.DOC -> "📄"
    FileType.IMAGE -> "🖼️"
    FileType.VIDEO -> "🎬"
}

fun formatSize(bytes: Long): String {
    if (bytes < 1024) return "$bytes B"
    val units = listOf("KB", "MB", "GB")
    var value = bytes / 1024.0
    var i = 0
    while (value >= 1024 && i < units.lastIndex) {
        value /= 1024
        i++
    }
    return String.format(Locale.US, "%.1f %s", value, units[i])
}

// minSdk 24 不能直接用 java.time（API 26+），先用 SimpleDateFormat
fun formatTime(mtime: Long): String =
    SimpleDateFormat("yyyy-MM-dd HH:mm", Locale.getDefault()).format(Date(mtime * 1000))
