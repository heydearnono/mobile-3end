import { abilityDelegatorRegistry, Component, Driver, ON } from '@kit.TestKit';
import { Want } from '@kit.AbilityKit';
import { afterAll, beforeAll, describe, expect, it } from '@ohos/hypium';
import { WANT_KEY_SAMPLE } from '../../../main/ets/data/ApiConfig';

/**
 * M1 UI 检查，需要模拟器 / 真机（ohosTest）。测试名前缀 = 覆盖的空。
 * 用 @ohos.UiTest 按组件 id 找控件，id 和 Android 的 testTag 对应：sort、file-list、detail-name。
 *
 * 启动时带 Want 参数 m3e.sample=true，不管 STAGE 是几都用写死的 SampleData（依赖注入）。
 * 依赖 SampleData 的排序结果，同 android/.../M1UiTest.kt：
 * - 「白屏率看板截图.png」名称序第 17 行（不在首屏），时间序第 4 行（在首屏）
 * - 「旅行vlog.mov」名称序第 15 行
 * 测试和 App 跑在同一个进程里，没法每个用例重启 App，所以每个用例开头先把界面归位
 */
const BUNDLE: string = 'com.example.mobile3end';

let driver: Driver;

async function startApp(): Promise<void> {
  const params: Record<string, Object> = {};
  params[WANT_KEY_SAMPLE] = true;
  const want: Want = { bundleName: BUNDLE, abilityName: 'EntryAbility', parameters: params };
  await abilityDelegatorRegistry.getAbilityDelegator().startAbility(want);
  await driver.delayMs(1500);
}

/** 回到列表页、名称序、滚到顶 */
async function reset(): Promise<void> {
  for (let i = 0; i < 3; i++) {
    const back = await driver.findComponent(ON.id('back'));
    if (back === null) {
      break;
    }
    await back.click();
    await driver.delayMs(500);
  }
  const sort = await driver.findComponent(ON.id('sort'));
  if ((await sort.getText()).indexOf('名称') < 0) {
    await sort.click();
    await driver.delayMs(300);
  }
  await (await driver.findComponent(ON.id('file-list'))).scrollToTop();
  await driver.delayMs(300);
}

/** 文字所在的行是否完整地显示在列表可视区域里 */
async function isOnScreen(name: string): Promise<boolean> {
  const row: Component | null = await driver.findComponent(ON.text(name));
  if (row === null) {
    return false;
  }
  const list = await (await driver.findComponent(ON.id('file-list'))).getBounds();
  const r = await row.getBounds();
  return r.top >= list.top && r.bottom <= list.bottom && r.bottom > r.top;
}

async function tap(name: string): Promise<void> {
  await (await driver.findComponent(ON.text(name))).click();
  await driver.delayMs(800);
}

export default function m1UiTest() {
  describe('M1Ui', () => {
    beforeAll(async () => {
      driver = Driver.create();
      await startApp();
    });

    afterAll(async () => {
      await reset();
    });

    it('m1_2_sortToggleResortsList', 0, async () => {
      await reset();
      expect(await isOnScreen('白屏率看板截图.png')).assertFalse();

      const sort = await driver.findComponent(ON.id('sort'));
      await sort.click();
      await driver.delayMs(500);

      expect(await sort.getText()).assertContain('时间');
      expect(await isOnScreen('白屏率看板截图.png')).assertTrue();
    });

    it('m1_3_m1_4_openDetailShowsTappedFile', 0, async () => {
      await reset();
      await tap('Android学习笔记.md');
      const name = await driver.findComponent(ON.id('detail-name'));
      expect(name !== null).assertTrue();
      expect(await name.getText()).assertContain('Android学习笔记.md');
    });

    it('m1_5_m1_6_backButtonReturnsToList', 0, async () => {
      await reset();
      await tap('Android学习笔记.md');
      await (await driver.findComponent(ON.id('back'))).click();
      await driver.delayMs(800);
      expect(await driver.findComponent(ON.id('detail-name')) === null).assertTrue();
      expect(await driver.findComponent(ON.id('sort')) !== null).assertTrue();
    });

    it('m1_e2e_backKeepsScrollPosition', 0, async () => {
      await reset();
      await (await driver.findComponent(ON.id('file-list'))).scrollSearch(ON.text('旅行vlog.mov'));
      await driver.delayMs(300);
      expect(await isOnScreen('旅行vlog.mov')).assertTrue();
      await tap('旅行vlog.mov');
      await (await driver.findComponent(ON.id('back'))).click();
      await driver.delayMs(800);
      expect(await isOnScreen('旅行vlog.mov')).assertTrue();
    });
  });
}
