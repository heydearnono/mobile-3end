import { TODO } from '../common/Todo';

// A1 第 2 节：class / interface / enum 与 JSON
//
// 语言层面和 TS 一样：interface 只在编译期存在，class 运行时真有构造函数和原型。
// 区别在于 ArkTS 没有 any，JSON.parse 的结果只能 `as` 成某个类型，而 `as` 只骗编译器，不做任何转换：
//   const m = JSON.parse(text) as PackageManifest
//     m instanceof PackageManifest → false；m.hashOf('x') → 运行时报 "hashOf is not callable"
//     JSON 里缺了 entry，m.entry 照样是 undefined，类型上却写着 string
// 所以安全的做法分两步（M2-1、M4-5 都是这么写的）：
//   1. as 成一个字段全可选的 interface（RawManifest），如实表示「JSON 里什么都可能没有」
//   2. 逐个字段检查 typeof，检查通过再 new 出真正的 class 实例
// 对照：Kotlin 用 kotlinx.serialization（@Serializable + decodeFromString，字段类型不对直接抛异常），
// Swift 用 Codable（JSONDecoder().decode），都是库替你做了第 2 步。ArkTS 没有现成的，手写。
//
// enum：字符串枚举和 TS 一样只有「名字 → 值」：PackageMode['OFFLINE'] 得到 'offline'，
// 没有「值 → 枚举」的反查，所以要像下面 toPackageMode 这样 switch 一遍（M2 的 toFileType 也是这样）

/** 离线包怎么用：offline = 拦截请求读包里的文件，online = 直接加载线上地址 */
export enum PackageMode {
  OFFLINE = 'offline',
  ONLINE = 'online',
}

export function toPackageMode(s: string | undefined): PackageMode | undefined {
  switch (s) {
    case PackageMode.OFFLINE:
      return PackageMode.OFFLINE;
    case PackageMode.ONLINE:
      return PackageMode.ONLINE;
    default:
      return undefined;
  }
}

/**
 * manifest.json 的原始结构。字段全可选；files 的值类型写 Object：JSON 里可能混进数字、对象，不一定是字符串
 */
export interface RawManifest {
  name?: string;
  version?: number;
  entry?: string;
  mode?: string;
  files?: Record<string, Object>;
}

/** 序列化用的结构：JSON.stringify 能正确处理的只有普通对象、数组、基本类型 */
export interface ManifestJson {
  name: string;
  version: number;
  entry: string;
  mode: string;
  files: Record<string, string>;
}

/**
 * 离线包的描述文件（本项目的 mock/h5 没有，真实的离线包一般都有一份），例如
 *   {"name":"demo-h5","version":3,"entry":"index.html","mode":"offline",
 *    "files":{"index.html":"9f2c01","app.js":"1ab0e7"}}
 * files 是「包内路径 → 校验和」，下载完逐个比对，防止包被截断或篡改
 */
export class PackageManifest {
  name: string;
  version: number;
  entry: string;
  mode: PackageMode;
  files: Map<string, string>;

  constructor(name: string, version: number, entry: string, mode: PackageMode, files: Map<string, string>) {
    this.name = name;
    this.version = version;
    this.entry = entry;
    this.mode = mode;
    this.files = files;
  }

  /** 某个文件的校验和，包里没有这个文件就是 undefined */
  hashOf(path: string): string | undefined {
    return this.files.get(path);
  }

  // 空 A1-3：解析 manifest.json。离线包是从网络下载的，内容不可信，坏了不能崩，一律返回 undefined：
  // - JSON 不合法、或者解出来不是对象（比如 'null'、'3'）→ undefined
  // - name、entry 不是非空字符串，version 不是数字，mode 不认识 → undefined
  // - files 缺失 → 空 Map；files 里只保留值是字符串的项
  // - 返回 new 出来的 PackageManifest，不能直接 as
  // 提示 1：JSON.parse(text) as RawManifest，再用 typeof 检查每个字段；Record 的键用 Object.keys 遍历
  static parse(text: string): PackageManifest | undefined {
    return TODO('A1-3');
  }

  // 空 A1-4：序列化回 JSON，字段顺序 name、version、entry、mode、files（files 按插入顺序）
  // 提示 1：JSON.stringify(this) 不行：Map 会变成 {}。先把 Map 转成 Record，再拼一个 ManifestJson
  toJson(): string {
    return TODO('A1-4');
  }
}
