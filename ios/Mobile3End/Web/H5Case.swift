import Foundation

/// H5 页的测试用例，对应 spec「H5 测试用例」，外加几个 iOS 上值得看的场景。H5 页右上角「用例」菜单切换
enum H5Case: String, CaseIterable, Identifiable {
    case normal
    case blank
    case missing
    case slow
    /// Android / 鸿蒙的离线包地址。iOS 拦不了 https，看看会发生什么
    case androidURL = "android-url"
    /// 真实外网页面，需要联网
    case external
    /// 不联网的「外部页面」：loadHTMLString 以 https://evil.test 为 origin 加载一段内联 HTML，检查 bridge 有没有暴露
    case foreign
    /// 内联页面，0.5s 后才渲染：检测太早（不等 1s）就会误报
    case delayed


    var id: String { rawValue }

    var title: String {
        switch self {
        case .normal: "正常"
        case .blank: "blank：挂载前抛异常"
        case .missing: "missing：引用不存在的 js"
        case .slow: "slow：3s 后才渲染"
        case .androidURL: "Android 的离线包地址"
        case .external: "外部页面 example.com"
        case .foreign: "外部页面（内联，evil.test）"
        case .delayed: "0.5s 后才渲染（内联）"
        }
    }

    var url: URL {
        switch self {
        case .normal: OfflinePackage.entryURL
        case .blank, .missing, .slow: URL(string: "appoffline://h5/index.html?case=\(rawValue)")!
        case .androidURL: URL(string: "https://h5.offline.test/index.html")!
        case .external: URL(string: "https://example.com/")!
        case .foreign: URL(string: "https://evil.test/")!
        case .delayed: URL(string: "appoffline://h5/delayed.html")!
        }
    }

    /// .delayed 用的内联页面：和离线包同 origin，0.5s 后往 #app 里塞内容
    static let delayedHTML = """
    <!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
    <body><div id="app"></div>
    <script>setTimeout(function () { document.getElementById('app').innerHTML = '<h1>0.5s 后渲染完成</h1>'; }, 500);</script>
    </body></html>
    """

    /// .foreign 用的内联页面：页面上显示 bridge 是否暴露、是否响应
    static let foreignHTML = """
    <!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
    <body><div id="app"><h1>外部页面 evil.test</h1><p id="r">bridge: …</p></div>
    <script>
      var r = document.getElementById('r');
      var h = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.NativeBridge;
      if (!h) {
        r.textContent = 'bridge: none';
      } else {
        r.textContent = 'bridge: exposed, waiting';
        window.__bridgeCallback = function () { r.textContent = 'bridge: responded'; };
        h.postMessage(JSON.stringify({ id: '1', method: 'getDeviceInfo', params: {} }));
        setTimeout(function () { if (r.textContent.indexOf('waiting') > 0) r.textContent = 'bridge: exposed, no response'; }, 1500);
      }
    </script></body></html>
    """
}
