import { http } from '@kit.NetworkKit';
import { TODO } from '../common/Todo';

/** 逻辑代码只依赖这个接口，测试里换成假的 */
export interface HttpGet {
  /** 成功（HTTP 200）resolve 响应体文本；网络错误或非 200 都 reject */
  get(url: string): Promise<string>;
}

/**
 * 用 @ohos.net.http（NetworkKit）实现。
 * 选它而不是 rcp（RemoteCommunicationKit）：spec / compare.md 写的就是它；API 是 OpenHarmony 通用的；
 * 用法接近浏览器 XHR，一个请求一个对象，概念最少。rcp 有 session、拦截器、默认禁明文（API 23+），
 * 做 SDK 级网络库时再看。
 *
 * 用之前要在 module.json5 声明 ohos.permission.INTERNET（M2 手工任务），否则 request 直接报 201
 */
export class OhosHttpClient implements HttpGet {
  private timeoutMs: number;

  constructor(timeoutMs: number = 5000) {
    this.timeoutMs = timeoutMs;
  }

  // 空 M2-4：发 GET，200 时返回文本，其余情况抛 Error；无论成败都要释放请求对象
  // 提示 1：http.createHttp() 一次性使用；request 返回 Promise<HttpResponse>；看 responseCode 和 result
  async get(url: string): Promise<string> {
    return TODO('M2-4');
  }
}
