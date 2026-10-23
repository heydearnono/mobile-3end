import { hilog } from '@kit.PerformanceAnalysisKit';

// 全工程统一的日志 tag。DevEco 的 Log 面板（HiLog）里搜 `M3E`，命令行 `hdc hilog -T M3E`
export const TAG: string = 'M3E';
// hilog 的 domain 是 0x0000–0xFFFF 的业务域编号，过滤用，学习项目统一 0x0000
export const DOMAIN: number = 0x0000;

/**
 * hilog 的格式串里参数默认是隐私的：release 包里 `%s` 会打印成 `<private>`。
 * 要看到原文必须写 `%{public}s`，这是和 Android Log.d / console.log 最不一样的地方
 */
export class Log {
  static d(msg: string): void {
    hilog.debug(DOMAIN, TAG, '%{public}s', msg);
  }

  static i(msg: string): void {
    hilog.info(DOMAIN, TAG, '%{public}s', msg);
  }

  static w(msg: string): void {
    hilog.warn(DOMAIN, TAG, '%{public}s', msg);
  }

  static e(msg: string): void {
    hilog.error(DOMAIN, TAG, '%{public}s', msg);
  }
}
