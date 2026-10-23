import { Log } from '../common/Log';
import { STAGE } from '../common/Stage';
import { TODO } from '../common/Todo';
import { API_BASE, FILES_PATH, WANT_KEY_API_BASE, WANT_KEY_SAMPLE } from '../data/ApiConfig';
import { FileCache } from '../data/FileCache';
import { FileRepository, ListState, LoadKind } from '../data/FileRepository';
import { OhosHttpClient } from '../data/HttpClient';
import { PreferencesKvStore } from '../data/KvStore';
import { APP_BACKGROUND, APP_FOREGROUND, KEY_APP_STATE } from '../lifecycle/AppState';
import { ForegroundRefresher } from '../lifecycle/ForegroundRefresher';
import { busyWait, busyWaitOffMain } from '../lifecycle/Threads';
import {
  FileItem, fileKey, formatSize, formatTime, iconOf, nextOrder, SortOrder, sortFiles, sortLabel
} from '../model/FileItem';
import { SampleData } from '../model/SampleData';
import { detailIdOf, openDetail, ROUTE_DETAIL, ROUTE_H5 } from '../nav/Routes';
import { FileDetailView } from '../view/FileDetailView';
import { H5Page } from '../view/H5Page';
import { OFFLINE_ENTRY } from '../web/OfflinePackage';

function h5UrlOf(param: Object | undefined): string {
  return typeof param === 'string' ? param : OFFLINE_ENTRY;
}

/**
 * 唯一的 @Entry 页面。Navigation 的内容区就是列表页，其他页面（详情、H5）是 NavDestination，
 * 按名字压进 pathStack。列表页一直在组件树里，所以进详情再返回时滚动位置、状态都还在
 */
@Entry
@Component
struct Index {
  @Provide('pathStack') pathStack: NavPathStack = new NavPathStack();
  // @State：改它会触发 build() 里用到它的部分重新渲染，类似 Vue 的 ref
  // @Watch：值变化后回调指定方法，类似 Vue 的 watch
  @State @Watch('onOrderChange') order: SortOrder = SortOrder.NAME;
  @State listState: ListState = ListState.of(SampleData.files, false);
  // 订阅 AppStorage 里的前后台状态（EntryAbility 写入，见 lifecycle/AppState.ets）
  @StorageProp(KEY_APP_STATE) @Watch('onAppStateChange') appState: string = '';
  @State busyHint: string = '';

