@Entry
@Component
export struct OCRPage {
  @State message: string = 'hello world OCRPage'

  build() {
    Text(this.message)
      .width('100%')
      .backgroundColor('red')
      .fontSize(20)
      .fontColor('blue')
  }
}