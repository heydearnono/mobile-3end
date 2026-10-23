import { TODO } from '../common/Todo';
import { FileItem } from '../model/FileItem';

// A1 第 1 节：严格模式 —— ArkTS 是 TS 的一个子集
//
// 语法和 TS 一样，但编译器（ArkTS linter）禁掉了一批「运行时才知道对象长什么样」的写法，
// 目的是让方舟编译器能提前确定每个对象的布局（AOT 编译、性能）。最常见的几条：
//   不能用 any / unknown                    → 一律写具体类型；不确定的用 Object 或联合类型
//   对象字面量必须对应声明过的 class / interface
//     const o = { a: 1 }                     ✗  const o: Point = { x: 1, y: 2 }  ✓（Point 是 class 或 interface）
//     type T = { a: number }                 ✗  interface T { a: number }         ✓
//   不能用结构化类型（鸭子类型）赋值：两个 class 字段一模一样也不能互相赋值
//   动态键名：
//     { [key: string]: number }（索引签名）  ✗  Record<string, number> 或 Map<string, number>  ✓
//     Record 的字面量键要加引号：{ a: 1 } ✗  { 'a': 1 } ✓
//     obj['name']（对 class / interface 字段） ✗  obj.name  ✓；Record 可以 r['k']
//     'k' in obj、delete obj.k、for (k in obj) ✗  Map 的 has / delete / forEach，或 Object.keys(r)
//   解构 const { a } = o、const [x, y] = arr  ✗  一个个取
//   对象展开 { ...o, name: 'x' }              ✗  数组展开 [...arr, x] 可以
//   catch (e: Error) 写类型                    ✗  catch (e) 再 e as Error / e instanceof Error
//
// 这些「写了就编不过」，没法做成填空，在 hints/harmony-A1.md 里做成 🔬 实验：把 TS 写法粘进来看报错。
// 报错里括号中的 arkts-no-xxx 是规则名，搜官方文档「从 TypeScript 到 ArkTS 的适配规则」能找到原文和改法。
//
// 对照 Kotlin：Kotlin 本来就没有这些动态特性，ArkTS 是把 TS 往 Kotlin / Swift 那边收紧了一步。
// 动态键名的对象在 Kotlin 里是 Map<String, Int>，ArkTS 里也是 Record 或 Map。
//
// Record 和 Map 怎么选：
//   Record<string, V>  底下就是普通 JS 对象，能直接 JSON.stringify / JSON.parse，适合和 JSON 互转
//   Map<K, V>          有 has / delete / size，键可以不是字符串，插入有序；但 JSON.stringify(map) 得到 "{}"（第 2 节会用到）

// 空 A1-1：按类型统计文件个数，比如 { folder: 1, doc: 2 }。没出现的类型不要有这个键
// TS 里会写 const count: { [type: string]: number } = {}，ArkTS 里换成 Record
// 提示 1：读一个不存在的键得到 undefined，undefined + 1 是 NaN
export function countByType(files: FileItem[]): Record<string, number> {
  return TODO('A1-1');
}

// 空 A1-2：解析 URL 的查询串（不带 ?），JSBridge 用 URL 传参时常见：
//   'method=getFiles&dir=%2F%E5%B7%A5%E4%BD%9C&flag' → method → getFiles，dir → /工作，flag → ''
// 规则：
// - 按 & 分段，空段跳过
// - 每段按第一个 = 分成键和值，值里还可以有 =；没有 = 的整段是键，值是 ''
// - 键和值都要 decodeURIComponent
// - 同一个键出现多次，后面的覆盖前面的
// 提示 1：不能写 const [k, v] = part.split('=')（解构）；用 indexOf 找第一个 =，再 substring
export function parseQuery(query: string): Map<string, string> {
  return TODO('A1-2');
}
