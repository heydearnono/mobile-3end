import { TODO } from '../common/Todo';

/**
 * 白屏检测，规则见 spec.md「白屏检测」。纯逻辑：定时、执行 JS、上报都通过 WhiteScreenHost 注入，
 * H5Page.ets 里接到 setTimeout / runJavaScript / hilog，测试里接到假的
 */
export const ROOT_CHILD_COUNT_JS: string = "(document.getElementById('app') || {}).childElementCount || 0";
export const CHECK_DELAY_MS: number = 1000;

export const REASON_EMPTY_ROOT: string = 'empty_root';
export const REASON_RENDER_GONE: string = 'render_gone';
export const REASON_LOAD_ERROR: string = 'load_error';

export function whiteScreenLog(reason: string, url: string): string {
  return `[WHITE_SCREEN] reason=${reason} url=${url}`;
}

/** runJavaScript 的结果是字符串（数字会变成 "3"），脚本失败时可能是 "null" 或空串，都按 0 算 */
export function parseChildCount(jsResult: string | undefined | null): number {
  const n = Number(jsResult);
  return Number.isFinite(n) ? n : 0;
}

export enum CheckDecision {
  OK = 'ok',
  RETRY = 'retry',
  WHITE = 'white',
}

/** 检测策略：主文档加载完成后过了 elapsedMs，#app 有 childCount 个子元素，现在怎么判 */
export type WhitePolicy = (elapsedMs: number, childCount: number) => CheckDecision;

/** spec 的基础规则：1s 时为 0 就是白屏。case=slow 会误报 */
export function singleCheckPolicy(elapsedMs: number, childCount: number): CheckDecision {
  return childCount === 0 ? CheckDecision.WHITE : CheckDecision.OK;
}

export const SLOW_DEADLINE_MS: number = 5000;

// 空 M4-9：你给 case=slow 设计的检测时机。WhiteScreenMonitor 每隔 CHECK_DELAY_MS 问一次，返回 RETRY 就再等一轮
// 测试只卡三条底线：有子元素一定 OK；1s 时为空不能判白屏（slow 3s 才渲染）；到 SLOW_DEADLINE_MS 还为空必须判白屏
// 提示 1：最简单的方案是「轮询到截止时间」；想换别的方案，先在 notes 写理由，再改这里和测试
export function slowAwarePolicy(elapsedMs: number, childCount: number): CheckDecision {
  return TODO('M4-9');
}

// 和 BridgeEnv 一样写成函数类型的属性，方便用对象字面量实现
export interface WhiteScreenHost {
  /** delayMs 后执行 task */
  schedule: (delayMs: number, task: () => Promise<void>) => void;
  /** 在当前页面执行 JS，返回结果字符串 */
  evaluate: (js: string) => Promise<string>;
  /** 上报一行白屏日志 */
  report: (line: string) => void;
}

/**
 * 一个 Web 组件配一个。每次主文档开始加载（onPageBegin）算一「轮」，
 * 上一轮还没跑完的检测在新一轮开始后要作废；同一轮最多报一次白屏
 */
export class WhiteScreenMonitor {
  private host: WhiteScreenHost;
  private policy: WhitePolicy;
  private round: number = 0;
  private reported: boolean = false;

  constructor(host: WhiteScreenHost, policy: WhitePolicy) {
    this.host = host;
    this.policy = policy;
  }

  onPageBegin(url: string): void {
    this.round++;
    this.reported = false;
  }

  private report(reason: string, url: string): void {
    if (this.reported) {
      return;
    }
    this.reported = true;
    this.host.report(whiteScreenLog(reason, url));
  }

  /**
   * 主文档加载完成。CHECK_DELAY_MS 后执行 ROOT_CHILD_COUNT_JS，结果交给 policy：
   * - WHITE → 报 empty_root
   * - RETRY → 再等 CHECK_DELAY_MS 查一次（elapsed 累加）
   * - OK → 结束
   * 等待期间如果开始了新一轮（onPageBegin），这次检测作废，什么都不做
   */
  onPageEnd(url: string): void {
    // 空 M4-7：按上面的规则实现
    // 提示 1：在 schedule 之前记下当前 round，task 里对比；递归调用一个「第 n 次检查」的内部函数比较好写
    TODO('M4-7');
  }

  /**
   * 资源加载失败。子资源（图片、脚本）失败不算白屏，只有主文档失败才报 load_error
   */
  onErrorReceive(url: string, isMainFrame: boolean): void {
    // 空 M4-8：按上面的规则实现
    // 提示 1：ArkWeb 的 onErrorReceive 对每个失败的请求都会回调，不只主文档
    TODO('M4-8');
  }

  /** 渲染进程异常退出（崩溃 / 被杀 / OOM），回调触发即判定 */
  onRenderExited(url: string): void {
    this.report(REASON_RENDER_GONE, url);
  }
}
