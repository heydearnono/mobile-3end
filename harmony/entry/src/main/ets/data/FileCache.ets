import { Log } from '../common/Log';
import { TODO } from '../common/Todo';
import { FileItem, SortOrder } from '../model/FileItem';
import { encodeFiles, parseFilesJson } from './FilesJson';
import { KvStore } from './KvStore';

const KEY_FILES: string = 'files';
const KEY_ORDER: string = 'order';

/** 列表缓存 + 排序选择。只依赖 KvStore 接口，测试用 MemoryKvStore */
export class FileCache {
  private kv: KvStore;

  // ArkTS 不支持 TS 的构造参数属性（constructor(private kv: KvStore)），字段要单独声明
  constructor(kv: KvStore) {
    this.kv = kv;
  }

  saveFiles(files: FileItem[]): void {
    this.kv.put(KEY_FILES, encodeFiles(files));
  }

  /** 没有缓存或缓存损坏都返回 undefined，损坏时打日志 */
  loadFiles(): FileItem[] | undefined {
    const text = this.kv.get(KEY_FILES);
    if (text === undefined) {
      return undefined;
    }
    try {
      return parseFilesJson(text);
    } catch (e) {
      Log.w(`FileCache: 缓存损坏，忽略 ${(e as Error).message}`);
      return undefined;
    }
  }

  saveOrder(order: SortOrder): void {
    this.kv.put(KEY_ORDER, order);
  }

  // 空 M2-3：读出排序选择。没存过、或存的值不认识（比如老版本写的），都回到 NAME
  // 提示 1：存进去的是枚举的字符串值；字符串枚举不能 SortOrder[str] 反查
  loadOrder(): SortOrder {
    return TODO('M2-3');
  }
}
