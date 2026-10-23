import { AbilityConstant, Configuration, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { Log } from '../common/Log';
import { STAGE } from '../common/Stage';
import { installCrashReporter } from '../crash/CrashReporter';
import { WANT_KEY_API_BASE, WANT_KEY_H5, WANT_KEY_SAMPLE } from '../data/ApiConfig';
import { APP_BACKGROUND, APP_FOREGROUND, publishAppState } from '../lifecycle/AppState';

const PAGE_INDEX: string = 'pages/Index';
// 直达 H5 页（Want 参数 m3e.h5），不经过列表页
const PAGE_H5_ENTRY: string = 'pages/H5Entry';

// 应用级生命周期。对应 Android 的 Activity：一个 UIAbility 一个任务（最近任务里的一张卡片），
// 但页面不在这里，页面在 windowStage.loadContent 加载的 ArkUI 里
export default class EntryAbility extends UIAbility {
  private windowStage: window.WindowStage | undefined = undefined;
  private currentPage: string = '';

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    Log.i(`EntryAbility.onCreate reason=${launchParam.launchReason}`);
    if (STAGE >= 5) {
      installCrashReporter();
    }
    this.readTestParams(want);
  }

  // 已经在运行时再次被拉起（如从桌面图标、或测试再次 startAbility）走这里，不走 onCreate
  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    Log.i('EntryAbility.onNewWant');
    this.readTestParams(want);
    // 窗口已经在了，onWindowStageCreate 不会再走。要换页（列表页 ↔ 直达 H5 页）就重新 loadContent；
    // 直达 H5 页每次都重新加载，这样换个 case 再 aa start 也能生效；留在列表页时不动，保留现有状态
    const target = this.targetPage();
    if (this.windowStage !== undefined && (target !== this.currentPage || target === PAGE_H5_ENTRY)) {
      this.loadPage(this.windowStage, target);
    }
  }

  // UI 测试通过 Want 参数注入依赖：强制写死数据 / 换 mock 地址 / 直达 H5 页
  private readTestParams(want: Want): void {
    const params = want.parameters;
    const sample = params !== undefined && params[WANT_KEY_SAMPLE] === true;
    AppStorage.setOrCreate<boolean>(WANT_KEY_SAMPLE, sample);
    const apiBase = params !== undefined ? params[WANT_KEY_API_BASE] : undefined;
    AppStorage.setOrCreate<string>(WANT_KEY_API_BASE, typeof apiBase === 'string' ? apiBase : '');
    // 直达 H5 页：aa start 的 --ps 传进来是字符串
    const h5 = params !== undefined ? params[WANT_KEY_H5] : undefined;
    AppStorage.setOrCreate<string>(WANT_KEY_H5, typeof h5 === 'string' ? h5 : '');
  }

  private targetPage(): string {
    return (AppStorage.get<string>(WANT_KEY_H5) ?? '') !== '' ? PAGE_H5_ENTRY : PAGE_INDEX;
  }

  private loadPage(windowStage: window.WindowStage, page: string): void {
    this.currentPage = page;
    windowStage.loadContent(page, (err) => {
      if (err.code) {
        Log.e(`Failed to load the content. Cause: ${JSON.stringify(err)}`);
        return;
      }
      Log.i(`Succeeded in loading the content. page=${page}`);
    });
  }

  onDestroy(): void {
    Log.i('EntryAbility.onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    Log.i('EntryAbility.onWindowStageCreate');
    // 窗口层面的前后台（SHOWN / ACTIVE / INACTIVE / HIDDEN），和 onForeground / onBackground 对照着看顺序
    windowStage.on('windowStageEvent', (event: window.WindowStageEventType) => {
      Log.i(`windowStageEvent ${event}`);
    });

    this.windowStage = windowStage;
    this.loadPage(windowStage, this.targetPage());

    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      Log.e(`Failed to set colorMode. Cause: ${JSON.stringify(err)}`);
    }
  }

  onWindowStageDestroy(): void {
    Log.i('EntryAbility.onWindowStageDestroy');
    this.windowStage = undefined;
    this.currentPage = '';
  }

  onForeground(): void {
    Log.i('EntryAbility.onForeground');
    if (STAGE >= 3) {
      publishAppState(APP_FOREGROUND);
    }
  }

  onBackground(): void {
    Log.i('EntryAbility.onBackground');
    if (STAGE >= 3) {
      publishAppState(APP_BACKGROUND);
    }
  }

  // 旋转屏幕、切深色模式、改字体大小时回调。鸿蒙默认不重建 Ability / 页面，只通知
  onConfigurationUpdate(newConfig: Configuration): void {
    Log.i(`EntryAbility.onConfigurationUpdate direction=${newConfig.direction} colorMode=${newConfig.colorMode}`);
  }
}
