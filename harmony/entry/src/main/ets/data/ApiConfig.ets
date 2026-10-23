/**
 * mock 服务地址（README「本地 mock 服务」）。
 *
 * 鸿蒙模拟器访问宿主机的地址：待实测，结果记到 notes/harmony-M2.md。
 * 先填华为官方文档《使用模拟器访问网络》里给的 10.0.2.2（模拟器的默认网关，和 Android 模拟器同一套 QEMU 网络）。
 * 不通再试：`hdc rport tcp:8000 tcp:8000` 把设备端口反向转发到 Mac，然后改成 http://127.0.0.1:8000。
 * 真机：Mac 的局域网 IP。
 */
export const API_BASE: string = 'http://10.0.2.2:8000';
export const FILES_PATH: string = '/api/files.json';

// UI 测试通过 Want 参数覆盖地址（如指向一个连不上的端口来测失败态），见 EntryAbility
export const WANT_KEY_API_BASE: string = 'm3e.apiBase';
// UI 测试强制用写死数据，不受 STAGE 影响
export const WANT_KEY_SAMPLE: string = 'm3e.sample';
/**
 * 直达 H5 页（调试用）：带上这个 Want 参数启动，不进列表页，直接打开离线包页面，不会跑到 M1–M3 的空。
 * 值是 H5 测试用例名：normal（无 case）/ blank / missing / slow，见 pages/H5Entry.ets。命令见 hints/harmony-M4.md 开头
 */
export const WANT_KEY_H5: string = 'm3e.h5';
