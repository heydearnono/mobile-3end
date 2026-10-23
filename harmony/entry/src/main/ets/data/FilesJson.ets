import { TODO } from '../common/Todo';
import { FileItem, FileType } from '../model/FileItem';

// 接口原始结构。字段全标成可选：JSON 里缺了什么，类型上就要能表示「没有」
export interface RawFile {
  id?: string;
  name?: string;
  type?: string;
  size?: number;
  mtime?: number;
}

export interface RawFilesResponse {
  files?: RawFile[];
}

// 缓存写回时用的结构，和接口同构，这样读缓存可以复用 parseFilesJson
export interface FilesPayload {
  files: FileItem[];
}

// 字符串 → 枚举。注意：TS 的字符串枚举没有反向映射，不能写 FileType[str]
export function toFileType(s: string | undefined): FileType | undefined {
  switch (s) {
    case FileType.FOLDER:
      return FileType.FOLDER;
    case FileType.DOC:
      return FileType.DOC;
    case FileType.IMAGE:
      return FileType.IMAGE;
    case FileType.VIDEO:
      return FileType.VIDEO;
    default:
      return undefined;
  }
}

/**
 * 解码 `GET /api/files.json` 的响应体。
 * - JSON 本身不合法 → 抛异常（JSON.parse 自己会抛）
 * - 没有 files 数组 → 抛 Error
 * - 单条缺 id / name，或 type 不认识 → 跳过这一条
 * - size / mtime 缺失 → 按 0
 */
export function parseFilesJson(text: string): FileItem[] {
  // 空 M2-1：按上面的规则解码
  // 提示 1：ArkTS 没有 any，JSON.parse 的结果要 `as` 成上面声明的接口，然后逐字段检查
  return TODO('M2-1');
}

export function encodeFiles(files: FileItem[]): string {
  const payload: FilesPayload = { files: files };
  return JSON.stringify(payload);
}
