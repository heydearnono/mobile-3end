/**
 * 填空占位，对应 Kotlin 的 TODO()：工程能编译，跑到这一行才抛异常。
 * 返回 never，所以 `const x: string = TODO(...)` 这种写法也能通过类型检查。
 */
export function TODO(id: string): never {
  throw new Error('An operation is not implemented: ' + id);
}
