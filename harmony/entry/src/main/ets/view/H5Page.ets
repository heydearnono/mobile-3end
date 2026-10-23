import { webview } from '@kit.ArkWeb';
import { promptAction } from '@kit.ArkUI';
import { bundleManager } from '@kit.AbilityKit';
import { deviceInfo } from '@kit.BasicServicesKit';
import { Log } from '../common/Log';
import { TODO } from '../common/Todo';
import { H5_ERROR_HOOK_JS, h5ErrorLine } from '../crash/CrashReporter';
import { KEY_APP_STATE } from '../lifecycle/AppState';
import { BRIDGE_NAME, BridgeDispatcher, BridgeEnv, DeviceInfo, eventScript, isTrustedPage } from '../web/Bridge';
import { OFFLINE_ENTRY, OFFLINE_ORIGIN, resolveOffline } from '../web/OfflinePackage';
import { slowAwarePolicy, WhiteScreenHost, WhiteScreenMonitor } from '../web/WhiteScreen';

interface AppStateData {
  state: string;
}

interface UrlPermission {
  scheme: string;
  host: string;
  port: string;
  path: string;
}

interface ProxyPermissionBody {
  urlPermissionList: UrlPermission[];
}

interface ProxyPermission {
  javascriptProxyPermission: ProxyPermissionBody;
}

/**
 * javaScriptProxy 的 permission：ArkWeb 自带的 URL 白名单，不在名单里的页面调 NativeBridge 会被拒（Jsb Permission Denied）。
 * 注意它挡的是「调用」，NativeBridge 对象本身还是会注入到所有页面。所以 BridgeDispatcher 里还要再校验一次 origin
 */
function bridgePermission(): string {
  const p: ProxyPermission = {
    javascriptProxyPermission: {
      urlPermissionList: [{ scheme: 'https', host: 'h5.offline.test', port: '', path: '' }],
    },
  };
  return JSON.stringify(p);
}

/**
 * 注册给 H5 的对象。H5 里 window.NativeBridge.postMessage(str) 会同步调到这里的 postMessage，
 * 运行在 ArkTS 主线程（UI 线程），H5 线程会等它返回
 */
class NativeBridgeProxy {
  private controller: webview.WebviewController;
  private dispatcher: BridgeDispatcher;

  constructor(controller: webview.WebviewController, dispatcher: BridgeDispatcher) {
    this.controller = controller;
    this.dispatcher = dispatcher;
  }

  // 空 M4-6：收到 H5 消息 → 交给 dispatcher（带上当前页面 URL）→ 有返回的 JS 就执行回去
  // 提示 1：WebviewController 能拿到当前页面 URL，也能执行 JS；runJavaScript 返回 Promise，失败要接住
  postMessage(message: string): void {
    TODO('M4-6');
  }
}

@Component
export struct H5Page {
  startUrl: string = OFFLINE_ENTRY;
  controller: webview.WebviewController = new webview.WebviewController();
  @StorageProp(KEY_APP_STATE) @Watch('onAppState') appState: string = '';
  @State currentUrl: string = '';

  private dispatcher: BridgeDispatcher | undefined = undefined;
  private proxy: NativeBridgeProxy | undefined = undefined;
  private monitor: WhiteScreenMonitor | undefined = undefined;

  aboutToAppear(): void {
    Log.i(`H5Page.aboutToAppear ${this.startUrl}`);
    // M4 手工任务：在这里打开 Web 远程调试，见 hints/harmony-M4.md「远程调试」

    const env: BridgeEnv = {
      deviceInfo: (): DeviceInfo => {
        const bundle = bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT);
        const info: DeviceInfo = {
          platform: 'harmony',
          osVersion: `${deviceInfo.osFullName} (API ${deviceInfo.sdkApiVersion})`,
          appVersion: bundle.versionName,
        };
        return info;
      },
      toast: (text: string): void => {
        const options: promptAction.ShowToastOptions = { message: text };
        this.getUIContext().getPromptAction().showToast(options);
      },
    };
    this.dispatcher = new BridgeDispatcher(env);
    this.proxy = new NativeBridgeProxy(this.controller, this.dispatcher);

