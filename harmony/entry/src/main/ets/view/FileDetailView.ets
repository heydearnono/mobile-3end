import { Log } from '../common/Log';
import { TODO } from '../common/Todo';
import { FileItem, formatSize, formatTime, iconOf } from '../model/FileItem';
import { goBack } from '../nav/Routes';

@Component
export struct FileDetailView {
  file: FileItem | undefined = undefined;
  // 和 Index 的 @Provide('pathStack') 配对：跨层级拿到同一个 NavPathStack，不用一层层传。类似 Vue 的 provide / inject
  @Consume('pathStack') pathStack: NavPathStack;

  build() {
    NavDestination() {
      Column({ space: 8 }) {
        Row() {
          Button('← 返回')
            .id('back')
            .type(ButtonType.Normal)
            .backgroundColor(Color.Transparent)
            .fontColor('#0a59f7')
            .onClick(() => {
              // 空 M1-6：返回列表页
              // 提示 1：M1-5 写好的函数 + 上面 @Consume 拿到的栈
              TODO('M1-6');
            })
          Text('详情').fontSize(18).fontWeight(FontWeight.Medium)
        }
        .width('100%')

        // 一个 Text 带 id，测试按 id 找；文件不存在时也显示在这里
        Text(this.file === undefined ? '文件不存在' : `${iconOf(this.file.type)} ${this.file.name}`)
          .id('detail-name')
          .fontSize(20)
        if (this.file !== undefined) {
          Text(`id：${this.file.id}`)
          Text(`类型：${this.file.type}`)
          Text(`大小：${this.file.size > 0 ? formatSize(this.file.size) : '—'}`)
          Text(`修改时间：${formatTime(this.file.mtime)}`)
        }
      }
      .alignItems(HorizontalAlign.Start)
      .padding(16)
      .width('100%')
    }
    .hideTitleBar(true)
    // NavDestination 自己的生命周期：页面级「显示 / 隐藏」，M3 对照 Index 的 onPageShow 看
    .onShown(() => Log.i(`FileDetailView.onShown id=${this.file?.id}`))
    .onHidden(() => Log.i('FileDetailView.onHidden'))
  }
}
