import { Log } from '../common/Log';
import { WANT_KEY_H5 } from '../data/ApiConfig';
import { ROUTE_H5 } from '../nav/Routes';
import { H5Page } from '../view/H5Page';
import { OFFLINE_ENTRY } from '../web/OfflinePackage';

/** Want 参数 m3e.h5 的值 → 页面地址：normal（或空）不带 case，其余拼成 ?case=<值> */
function h5UrlOfCase(testCase: string): string {
  return testCase === '' || testCase === 'normal' ? OFFLINE_ENTRY : `${OFFLINE_ENTRY}?case=${encodeURIComponent(testCase)}`;
}

/**
 * 直达 H5 页（调试用）：EntryAbility 看到 Want 参数 m3e.h5 时加载这个页面，代替 pages/Index。
 * 不渲染列表页，所以不会跑到 M1–M3 的空，也不看 STAGE。命令见 hints/harmony-M4.md 开头。
 *
 * H5Page 的根是 NavDestination，要放在 Navigation 里才能正常显示（标题栏、返回），
 * 所以这里也套一层 Navigation，一进来就把 H5 页压栈。按返回会回到下面这行提示
 */
@Entry
@Component
struct H5Entry {
  private pathStack: NavPathStack = new NavPathStack();

  aboutToAppear(): void {
    const url = h5UrlOfCase(AppStorage.get<string>(WANT_KEY_H5) ?? '');
    Log.i(`H5Entry.aboutToAppear ${url}`);
    this.pathStack.pushPathByName(ROUTE_H5, url, false);
  }

  @Builder
  pageMap(name: string, param: Object) {
    if (name === ROUTE_H5) {
      H5Page({ startUrl: typeof param === 'string' ? param : OFFLINE_ENTRY })
    }
  }

  build() {
    Navigation(this.pathStack) {
      Column() {
        Text('H5 直达入口（m3e.h5）。重新 aa start 再打开一次，或者退出 App')
          .fontSize(14)
          .fontColor('#86909c')
          .padding(16)
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
    }
    .hideTitleBar(true)
    .mode(NavigationMode.Stack)
    .navDestination(this.pageMap)
  }
}
