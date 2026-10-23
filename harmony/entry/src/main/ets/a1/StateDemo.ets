import { FileItem, FileType, nextOrder, SortOrder } from '../model/FileItem';
import { ListState, LoadKind } from '../data/FileRepository';

// A1-8 的验证台：在 DevEco 里打开这个文件，右侧 Previewer 就能跑（不用模拟器）。
// 每个按钮执行 STATE_QUIZ 里对应的那一行（变量名多了题号后缀，含义一样），看旁边的文字变不变。
// 不变的那几条，数据其实已经改了：点最下面的「tick + 1」，每行文字都会重新读一遍数据，就能看到真实的值

/** @Observed：new 出来的实例是一个被观察的代理对象，改它的属性能通知到用 @ObjectLink 接它的子组件 */
@Observed
export class FileRow {
  id: string;
  name: string;

  constructor(id: string, name: string) {
    this.id = id;
    this.name = name;
  }
}

function newItem(n: number): FileItem {
  const f: FileItem = { id: `new${n}`, name: `新文件${n}`, type: FileType.DOC, size: 1, mtime: 1 };
  return f;
}

function threeFiles(): FileItem[] {
  return [newItem(1), newItem(2), newItem(3)];
}

/** 第 8 题：子组件用 @ObjectLink 接 @Observed 对象 */
@Component
struct RowView {
  @ObjectLink row: FileRow;

  build() {
    Text(`  子组件 @ObjectLink：${this.row.name}`).fontSize(13)
  }
}

/** 第 9 题：@Prop 是父组件值的拷贝 */
@Component
struct PropChild {
  @Prop title: string = '';

  build() {
    Button(`9. @Prop 子组件改（子：${this.title}）`).fontSize(13).onClick(() => {
      this.title = this.title + '!';
    })
  }
}

/** 第 10 题：@Link 和父组件的 @State 是同一个值 */
@Component
struct LinkChild {
  @Link title: string;

  build() {
    Button(`10. @Link 子组件改（子：${this.title}）`).fontSize(13).onClick(() => {
      this.title = this.title + '!';
    })
  }
}

@Preview
@Component
export struct StateDemo {
  @State order: SortOrder = SortOrder.NAME;
  // 每题一个独立的变量：共用一个的话，点了会刷新的那题，会顺带把不刷新那题的文字也刷出来
  @State listState2: ListState = ListState.of(threeFiles(), false);
  @State listState3: ListState = ListState.of(threeFiles(), false);
  @State listState4: ListState = ListState.of(threeFiles(), false);
  @State listState5: ListState = ListState.of(threeFiles(), false);
  @State files6: FileItem[] = threeFiles();
  @State files7: FileItem[] = threeFiles();
  @State rows: FileRow[] = [new FileRow('r1', '行一'), new FileRow('r2', '行二')];
  @State title: string = '标题';
  /** 每行文字都读了 tick：tick 一变，所有行都会重新渲染，显示数据的真实值 */
  @State tick: number = 0;
  private added: number = 3;

  build() {
    Scroll() {
      Column({ space: 8 }) {
        Row({ space: 8 }) {
          Button('1. order').fontSize(13).onClick(() => {
            this.order = nextOrder(this.order);
          })
          Text(`${this.tick}｜order=${this.order}`).fontSize(13).layoutWeight(1)
        }
        .width('100%')
        Row({ space: 8 }) {
          Button('2. kind').fontSize(13).onClick(() => {
            this.listState2.kind = this.listState2.kind === LoadKind.ERROR ? LoadKind.CONTENT : LoadKind.ERROR;
          })
          Text(`${this.tick}｜kind=${this.listState2.kind}`).fontSize(13).layoutWeight(1)
        }
        .width('100%')
        Row({ space: 8 }) {
          Button('3. files =').fontSize(13).onClick(() => {
            this.listState3.files = this.listState3.files.concat([newItem(++this.added)]);
          })
          Text(`${this.tick}｜listState.files 共 ${this.listState3.files.length} 个`).fontSize(13).layoutWeight(1)
        }
        .width('100%')
        Row({ space: 8 }) {
          Button('4. files.push').fontSize(13).onClick(() => {
            this.listState4.files.push(newItem(++this.added));
          })
          Text(`${this.tick}｜listState.files 共 ${this.listState4.files.length} 个`).fontSize(13).layoutWeight(1)
        }
        .width('100%')
        Row({ space: 8 }) {
          Button('5. push + 赋自己').fontSize(13).onClick(() => {
            this.listState5.files.push(newItem(++this.added));
            this.listState5 = this.listState5;
          })
          Text(`${this.tick}｜listState.files 共 ${this.listState5.files.length} 个`).fontSize(13).layoutWeight(1)
        }
        .width('100%')
        Row({ space: 8 }) {
          Button('6. push').fontSize(13).onClick(() => {
            this.files6.push(newItem(++this.added));
          })
          Text(`${this.tick}｜files 共 ${this.files6.length} 个`).fontSize(13).layoutWeight(1)
        }
        .width('100%')
        Row({ space: 8 }) {
          Button('7. [0].name').fontSize(13).onClick(() => {
            this.files7[0].name = this.files7[0].name + '!';
          })
          Text(`${this.tick}｜files[0]=${this.files7[0].name}`).fontSize(13).layoutWeight(1)
        }
        .width('100%')
        Row({ space: 8 }) {
          Button('8. rows[0].name').fontSize(13).onClick(() => {
            this.rows[0].name = this.rows[0].name + '!';
          })
          Text(`${this.tick}｜父组件直接读：${this.rows[0].name}`).fontSize(13).layoutWeight(1)
        }
        .width('100%')
        ForEach(this.rows, (row: FileRow) => {
          RowView({ row: row })
        }, (row: FileRow): string => row.id)

        Text(`${this.tick}｜父组件的 title=${this.title}`).fontSize(13)
        PropChild({ title: this.title })
        LinkChild({ title: this.title })

        Button('tick + 1：所有行重新读一遍数据').onClick(() => {
          this.tick++;
        })
      }
      .alignItems(HorizontalAlign.Start)
      .padding(16)
    }
  }
}
