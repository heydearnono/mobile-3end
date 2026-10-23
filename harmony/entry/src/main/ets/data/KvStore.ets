import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { TODO } from '../common/Todo';

/** 最小的 KV 接口，对应 localStorage。逻辑代码只依赖它，测试里换成内存版 */
export interface KvStore {
  get(key: string): string | undefined;
  put(key: string, value: string): void;
}

export class MemoryKvStore implements KvStore {
  private map: Map<string, string> = new Map<string, string>();

  get(key: string): string | undefined {
    return this.map.get(key);
  }

  put(key: string, value: string): void {
    this.map.set(key, value);
  }
}

/**
 * 用 Preferences（@kit.ArkData）实现。一个 name 对应应用沙箱里的一个 XML 文件，
 * 进程内有缓存：getPreferencesSync 拿到的是同一个实例
 */
export class PreferencesKvStore implements KvStore {
  private prefs: preferences.Preferences;

  constructor(context: common.Context, name: string) {
    const options: preferences.Options = { name: name };
    this.prefs = preferences.getPreferencesSync(context, options);
  }

  // 空 M2-2（上）：读一个字符串，没有就返回 undefined
  // 提示 1：getSync 必须给默认值；返回类型是 ValueType 联合类型，要收窄成 string
  get(key: string): string | undefined {
    return TODO('M2-2');
  }

  // 空 M2-2（下）：写一个字符串，并且确保落盘（进程被杀后还在）
  // 提示 1：putSync 只改内存里的那份
  put(key: string, value: string): void {
    TODO('M2-2');
  }
}
