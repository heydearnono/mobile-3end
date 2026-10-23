import { describe, expect, it } from '@ohos/hypium';
import { crashLog, h5ErrorLine, H5_UNCAUGHT_PREFIX } from '../main/ets/crash/CrashReporter';

/** M5 纯逻辑检查（本地单测）。M5-1（errorManager 钩子）要在设备上手工验，见 hints */
export default function m5LogicTest() {
  describe('M5Logic', () => {
    it('m5_0_crashLog_givenAsExample', 0, () => {
      expect(crashLog('Error', 'boom', 'at a (x.ets:1:1)')).assertEqual('[CRASH] Error: boom\nat a (x.ets:1:1)');
    });

    it('m5_2_uncaughtErrorIsReported', 0, () => {
      const line = h5ErrorLine(true, 'Uncaught Error: [case=blank] simulated crash before mount',
        'https://h5.offline.test/app.js', 9);
      expect(line).assertEqual(
        '[H5_ERROR] Uncaught Error: [case=blank] simulated crash before mount @ https://h5.offline.test/app.js:9');
    });

    it('m5_2_hookedStackIsReported', 0, () => {
      const msg = `${H5_UNCAUGHT_PREFIX} Error: boom\n    at https://h5.offline.test/app.js:9:11`;
      expect(h5ErrorLine(true, msg, 'https://h5.offline.test/index.html', 1)).assertContain('app.js:9:11');
    });

    it('m5_2_ordinaryLogsAreIgnored', 0, () => {
      expect(h5ErrorLine(true, 'missing.js load failed (expected)', 'x', 1)).assertUndefined();
      expect(h5ErrorLine(false, 'Uncaught Error: but logged as info', 'x', 1)).assertUndefined();
    });
  });
}
