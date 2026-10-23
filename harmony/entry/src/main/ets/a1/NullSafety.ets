import { TODO } from '../common/Todo';
import { FileItem } from '../model/FileItem';

// A1 第 3 节：空安全
//
// ?.、??、!、可选参数 a?: T、类型收窄（typeof / !== undefined 之后自动当非空用），写法和 TS 完全一样。
// 差异在「开关」和「哪些地方编译器不管」：
//   - strictNullChecks / strictPropertyInitialization 永远开着，没法关：
//     class 字段必须有初始值或在构造函数里赋值，否则报 has no initializer（K1 里 Kotlin 也是这样）
//     name!: string 这种「我保证以后会赋值」的写法只给 WARN（arkts-no-definite-assignment），别用
//   - 编译器替你查的：Map.get(k) 返回 V | undefined，不处理直接 .xxx 会报 'v' is possibly 'undefined'
//   - 编译器不查的（和 TS 默认一样，没开 noUncheckedIndexedAccess）：
//       arr[100]         类型是元素类型，运行时是 undefined
//       record['不存在'] 类型是 V，运行时是 undefined（A1-1 里的 NaN 就是这么来的）
//       JSON.parse(...) as T 之后的每个字段（第 2 节）
//   - a!：和 TS 一样只骗编译器，运行时不检查。Kotlin 的 a!! 是 null 就立刻抛 NPE；
//     ArkTS 的 a! 是 undefined 就继续往下走，等到后面 .name 才崩，崩的位置离真正出错的地方很远
//
// 对照 Kotlin：?. ≈ ?.，?? ≈ ?:，! ≈ !!（但不抛异常）。Kotlin 的 list[100] 会抛越界，ArkTS 不会

// 空 A1-5：按 id 找文件名，找不到返回「文件不存在」
// 要求：一个表达式
// 提示 1：Map.get 的返回类型带 undefined，?. 和 ?? 连用
export function nameOf(files: Map<string, FileItem>, id: string): string {
  return TODO('A1-5');
}

// 空 A1-6：按 id 取文件，找不到时抛 Error，message 是「找不到文件 <id>」
// 不能写 return files.get(id)!：找不到时它会安静地返回 undefined，调用方拿到一个「类型是 FileItem 的 undefined」
// 提示 1：先存到一个变量里，判断 === undefined；判断之后这个变量自动收窄成 FileItem
export function requireFile(files: Map<string, FileItem>, id: string): FileItem {
  return TODO('A1-6');
}
