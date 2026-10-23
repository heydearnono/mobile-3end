import { TODO } from '../common/Todo';
import { FileItem } from '../model/FileItem';

/**
 * 路由名。和 vue-router 的命名路由一样，Navigation 按名字找页面：
 * Index.ets 里 `.navDestination(this.pageMap)` 把名字映射成组件。
 * 列表页是 Navigation 的首页（不在栈里），所以栈空 = 在列表页
 */
export const ROUTE_DETAIL: string = 'detail';
export const ROUTE_H5: string = 'h5';

// 空 M1-3：跳到这个文件的详情页，把 id 作为路由参数带过去
// 提示 1：NavPathStack 上按名字入栈的方法，第二个参数就是 param
export function openDetail(stack: NavPathStack, file: FileItem): void {
  TODO('M1-3');
}

// 空 M1-4：从 navDestination 构建函数拿到的 param 里取出 id；不是字符串时返回 undefined
// 提示 1：param 的静态类型是 Object | undefined，ArkTS 不允许 any，要自己判断类型再收窄
export function detailIdOf(param: Object | undefined): string | undefined {
  return TODO('M1-4');
}

// 空 M1-5：从详情页返回列表页
// 提示 1：返回 ≠ 再跳一次
export function goBack(stack: NavPathStack): void {
  TODO('M1-5');
}
