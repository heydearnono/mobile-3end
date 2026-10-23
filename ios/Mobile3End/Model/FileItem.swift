import Foundation
import UIKit

enum FileType: String, Codable, CaseIterable, Sendable {
    case folder, doc, image, video
}

struct FileItem: Codable, Hashable, Identifiable, Sendable {
    // 有了名为 id 的属性，声明 Identifiable 就够了，List / ForEach 用它当 key
    let id: String
    let name: String
    let type: FileType
    /// 字节，文件夹为 0
    let size: Int64
    /// 秒级时间戳
    let mtime: Int64
}

enum SortOrder: String, CaseIterable, Sendable {
    case name, time

    var label: String {
        switch self {
        case .name: "名称"
        case .time: "时间"
        }
    }
}

/// 文件夹永远排在前面；同类之间：
/// - name：按名称升序
/// - time：按修改时间倒序（新的在上）
func sortFiles(_ files: [FileItem], _ order: SortOrder) -> [FileItem] {
    // 空 M1-1：实现上面的规则，结果要和 Android 版逐条一致（UI 测试依赖它）
    // 提示 1：Swift 没有 compareBy / then，sorted(by:) 要你自己写「a 是否该排在 b 前面」
    TODO("M1-1")
}

func iconOf(_ type: FileType) -> String {
    switch type {
    case .folder: "📁"
    case .doc: "📄"
    case .image: "🖼️"
    case .video: "🎬"
    }
}

func formatSize(_ bytes: Int64) -> String {
    if bytes < 1024 { return "\(bytes) B" }
    let units = ["KB", "MB", "GB"]
    var value = Double(bytes) / 1024
    var i = 0
    while value >= 1024 && i < units.count - 1 {
        value /= 1024
        i += 1
    }
    // String(format:) 不带 locale，小数点固定是「.」，和 Android 的 Locale.US 一致
    return String(format: "%.1f %@", value, units[i])
}

private let timeFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd HH:mm"
    return f
}()

func formatTime(_ mtime: Int64) -> String {
    timeFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(mtime)))
}
