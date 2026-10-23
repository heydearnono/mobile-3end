import { TODO } from '../common/Todo';
import { FileItem } from '../model/FileItem';

// A1 第 4 节：装饰器与状态（ArkUI 状态管理 V1）
//
// @State、@Prop 这些 @xxx 是 ArkUI 框架的装饰器，不是 ArkTS 语言本身的特性（语言层面只是 TS 的装饰器语法）。
// 这个工程用的是 V1（@Component + @State / @Prop / @Link / @Provide / @Consume / @Observed / @ObjectLink）；
// V2（@ComponentV2 + @Local / @Param / @ObservedV2 / @Trace）是 API 12 起的新写法，读线上 App 代码时两种都可能见到，末尾有对照。
//
// V1 的 @State 只观察「一层」：
//   this.order = x                    @State 变量自身被赋值                     → 刷新
//   this.listState.kind = x           @State 是 class 对象，改它的第一层属性      → 刷新
//   this.files.push(x) / files[0] = x  @State 是数组，增删、替换元素               → 刷新
//   this.listState.files.push(x)      第二层：files 是 listState 的属性，push 没有给 listState.files 赋值 → 不刷新
//   this.files[0].name = x            第二层：改的是数组元素的属性                → 不刷新
//   this.listState = this.listState   赋的是同一个对象，框架先比 ===，没变就什么都不做 → 不刷新
// 数据确实改了，只是框架不知道，界面停在旧值；等别的状态变化引起这块重新渲染，才「突然」对上。这类 bug 很难查。
//
// 两种修法：
//   1. 不可变更新：生成新对象 / 新数组再整体赋值（下面的 A1-7）。≈ Kotlin data class 的 copy、
//      SwiftUI 里 struct 是值类型（改字段就是换了个新值）、React 的 setState({...})
//   2. @Observed class + 子组件里用 @ObjectLink 接：每一层都是被观察的对象，原地改字段也能刷新。
//      ≈ Vue 的 reactive 深响应，但要自己一层层标注、一层层拆成子组件
//
// 父子组件之间：
//   @Prop   单向：父 → 子，子组件拿到的是一份拷贝（对象是深拷贝），子组件改了父组件不知道      ≈ Vue props
//   @Link   双向：子组件改了，父组件的 @State 跟着变；父组件传的时候写 $变量名 或 this.变量名  ≈ Vue v-model
//   @Provide / @Consume  跨多层，按名字配对（Index 的 pathStack 就是这么传给详情页的） ≈ Vue provide / inject
//
// 刷新行为本地单测测不了（要真的渲染组件），所以 A1-8 是「预测」题，答完用 StateDemo.ets 在 DevEco 预览器里验证。
//
// V2 对照：@ObservedV2 class + 属性上的 @Trace，被 @Trace 的属性不管多深都能观察；
// @Local ≈ @State，@Param ≈ @Prop（但子组件不能改），@Event 让子组件通知父组件改

// 空 A1-7：把 id 对应的文件改名，用于 `this.files = renameFile(this.files, id, name)`
// - 不能改入参：files 数组和里面的每个对象都保持原样
// - 返回新数组；改了名的是新对象，其他元素还是原来那个对象（=== 相等，ForEach 不会重建这些行）
// - id 不存在 → 原样返回 files（同一个数组，赋给 @State 时 === 相等，不会触发刷新）
// TS 里一行 files.map(f => f.id === id ? { ...f, name } : f)，ArkTS 不支持对象展开
// 提示 1：FileItem 是 interface，新对象要把每个字段都写出来；对象字面量要有类型可对应（赋给标了类型的变量，或者 map 回调写返回类型）
export function renameFile(files: FileItem[], id: string, newName: string): FileItem[] {
  return TODO('A1-7');
}

/**
 * A1-8 的题目。前提（和 pages/Index.ets 一样）：
 *   @State order: SortOrder
 *   @State listState: ListState   // ListState 是普通 class，没有 @Observed，见 data/FileRepository.ets
 *   @State files: FileItem[]      // FileItem 是 interface
 *   @State rows: FileRow[]        // FileRow 是 @Observed class，见 StateDemo.ets
 * 问：执行这一行之后，界面上用到这块数据的地方会不会刷新？
 */
export const STATE_QUIZ: string[] = [
  /* 1 */ 'this.order = nextOrder(this.order)',
  /* 2 */ 'this.listState.kind = LoadKind.ERROR',
  /* 3 */ 'this.listState.files = newFiles',
  /* 4 */ 'this.listState.files.push(item)',
  /* 5 */ 'this.listState.files.push(item); this.listState = this.listState',
  /* 6 */ 'this.files.push(item)',
  /* 7 */ "this.files[0].name = '新名字'",
  /* 8 */ "this.rows[0].name = '新名字'，这一行由子组件渲染，子组件用 @ObjectLink row: FileRow 接",
  /* 9 */ "子组件 @Prop title: string 里执行 this.title = '新标题'，父组件传进来的那个 @State 变",
  /* 10 */ "子组件 @Link title: string 里执行 this.title = '新标题'，父组件传进来的那个 @State 变",
];

// 空 A1-8：按 STATE_QUIZ 的顺序，返回 10 个 true（会刷新 / 会变）或 false
// 提示 1：先读本文件开头的注释；拿不准的先猜，再到预览器里点 StateDemo 的按钮看
export function predictRefresh(): boolean[] {
  return TODO('A1-8');
}
