# 鸿蒙 M2 提示与答案

开始前：把 `entry/src/main/ets/common/Stage.ets` 改成 `STAGE = 2`。列表改为走网络 + 缓存，排序开始持久化。

分级提示、notes 记录规则同 `harmony-M1.md`。

检查范围：
- M2-1、M2-3、M2-5 有本地单测
- M2-2（Preferences）、M2-4（http）依赖系统能力，本地单测里这些 API 是空壳，只在设备测试（ohosTest）里查
- M2-6 在页面里，靠下面的手工验收
- 建议顺序：M2-1 → M2-3 → M2-5（纯逻辑，本地就能全绿）→ 手工任务 A、B → M2-2、M2-4 → M2-6

---

## 手工任务 A：网络权限

鸿蒙访问网络要在 `entry/src/main/module.json5` 的 `module` 下声明权限，和 Android 的 `<uses-permission android:name="android.permission.INTERNET"/>` 一样：

```json5
"requestPermissions": [
  { "name": "ohos.permission.INTERNET" }
],
```

不声明的话，`http.request` 直接失败，错误码 201（Permission denied）。编译时 ArkTS 也会给一条 WARN：`To use this API, you need to apply for the permissions: ohos.permission.INTERNET`，先别加，🔬 看看列表页的失败态上显示什么，再加上。

## 手工任务 B：明文 http

**这一条和 spec 的说法不一样**。spec 写「三端默认都限制明文请求」，但查到的鸿蒙文档（OpenHarmony 文档「使用 HTTP 访问网络 · 明文 HTTP 访问权限配置说明」，以及 SDK 里 `networkSecurity.isCleartextPermitted` 的注释）是：

- 配置文件固定在 `entry/src/main/resources/base/profile/network_config.json`，不用在 module.json5 里引用
- `cleartextTrafficPermitted` 默认 `true`：**`@ohos.net.http` 默认允许明文**。API 18 起默认允许且不可配置，API 20 起可以配置关掉
- 优先级：`component-config` > `domain-config` > `base-config`
- `component-config` 决定每个组件是否遵守这份配置：`Request` / `Network Kit` 默认遵守，`ArkWeb` 默认不遵守；`Remote Communication Kit`（rcp）和 Media Kit 从 API 23 起可配

所以这一端的学习点反过来：**先确认默认能通，再自己关掉明文，看它怎么报错，最后只对 mock 地址放行**。

1. 🔬 什么都不配，`STAGE = 2` 跑起来，列表能出来（前提是任务 A 做了、mock 服务开着、`ApiConfig.ets` 的地址对）
2. 新建 `network_config.json`，全局禁止明文：

   ```json
   {
     "network-security-config": {
       "base-config": {
         "cleartextTrafficPermitted": false
       }
     }
   }
   ```

   🔬 重新安装，列表进入失败态。记下错误信息（应该是 `2300997 Cleartext traffic not permitted`）
3. 只对 mock 地址放行：

   ```json
   {
     "network-security-config": {
       "base-config": {
         "cleartextTrafficPermitted": false
       },
       "domain-config": [
         {
           "domains": [{ "include-subdomains": false, "name": "10.0.2.2" }],
           "cleartextTrafficPermitted": true
         }
       ]
     }
   }
   ```

   🔬 列表恢复了吗？`name` 写 IP 管用吗？和 Android M2 里 `network_security_config.xml` 的 `domain-config` 对照（那边对 IP 的支持也是常见坑）

结论写进 notes，并更新 `compare.md` 的「明文 http 放行」行。文档里给的示例 JSON 少逗号、带注释，照抄会解析失败，用上面这份。

## 手工任务 C：模拟器访问宿主机的地址

`data/ApiConfig.ets` 的 `API_BASE` 先填的是 `http://10.0.2.2:8000`。依据：华为开发者文档《使用模拟器访问网络》（Accessing the Network Using the Emulator）写的是「模拟器通过 10.0.2.2:<端口> 访问本机服务，10.0.2.2 是模拟器的默认网关」，和 Android 模拟器同一套 QEMU 用户态网络。

🔬 实测：

