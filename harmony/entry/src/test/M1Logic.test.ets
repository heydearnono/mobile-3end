import { describe, expect, it } from '@ohos/hypium';
import { FileItem, fileKey, FileType, SortOrder, sortFiles } from '../main/ets/model/FileItem';
import { SampleData } from '../main/ets/model/SampleData';
import { detailIdOf, goBack, openDetail, ROUTE_DETAIL, ROUTE_H5 } from '../main/ets/nav/Routes';

/**
 * M1 纯逻辑检查，本地单测（跑在 DevEco 自带的预览器运行时里，不需要模拟器）。测试名前缀 = 覆盖的空。
 * NavPathStack 是 ArkUI 的普通类，不绑 Navigation 也能用，所以路由逻辑能在这里测
 */
function f(id: string, name: string, type: FileType, mtime: number): FileItem {
  const item: FileItem = { id: id, name: name, type: type, size: 1, mtime: mtime };
  return item;
}

const input: FileItem[] = [
  f('a', 'a.txt', FileType.DOC, 10),
  f('F1', 'F1', FileType.FOLDER, 1),
  f('b', 'b.txt', FileType.DOC, 30),
  f('c', 'c.png', FileType.IMAGE, 20),
  f('F2', 'F2', FileType.FOLDER, 5),
];

function ids(list: FileItem[]): string {
  return list.map((x: FileItem) => x.id).join(',');
}

function paramOf(stack: NavPathStack, name: string): Object | undefined {
  // getParamByName 返回 Array<unknown>，ArkTS 不允许 unknown 落到变量上，要立刻断言成具体类型
  const params = stack.getParamByName(name) as Object[];
  return params.length > 0 ? params[0] : undefined;
}

export default function m1LogicTest() {
  describe('M1Logic', () => {
    it('m1_0_sortFiles_givenAsExample', 0, () => {
      expect(ids(sortFiles(input, SortOrder.NAME))).assertEqual('F1,F2,a,b,c');
      expect(ids(sortFiles(input, SortOrder.TIME))).assertEqual('F2,F1,b,c,a');
      expect(ids(input)).assertEqual('a,F1,b,c,F2'); // 不改入参
    });

    it('m1_0_sampleDataOrderMatchesAndroid', 0, () => {
      // UI 测试依赖的几个位置，和 android/.../M1UiTest.kt 注释里的「第 n 行」一致（n 从 0 数）
      const byName = sortFiles(SampleData.files, SortOrder.NAME).map((x: FileItem) => x.name);
      const byTime = sortFiles(SampleData.files, SortOrder.TIME).map((x: FileItem) => x.name);
      expect(byName.indexOf('Demo演示.mp4')).assertEqual(4);
      expect(byName.indexOf('旅行vlog.mov')).assertEqual(15);
      expect(byName.indexOf('白屏率看板截图.png')).assertEqual(17);
      expect(byTime.indexOf('白屏率看板截图.png')).assertEqual(4);
      expect(byTime.indexOf('Demo演示.mp4')).assertEqual(19);
    });

    it('m1_1_keyStaysSameWhenOtherFieldsChange', 0, () => {
      const before = f('x1', '旧名字.txt', FileType.DOC, 100);
      const after = f('x1', '新名字.txt', FileType.DOC, 200);
      expect(fileKey(after)).assertEqual(fileKey(before));
    });

    it('m1_1_keysAreUniqueInSampleData', 0, () => {
      const keys = new Set<string>(SampleData.files.map((x: FileItem) => fileKey(x)));
      expect(keys.size).assertEqual(SampleData.files.length);
    });

    it('m1_3_openDetailPushesDetailWithId', 0, () => {
      const stack = new NavPathStack();
      openDetail(stack, f('f10', 'Android学习笔记.md', FileType.DOC, 1));
      expect(stack.size()).assertEqual(1);
      expect(stack.getAllPathName().join(',')).assertEqual(ROUTE_DETAIL);
      expect(paramOf(stack, ROUTE_DETAIL) as string).assertEqual('f10');
    });

    it('m1_4_detailIdOfReadsStringParam', 0, () => {
      const stack = new NavPathStack();
      stack.pushPathByName(ROUTE_DETAIL, 'f10');
      expect(detailIdOf(paramOf(stack, ROUTE_DETAIL))).assertEqual('f10');
    });

    it('m1_4_detailIdOfRejectsNonString', 0, () => {
      expect(detailIdOf(undefined)).assertUndefined();
      const n: number = 42;
      expect(detailIdOf(n as Object)).assertUndefined();
    });

    it('m1_5_goBackPopsOnlyTheTopPage', 0, () => {
      const stack = new NavPathStack();
      stack.pushPathByName(ROUTE_H5, 'u');
      stack.pushPathByName(ROUTE_DETAIL, 'f10');
      goBack(stack);
      expect(stack.getAllPathName().join(',')).assertEqual(ROUTE_H5);
    });

    it('m1_e2e_openThenBackReturnsToList', 0, () => {
      const stack = new NavPathStack();
      openDetail(stack, f('f10', 'Android学习笔记.md', FileType.DOC, 1));
      goBack(stack);
      expect(stack.size()).assertEqual(0);
    });
  });
}
