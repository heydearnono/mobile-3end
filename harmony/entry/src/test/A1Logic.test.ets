import { describe, expect, it } from '@ohos/hypium';
import { checksum, withTimeout } from '../main/ets/a1/Async';
import { PackageManifest, PackageMode, RawManifest, toPackageMode } from '../main/ets/a1/Json';
import { nameOf, requireFile } from '../main/ets/a1/NullSafety';
import { predictRefresh, renameFile, STATE_QUIZ } from '../main/ets/a1/State';
import { countByType, parseQuery } from '../main/ets/a1/Strict';
import { FileItem, FileType } from '../main/ets/model/FileItem';

/** A1 ArkTS 语言专项（本地单测，不需要设备） */

function file(id: string, name: string, type: FileType): FileItem {
  const f: FileItem = { id: id, name: name, type: type, size: 1, mtime: 1 };
  return f;
}

const FILES: FileItem[] = [
  file('d1', '工作资料', FileType.FOLDER),
  file('f1', '季度复盘.docx', FileType.DOC),
  file('f2', '接口文档.md', FileType.DOC),
  file('f3', '白屏截图.png', FileType.IMAGE),
];

function byId(files: FileItem[]): Map<string, FileItem> {
  const m = new Map<string, FileItem>();
  files.forEach((f: FileItem) => m.set(f.id, f));
  return m;
}

const MANIFEST: string =
  '{"name":"demo-h5","version":3,"entry":"index.html","mode":"offline",' +
    '"files":{"index.html":"9f2c01","app.js":"1ab0e7"}}';

function sleep<T>(ms: number, value: T): Promise<T> {
  return new Promise<T>((resolve: (v: T) => void) => {
    setTimeout(() => resolve(value), ms);
  });
}

