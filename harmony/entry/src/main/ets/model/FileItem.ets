import { TODO } from '../common/Todo';

// 字符串枚举，值和接口里的 `type` 字段一致，M2 解码时可以直接比较
export enum FileType {
  FOLDER = 'folder',
  DOC = 'doc',
  IMAGE = 'image',
  VIDEO = 'video',
}

// ArkTS 不支持结构化类型推断出来的「匿名对象」：对象字面量必须标注成某个 interface / class
export interface FileItem {
  id: string;
  name: string;
  type: FileType;
  /** 字节，文件夹为 0 */
  size: number;
  /** 秒级时间戳 */
  mtime: number;
}

export enum SortOrder {
  NAME = 'name',
  TIME = 'time',
}

export function sortLabel(order: SortOrder): string {
  return order === SortOrder.NAME ? '名称' : '时间';
}

export function nextOrder(order: SortOrder): SortOrder {
  return order === SortOrder.NAME ? SortOrder.TIME : SortOrder.NAME;
}

// 和 Kotlin 的 String.compareTo 一样按 UTF-16 码元比较，不用 localeCompare，
// 这样三端排序结果完全一致（UI 测试依赖它）
function compareText(a: string, b: string): number {
  return a < b ? -1 : (a > b ? 1 : 0);
}

/**
 * 文件夹永远排在前面；同类之间：
 * - NAME：按名称升序
 * - TIME：按修改时间倒序（新的在上）
 * 不修改入参，返回新数组
 */
export function sortFiles(files: FileItem[], order: SortOrder): FileItem[] {
  return files.slice().sort((a: FileItem, b: FileItem): number => {
    const folderA = a.type === FileType.FOLDER ? 0 : 1;
    const folderB = b.type === FileType.FOLDER ? 0 : 1;
    if (folderA !== folderB) {
      return folderA - folderB;
    }
    return order === SortOrder.NAME ? compareText(a.name, b.name) : b.mtime - a.mtime;
  });
}

// 空 M1-1：ForEach 的键值生成函数（第三个参数），给每一行一个稳定的 key
// 提示 1：和 Compose items(key = ...)、Vue v-for 的 :key 是同一回事
export function fileKey(item: FileItem): string {
  return TODO('M1-1');
}

export function iconOf(type: FileType): string {
  switch (type) {
    case FileType.FOLDER:
      return '📁';
    case FileType.DOC:
      return '📄';
    case FileType.IMAGE:
      return '🖼️';
    default:
      return '🎬';
  }
}

export function formatSize(bytes: number): string {
  if (bytes < 1024) {
    return `${bytes} B`;
  }
  const units: string[] = ['KB', 'MB', 'GB'];
  let value = bytes / 1024;
  let i = 0;
  while (value >= 1024 && i < units.length - 1) {
    value /= 1024;
    i++;
  }
  return `${value.toFixed(1)} ${units[i]}`;
}

function pad2(n: number): string {
  return n < 10 ? `0${n}` : `${n}`;
}

// 本地时区，格式和 Android 的 SimpleDateFormat("yyyy-MM-dd HH:mm") 一致
export function formatTime(mtime: number): string {
  const d = new Date(mtime * 1000);
  return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())} ${pad2(d.getHours())}:${pad2(d.getMinutes())}`;
}
