import router from '@ohos.router'
import { PhotoItem } from '../types'
import { hilog } from '@kit.PerformanceAnalysisKit'
import preferences from '@ohos.data.preferences'
import { rcp } from '@kit.RemoteCommunicationKit'
import { photoAccessHelper } from '@kit.MediaLibraryKit'
import { fileIo as fs } from '@kit.CoreFileKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { window } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'
import promptAction from '@ohos.promptAction'

interface PhotoAsset {
  uri: string
}

@Entry
@Component
export struct PreviewPage {
  @State private item: PhotoItem | undefined = undefined
  @State private favoriteIds: number[] = []
  @State private bottomInset: number = 0
  private previewHeight: number = 420

  aboutToAppear() {
    const params = router.getParams() as Record<string, string>
    try {
      if (params && params.item) {
        this.item = JSON.parse(params.item) as PhotoItem
      }
      if (params && params.favs) {
        const favs = JSON.parse(params.favs) as number[]
        if (Array.isArray(favs)) {
          this.favoriteIds = favs
        }
      }
    } catch (e) {
      hilog.error(0x0000, 'Preview', 'parse params error %{public}s', JSON.stringify(e))
    }
    this.initFavorites()
    this.initBottomInset()
  }

  private async initFavorites() {
    const ctx = getContext(this)
    try {
      const prefs = await preferences.getPreferences(ctx, 'photo_favorites')
      const stored = await prefs.get('favorites', '[]') as string
      this.favoriteIds = JSON.parse(stored)
    } catch (e) {
      hilog.error(0x0000, 'Preview', 'initFavorites error %{public}s', JSON.stringify(e))
    }
  }

  private async persistFavorites() {
    const ctx = getContext(this)
    try {
      const prefs = await preferences.getPreferences(ctx, 'photo_favorites')
      await prefs.put('favorites', JSON.stringify(this.favoriteIds))
      await prefs.flush()
    } catch (e) {
      hilog.error(0x0000, 'Preview', 'persistFavorites error %{public}s', JSON.stringify(e))
    }
  }

