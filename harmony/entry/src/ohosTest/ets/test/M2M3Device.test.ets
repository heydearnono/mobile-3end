import { abilityDelegatorRegistry } from '@kit.TestKit';
import { preferences } from '@kit.ArkData';
import { describe, expect, it } from '@ohos/hypium';
import { OhosHttpClient } from '../../../main/ets/data/HttpClient';
import { PreferencesKvStore } from '../../../main/ets/data/KvStore';
import { busyWaitOffMain } from '../../../main/ets/lifecycle/Threads';

/**
 * M2 / M3 里依赖系统能力的空（Preferences、http、TaskPool），本地单测里这些 API 是空壳，只能在设备上测
 */
const TODO_MARK: string = 'An operation is not implemented';

export default function m2m3DeviceTest() {
  describe('M2M3Device', () => {
    it('m2_2_preferencesPersistAcrossReload', 0, () => {
      const ctx = abilityDelegatorRegistry.getAbilityDelegator().getAppContext();
      const name = 'm3e-device-test';
      const kv = new PreferencesKvStore(ctx, name);
      kv.put('k', 'v1');
      // 把进程内缓存的实例扔掉，强制下次从文件读：只 put 没落盘的话这里就读不到了
      const options: preferences.Options = { name: name };
      preferences.removePreferencesFromCacheSync(ctx, options);
      const again = new PreferencesKvStore(ctx, name);
      expect(again.get('k')).assertEqual('v1');
      expect(again.get('missing')).assertUndefined();
    });

    it('m2_4_httpRejectsWhenUnreachable', 0, async () => {
      let message = '';
      try {
        await new OhosHttpClient(2000).get('http://127.0.0.1:9/api/files.json');
      } catch (e) {
        message = (e as Error).message ?? JSON.stringify(e);
      }
      if (message.indexOf(TODO_MARK) >= 0) {
        throw new Error(message); // 让 check.sh 显示「运行到了未填的空」
      }
      expect(message !== '').assertTrue();
    });

    it('m3_4_taskPoolDoesNotBlockCaller', 0, async () => {
      const start = Date.now();
      const pending = busyWaitOffMain(500);
      const syncCost = Date.now() - start;
      const cost = await pending;
      expect(syncCost < 200).assertTrue(); // 调用方立刻拿到 Promise，没被卡住
      expect(cost >= 500).assertTrue();
    });
  });
}
