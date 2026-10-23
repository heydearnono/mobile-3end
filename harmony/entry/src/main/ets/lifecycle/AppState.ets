import { TODO } from '../common/Todo';

/**
 * 应用前后台状态，从 UIAbility 传到页面。
 * UIAbility 不是组件，没法直接改页面的 @State；鸿蒙的惯用法是经过 AppStorage（应用级的全局状态仓库，
 * 类似一个全局 Pinia store）：Ability 里写，页面里用 @StorageProp / @StorageLink 订阅
 */
export const KEY_APP_STATE: string = 'm3e.appState';
export const APP_FOREGROUND: string = 'foreground';
export const APP_BACKGROUND: string = 'background';

// 空 M3-3：把前后台状态写进 AppStorage 的 KEY_APP_STATE，key 不存在时要能自动创建
// 提示 1：AppStorage 有 set 和 setOrCreate 两个写法，区别就在「key 不存在时」
export function publishAppState(state: string): void {
  TODO('M3-3');
}
