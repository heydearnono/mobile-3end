import { Log } from '../common/Log';
import { TODO } from '../common/Todo';
import { FileItem } from '../model/FileItem';
import { FileCache } from './FileCache';
import { parseFilesJson } from './FilesJson';
import { HttpGet } from './HttpClient';

export enum LoadKind {
  LOADING = 'loading',
  CONTENT = 'content',
  EMPTY = 'empty',
  ERROR = 'error',
}

/** 列表页的界面状态。用 class 而不是对象字面量：ArkTS 里 @State 观察的是 class 实例的属性赋值 */
export class ListState {
  kind: LoadKind;
  files: FileItem[];
  /** 当前显示的是不是缓存（网络结果还没回来或失败了） */
  fromCache: boolean;
  /** ERROR 时的原因 */
  message: string;

  constructor(kind: LoadKind, files: FileItem[], fromCache: boolean, message: string) {
    this.kind = kind;
    this.files = files;
    this.fromCache = fromCache;
    this.message = message;
  }

  static loading(): ListState {
    return new ListState(LoadKind.LOADING, [], false, '');
  }

  static error(message: string): ListState {
    return new ListState(LoadKind.ERROR, [], false, message);
  }

  /** 有数据 → CONTENT，空数组 → EMPTY */
  static of(files: FileItem[], fromCache: boolean): ListState {
    return new ListState(files.length > 0 ? LoadKind.CONTENT : LoadKind.EMPTY, files, fromCache, '');
  }
}

export class FileRepository {
  private http: HttpGet;
  private cache: FileCache;
  private url: string;

  constructor(http: HttpGet, cache: FileCache, url: string) {
    this.http = http;
    this.cache = cache;
    this.url = url;
  }

  /**
   * 先缓存、后网络。每次界面状态变化调用一次 onState：
   * 1. 有缓存 → 先发 ListState.of(缓存, true)；没缓存 → 先发 loading
   * 2. 请求 + 解码成功 → 写缓存，发 ListState.of(新数据, false)
   * 3. 失败 → 有缓存：什么都不发（继续显示缓存），打日志；没缓存：发 error
   */
  async load(onState: (state: ListState) => void): Promise<void> {
    // 空 M2-5：按上面的顺序实现
    // 提示 1：await 一个 reject 的 Promise 会抛异常，用 try / catch 接住，和 Kotlin 协程里一样
    TODO('M2-5');
  }
}
