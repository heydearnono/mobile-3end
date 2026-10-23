package com.example.mobile3end.data

import com.example.mobile3end.model.FileItem
import com.example.mobile3end.model.FileType
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

/**
 * 接口 / 缓存里的 JSON 长这样（见 spec 公共约定）：
 * `{ "files": [ { "id", "name", "type", "size", "mtime" } ] }`
 *
 * DTO 和 UI 用的 FileItem 分开：接口字段是字符串 type，UI 要的是枚举。
 * 类比 FE 里 API 返回值先过一层 adapter 再进 store
 */
@Serializable
data class FileDto(
    val id: String,
    val name: String,
    val type: String,
    val size: Long,
    val mtime: Long,
)

@Serializable
data class FilesResponse(val files: List<FileDto>)

/** 全工程共用一份配置：接口多给的字段忽略，不报错 */
val AppJson = Json { ignoreUnknownKeys = true }

fun FileItem.toDto() = FileDto(id, name, type.name.lowercase(), size, mtime)

// 空 M2-1：把接口返回的 JSON 字符串解析成 List<FileItem>
// - type 是小写字符串（"folder" / "doc" / "image" / "video"），认不出来的当 DOC，不能整体失败
// - JSON 本身坏了（不是合法 JSON、缺字段）就直接抛异常，交给调用方处理
// 提示 1：AppJson.decodeFromString<FilesResponse>(json)，再把每个 FileDto 转成 FileItem
fun parseFiles(json: String): List<FileItem> {
    val response = AppJson.decodeFromString<FilesResponse>(json)
    return response.files.map { dto ->
        val type = when (dto.type) {
            "folder" -> FileType.FOLDER
            "doc"    -> FileType.DOC
            "image"  -> FileType.IMAGE
            "video"  -> FileType.VIDEO
            else     -> FileType.DOC   // 认不出来的当 DOC
        }
        FileItem(
            id = dto.id,
            name = dto.name,
            type = type,
            size = dto.size,
            mtime = dto.mtime,
        )
    }
}

fun encodeFiles(files: List<FileItem>): String =
    AppJson.encodeToString(FilesResponse(files.map { it.toDto() }))
