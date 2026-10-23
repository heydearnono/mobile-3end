import SwiftUI

/// 列表页要显示的内容。M1 永远是 .loaded(SampleData.files)；M2 起来自 FileListModel
enum ListState: Equatable {
    case loading
    case failed(String)
    case loaded([FileItem])

    var files: [FileItem] {
        if case .loaded(let files) = self { return files }
        return []
    }
}

struct FileListScreen: View {
    let state: ListState
    /// @Binding：状态的主人在父视图（M1 是 RootView 的 @State，M2 起是 FileListModel），这里只是借来读写
    /// 类比 Vue 的 v-model：props + emit('update:order') 合成一个
    @Binding var order: SortOrder
    var onOpen: (FileItem) -> Void
    var onRetry: () -> Void = {}

    var body: some View {
        content
            .navigationTitle("我的文件")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("排序：\(order.label)") { toggleOrder() }
                        .accessibilityIdentifier("sort")
                }
            }
            .onAppear { M3ELog.d("FileListScreen.onAppear") }
            .onDisappear { M3ELog.d("FileListScreen.onDisappear") }
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .loading:
            ProgressView("加载中…")
                .accessibilityIdentifier("loading")
        case .failed(let message):
            VStack(spacing: 12) {
                Text("加载失败").font(.headline)
                Text(message).font(.footnote).foregroundStyle(.secondary)
                Button("重试", action: onRetry)
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("retry")
            }
            .padding()
        case .loaded(let files) where files.isEmpty:
            ContentUnavailableView("没有文件", systemImage: "tray")
                .accessibilityIdentifier("empty")
        case .loaded(let files):
            List(sorted(files)) { file in
                Button { onOpen(file) } label: { FileRow(file: file) }
                    .foregroundStyle(.primary)
            }
            .listStyle(.plain)
            .accessibilityIdentifier("file-list")
        }
    }

    // 空 M1-2：点排序按钮，在「名称 / 时间」之间切换
    // 提示 1：order 是 @Binding，直接赋值就会写回父视图的状态
    private func toggleOrder() {
        TODO("M1-2")
    }

    // 空 M1-3：返回排好序的列表
    // 提示 1：SwiftUI 没有 remember(key)，body 每次执行都会调到这里
    private func sorted(_ files: [FileItem]) -> [FileItem] {
        TODO("M1-3")
    }
}

private struct FileRow: View {
    let file: FileItem

    var body: some View {
        HStack(spacing: 12) {
            Text(iconOf(file.type)).font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                Text(file.size > 0 ? "\(formatSize(file.size)) · \(formatTime(file.mtime))" : formatTime(file.mtime))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct FileDetailScreen: View {
    let file: FileItem?
    /// 系统注入的「关掉当前页」动作，push 进来的页就是 pop，sheet 弹出的就是收起
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            if let file {
                Text("\(iconOf(file.type)) \(file.name)")
                    .font(.headline)
                    .accessibilityIdentifier("detail-name")
                LabeledContent("id", value: file.id)
                LabeledContent("类型", value: file.type.rawValue)
                LabeledContent("大小", value: file.size > 0 ? formatSize(file.size) : "—")
                LabeledContent("修改时间", value: formatTime(file.mtime))
            } else {
                Text("文件不存在").accessibilityIdentifier("detail-name")
            }
        }
        .navigationTitle("详情")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("返回列表") { back() }
                    .accessibilityIdentifier("back")
            }
        }
        .onAppear { M3ELog.d("FileDetailScreen.onAppear id=\(file?.id ?? "nil")") }
        .onDisappear { M3ELog.d("FileDetailScreen.onDisappear id=\(file?.id ?? "nil")") }
    }

    // 空 M1-6：返回列表页（左上角系统自带的返回按钮不用管，这里是自己加的按钮）
    // 提示 1：这个页面不知道 NavigationStack 的 path，但上面有个 @Environment 拿到的东西
    private func back() {
        TODO("M1-6")
    }
}
