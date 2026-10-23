import SwiftUI
import WebKit

/// 全屏 H5 页
struct H5Screen: View {
    let initialCase: H5Case

    /// 注意不能写成 `@State private var controller = H5Controller()`：
    /// @State 的初始值表达式每次这个结构体被创建都会执行一遍（只是结果被丢掉），会反复 new WKWebView
    @State private var controller: H5Controller?
    @State private var currentCase: H5Case = .normal
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            if let controller {
                WebViewHost(webView: controller.webView)
                    .ignoresSafeArea(edges: .bottom)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if let controller { StatusStrip(page: controller.page, testCase: currentCase) }
        }
        .overlay(alignment: .bottom) {
            if let toast = controller?.page.toast {
                Text(toast)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.black.opacity(0.75), in: Capsule())
                    .foregroundStyle(.white)
                    .padding(.bottom, 40)
                    .accessibilityIdentifier("toast")
            }
        }
        .navigationTitle("H5")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu("用例") {
                    ForEach(H5Case.allCases) { c in
                        Button(c.title) { load(c) }
                    }
                    Divider()
                    Button("模拟渲染进程崩溃") { controller?.debugKillWebContentProcess() }
                    Button("重新加载") { controller?.webView.reload() }
                }
                .accessibilityIdentifier("h5-cases")
            }
        }
        .onAppear {
            M3ELog.d("H5Screen.onAppear")
            if controller == nil {
                controller = H5Controller()
                load(initialCase)
            }
        }
        .onDisappear { M3ELog.d("H5Screen.onDisappear") }
        .onChange(of: scenePhase) { _, phase in
            controller?.scenePhaseChanged(phase)
        }
    }

    private func load(_ c: H5Case) {
        currentCase = c
        controller?.load(c)
    }
}

private struct StatusStrip: View {
    let page: H5PageState
    let testCase: H5Case

    var body: some View {
        HStack {
            Text("case=\(testCase.rawValue)")
            Spacer()
            Text("OFFLINE_404 ×\(page.offline404Count)")
                .accessibilityIdentifier("offline-404")
            Text("白屏检测：\(page.detector.status)")
                .accessibilityIdentifier("wsd-status")
        }
        .font(.caption.monospaced())
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
    }
}

/// SwiftUI 没有 WebView 组件（iOS 26 才有），用 UIViewRepresentable 把 UIKit 的 WKWebView 包进来
private struct WebViewHost: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> WKWebView { webView }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
