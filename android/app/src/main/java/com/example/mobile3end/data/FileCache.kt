package com.example.mobile3end.data

import android.util.Log
import com.example.mobile3end.TAG
import com.example.mobile3end.model.FileItem
import java.io.File

/** 本地缓存放哪。测试里换成内存版 */
interface LocalFiles {
    fun load(): List<FileItem>?
    fun save(files: List<FileItem>)
}

/**
 * 列表缓存：整份 JSON 存成一个文件。位置用 context.filesDir（App 私有目录，卸载即删，不需要权限），
 * 和线上 App 的离线包解压后放的地方是同一类目录
 */
class FileCache(
    private val file: File,
    private val log: (String) -> Unit = { Log.d(TAG, it) },
) : LocalFiles {

    // 空 M2-3：把列表写进 file，格式和接口一致（encodeFiles 已经写好）
    // 写到一半进程被杀，文件就只剩半截。先写临时文件，写完再改名，改名是原子的
    // 提示 1：File.writeText / File.renameTo；临时文件放在同一个目录下
    override fun save(files: List<FileItem>) {
        val tmp = File(file.parentFile, file.name + ".tmp")
        tmp.writeText(encodeFiles(files))
        if (!tmp.renameTo(file)) {
            tmp.delete()
            log("缓存写入失败：$file")
            return
        }
        log("缓存已写入 ${files.size} 条")
    }

    // 空 M2-4：读缓存。没有文件返回 null；文件坏了（解析失败）也返回 null 并打日志，不能让 App 崩
    // 提示 1：file.exists()；runCatching { ... }.getOrNull()，或者 try / catch
    override fun load(): List<FileItem>? {
        if (!file.exists()) return null
        return runCatching {
            parseFiles(file.readText())
        }.onFailure { e ->
            log("读缓存失败：${e.message}")
        }.getOrNull()
    }
}
