import { TODO } from '../common/Todo';

/**
 * 「切后台超过 30s 再回前台就刷新一次」的判定。不碰任何系统 API，时间由调用方传进来，方便测试。
 * 回前台时不管刷不刷新，都要清掉上次进后台的时间，避免下次回前台重复触发
 */
export class ForegroundRefresher {
  readonly thresholdMs: number;
  /** 上次进后台的时间戳（ms），-1 表示还没进过后台 */
  private backgroundAt: number = -1;

  constructor(thresholdMs: number = 30000) {
    this.thresholdMs = thresholdMs;
  }

  // 空 M3-1：记下进后台的时间
  // 提示 1：只要一个赋值
  onBackground(now: number): void {
    TODO('M3-1');
  }

  // 空 M3-2：回前台，返回这次要不要刷新（在后台待满 thresholdMs 才刷新，正好 30s 也算）
  // 提示 1：冷启动时也会回调一次 onForeground，那时候从没进过后台
  onForeground(now: number): boolean {
    return TODO('M3-2');
  }
}
