import { describe, expect, it } from '@ohos/hypium';
import { BridgeDispatcher, BridgeEnv, DeviceInfo, ERR_METHOD_NOT_FOUND } from '../main/ets/web/Bridge';
import { mimeOf, OFFLINE_ENTRY, offlinePathOf, originOf, resolveOffline } from '../main/ets/web/OfflinePackage';
import {
  CheckDecision, CHECK_DELAY_MS, ROOT_CHILD_COUNT_JS, singleCheckPolicy, SLOW_DEADLINE_MS, slowAwarePolicy,
  WhitePolicy, WhiteScreenHost, WhiteScreenMonitor
} from '../main/ets/web/WhiteScreen';

/**
 * M4 纯逻辑检查（本地单测）：离线包路由、bridge 分发、白屏判定。
 * WebResourceResponse / runJavaScript 这些 ArkWeb 胶水在本地单测里是空壳，按 hints 里的手工步骤在设备上验
 */

// ---- 离线包 ----

class FakePackage {
  files: Map<string, ArrayBuffer> = new Map<string, ArrayBuffer>();
  reads: string[] = [];

  constructor(paths: string[]) {
    paths.forEach((p: string) => this.files.set(p, new ArrayBuffer(p.length)));
  }

  read(path: string): ArrayBuffer | undefined {
    this.reads.push(path);
    return this.files.get(path);
  }
}

function pkg(): FakePackage {
  return new FakePackage(['h5/index.html', 'h5/app.js', 'h5/style.css', 'h5/sub/index.html']);
}

// ---- bridge ----

interface CallbackError {
  code: string;
  message: string;
}

interface CallbackView {
  id: string;
  ok: boolean;
  data?: Record<string, Object>;
  error?: CallbackError;
}

const CB_PREFIX: string = 'window.__bridgeCallback(';

function parseCallback(js: string | undefined): CallbackView {
  if (js === undefined || !js.startsWith(CB_PREFIX) || !js.endsWith(')')) {
    throw new Error(`不是回调脚本：${js}`);
  }
  return JSON.parse(js.substring(CB_PREFIX.length, js.length - 1)) as CallbackView;
}

class FakeEnv {
  toasts: string[] = [];

  env(): BridgeEnv {
    const e: BridgeEnv = {
      deviceInfo: (): DeviceInfo => {
        const d: DeviceInfo = { platform: 'harmony', osVersion: 'test-os', appVersion: '1.0.0' };
        return d;
      },
      toast: (text: string): void => {
        this.toasts.push(text);
      },
    };
    return e;
  }
}

const PAGE: string = OFFLINE_ENTRY + '?case=normal';

// ---- 白屏 ----

class Scheduled {
  delay: number;
  task: () => Promise<void>;

  constructor(delay: number, task: () => Promise<void>) {
    this.delay = delay;
    this.task = task;
  }
}

class FakeHost {
  queue: Scheduled[] = [];
  results: string[] = [];
  scripts: string[] = [];
  reports: string[] = [];

  host(): WhiteScreenHost {
    const h: WhiteScreenHost = {
      schedule: (delayMs: number, task: () => Promise<void>): void => {
        this.queue.push(new Scheduled(delayMs, task));
      },
      evaluate: (js: string): Promise<string> => {
        this.scripts.push(js);
        return Promise.resolve(this.results.length > 0 ? this.results.shift()! : '0');
      },
      report: (line: string): void => {
        this.reports.push(line);
      },
    };
    return h;
  }

  /** 执行最早排队的一个任务，返回它的延迟 */
  async runNext(): Promise<number> {
    const next = this.queue.shift();
    if (next === undefined) {
      return -1;
    }
    await next.task();
    return next.delay;
  }

  async runAll(): Promise<void> {
    while (this.queue.length > 0) {
      await this.runNext();
    }
  }
}

const URL1: string = OFFLINE_ENTRY + '?case=blank';

