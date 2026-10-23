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
