import { Log } from '../common/Log';
import { TODO } from '../common/Todo';
import { OFFLINE_ORIGIN, originOf } from './OfflinePackage';

/**
 * JSBridge 协议见 spec.md「JSBridge 协议」。H5 调 window.NativeBridge.postMessage(str)，
 * Native 用 runJavaScript 执行 window.__bridgeCallback(...) / window.__bridgeEvent(...) 回去。
 *
 * 这里是纯逻辑：输入「消息字符串 + 发消息时页面的 URL」，输出「要执行的 JS」（undefined 表示不回）。
 * 怎么拿到消息、怎么执行 JS 在 H5Page.ets
 */
export const BRIDGE_NAME: string = 'NativeBridge';
export const ERR_METHOD_NOT_FOUND: string = 'METHOD_NOT_FOUND';

export interface BridgeRequest {
  id?: string;
  method?: string;
  params?: Record<string, Object>;
}

export interface DeviceInfo {
  platform: string;
  osVersion: string;
  appVersion: string;
}

/**
 * Native 能力，测试里换成假的。
 * 写成「函数类型的属性」而不是方法签名：ArkTS 不允许用对象字面量实现带方法的 interface
 */
export interface BridgeEnv {
  deviceInfo: () => DeviceInfo;
  toast: (text: string) => void;
}

export interface BridgeError {
  code: string;
  message: string;
}

interface OkPayload {
  id: string;
  ok: boolean;
  data: Object;
}

interface ErrorPayload {
  id: string;
  ok: boolean;
  error: BridgeError;
}

interface EventPayload {
  event: string;
  data: Object;
}

// JSON 是 JS 字面量的子集，直接拼进脚本就是一个对象字面量，不需要再 JSON.parse
export function callbackOk(id: string, data: Object): string {
  const p: OkPayload = { id: id, ok: true, data: data };
  return `window.__bridgeCallback(${JSON.stringify(p)})`;
}

export function callbackError(id: string, code: string, message: string): string {
  const err: BridgeError = { code: code, message: message };
  const p: ErrorPayload = { id: id, ok: false, error: err };
  return `window.__bridgeCallback(${JSON.stringify(p)})`;
}

export function eventScript(event: string, data: Object): string {
  const p: EventPayload = { event: event, data: data };
  return `window.__bridgeEvent(${JSON.stringify(p)})`;
}

/** 只认离线包的 origin */
export function isTrustedPage(pageUrl: string): boolean {
  return originOf(pageUrl) === OFFLINE_ORIGIN;
}

interface ToastResult {
}

export class BridgeDispatcher {
  private env: BridgeEnv;

  constructor(env: BridgeEnv) {
    this.env = env;
  }

  /**
   * 处理一条 H5 消息，返回要执行的 JS；返回 undefined 表示不回应。
   * - 页面不是离线包 origin → 不回应（打一行 warn 日志）
   * - 不是合法 JSON、或没有字符串类型的 id → 不回应（没法回，H5 那边会超时）
   * - getDeviceInfo → 成功，data 为 env.deviceInfo()
   * - toast → 调 env.toast(params.text)，text 不是字符串时按空串；成功，data 为 {}
   * - 其他 → 失败，code 为 METHOD_NOT_FOUND，message 里带上方法名
   */
  handle(raw: string, pageUrl: string): string | undefined {
    // 空 M4-5：按上面的规则实现整个方法
    // 提示 1：JSON.parse 会抛异常；ArkTS 里 `as BridgeRequest` 只是告诉编译器类型，不做运行时检查
    return TODO('M4-5');
  }
}