    const host: WhiteScreenHost = {
      schedule: (delayMs: number, task: () => Promise<void>): void => {
        setTimeout(() => {
          task().catch((e: Error) => Log.e(`白屏检测失败 ${e.message}`));
        }, delayMs);
      },
      evaluate: (js: string): Promise<string> => this.controller.runJavaScript(js),
      report: (line: string): void => Log.w(line),
    };
    this.monitor = new WhiteScreenMonitor(host, slowAwarePolicy);
  }

  aboutToDisappear(): void {
    Log.i('H5Page.aboutToDisappear');
  }

  // 前后台变化推给 H5。只推给离线包页面：其他页面没有 __bridgeEvent，也不该收到
  onAppState(): void {
    if (this.currentUrl === '' || !isTrustedPage(this.currentUrl)) {
      return;
    }
    const data: AppStateData = { state: this.appState };
    this.controller.runJavaScript(eventScript('appState', data))
      .catch((e: Error) => Log.e(`推送 appState 失败 ${e.message}`));
  }

  private readRawfile(path: string): ArrayBuffer | undefined {
    try {
      const bytes = this.getUIContext().getHostContext()!.resourceManager.getRawFileContentSync(path);
      // Uint8Array 可能是一个更大 buffer 的切片，按 offset / length 拷出自己那段
      return bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength);
    } catch (e) {
      return undefined; // 9001005：文件不存在
    }
  }

  // 空 M4-4：离线包拦截。不是离线包的请求返回 null（放行）；是的话用 resolveOffline 的结果组装 WebResourceResponse，
  // 有 log 就用 Log.w 打出来
  // 提示 1：WebResourceResponse 要设置 数据 / 编码 / MIME / 状态码 / 原因短语，最后标记 ready
  interceptRequest(event: OnInterceptRequestEvent): WebResourceResponse | null {
    return TODO('M4-4');
  }

  private load(url: string): void {
    try {
      this.controller.loadUrl(url);
    } catch (e) {
      Log.e(`loadUrl 失败 ${JSON.stringify(e)}`);
    }
  }

  @Builder
  caseButton(label: string, url: string) {
    Button(label).fontSize(12).height(28).margin(2).onClick(() => this.load(url))
  }

  build() {
    NavDestination() {
      Column() {
        Flex({ wrap: FlexWrap.Wrap }) {
          this.caseButton('正常', OFFLINE_ENTRY)
          this.caseButton('blank', `${OFFLINE_ENTRY}?case=blank`)
          this.caseButton('missing', `${OFFLINE_ENTRY}?case=missing`)
          this.caseButton('slow', `${OFFLINE_ENTRY}?case=slow`)
          this.caseButton('example.com', 'https://example.com')
          this.caseButton('不存在的离线页', `${OFFLINE_ORIGIN}/nope.html`)
        }
        .padding(4)

        Web({ src: this.startUrl, controller: this.controller })
          .id('h5-web')
          .javaScriptAccess(true)
          .domStorageAccess(true)
          .javaScriptProxy({
            object: this.proxy!,
            name: BRIDGE_NAME,
            methodList: ['postMessage'],
            controller: this.controller,
            permission: bridgePermission(),
          })
          // M5：页面任何脚本执行前注入，捕获 H5 未捕获异常的堆栈
          .javaScriptOnDocumentStart([{ script: H5_ERROR_HOOK_JS, scriptRules: ['*'] }])
          .onInterceptRequest((event: OnInterceptRequestEvent) => this.interceptRequest(event))
          .onPageBegin((event: OnPageBeginEvent) => {
            Log.i(`onPageBegin ${event.url}`);
            this.currentUrl = event.url;
            this.monitor?.onPageBegin(event.url);
          })
          .onPageEnd((event: OnPageEndEvent) => {
            Log.i(`onPageEnd ${event.url}`);
            this.currentUrl = event.url;
            this.monitor?.onPageEnd(event.url);
          })
          .onErrorReceive((event: OnErrorReceiveEvent) => {
            const url = event.request.getRequestUrl();
            Log.w(`onErrorReceive ${event.error.getErrorCode()} ${event.error.getErrorInfo()} ${url}`);
            this.monitor?.onErrorReceive(url, event.request.isMainFrame());
          })
          .onRenderExited((event: OnRenderExitedEvent) => {
            Log.e(`onRenderExited reason=${event.renderExitReason}`);
            this.monitor?.onRenderExited(this.currentUrl);
          })
          .onConsole((event: OnConsoleEvent) => {
            const m = event.message;
            const line = h5ErrorLine(m.getMessageLevel() === MessageLevel.Error, m.getMessage(), m.getSourceId(),
              m.getLineNumber());
            if (line !== undefined) {
              Log.e(line);
            }
            return false; // false：继续交给系统打印到 hilog（tag 带 webview / ArkWeb）
          })
          .width('100%')
          .layoutWeight(1)
      }
      .width('100%')
      .height('100%')
    }
    .title('H5')
    .onShown(() => Log.i('H5Page.onShown'))
    .onHidden(() => Log.i('H5Page.onHidden'))
  }
}