  private cache: FileCache | undefined = undefined;
  private repository: FileRepository | undefined = undefined;
  private refresher: ForegroundRefresher = new ForegroundRefresher();
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    Log.i(`Index.aboutToAppear STAGE=${STAGE}`);
    const forceSample = AppStorage.get<boolean>(WANT_KEY_SAMPLE) === true;
    const context = this.getUIContext().getHostContext();
    if (STAGE < 2 || forceSample || context === undefined) {
      return;
    }
    this.cache = new FileCache(new PreferencesKvStore(context, 'm3e'));
    const base = AppStorage.get<string>(WANT_KEY_API_BASE) || API_BASE;
    this.repository = new FileRepository(new OhosHttpClient(), this.cache, base + FILES_PATH);
    this.order = this.cache.loadOrder();
    this.reload();
  }

  aboutToDisappear(): void {
    Log.i('Index.aboutToDisappear');
  }

  // @Entry 页面才有的页面级生命周期，NavDestination 之间切换不会触发它们
  onPageShow(): void {
    Log.i('Index.onPageShow');
  }

  onPageHide(): void {
    Log.i('Index.onPageHide');
  }

  onBackPress(): boolean | void {
    Log.i(`Index.onBackPress stack=${this.pathStack.size()}`);
  }

  private reload(): void {
    const repo = this.repository;
    if (repo === undefined) {
      return;
    }
    repo.load((s: ListState) => {
      this.listState = s;
    }).catch((e: Error) => Log.e(`Index.reload 失败 ${e.message}`));
  }

  onOrderChange(): void {
    const cache = this.cache;
    if (cache === undefined) {
      return; // STAGE < 2：不持久化
    }
    // 空 M2-6：排序变了，存起来，下次启动 aboutToAppear 会读回来
    // 提示 1：一行，用上面的 cache
    TODO('M2-6');
  }

  onAppStateChange(): void {
    if (STAGE < 3) {
      return;
    }
    Log.i(`Index.onAppStateChange ${this.appState}`);
    // 空 M3-5：进后台时告诉 refresher；回前台时问 refresher 要不要刷新，要就 reload()
    // 提示 1：Date.now() 是毫秒
    TODO('M3-5');
  }

  @Builder
  pageMap(name: string, param: Object) {
    if (name === ROUTE_DETAIL) {
      FileDetailView({ file: SampleData.find(this.listState.files, detailIdOf(param)) })
    } else if (name === ROUTE_H5) {
      H5Page({ startUrl: h5UrlOf(param) })
    }
  }

  @Builder
  fileRow(item: FileItem) {
    Row({ space: 12 }) {
      Text(iconOf(item.type)).fontSize(24)
      Column({ space: 2 }) {
        Text(item.name).fontSize(16)
        Text((item.size > 0 ? formatSize(item.size) + ' · ' : '') + formatTime(item.mtime))
          .fontSize(12)
          .fontColor('#86909c')
      }
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
  }

  @Builder
  fileList() {
    List({ scroller: this.scroller }) {
      // ForEach(数据, 每项怎么渲染, 每项的 key)
      ForEach(sortFiles(this.listState.files, this.order), (item: FileItem) => {
        ListItem() {
          this.fileRow(item)
        }
        .onClick(() => openDetail(this.pathStack, item))
      }, (item: FileItem): string => fileKey(item))
    }
    .id('file-list')
    .divider({ strokeWidth: 1, color: '#f2f3f5' })
    .width('100%')
    .layoutWeight(1)
  }

  @Builder
  content() {
    if (this.listState.kind === LoadKind.LOADING) {
      Column({ space: 8 }) {
        LoadingProgress().width(48).height(48)
        Text('加载中…')
      }
      .id('loading')
      .justifyContent(FlexAlign.Center)
      .layoutWeight(1)
    } else if (this.listState.kind === LoadKind.ERROR) {
      Column({ space: 12 }) {
        Text(`加载失败：${this.listState.message}`).id('error').fontColor('#cf222e')
        Button('重试').id('retry').onClick(() => this.reload())
      }
      .justifyContent(FlexAlign.Center)
      .layoutWeight(1)
    } else if (this.listState.kind === LoadKind.EMPTY) {
      Column() {
        Text('还没有文件').id('empty')
      }
      .justifyContent(FlexAlign.Center)
      .layoutWeight(1)
    } else {
      if (this.listState.fromCache) {
        Text('显示的是缓存').id('from-cache').fontSize(12).fontColor('#86909c').padding({ left: 16 })
      }
      this.fileList()
    }
  }

  @Builder
  demoBar() {
    Flex({ wrap: FlexWrap.Wrap }) {
      if (STAGE >= 3) {
        // 主线程卡住时这个转圈会停
        LoadingProgress().width(28).height(28)
        Button('主线程卡 2s').id('block-main').fontSize(12).margin(4).onClick(() => {
          const cost = busyWait(2000);
          Log.w(`主线程忙等结束 ${cost}ms`);
        })
        Button('TaskPool 2s').id('block-taskpool').fontSize(12).margin(4).onClick(() => {
          this.busyHint = 'TaskPool 执行中…';
          busyWaitOffMain(2000).then((cost: number) => {
            this.busyHint = `TaskPool 完成 ${cost}ms`;
            Log.i(this.busyHint);
          });
        })
        Text(this.busyHint).fontSize(12)
      }
      if (STAGE >= 4) {
        Button('打开 H5').id('open-h5').fontSize(12).margin(4).onClick(() => {
          this.pathStack.pushPathByName(ROUTE_H5, OFFLINE_ENTRY);
        })
      }
      if (STAGE >= 5) {
        Button('Native 崩溃').id('crash').fontSize(12).margin(4).backgroundColor('#cf222e').onClick(() => {
          throw new Error('[M5] 故意抛出的 Native 异常');
        })
      }
    }
    .padding({ left: 12, right: 12 })
  }

  build() {
    Navigation(this.pathStack) {
      Column() {
        Row() {
          Text('我的文件').fontSize(20).fontWeight(FontWeight.Bold)
          Blank()
          Button(`排序：${sortLabel(this.order)}`)
            .id('sort')
            .type(ButtonType.Normal)
            .backgroundColor(Color.Transparent)
            .fontColor('#0a59f7')
            .onClick(() => {
              // 空 M1-2：切换排序（名称 ↔ 时间），列表要即时刷新
              // 提示 1：给 @State 字段重新赋值就会触发重新渲染，model/FileItem.ets 里有现成的切换函数
              TODO('M1-2');
            })
        }
        .width('100%')
        .padding({ left: 16, right: 8, top: 8, bottom: 8 })

        this.demoBar()
        this.content()
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
    .mode(NavigationMode.Stack)
    .navDestination(this.pageMap)
  }
}
