import Foundation

/// 列表缓存：整份 [FileItem] 存成一个 JSON 文件
struct FileCache {
    let fileURL: URL
    var log: (String) -> Void = M3ELog.d

    /// Caches 目录：不进 iCloud 备份，空间紧张时系统可能清掉，正适合「丢了也能重新拉」的数据
    static let standard = FileCache(
        fileURL: URL.cachesDirectory.appending(path: "files-cache.json")
    )

    // 空 M2-4：把列表编码成 JSON 写进 fileURL；失败只打日志，不抛给调用方
    // 提示 1：JSONEncoder + Data.write(to:options:)，想想写到一半 App 被杀会怎样
    func save(_ files: [FileItem]) {
        TODO("M2-4")
    }

    // 空 M2-5：读缓存。文件不存在、内容损坏都返回 nil
    // 提示 1：Data(contentsOf:) 和 JSONDecoder 都会 throw，try? 能把错误变成 nil
    func load() -> [FileItem]? {
        TODO("M2-5")
    }

    func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}

/// 排序选择持久化。UserDefaults ≈ localStorage：同步 API、存小量 KV、App 删除时一起删
struct SortStore {
    static let key = "sortOrder"
    let defaults: UserDefaults

    // 空 M2-6：读写排序选择。没存过或存的值认不出来时返回 .name
    // 提示 1：存 rawValue 字符串；SortOrder(rawValue:) 返回的是可选值
    var order: SortOrder {
        get {
            TODO("M2-6")
        }
        nonmutating set {
            TODO("M2-6")
        }
    }
}
