import { errorManager } from '@kit.AbilityKit';
import { Log } from '../common/Log';
import { TODO } from '../common/Todo';

export function crashLog(name: string, message: string, stack: string): string {
  return `[CRASH] ${name}: ${message}\n${stack}`;
}

let observerId: number = -1;

// 空 M5-1：注册 ArkTS 未捕获异常的观察者，异常发生时用 crashLog 打一条 error 日志（带堆栈）；重复调用只注册一次
// 提示 1：@kit.AbilityKit 的 errorManager；observer 是一个 ErrorObserver 类型的对象，有两个回调
export function installCrashReporter(): void {
  TODO('M5-1');
}

/**
 * 页面开始解析前注入的脚本（Web 组件的 javaScriptOnDocumentStart）：把 H5 的未捕获异常连同堆栈打到 console。
 * 浏览器自带的「Uncaught Error: ...」console 消息只有一行，没有堆栈
 */
export const H5_ERROR_HOOK_JS: string =
  "window.addEventListener('error', function (e) {" +
    " console.error('[H5_UNCAUGHT] ' + ((e.error && e.error.stack) || e.message));" +
  " });";

export const H5_UNCAUGHT_PREFIX: string = '[H5_UNCAUGHT]';

// 空 M5-2：判断一条 H5 console 消息是不是未捕获异常，是就返回要打的日志行，否则 undefined
// 规则：只看 error 级别；消息以 'Uncaught' 或 H5_UNCAUGHT_PREFIX 开头才算；
// 日志行格式 `[H5_ERROR] <message> @ <source>:<line>`
// 提示 1：普通的 console.error('xxx') 不是异常，不要报
export function h5ErrorLine(isError: boolean, message: string, source: string, line: number): string | undefined {
  return TODO('M5-2');
}
