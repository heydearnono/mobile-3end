import { TODO } from '../common/Todo';

/**
 * 离线包：H5 访问 https://h5.offline.test/...，在 onInterceptRequest 里拦下来，
 * 从 rawfile/h5/ 读文件返回。`.test` 是保留域名，拦截失效时会直接加载失败，便于发现。
 *
 * 这个文件只放纯逻辑（URL → 状态码 / MIME / 数据），不碰 ArkWeb，所以能在本地单测里跑；
 * 和 WebResourceResponse 打交道的胶水在 H5Page.ets
 */
export const OFFLINE_ORIGIN: string = 'https://h5.offline.test';
export const OFFLINE_ENTRY: string = OFFLINE_ORIGIN + '/index.html';
/** rawfile 下的目录名。rawfile 只能放在 resources/rawfile 里，构建前从 mock/h5 同步过来（check.sh / sync-h5.sh） */
export const RAWFILE_DIR: string = 'h5';

export const LOG_OFFLINE_404: string = '[OFFLINE_404]';

const MIME_TABLE: Map<string, string> = new Map<string, string>([
  ['html', 'text/html'],
  ['htm', 'text/html'],
  ['js', 'application/javascript'],
  ['mjs', 'application/javascript'],
  ['css', 'text/css'],
  ['json', 'application/json'],
  ['map', 'application/json'],
  ['txt', 'text/plain'],
  ['png', 'image/png'],
  ['jpg', 'image/jpeg'],
  ['jpeg', 'image/jpeg'],
  ['gif', 'image/gif'],
  ['webp', 'image/webp'],
  ['svg', 'image/svg+xml'],
  ['ico', 'image/x-icon'],
  ['woff', 'font/woff'],
  ['woff2', 'font/woff2'],
  ['ttf', 'font/ttf'],
]);

/** 按扩展名给 MIME，不认识的给 application/octet-stream */
export function mimeOf(path: string): string {
  const slash = path.lastIndexOf('/');
  const dot = path.lastIndexOf('.');
  if (dot <= slash) {
    return 'application/octet-stream';
  }
  return MIME_TABLE.get(path.substring(dot + 1).toLowerCase()) ?? 'application/octet-stream';
}

/**
 * 取 URL 的 origin：`scheme://host[:port]`，全部小写。不是 `xxx://` 开头的返回空串。
 * 不用 @kit.ArkTS 的 url.URL：本地单测环境里系统 API 都是空壳，纯字符串处理才能测
 */
export function originOf(url: string): string {
  // 空 M4-1：按上面的规则取 origin
  // 提示 1：authority 是 `://` 之后、第一个 / ? # 之前的部分；小心 `https://h5.offline.test@evil.com/` 这种写法
  return TODO('M4-1');
}

/**
 * 离线包 URL → 包内相对路径（已 URL 解码，不含 query / hash）。
 * - origin 不是 OFFLINE_ORIGIN → undefined（不归我们管，放行）
 * - 路径为空或以 / 结尾 → 补 index.html
 * - 解码失败（如 %E0%A4%A）→ 原样返回未解码的路径，后面自然找不到文件
 * 例：https://h5.offline.test/index.html?case=blank → index.html
 */
export function offlinePathOf(url: string): string | undefined {
  // 空 M4-2：按上面的规则实现
  // 提示 1：先用 M4-1 判 origin；再把 origin 后面那段切掉 ? 和 # 之后的内容
  return TODO('M4-2');
}

/** 离线包对一个请求的回答。data 为 undefined 表示没有响应体 */
export class OfflineResponse {
  status: number;
  reason: string;
  mime: string;
  data: ArrayBuffer | undefined;
  /** 要打的日志，空串表示不打 */
  log: string;

  constructor(status: number, reason: string, mime: string, data: ArrayBuffer | undefined, log: string) {
    this.status = status;
    this.reason = reason;
    this.mime = mime;
    this.data = data;
    this.log = log;
  }
}

/**
 * 决定离线包怎么回答这个请求。
 * - 不是离线包 origin → undefined（放行，交给网络）
 * - 路径里有 `..` 段（想跳出 h5 目录）→ 404，不去读文件
 * - read(`h5/<path>`) 返回 undefined → 404，log 为 `[OFFLINE_404] <完整 url>`
 * - 读到了 → 200，按扩展名给 MIME
 * 404 的 reason 为 'Not Found'，mime 为 text/plain，data 为 undefined；200 的 reason 为 'OK'
 */
export function resolveOffline(url: string, read: (rawPath: string) => ArrayBuffer | undefined): OfflineResponse | undefined {
  // 空 M4-3：按上面的规则实现
  // 提示 1：read 的参数要带上 RAWFILE_DIR 前缀
  return TODO('M4-3');
}
