import XCTest
@testable import Mobile3End

/// M1 纯逻辑检查。方法名前缀 = 覆盖的空（XCTest 要求以 test 开头）
@MainActor
final class M1LogicTests: XCTestCase {

    private let input = [
        item("a", "a.txt", .doc, mtime: 10),
        item("F1", "F1", .folder, mtime: 1),
        item("b", "b.txt", .doc, mtime: 30),
        item("c", "c.png", .image, mtime: 20),
        item("F2", "F2", .folder, mtime: 5),
    ]

    private func ids(_ list: [FileItem]) -> [String] { list.map(\.id) }

    func test_m1_1_nameOrder_foldersFirst() async {
        XCTAssertEqual(ids(sortFiles(input, .name)), ["F1", "F2", "a", "b", "c"])
    }

    func test_m1_1_timeOrder_newestFirst_foldersStillOnTop() async {
        XCTAssertEqual(ids(sortFiles(input, .time)), ["F2", "F1", "b", "c", "a"])
    }

    func test_m1_1_sampleData_sameAsAndroid() async {
        // 和 Android 的排序结果逐条对齐：大写字母 < 小写字母 < 汉字（按 Unicode 码位，不是拼音）
        let byName = sortFiles(SampleData.files, .name).map(\.name)
        XCTAssertEqual(Array(byName.prefix(8)), [
            "工作资料", "照片备份", "设计稿导出",
            "Android学习笔记.md", "Demo演示.mp4", "README.txt", "budget-2026.xlsx", "会议录音.m4a",
        ])
        XCTAssertEqual(byName.last, "需求评审纪要.pdf")

        let byTime = sortFiles(SampleData.files, .time).map(\.name)
        XCTAssertEqual(Array(byTime.prefix(5)), ["工作资料", "照片备份", "设计稿导出", "Android学习笔记.md", "白屏率看板截图.png"])
        XCTAssertEqual(byTime.last, "Demo演示.mp4")
    }

    func test_m1_0_formatters_givenAsExample() async {
        XCTAssertEqual(formatSize(1023), "1023 B")
        XCTAssertEqual(formatSize(482133), "470.8 KB")
        XCTAssertEqual(formatSize(734003200), "700.0 MB")
        XCTAssertEqual(iconOf(.folder), "📁")
    }
}