export default function m4LogicTest() {
  describe('M4Logic', () => {
    it('m4_0_mimeOf_givenAsExample', 0, () => {
      expect(mimeOf('index.html')).assertEqual('text/html');
      expect(mimeOf('a/b/app.JS')).assertEqual('application/javascript');
      expect(mimeOf('sub.dir/README')).assertEqual('application/octet-stream');
    });

    it('m4_1_originOfBasic', 0, () => {
      expect(originOf('https://h5.offline.test/index.html?case=blank')).assertEqual('https://h5.offline.test');
      expect(originOf('HTTPS://H5.Offline.TEST/x')).assertEqual('https://h5.offline.test');
      expect(originOf('https://h5.offline.test?x=1')).assertEqual('https://h5.offline.test');
      expect(originOf('about:blank')).assertEqual('');
    });

    it('m4_1_originOfLookalikes', 0, () => {
      expect(originOf('https://h5.offline.test.evil.com/index.html')).assertEqual('https://h5.offline.test.evil.com');
      expect(originOf('https://h5.offline.test@evil.com/index.html')).assertEqual('https://evil.com');
      expect(originOf('http://h5.offline.test/index.html')).assertEqual('http://h5.offline.test');
    });

    it('m4_1_m4_2_pathOfOfflineUrls', 0, () => {
      expect(offlinePathOf(OFFLINE_ENTRY + '?case=blank')).assertEqual('index.html');
      expect(offlinePathOf('https://h5.offline.test')).assertEqual('index.html');
      expect(offlinePathOf('https://h5.offline.test/')).assertEqual('index.html');
      expect(offlinePathOf('https://h5.offline.test/sub/')).assertEqual('sub/index.html');
      expect(offlinePathOf('https://h5.offline.test/app.js#top')).assertEqual('app.js');
      expect(offlinePathOf('https://h5.offline.test/%E4%B8%AD.png?v=1')).assertEqual('中.png');
    });

    it('m4_1_m4_2_foreignUrlsAreNotOurs', 0, () => {
      expect(offlinePathOf('https://example.com/index.html')).assertUndefined();
      expect(offlinePathOf('https://h5.offline.test.evil.com/index.html')).assertUndefined();
      expect(offlinePathOf('http://h5.offline.test/index.html')).assertUndefined();
    });

    it('m4_3_hitReturns200WithMime', 0, () => {
      const p = pkg();
      const r = resolveOffline(OFFLINE_ENTRY + '?case=missing', (path: string) => p.read(path));
      expect(r !== undefined).assertTrue();
      expect(r!.status).assertEqual(200);
      expect(r!.reason).assertEqual('OK');
      expect(r!.mime).assertEqual('text/html');
      expect(r!.data).assertEqual(p.files.get('h5/index.html'));
      expect(r!.log).assertEqual('');
      expect(p.reads.join(',')).assertEqual('h5/index.html');
      expect(resolveOffline('https://h5.offline.test/style.css', (path: string) => p.read(path))!.mime)
        .assertEqual('text/css');
    });

    it('m4_3_missReturns404AndLogsFullUrl', 0, () => {
      const p = pkg();
      const url = 'https://h5.offline.test/missing.js?v=2';
      const r = resolveOffline(url, (path: string) => p.read(path));
      expect(r!.status).assertEqual(404);
      expect(r!.reason).assertEqual('Not Found');
      expect(r!.mime).assertEqual('text/plain');
      expect(r!.data).assertUndefined();
      expect(r!.log).assertEqual('[OFFLINE_404] ' + url);
    });

    it('m4_3_foreignUrlIsPassedThrough', 0, () => {
      const p = pkg();
      expect(resolveOffline('https://example.com/', (path: string) => p.read(path))).assertUndefined();
      expect(p.reads.length).assertEqual(0);
    });

    it('m4_3_pathTraversalIsBlocked', 0, () => {
      const p = pkg();
      const a = resolveOffline('https://h5.offline.test/../secret.txt', (path: string) => p.read(path));
      const b = resolveOffline('https://h5.offline.test/sub/%2e%2e/%2e%2e/x', (path: string) => p.read(path));
      expect(a!.status).assertEqual(404);
      expect(b!.status).assertEqual(404);
      expect(p.reads.length).assertEqual(0);
    });

    it('m4_1_m4_5_getDeviceInfo', 0, () => {
      const cb = parseCallback(new BridgeDispatcher(new FakeEnv().env())
        .handle('{"id":"1","method":"getDeviceInfo","params":{}}', PAGE));
      expect(cb.id).assertEqual('1');
      expect(cb.ok).assertTrue();
      expect(cb.data!['platform'] as string).assertEqual('harmony');
      expect(cb.data!['appVersion'] as string).assertEqual('1.0.0');
    });

    it('m4_1_m4_5_toastCallsNativeAndSucceeds', 0, () => {
      const fake = new FakeEnv();
      const d = new BridgeDispatcher(fake.env());
      const cb = parseCallback(d.handle('{"id":"2","method":"toast","params":{"text":"你好"}}', PAGE));
      expect(cb.ok).assertTrue();
      expect(JSON.stringify(cb.data)).assertEqual('{}');
      d.handle('{"id":"3","method":"toast"}', PAGE);
      expect(fake.toasts.join('|')).assertEqual('你好|');
    });

    it('m4_1_m4_5_unknownMethodIsNotFound', 0, () => {
      const fake = new FakeEnv();
      const cb = parseCallback(new BridgeDispatcher(fake.env()).handle('{"id":"9","method":"notExist"}', PAGE));
      expect(cb.id).assertEqual('9');
      expect(cb.ok).assertFalse();
      expect(cb.error!.code).assertEqual(ERR_METHOD_NOT_FOUND);
      expect(cb.error!.message).assertContain('notExist');
      expect(fake.toasts.length).assertEqual(0);
    });

    it('m4_1_m4_5_ignoresOtherOrigins', 0, () => {
      const fake = new FakeEnv();
      const d = new BridgeDispatcher(fake.env());
      const msg = '{"id":"1","method":"toast","params":{"text":"x"}}';
      expect(d.handle(msg, 'https://example.com/')).assertUndefined();
      expect(d.handle(msg, 'https://h5.offline.test.evil.com/index.html')).assertUndefined();
      expect(d.handle(msg, 'https://h5.offline.test@evil.com/index.html')).assertUndefined();
      expect(fake.toasts.length).assertEqual(0);
    });

    it('m4_1_m4_5_ignoresMalformedMessages', 0, () => {
      const d = new BridgeDispatcher(new FakeEnv().env());
      expect(d.handle('not json', PAGE)).assertUndefined();
      expect(d.handle('{"method":"getDeviceInfo"}', PAGE)).assertUndefined();
      expect(d.handle('null', PAGE)).assertUndefined();
    });

    it('m4_0_renderExitedAndReportOnce_givenAsExample', 0, () => {
      const h = new FakeHost();
      const m = new WhiteScreenMonitor(h.host(), singleCheckPolicy);
      m.onPageBegin(URL1);
      m.onRenderExited(URL1);
      m.onRenderExited(URL1);
      expect(h.reports.join('\n')).assertEqual(`[WHITE_SCREEN] reason=render_gone url=${URL1}`);
    });

    it('m4_7_emptyRootReportedAfter1s', 0, async () => {
      const h = new FakeHost();
      const m = new WhiteScreenMonitor(h.host(), singleCheckPolicy);
      m.onPageBegin(URL1);
      m.onPageEnd(URL1);
      expect(h.scripts.length).assertEqual(0); // 不能立刻查
      expect(await h.runNext()).assertEqual(CHECK_DELAY_MS);
      expect(h.scripts.join('')).assertEqual(ROOT_CHILD_COUNT_JS);
      expect(h.reports.join('\n')).assertEqual(`[WHITE_SCREEN] reason=empty_root url=${URL1}`);
    });

    it('m4_7_renderedPageIsNotReported', 0, async () => {
      const h = new FakeHost();
      h.results = ['5'];
      const m = new WhiteScreenMonitor(h.host(), singleCheckPolicy);
      m.onPageBegin(OFFLINE_ENTRY);
      m.onPageEnd(OFFLINE_ENTRY);
      await h.runAll();
      expect(h.reports.length).assertEqual(0);
    });

    it('m4_7_retriesWhilePolicySaysRetry', 0, async () => {
      const seen: number[] = [];
      const policy: WhitePolicy = (elapsed: number, count: number): CheckDecision => {
        seen.push(elapsed);
        return elapsed < 3000 ? CheckDecision.RETRY : CheckDecision.WHITE;
      };
      const h = new FakeHost();
      const m = new WhiteScreenMonitor(h.host(), policy);
      m.onPageBegin(URL1);
      m.onPageEnd(URL1);
      await h.runAll();
      expect(seen.join(',')).assertEqual('1000,2000,3000');
      expect(h.reports.length).assertEqual(1);
    });

    it('m4_7_newPageCancelsPendingCheck', 0, async () => {
      const h = new FakeHost();
      const m = new WhiteScreenMonitor(h.host(), singleCheckPolicy);
      m.onPageBegin(URL1);
      m.onPageEnd(URL1);
      m.onPageBegin('https://example.com/'); // 1s 内用户点了别的页面
      await h.runAll();
      expect(h.reports.length).assertEqual(0);
    });

    it('m4_8_onlyMainFrameErrorIsWhiteScreen', 0, () => {
      const h = new FakeHost();
      const m = new WhiteScreenMonitor(h.host(), singleCheckPolicy);
      m.onPageBegin(URL1);
      m.onErrorReceive('https://cdn.example.com/a.png', false);
      expect(h.reports.length).assertEqual(0);
      m.onErrorReceive('https://nope.invalid/', true);
      expect(h.reports.join('\n')).assertEqual('[WHITE_SCREEN] reason=load_error url=https://nope.invalid/');
    });

    it('m4_9_policyBottomLines', 0, () => {
      expect(slowAwarePolicy(1000, 3)).assertEqual(CheckDecision.OK);
      expect(slowAwarePolicy(SLOW_DEADLINE_MS + 1000, 1)).assertEqual(CheckDecision.OK);
      expect(slowAwarePolicy(1000, 0) === CheckDecision.WHITE).assertFalse();
      expect(slowAwarePolicy(SLOW_DEADLINE_MS, 0)).assertEqual(CheckDecision.WHITE);
    });

    it('m4_e2e_slowNotReported_blankReportedByDeadline', 0, async () => {
      // slow：3s 才渲染
      const slow = new FakeHost();
      slow.results = ['0', '0', '4'];
      const m1 = new WhiteScreenMonitor(slow.host(), slowAwarePolicy);
      m1.onPageBegin(OFFLINE_ENTRY + '?case=slow');
      m1.onPageEnd(OFFLINE_ENTRY + '?case=slow');
      await slow.runAll();
      expect(slow.reports.length).assertEqual(0);
      // blank：一直是空的，截止前必须报出来，且只报一次
      const blank = new FakeHost();
      const m2 = new WhiteScreenMonitor(blank.host(), slowAwarePolicy);
      m2.onPageBegin(URL1);
      m2.onPageEnd(URL1);
      await blank.runAll();
      expect(blank.reports.length).assertEqual(1);
      expect(blank.scripts.length <= SLOW_DEADLINE_MS / CHECK_DELAY_MS).assertTrue();
    });
  });
}
