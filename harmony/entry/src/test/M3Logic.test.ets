import { describe, expect, it } from '@ohos/hypium';
import { APP_BACKGROUND, APP_FOREGROUND, KEY_APP_STATE, publishAppState } from '../main/ets/lifecycle/AppState';
import { ForegroundRefresher } from '../main/ets/lifecycle/ForegroundRefresher';

/**
 * M3 纯逻辑检查（本地单测）。时间都是传进去的假时间，不用真等 30s。
 * TaskPool 在本地单测里是空壳，M3-4 在 ohosTest（设备）里测
 */
export default function m3LogicTest() {
  describe('M3Logic', () => {
    it('m3_1_m3_2_refreshAfter30sInBackground', 0, () => {
      const r = new ForegroundRefresher();
      r.onBackground(1000);
      expect(r.onForeground(1000 + 31000)).assertTrue();
    });

    it('m3_1_m3_2_exactly30sCounts', 0, () => {
      const r = new ForegroundRefresher();
      r.onBackground(0);
      expect(r.onForeground(30000)).assertTrue();
    });

    it('m3_1_m3_2_shortBackgroundDoesNotRefresh', 0, () => {
      const r = new ForegroundRefresher();
      r.onBackground(1000);
      expect(r.onForeground(1000 + 29999)).assertFalse();
    });

    it('m3_1_usesLatestBackgroundTime', 0, () => {
      // 进后台 → 回前台 → 再进后台：以最后一次进后台为准
      const r = new ForegroundRefresher();
      r.onBackground(0);
      r.onForeground(5000);
      r.onBackground(100000);
      expect(r.onForeground(110000)).assertFalse();
    });

    it('m3_2_coldStartForegroundDoesNotRefresh', 0, () => {
      // 冷启动：没进过后台就回调了 onForeground（Date.now() 很大）
      expect(new ForegroundRefresher().onForeground(1760000000000)).assertFalse();
    });

    it('m3_2_onlyRefreshesOncePerBackground', 0, () => {
      const r = new ForegroundRefresher();
      r.onBackground(0);
      expect(r.onForeground(60000)).assertTrue();
      expect(r.onForeground(120000)).assertFalse();
    });

    it('m3_3_publishCreatesKeyWhenMissing', 0, () => {
      AppStorage.delete(KEY_APP_STATE);
      publishAppState(APP_BACKGROUND);
      expect(AppStorage.get<string>(KEY_APP_STATE)).assertEqual(APP_BACKGROUND);
      publishAppState(APP_FOREGROUND);
      expect(AppStorage.get<string>(KEY_APP_STATE)).assertEqual(APP_FOREGROUND);
    });
  });
}