export default function a1LogicTest() {
  describe('A1Logic', () => {
    it('a1_0_asDoesNotCreateInstance_givenAsExample', 0, () => {
      // 不依赖任何空：as 只骗编译器。JSON 里 mode 写错了，类型上照样是 string，instanceof 也是 false
      const raw = JSON.parse('{"name":"x","mode":"OFFLINE"}') as RawManifest;
      expect(raw.mode).assertEqual('OFFLINE');
      expect(toPackageMode(raw.mode)).assertUndefined();
      expect(toPackageMode('offline')).assertEqual(PackageMode.OFFLINE);
      const fake = JSON.parse(MANIFEST) as PackageManifest;
      expect(fake instanceof PackageManifest).assertFalse();
      expect(fake.version).assertEqual(3);
    });

    // ---------- 第 1 节 严格模式 ----------

    it('a1_1_countsEachType', 0, () => {
      const count = countByType(FILES);
      expect(count['folder']).assertEqual(1);
      expect(count['doc']).assertEqual(2);
      expect(count['image']).assertEqual(1);
      expect(JSON.stringify(count)).assertEqual('{"folder":1,"doc":2,"image":1}');
    });

    it('a1_1_emptyAndMissingTypes', 0, () => {
      expect(JSON.stringify(countByType([]))).assertEqual('{}');
      expect(Object.keys(countByType(FILES)).indexOf('video')).assertEqual(-1);
    });

    it('a1_2_parsesBridgeQuery', 0, () => {
      const q = parseQuery('method=getFiles&dir=%2F%E5%B7%A5%E4%BD%9C&flag');
      expect(q.size).assertEqual(3);
      expect(q.get('method')).assertEqual('getFiles');
      expect(q.get('dir')).assertEqual('/工作');
      expect(q.get('flag')).assertEqual('');
    });

    it('a1_2_valueMayContainEquals', 0, () => {
      const q = parseQuery('cb=a%3Db&sig=x==');
      expect(q.get('cb')).assertEqual('a=b');
      expect(q.get('sig')).assertEqual('x==');
    });

    it('a1_2_skipsEmptyPartsAndLastWins', 0, () => {
      const q = parseQuery('&a=1&&a=2&');
      expect(q.size).assertEqual(1);
      expect(q.get('a')).assertEqual('2');
      expect(parseQuery('').size).assertEqual(0);
    });

    it('a1_2_decodesKeys', 0, () => {
      expect(parseQuery('%E5%90%8D=v').get('名')).assertEqual('v');
    });

    // ---------- 第 2 节 JSON ----------

    it('a1_3_parsesManifest', 0, () => {
      const m = PackageManifest.parse(MANIFEST);
      expect(m instanceof PackageManifest).assertTrue();
      const ok = m!;
      expect(ok.name).assertEqual('demo-h5');
      expect(ok.version).assertEqual(3);
      expect(ok.entry).assertEqual('index.html');
      expect(ok.mode).assertEqual(PackageMode.OFFLINE);
      expect(ok.files.size).assertEqual(2);
      // 方法能调：说明是 new 出来的实例，不是 as 出来的
      expect(ok.hashOf('app.js')).assertEqual('1ab0e7');
      expect(ok.hashOf('missing.js')).assertUndefined();
    });

    it('a1_3_rejectsBadJson', 0, () => {
      expect(PackageManifest.parse('<html>404</html>')).assertUndefined();
      expect(PackageManifest.parse('null')).assertUndefined();
      expect(PackageManifest.parse('3')).assertUndefined();
      expect(PackageManifest.parse('"offline"')).assertUndefined();
    });

    it('a1_3_rejectsBadFields', 0, () => {
      expect(PackageManifest.parse('{"version":3,"entry":"index.html","mode":"offline"}')).assertUndefined();
      expect(PackageManifest.parse('{"name":"","version":3,"entry":"index.html","mode":"offline"}')).assertUndefined();
      expect(PackageManifest.parse('{"name":"x","version":"3","entry":"index.html","mode":"offline"}')).assertUndefined();
      expect(PackageManifest.parse('{"name":"x","version":3,"entry":7,"mode":"offline"}')).assertUndefined();
      expect(PackageManifest.parse('{"name":"x","version":3,"entry":"","mode":"offline"}')).assertUndefined();
      expect(PackageManifest.parse('{"name":"x","version":3,"entry":"index.html","mode":"OFFLINE"}')).assertUndefined();
      expect(PackageManifest.parse('{"name":"x","version":3,"entry":"index.html"}')).assertUndefined();
    });

    it('a1_3_filesOptionalAndFiltered', 0, () => {
      const noFiles = PackageManifest.parse('{"name":"x","version":0,"entry":"a.html","mode":"online"}');
      expect(noFiles !== undefined && noFiles.files.size === 0 && noFiles.mode === PackageMode.ONLINE).assertTrue();
      const mixed = PackageManifest.parse(
        '{"name":"x","version":1,"entry":"a.html","mode":"offline","files":{"a.html":"aa","b.js":12,"c.css":null,"d":{}}}');
      expect(mixed !== undefined && mixed.files.size === 1 && mixed.hashOf('a.html') === 'aa').assertTrue();
      const badFiles = PackageManifest.parse('{"name":"x","version":1,"entry":"a.html","mode":"offline","files":"nope"}');
      expect(badFiles !== undefined && badFiles.files.size === 0).assertTrue();
    });

    it('a1_4_toJson', 0, () => {
      const files = new Map<string, string>();
      files.set('index.html', '9f2c01');
      files.set('app.js', '1ab0e7');
      const m = new PackageManifest('demo-h5', 3, 'index.html', PackageMode.OFFLINE, files);
      expect(m.toJson()).assertEqual(MANIFEST);
    });

    it('a1_3_a1_4_roundTrip', 0, () => {
      const m = PackageManifest.parse(MANIFEST)!;
      m.files.set('style.css', '77aa00');
      const again = PackageManifest.parse(m.toJson())!;
      expect(again.hashOf('style.css')).assertEqual('77aa00');
      expect(again.toJson()).assertEqual(m.toJson());
    });

    // ---------- 第 3 节 空安全 ----------

    it('a1_5_nameOrFallback', 0, () => {
      const m = byId(FILES);
      expect(nameOf(m, 'f2')).assertEqual('接口文档.md');
      expect(nameOf(m, 'nope')).assertEqual('文件不存在');
    });

    it('a1_5_emptyNameIsKept', 0, () => {
      // ?? 只在 null / undefined 时兜底，'' 不算；写成 || 就错了
      expect(nameOf(byId([file('e', '', FileType.DOC)]), 'e')).assertEqual('');
    });

    it('a1_6_returnsFile', 0, () => {
      expect(requireFile(byId(FILES), 'f3').name).assertEqual('白屏截图.png');
    });

    it('a1_6_throwsWithId', 0, () => {
      let message = '';
      try {
        const f = requireFile(byId(FILES), 'x9');
        message = `没抛异常，拿到了 ${typeof f}`;
      } catch (e) {
        message = (e as Error).message;
      }
      expect(message).assertEqual('找不到文件 x9');
    });

    // ---------- 第 4 节 状态 ----------

    it('a1_7_renamesTargetOnly', 0, () => {
      const out = renameFile(FILES, 'f1', '年度复盘.docx');
      expect(out.length).assertEqual(FILES.length);
      expect(out[1].name).assertEqual('年度复盘.docx');
      expect(out[1].id).assertEqual('f1');
      expect(out[1].type).assertEqual(FileType.DOC);
    });

    it('a1_7_doesNotMutateInput', 0, () => {
      const before = JSON.stringify(FILES);
      const out = renameFile(FILES, 'f1', '新名字');
      expect(JSON.stringify(FILES)).assertEqual(before);
      expect(out === FILES).assertFalse();
      expect(out[1] === FILES[1]).assertFalse();
    });

    it('a1_7_keepsOtherObjects', 0, () => {
      const out = renameFile(FILES, 'f1', '新名字');
      expect(out[0] === FILES[0]).assertTrue();
      expect(out[2] === FILES[2]).assertTrue();
      expect(out[3] === FILES[3]).assertTrue();
    });

    it('a1_7_unknownIdReturnsSameArray', 0, () => {
      expect(renameFile(FILES, 'nope', 'x') === FILES).assertTrue();
    });

    it('a1_8_predictRefresh', 0, () => {
      const answer = predictRefresh();
      expect(answer.length).assertEqual(STATE_QUIZ.length);
      const wrong: number[] = [];
      // key 就是答案（y = 会刷新），做完再看
      const key = 'yyynnynyny';
      answer.forEach((v: boolean, i: number) => {
        if (v !== (key.charAt(i) === 'y')) {
          wrong.push(i + 1);
        }
      });
      expect(wrong.length === 0 ? '全对' : `第 ${wrong.join('、')} 题不对`).assertEqual('全对');
    });

    // ---------- 第 5 节 async / TaskPool ----------

    it('a1_9_fastTaskWins', 0, async () => {
      expect(await withTimeout<string>(sleep<string>(10, 'data'), 500, 'timeout')).assertEqual('data');
    });

    it('a1_9_slowTaskTimesOut', 0, async () => {
      const start = Date.now();
      const r = await withTimeout<string>(sleep<string>(1000, 'data'), 50, 'timeout');
      expect(r).assertEqual('timeout');
      expect(Date.now() - start < 800).assertTrue();
    });

    it('a1_9_rejectionPassesThrough', 0, async () => {
      let message = '';
      try {
        await withTimeout<string>(Promise.reject<string>(new Error('net down')), 500, 'timeout');
        message = '没有 reject';
      } catch (e) {
        message = (e as Error).message;
      }
      expect(message).assertEqual('net down');
    });

    it('a1_10_knownValues', 0, () => {
      expect(checksum('')).assertEqual('811c9dc5');
      expect(checksum('a')).assertEqual('e40c292c');
      expect(checksum('foobar')).assertEqual('bf9cf968');
    });

    it('a1_10_padsAndHandlesNonAscii', 0, () => {
      expect(checksum('akd')).assertEqual('0d368b73');
      expect(checksum('白屏')).assertEqual('240135a5');
      expect(checksum('index.html')).assertEqual('efe35522');
    });
  });
}
