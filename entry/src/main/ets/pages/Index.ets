import { HomePage } from './Home'
import { OCRPage } from './OCR'

@Entry
@Component
struct Index {
  @State message: string = 'Hello World';
  private controller: TabsController = new TabsController();
  @State private currentIndex: number = 0;
  @State private homeReloadFlag: boolean = false;

  onPageShow() {
    this.homeReloadFlag = !this.homeReloadFlag
  }

  build() {
    Tabs({ controller: this.controller, barPosition: BarPosition.End }) {
      TabContent() {
        if (this.homeReloadFlag) {
          HomePage()
        } else {
          HomePage()
        }
      }
      .tabBar(this.TabItem($r('app.string.Tab_Home'), 0, $r('app.media.home_sel'), $r('app.media.home_nor')))

      TabContent() {
        OCRPage()
      }
      .tabBar(this.TabItem($r('app.string.Tab_OCR'), 1, $r('app.media.ocr_sel'), $r('app.media.ocr_nor')))
    }
    .scrollable(false)
    .barMode(BarMode.Fixed)
    .animationDuration(0)
    .vertical(false)
    .width('100%')
    .height('100%')
    .onChange((index: number) => {
      this.currentIndex = index
    })
  }

  @Builder TabItem(title: ResourceStr,
    index: number,
    iconActive: Resource,
    iconInActive: Resource){
    Column() {
      Image(this.currentIndex === index ? iconActive : iconInActive)
        .width(24)
        .height(24)
      Text(title)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.currentIndex === index ?  $r('app.color.tab_sel_color') : $r('app.color.tab_nor_color'))
        .margin({ top: 8 })
    }
    .height(56)
    .padding({top: 10})
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}