1. 仓库根目录 `python3 -m http.server 8000 -d mock`
2. `hdc shell`，在设备里 `curl -v http://10.0.2.2:8000/api/files.json`（设备没有 curl 就跳过，直接看 App）
3. 不通的话试反向端口转发：`hdc rport tcp:8000 tcp:8000`（设备的 8000 → Mac 的 8000），`API_BASE` 改成 `http://127.0.0.1:8000`
4. 真机用 Mac 的局域网 IP（`ipconfig getifaddr en0`），手机和 Mac 同一个 Wi-Fi

哪个通、哪个不通，记到 `notes/harmony-M2.md`，并把 README 里「鸿蒙模拟器：待实测」那一格填上。

---

## M2-1 解码 JSON · `data/FilesJson.ets`

<details><summary>提示 2</summary>

`JSON.parse(text) as RawFilesResponse` 只是告诉编译器「相信我」，运行时不做任何检查，和 TS 一样。所以接下来每个字段都要自己判：

- `Array.isArray(raw.files)`，不是数组就 `throw new Error(...)`
- `typeof f.id === 'string'`、`typeof f.name === 'string'`
- `toFileType(f.type)` 返回 `undefined` 就跳过
- `f.size ?? 0`

ArkTS 里对象字面量要标注类型：`const item: FileItem = { ... }`。
</details>

<details><summary>答案</summary>

```ts
const raw = JSON.parse(text) as RawFilesResponse;
if (raw === null || raw === undefined || !Array.isArray(raw.files)) {
  throw new Error('bad payload: files missing');
}
const out: FileItem[] = [];
for (const f of raw.files) {
  const type = toFileType(f.type);
  if (type === undefined || typeof f.id !== 'string' || typeof f.name !== 'string') {
    continue;
  }
  const item: FileItem = { id: f.id, name: f.name, type: type, size: f.size ?? 0, mtime: f.mtime ?? 0 };
  out.push(item);
}
return out;
```
</details>

想一想：
- Android 用的是什么（kotlinx.serialization / Gson）？那边字段缺失、类型不对时是抛异常还是给默认值？鸿蒙这里全靠手写，哪种更容易在线上出「列表少了几条」这种不报错的问题？
- 对工作：线上 App 的 H5 通过 bridge 传给 Native 的 JSON，Native 那边是不是也是这样 `as` 一下就用？

---

## M2-2 Preferences 读写 · `data/KvStore.ets`

<details><summary>提示 2</summary>

- 读：`this.prefs.getSync(key, '')`，返回 `preferences.ValueType`（`number | string | boolean | ...` 的联合），`typeof v === 'string'` 收窄
- 写：`putSync` 只改进程内存里的那份 Preferences 对象，要调用另一个方法才会写进沙箱里的文件。设备测试 `m2_2` 会先把内存缓存扔掉再读
</details>

<details><summary>答案</summary>

```ts
get(key: string): string | undefined {
  const v = this.prefs.getSync(key, '');
  return typeof v === 'string' && v !== '' ? v : undefined;
}

put(key: string, value: string): void {
  this.prefs.putSync(key, value);
  this.prefs.flushSync();
}
```
</details>

想一想：
- `flushSync` 在主线程做文件 IO。Android 的 DataStore 为什么强制用协程？鸿蒙有异步版 `flush()`，什么时候该用它？
- 🔬 不 `flush`，杀进程（`hdc shell aa force-stop com.example.mobile3end`）再启动，排序还在吗？正常退出（上滑关掉）呢？
- 对工作：H5 的 `localStorage` 存在哪里？和 Preferences 是同一个文件吗？清除应用数据时一起清吗？

---

## M2-3 读排序选择 · `data/FileCache.ets`

<details><summary>提示 2</summary>

存进去的是 `SortOrder` 的字符串值（`'name'` / `'time'`）。TS 的字符串枚举没有反向映射，`SortOrder['time']` 拿不到；`as SortOrder` 不检查任何东西。直接和枚举成员比较。
</details>

<details><summary>答案</summary>

```ts
const v = this.kv.get(KEY_ORDER);
return v === SortOrder.TIME ? SortOrder.TIME : SortOrder.NAME;
```
</details>

想一想：存的是枚举的值而不是下标（0 / 1），好处是什么？以后在中间插一个 `SIZE` 排序，老用户的数据会怎样？

---

## M2-4 发 GET · `data/HttpClient.ets`

<details><summary>提示 2</summary>