  private initBottomInset() {
    try {
      const ctx = getContext(this) as common.UIAbilityContext
      const windowStage = ctx.windowStage
      const mainWindow = windowStage.getMainWindowSync()
      const navRect = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR).bottomRect
      this.bottomInset = navRect.height || 0
    } catch (e) {
      hilog.error(0x0000, 'Preview', 'initBottomInset error %{public}s', JSON.stringify(e))
      this.bottomInset = 0
    }
  }

  private isFavorite(id: number): boolean {
    return this.favoriteIds.indexOf(id) !== -1
  }

  private toggleFavorite(id: number) {
    const idx = this.favoriteIds.indexOf(id)
    if (idx === -1) {
      this.favoriteIds = [...this.favoriteIds, id]
    } else {
      const next = [...this.favoriteIds]
      next.splice(idx, 1)
      this.favoriteIds = next
    }
    this.persistFavorites()
  }

  private async saveImage() {
    // 由于移除了SaveButton组件，直接执行保存逻辑

    if (!this.item) {
      return
    }

    try {
      promptAction.showToast({ message: 'Downloading...' })
      // 1. Download image
      const session = rcp.createSession()
      const req = new rcp.Request(this.item.src.large || this.item.src.original, 'GET')
      const resp = await session.fetch(req)
      session.close()

      if (resp.statusCode !== 200 || !resp.body) {
        throw new Error('Download failed')
      }
      const buffer = resp.body
      // 2. Save to Media Library
      const context = getContext(this)
      const phHelper = photoAccessHelper.getPhotoAccessHelper(context)
      const assetUri = await phHelper.createAsset(photoAccessHelper.PhotoType.IMAGE, 'jpg') as string
      const file = await fs.open(assetUri, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE)
      await fs.write(file.fd, buffer)
      await fs.close(file.fd)

      promptAction.showToast({ message: 'Image saved successfully' })

    } catch (e) {
      hilog.error(0x0000, 'Preview', 'saveImage error %{public}s', JSON.stringify(e))
      promptAction.showToast({ message: 'Failed to save image' })
    }
  }

  build() {
    Column() {
      if (this.item) {
        Scroll() {
          Column() {
            Stack() {
              Row() {
                Image(this.item.src.large || this.item.src.original)
                  .width('100%')
                  .height('100%')
                  .objectFit(ImageFit.Contain)
              }
              .align(Alignment.Center)
              .backgroundColor('#f5f5f5')
              .width('100%')
              .height('100%')

              Row() {
                Button() {
                  Text('✕')
                    .fontSize(18)
                    .fontColor(Color.White)
                }
                .type(ButtonType.Circle)
                .width(32)
                .height(32)
                .backgroundColor('rgba(0,0,0,0.4)')
                .onClick(() => router.back())

                Blank().layoutWeight(1)

                Button(this.isFavorite(this.item.id) ? '❤' : '♡')
                  .type(ButtonType.Circle)
                  .width(32)
                  .height(32)
                  .fontColor(this.isFavorite(this.item.id) ? '#ff4d4f' : '#333')
                  .backgroundColor('#ffffff')
                  .onClick(() => this.toggleFavorite(this.item!.id))
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 16 })
              .position({ top: 0 })
              .alignItems(VerticalAlign.Top)
              .justifyContent(FlexAlign.SpaceBetween)
              .hitTestBehavior(HitTestMode.Transparent)
            }
            .padding({ left: 0, right: 0, top: 0 })
            .margin({ top: 12, left: 12, right: 12 })
            .width('100%')
            .height(this.previewHeight)
            .borderRadius(16)
            .clip(true)
            .backgroundColor('#000')
            
            // Photographer Info
            Row() {
              Row() {
                Text(this.item.photographer.charAt(0).toUpperCase())
                  .width('100%')
                  .height('100%')
                  .borderRadius(20)
                  .backgroundColor('#f3f4f6')
                  .fontColor('#374151')
                  .fontSize(20)
                  .fontWeight(FontWeight.Bold)
                  .textAlign(TextAlign.Center)
              }
              .width(48)
              .height(48)
              .margin({ right: 12 })

              Column() {
                Text('Photographer')
                  .fontSize(12)
                  .fontColor('#6b7280')
                  .margin({ bottom: 2 })
                Text(this.item.photographer)
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#111827')
              }
              .alignItems(HorizontalAlign.Start)
            }
            .width('100%')
            .padding({ left: 20, right: 20, top: 20, bottom: 8 })

            // Details Card
            Column() {
              Row() {
                Text('Dimensions')
                  .fontColor('#6b7280')
                  .fontSize(14)
                Blank().layoutWeight(1)
                Text(`${this.item.width} x ${this.item.height}`)
                  .fontWeight(FontWeight.Medium)
                  .fontSize(14)
                  .fontColor('#374151')
              }
              .padding({ bottom: 12 })
              .width('100%')

              Row() {
                Text('ID')
                  .fontColor('#6b7280')
                  .fontSize(14)
                Blank().layoutWeight(1)
                Text(`${this.item.id}`)
                  .fontWeight(FontWeight.Medium)
                  .fontSize(14)
                  .fontColor('#374151')
              }
              .padding({ bottom: this.item.alt ? 12 : 0 })
              .width('100%')

              if (this.item.alt) {
                Divider().color('#e5e7eb').margin({ bottom: 12 })
                Text(this.item.alt)
                  .fontColor('#4b5563')
                  .fontSize(14)
                  .fontStyle(FontStyle.Normal)
                  .lineHeight(20)
              }
            }
            .padding(16)
            .margin({ left: 20, right: 20, top: 8 })
            .backgroundColor('#f9fafb')
            .borderRadius(12)

            Blank().height(0)
          }
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
      Button('保存图片', { type: ButtonType.Capsule, stateEffect: true })
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .onClick(() => this.saveImage())
        .backgroundColor('#16a34a')
        .fontColor(Color.White)
        .width('90%')
        .height(50)
        .shadow({ radius: 8, color: 'rgba(22, 163, 74, 0.24)', offsetY: 4 })
        .margin({ bottom: this.bottomInset + 8 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.White)
  }

  private getAspect(): number {
    const w = this.item?.width || 0
    const h = this.item?.height || 0
    if (w > 0 && h > 0) {
      return w / h
    }
    return 3 / 4
  }
}
