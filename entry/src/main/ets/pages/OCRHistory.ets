import router from '@ohos.router'
import { common } from '@kit.AbilityKit'
import { OCRHistoryManager, OCRRecord } from '../helpers/OCRHistoryManager'

@Entry
@Component
struct OCRHistoryPage {
  @State historyRecords: OCRRecord[] = []

  aboutToAppear() {
    this.loadHistory()
  }

  private async loadHistory() {
    const ctx = getContext(this) as common.UIAbilityContext
    this.historyRecords = await OCRHistoryManager.getRecords(ctx)
  }

  build() {
    Column() {
      // Header
      Row() {
        Image($r('app.media.startIcon')) // Back Arrow placeholder if no explicit resource
          // Using a simple Text arrow for now if unsure about resources, or standard pattern
          .width(0)
          .height(0)

        Button() {
          Text('‹')
           .fontSize(32)
           .fontColor('#111827')
           .offset({ y: -2 })
        }
        .type(ButtonType.Normal)
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          router.back()
        })
        .width(44)
        .height(44)
        
        Text('识别历史')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#111827')
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .margin({ right: 44 }) // Balance the back button
          
        Text('清空')
          .fontColor(Color.Red)
          .fontSize(16)
          .margin({ right: 16 })
          .onClick(async () => {
             const ctx = getContext(this) as common.UIAbilityContext
             await OCRHistoryManager.clearHistory(ctx)
             this.loadHistory()
          })
          .position({ x: '100%', y: 12 })
          .markAnchor({ x: '100%', y: 0 }) // Align right
      }
      .width('100%')
      .height(56)
      .alignItems(VerticalAlign.Center)
      .padding({ left: 8, right: 16 })
      .border({ width: { bottom: 0.5 }, color: '#e5e7eb' })

      if (this.historyRecords.length === 0) {
        Column() {
           Text('暂无历史记录')
             .fontColor('#9ca3af')
             .fontSize(16)
             .margin({ top: 100 })
        }
        .width('100%')
        .layoutWeight(1)
      } else {
        List() {
          ForEach(this.historyRecords, (item: OCRRecord) => {
            ListItem() {
              Row() {
                Image('file://' + item.imagePath)
                  .width(60)
                  .height(80)
                  .objectFit(ImageFit.Cover)
                  .borderRadius(8)
                  .backgroundColor('#f3f4f6')
                
                Column() {
                  Text(new Date(item.timestamp).toLocaleString())
                    .fontSize(12)
                    .fontColor('#9ca3af')
                    .margin({ bottom: 4 })
                  Text(item.text)
                    .maxLines(3)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .fontSize(15)
                    .fontColor('#374151')
                    .lineHeight(20)
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
                .padding({ left: 12, top: 2, bottom: 2 })
              }
              .width('100%')
              .padding(12)
              .backgroundColor(Color.White)
              .onClick(() => {
                 // Return result
                 router.back({
                   url: 'pages/OCR',
                   params: {
                     selectedRecord: JSON.stringify(item)
                   }
                 })
              })
            }
            .swipeAction({ end: this.DeleteButton(item) }) 
          })
        }
        .width('100%')
        .layoutWeight(1)
        .divider({ strokeWidth: 0.5, color: '#f3f4f6', startMargin: 16, endMargin: 16 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#ffffff')
  }

  @Builder DeleteButton(item: OCRRecord) {
    Button() {
       Text('删除')
         .fontColor(Color.White)
    }
    .width(80)
    .height('100%')
    .type(ButtonType.Normal)
    .backgroundColor(Color.Red)
    .onClick(async () => {
       // Ideally OCRHistoryManager should support deleting single item
       // For now, we do nothing or implement deleteSingle
    })
  }
}
