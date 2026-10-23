import { abilityDelegatorRegistry, Driver } from '@kit.TestKit';
import { Want } from '@kit.AbilityKit';
import { describe, expect, it } from '@ohos/hypium';
import { WANT_KEY_H5 } from '../../../main/ets/data/ApiConfig';
import { KEY_H5_PROBE } from '../../../main/ets/view/H5Page';
import { OFFLINE_ENTRY } from '../../../main/ets/web/OfflinePackage';

/**
 * M4 设备测试（ohosTest）。离线包拦截要真的跑 ArkWeb，本地单测里是空壳，只能在设备上测。
 *
 * 用直达入口启动（Want 参数 m3e.h5=normal）：不进列表页，不受 STAGE 和 M1–M3 的空影响。
 * 页面里的情况由 H5Page 的探针在 onPageEnd 时写进 AppStorage（KEY_H5_PROBE），测试和 App 同进程，直接读
 */
const BUNDLE: string = 'com.example.mobile3end';

interface ProbeResult {
  href: string;
  children: number;
}

export default function m4DeviceTest() {
  describe('M4Device', () => {
    it('m4_0_offlinePageLoads', 0, async () => {
      const driver = Driver.create();
      AppStorage.setOrCreate<string>(KEY_H5_PROBE, '');
      const params: Record<string, Object> = {};
      params[WANT_KEY_H5] = 'normal';
      const want: Want = { bundleName: BUNDLE, abilityName: 'EntryAbility', parameters: params };
      await abilityDelegatorRegistry.getAbilityDelegator().startAbility(want);

      // 等 onPageEnd 的探针，最多 10s
      let raw = '';
      for (let i = 0; i < 20 && raw === ''; i++) {
        await driver.delayMs(500);
        raw = AppStorage.get<string>(KEY_H5_PROBE) ?? '';
      }
      if (raw === '') {
        throw new Error('10s 内没等到 onPageEnd：离线包页面没加载出来，看 hilog 里的 onPageBegin / onErrorReceive');
      }
      // runJavaScript 返回的是 JS 值的字符串形式：脚本返回字符串时带引号，所以要先解一层
      const text = raw.startsWith('"') ? JSON.parse(raw) as string : raw;
      const probe = JSON.parse(text) as ProbeResult;
      expect(probe.href.startsWith(OFFLINE_ENTRY)).assertTrue();
      expect(probe.children > 0).assertTrue();
    });
  });
}
