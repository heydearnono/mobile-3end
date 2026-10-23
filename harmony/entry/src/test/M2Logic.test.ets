import { describe, expect, it } from '@ohos/hypium';
import { FileCache } from '../main/ets/data/FileCache';
import { FileRepository, ListState, LoadKind } from '../main/ets/data/FileRepository';
import { encodeFiles, parseFilesJson } from '../main/ets/data/FilesJson';
import { HttpGet } from '../main/ets/data/HttpClient';
import { MemoryKvStore } from '../main/ets/data/KvStore';
import { FileItem, FileType, SortOrder } from '../main/ets/model/FileItem';

/** M2 纯逻辑检查（本地单测）。网络和存储都换成假的：FakeHttp、MemoryKvStore */

// mock/api/files.json 的前 3 条 + 几条坏数据
// ArkTS 里连测试数据也不能写无类型的对象字面量，所以直接写 JSON 字符串
const BODY: string = '{"files":[' +
  '{"id":"f001","name":"工作资料","type":"folder","size":0,"mtime":1760500000},' +
  '{"id":"f003","name":"季度复盘.docx","type":"doc","size":482133,"mtime":1760830000},' +
  '{"id":"f005","name":"白屏率看板截图.png","type":"image","size":356210,"mtime":1760860000}' +
  ']}';

class FakeHttp implements HttpGet {
  body: string = BODY;
  fail: boolean = false;
  calls: number = 0;

  get(url: string): Promise<string> {
    this.calls++;
    return this.fail ? Promise.reject(new Error('connect refused')) : Promise.resolve(this.body);
  }
}

function item(id: string): FileItem {
  const f: FileItem = { id: id, name: id, type: FileType.DOC, size: 1, mtime: 1 };
  return f;
}

function describeState(s: ListState): string {
  return `${s.kind}:${s.files.map((x: FileItem) => x.id).join('+')}${s.fromCache ? '(cache)' : ''}`;
}

async function run(repo: FileRepository): Promise<string> {
  const seen: string[] = [];
  await repo.load((s: ListState) => {
    seen.push(describeState(s));
  });
  return seen.join(' | ');
}

function setup(cached: FileItem[] | undefined): FileCache {
  const cache = new FileCache(new MemoryKvStore());
  if (cached !== undefined) {
    cache.saveFiles(cached);
  }
  return cache;
}

export default function m2LogicTest() {
  describe('M2Logic', () => {
    it('m2_1_parsesMockResponse', 0, () => {
      const files = parseFilesJson(BODY);
      expect(files.length).assertEqual(3);
      expect(files[0].type).assertEqual(FileType.FOLDER);
      expect(files[2].name).assertEqual('白屏率看板截图.png');
      expect(files[2].size).assertEqual(356210);
      expect(files[1].mtime).assertEqual(1760830000);
    });

    it('m2_1_skipsBadItemsAndDefaultsNumbers', 0, () => {
      const text = '{"files":[' +
        '{"id":"ok","name":"a.md","type":"doc"},' +
        '{"id":"x1","name":"b.zip","type":"archive","size":1,"mtime":1},' +
        '{"name":"no-id.md","type":"doc","size":1,"mtime":1},' +
        '{"id":"x3","type":"doc","size":1,"mtime":1}' +
        ']}';
      const files = parseFilesJson(text);
      expect(files.length).assertEqual(1);
      expect(files[0].id).assertEqual('ok');
      expect(files[0].size).assertEqual(0);
      expect(files[0].mtime).assertEqual(0);
    });

    it('m2_1_throwsOnBadPayload', 0, () => {
      let notJson = false;
      try {
        parseFilesJson('<html>502 Bad Gateway</html>');
      } catch (e) {
        notJson = true;
      }
      let noFiles = false;
      try {
        parseFilesJson('{"data":[]}');
      } catch (e) {
        noFiles = true;
      }
      expect(notJson).assertTrue();
      expect(noFiles).assertTrue();
    });

    it('m2_0_cacheWritesJsonToKv_givenAsExample', 0, () => {
      // 不依赖任何空：没缓存时 loadFiles 返回 undefined；saveFiles 写进 KV 的是和接口同构的 JSON
      const kv = new MemoryKvStore();
      const cache = new FileCache(kv);
      expect(cache.loadFiles()).assertUndefined();
      cache.saveFiles([item('a')]);
      expect(kv.get('files')).assertEqual(encodeFiles([item('a')]));
      expect(kv.get('files')!.startsWith('{"files":[')).assertTrue();
    });

    it('m2_3_orderDefaultsToName', 0, () => {
      expect(new FileCache(new MemoryKvStore()).loadOrder()).assertEqual(SortOrder.NAME);
    });

    it('m2_3_orderRoundTrip', 0, () => {
      const cache = new FileCache(new MemoryKvStore());
      cache.saveOrder(SortOrder.TIME);
      expect(cache.loadOrder()).assertEqual(SortOrder.TIME);
      cache.saveOrder(SortOrder.NAME);
      expect(cache.loadOrder()).assertEqual(SortOrder.NAME);
    });

    it('m2_3_unknownStoredOrderFallsBackToName', 0, () => {
      const kv = new MemoryKvStore();
      kv.put('order', 'SIZE');
      expect(new FileCache(kv).loadOrder()).assertEqual(SortOrder.NAME);
    });

    it('m2_5_noCache_success_loadingThenContent', 0, async () => {
      const cache = setup(undefined);
      const seen = await run(new FileRepository(new FakeHttp(), cache, 'u'));
      expect(seen).assertEqual('loading: | content:f001+f003+f005');
      const saved = cache.loadFiles();
      expect(saved !== undefined && saved.length === 3).assertTrue();
    });

    it('m2_5_cache_success_cacheFirstThenFresh', 0, async () => {
      const seen = await run(new FileRepository(new FakeHttp(), setup([item('old')]), 'u'));
      expect(seen).assertEqual('content:old(cache) | content:f001+f003+f005');
    });

    it('m2_5_noCache_failure_showsError', 0, async () => {
      const http = new FakeHttp();
      http.fail = true;
      const seen = await run(new FileRepository(http, setup(undefined), 'u'));
      expect(seen).assertEqual('loading: | error:');
    });

    it('m2_5_cache_failure_keepsCache', 0, async () => {
      const http = new FakeHttp();
      http.fail = true;
      const cache = setup([item('old')]);
      const seen = await run(new FileRepository(http, cache, 'u'));
      expect(seen).assertEqual('content:old(cache)');
      const kept = cache.loadFiles();
      expect(kept !== undefined && kept[0].id === 'old').assertTrue();
    });

    it('m2_5_emptyListAndBadBody', 0, async () => {
      const http = new FakeHttp();
      http.body = '{"files":[]}';
      expect(await run(new FileRepository(http, setup(undefined), 'u'))).assertEqual('loading: | empty:');
      http.body = 'oops';
      expect(await run(new FileRepository(http, setup(undefined), 'u'))).assertEqual('loading: | error:');
    });

    it('m2_e2e_secondLaunchShowsCacheFromFirst', 0, async () => {
      // 同一个 KV 模拟「重启」：第一次请求成功写了缓存，第二次启动网络断了，仍能显示
      const kv = new MemoryKvStore();
      await run(new FileRepository(new FakeHttp(), new FileCache(kv), 'u'));
      const offline = new FakeHttp();
      offline.fail = true;
      const seen = await run(new FileRepository(offline, new FileCache(kv), 'u'));
      expect(seen).assertEqual('content:f001+f003+f005(cache)');
    });
  });
}
