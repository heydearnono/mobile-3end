import { taskpool } from '@kit.ArkTS';
import { TODO } from '../common/Todo';

/** 忙等 ms 毫秒，模拟一段 CPU 密集的同步代码。在主线程调用会卡住 UI */
export function busyWait(ms: number): number {
  const start = Date.now();
  let n = 0;
  while (Date.now() - start < ms) {
    n++;
  }
  return Date.now() - start;
}

/**
 * 在 TaskPool 的 worker 线程里执行的函数。@Concurrent 函数不能捕获外部变量（闭包），
 * 用到的东西要么作为参数传进来，要么写在函数体里。所以这里把 busyWait 的循环抄了一遍
 * 返回实际耗时（ms）
 */
@Concurrent
export function busyWaitConcurrent(ms: number): number {
  const start = Date.now();
  let n = 0;
  while (Date.now() - start < ms) {
    n++;
  }
  return Date.now() - start;
}

// 空 M3-4：把 busyWaitConcurrent 丢到 TaskPool 执行，返回它算出的耗时；主线程不被阻塞
// 提示 1：taskpool.execute(func, ...args) 返回 Promise<Object>，要自己收窄成 number
export async function busyWaitOffMain(ms: number): Promise<number> {
  return TODO('M3-4');
}
