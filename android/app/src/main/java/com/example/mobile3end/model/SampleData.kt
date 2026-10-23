package com.example.mobile3end.model

/** M1 用的写死数据，M2 会换成网络请求。UI 测试依赖这里的名称和排序结果，改动后要同步改测试 */
object SampleData {
    val files: List<FileItem> = listOf(
        FileItem("d1", "工作资料", FileType.FOLDER, 0, 1760500000),
        FileItem("d2", "照片备份", FileType.FOLDER, 0, 1760400000),
        FileItem("d3", "设计稿导出", FileType.FOLDER, 0, 1760100000),
        FileItem("f01", "季度复盘.docx", FileType.DOC, 482133, 1760830000),
        FileItem("f02", "需求评审纪要.pdf", FileType.DOC, 1250331, 1760750000),
        FileItem("f03", "白屏率看板截图.png", FileType.IMAGE, 356210, 1760860000),
        FileItem("f04", "团建合影.jpg", FileType.IMAGE, 4821990, 1759200000),
        FileItem("f05", "发布会录屏.mp4", FileType.VIDEO, 268435456, 1758900000),
        FileItem("f06", "接口文档.md", FileType.DOC, 18320, 1760600000),
        FileItem("f07", "旅行vlog.mov", FileType.VIDEO, 734003200, 1757000000),
        FileItem("f08", "截图_2026-10-01.png", FileType.IMAGE, 212004, 1759300000),
        FileItem("f09", "周报模板.xlsx", FileType.DOC, 66012, 1756000000),
        FileItem("f10", "Android学习笔记.md", FileType.DOC, 9120, 1760870000),
        FileItem("f11", "README.txt", FileType.DOC, 1024, 1760200000),
        FileItem("f12", "budget-2026.xlsx", FileType.DOC, 40960, 1755000000),
        FileItem("f13", "合同扫描件.pdf", FileType.DOC, 3355443, 1758000000),
        FileItem("f14", "猫.heic", FileType.IMAGE, 2097152, 1759900000),
        FileItem("f15", "会议录音.m4a", FileType.VIDEO, 15728640, 1757500000),
        FileItem("f16", "Demo演示.mp4", FileType.VIDEO, 52428800, 1752000000),
        FileItem("f17", "离线包说明.md", FileType.DOC, 5120, 1760700000),
    )

    fun find(id: String?): FileItem? = files.firstOrNull { it.id == id }
}
