/**
 * 当前做到第几个里程碑，决定 App 怎么接线。开始新里程碑时自己改这个数：
 * - `< 2`：列表用写死的 SampleData
 * - `>= 2`：列表走网络 + 本地缓存，排序持久化
 * - `>= 3`：切后台 30s 回前台自动刷新，主线程 / TaskPool 演示按钮
 * - `>= 4`：列表页出现 H5 入口
 * - `>= 5`：注册未捕获异常钩子，出现「Native 崩溃」按钮
 *
 * 测试不看这个值：测试都是直接 new 出要测的类 / 调用要测的函数（依赖注入），
 * 所以做 M<n> 时不会被后面里程碑的空卡住。
 */
export const STAGE: number = 1;

/**
 * M4 的两个开关。离线包拦截（M4-1 ~ M4-4）已经写好，一打开 H5 页还会跑到两块没填的空：
 * - bridge：H5 一 mount 就调 getDeviceInfo → NativeBridgeProxy.postMessage（M4-6）→ BridgeDispatcher.handle（M4-5）
 * - 白屏检测：onPageEnd → WhiteScreenMonitor.onPageEnd（M4-7，里面用到 M4-9）；onErrorReceive → M4-8
 * TODO 会 throw，ArkUI / ArkWeb 回调里没接住的异常一般会变成 JS Crash（App 退出），所以没填之前先关着：
 * - M4_BRIDGE = false：不注册 NativeBridge，H5 上显示 `bridge: none`，getDeviceInfo 显示 NO_BRIDGE，页面照常渲染。
 *   填完 M4-5、M4-6 后改成 true
 * - M4_WHITE_SCREEN = false：不建 WhiteScreenMonitor，onPageEnd 只打一行日志说明开关关着。
 *   填完 M4-7 ~ M4-9 后改成 true
 * 测试不看这两个值：本地单测直接测 Bridge / WhiteScreen 的纯逻辑；H5Page 的 bridgeEnabled / whiteScreenEnabled 也能显式传
 */
export const M4_BRIDGE: boolean = false;
export const M4_WHITE_SCREEN: boolean = false;