- `http.createHttp()` 得到一个一次性的 `HttpRequest`，用完 `destroy()`，放在 `finally` 里
- `await req.request(url, options)`，`options` 是 `http.HttpRequestOptions`：`method`、`expectDataType: http.HttpDataType.STRING`、`connectTimeout`、`readTimeout`
- 404、500 不会 reject，`resp.responseCode` 要自己判，不是 `http.ResponseCode.OK` 就 `throw`
- `resp.result` 是 `string | Object | ArrayBuffer`，指定了 STRING 后 `as string`
</details>

<details><summary>答案</summary>

```ts
const req = http.createHttp();
try {
  const options: http.HttpRequestOptions = {
    method: http.RequestMethod.GET,
    expectDataType: http.HttpDataType.STRING,
    connectTimeout: this.timeoutMs,
    readTimeout: this.timeoutMs,
  };
  const resp = await req.request(url, options);
  if (resp.responseCode !== http.ResponseCode.OK) {
    throw new Error(`HTTP ${resp.responseCode}`);
  }
  return resp.result as string;
} finally {
  req.destroy();
}
```
</details>

想一想：
- 为什么选 `@ohos.net.http` 而不是 rcp（Remote Communication Kit）：见 `HttpClient.ets` 顶部注释。🔬 有兴趣的话用 rcp 的 `session.get` 再写一个 `HttpGet` 实现，它对明文的默认值和 http 一样吗？（上面手工任务 B 的表）
- 不 `destroy()` 会怎样？浏览器的 `fetch` 为什么不需要你管这个？
- 对工作：H5 页面里的 `fetch` 走的是 ArkWeb 自己的网络栈，不走 `@ohos.net.http`。所以 `network_config.json` 里 `ArkWeb` 那一项默认 `false` 意味着什么？

---

## M2-5 先缓存后网络 · `data/FileRepository.ets`

<details><summary>提示 2</summary>

1. `const cached = this.cache.loadFiles();`
2. `onState(cached !== undefined ? ListState.of(cached, true) : ListState.loading())`
3. `try { 请求 → parseFilesJson → saveFiles → onState(ListState.of(files, false)) }`
4. `catch` 里只有 `cached === undefined` 才 `onState(ListState.error(...))`

解码失败（服务端返回 HTML 错误页）也要走 catch，所以 `parseFilesJson` 要放在 try 里。
</details>

<details><summary>答案</summary>

```ts
const cached = this.cache.loadFiles();
onState(cached !== undefined ? ListState.of(cached, true) : ListState.loading());
try {
  const files = parseFilesJson(await this.http.get(this.url));
  this.cache.saveFiles(files);
  onState(ListState.of(files, false));
} catch (e) {
  const message = (e as Error).message;
  Log.w(`FileRepository: 刷新失败 ${message}`);
  if (cached === undefined) {
    onState(ListState.error(message));
  }
}
```
</details>

想一想：
- `onState` 回调里给 `@State listState` 赋值。`load` 是 async 的，回调执行时在哪个线程？（ArkTS 的 Promise 和 JS 一样跑在当前线程的事件循环上，M3 会验证）
- 有缓存但刷新失败时，用户完全感知不到。这是对的吗？线上 App 的列表页是怎么处理的？

---

## M2-6 排序持久化 · `pages/Index.ets`

<details><summary>提示 2</summary>

`@Watch('onOrderChange')` 在 `this.order` 每次被赋新值后回调。`aboutToAppear` 里已经用 `cache.loadOrder()` 读回来了，这里只差写。
</details>

<details><summary>答案</summary>

```ts
cache.saveOrder(this.order);
```
</details>

想一想：`aboutToAppear` 里 `this.order = this.cache.loadOrder()` 也会触发一次 `onOrderChange`，又写回去一遍。有害吗？Vue 的 `watch` 有没有同样的问题？

---

## 手工验收（对照 spec M2）

- [ ] 开着 mock 服务启动：先转圈，然后出列表（12 条，来自 `mock/api/files.json`）
- [ ] 切排序 → 杀进程 → 重启，排序保持
- [ ] 重启后先显示「显示的是缓存」，随后提示消失（后台刷新成功）
- [ ] 关掉 mock 服务启动：有缓存显示缓存；清除应用数据（`hdc shell bm clean -n com.example.mobile3end -d`）后再启动，显示失败态，点「重试」能恢复（开回 mock 服务后）
- [ ] 把 `mock/api/files.json` 临时改成 `{"files":[]}`，显示空列表（验完改回来）
