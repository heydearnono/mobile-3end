/// M1 用的写死数据，M2 会换成网络请求。和 Android 的 SampleData.kt 逐条一致，UI 测试依赖这里的名称和排序结果
enum SampleData {
    static let files: [FileItem] = [
        FileItem(id: "d1", name: "工作资料", type: .folder, size: 0, mtime: 1760500000),
        FileItem(id: "d2", name: "照片备份", type: .folder, size: 0, mtime: 1760400000),
        FileItem(id: "d3", name: "设计稿导出", type: .folder, size: 0, mtime: 1760100000),
        FileItem(id: "f01", name: "季度复盘.docx", type: .doc, size: 482133, mtime: 1760830000),
        FileItem(id: "f02", name: "需求评审纪要.pdf", type: .doc, size: 1250331, mtime: 1760750000),
        FileItem(id: "f03", name: "白屏率看板截图.png", type: .image, size: 356210, mtime: 1760860000),
        FileItem(id: "f04", name: "团建合影.jpg", type: .image, size: 4821990, mtime: 1759200000),
        FileItem(id: "f05", name: "发布会录屏.mp4", type: .video, size: 268435456, mtime: 1758900000),
        FileItem(id: "f06", name: "接口文档.md", type: .doc, size: 18320, mtime: 1760600000),
        FileItem(id: "f07", name: "旅行vlog.mov", type: .video, size: 734003200, mtime: 1757000000),
        FileItem(id: "f08", name: "截图_2026-10-01.png", type: .image, size: 212004, mtime: 1759300000),
        FileItem(id: "f09", name: "周报模板.xlsx", type: .doc, size: 66012, mtime: 1756000000),
        FileItem(id: "f10", name: "Android学习笔记.md", type: .doc, size: 9120, mtime: 1760870000),
        FileItem(id: "f11", name: "README.txt", type: .doc, size: 1024, mtime: 1760200000),
        FileItem(id: "f12", name: "budget-2026.xlsx", type: .doc, size: 40960, mtime: 1755000000),
        FileItem(id: "f13", name: "合同扫描件.pdf", type: .doc, size: 3355443, mtime: 1758000000),
        FileItem(id: "f14", name: "猫.heic", type: .image, size: 2097152, mtime: 1759900000),
        FileItem(id: "f15", name: "会议录音.m4a", type: .video, size: 15728640, mtime: 1757500000),
        FileItem(id: "f16", name: "Demo演示.mp4", type: .video, size: 52428800, mtime: 1752000000),
        FileItem(id: "f17", name: "离线包说明.md", type: .doc, size: 5120, mtime: 1760700000),
    ]

    static func find(_ id: String?) -> FileItem? { files.first { $0.id == id } }
}
