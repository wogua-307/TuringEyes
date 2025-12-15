import router from '@ohos.router'
import { PhotoItem } from '../types'
import { hilog } from '@kit.PerformanceAnalysisKit'
import preferences from '@ohos.data.preferences'
import { rcp } from '@kit.RemoteCommunicationKit'
import http from '@ohos.net.http'
import { photoAccessHelper } from '@kit.MediaLibraryKit'
import { fileIo } from '@kit.CoreFileKit'
import image from '@ohos.multimedia.image'
import { BusinessError } from '@kit.BasicServicesKit'
import { window } from '@kit.ArkUI'
import promptAction from '@ohos.promptAction'
import { common, abilityAccessCtrl } from '@kit.AbilityKit';

interface PhotoAsset {
  uri: string
}

@Entry
@Component
export struct PreviewPage {
  @State private item: PhotoItem | undefined = undefined
  @StorageLink('app_favorite_ids') favoriteIds: number[] = []
  @State private bottomInset: number = 0
  private previewHeight: number = 420

  aboutToAppear() {
    const params = router.getParams() as Record<string, string>
    try {
      if (params && params.item) {
        this.item = JSON.parse(params.item) as PhotoItem
      }
      // Note: favs passed from Home are ignored in favor of AppStorage
    } catch (e) {
      hilog.error(0x0000, 'Preview', 'parse params error %{public}s', JSON.stringify(e))
    }
    this.initBottomInset()
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

    const ctx = getContext(this) as common.UIAbilityContext
    try {
      const atManager = abilityAccessCtrl.createAtManager()
      await atManager.requestPermissionsFromUser(ctx, ['ohos.permission.WRITE_IMAGEVIDEO'])
      promptAction.showToast({ message: 'Downloading...' })
      // 1. Create album asset immediately after user click
      const phHelper = photoAccessHelper.getPhotoAccessHelper(ctx)
      const assetUri: string = await phHelper.createAsset(photoAccessHelper.PhotoType.IMAGE, 'jpg') as string
      const file: fileIo.File = fileIo.openSync(assetUri, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE)


      // 2. 流式下载并写入
      const client = http.createHttp()
      try {
        client.on('dataReceive', (chunk: ArrayBuffer) => {
          const u8 = chunk instanceof ArrayBuffer ? new Uint8Array(chunk) : new Uint8Array(chunk as ArrayBuffer)
          fileIo.writeSync(file.fd, u8)
        })
        client.on('dataEnd', () => {
          fileIo.closeSync(file.fd)
          promptAction.showToast({ message: 'Image saved successfully' })
        })
        const url = this.item.src.large || this.item.src.original
        client.requestInStream(url, { method: http.RequestMethod.GET, connectTimeout: 5000 },
          (err: BusinessError<void>, _code: number) => {
            if (err) {
              hilog.error(0x0000, 'Preview', 'requestInStream error %{public}s', JSON.stringify(err))
            }
          })
      } catch (err) {
        fileIo.closeSync(file.fd)
        throw new Error(String(err))
      } finally {
        client.destroy()
      }

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

                Button() {
                  Image(this.isFavorite(this.item.id) ? $r('app.media.collection') : $r('app.media.collection_no'))
                    .width(20)
                    .height(20)
                }
                .type(ButtonType.Circle)
                .width(32)
                .height(32)
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
                Text('摄影师')
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
            .padding({
              left: 20,
              right: 20,
              top: 20,
              bottom: 8
            })

            // Details Card
            Column() {
              Row() {
                Text('分辨率 (宽 x 高)')
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
                Text('标识')
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
      Column() {
        SaveButton()
          .onClick(async (event: ClickEvent, result: SaveButtonOnClickResult) => {
            if (result === SaveButtonOnClickResult.SUCCESS) {
              const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
              // 免去权限申请和权限请求等环节，获得临时授权，保存对应图片
              // savePhotoToGallery(context);
              let helper = photoAccessHelper.getPhotoAccessHelper(context);
              try {
                http.createHttp().request(
                  this.item?.src.large || this.item?.src.original,
                  { expectDataType: http.HttpDataType.ARRAY_BUFFER }
                ).then(async (res: http.HttpResponse) => {
                  console.info('res', JSON.stringify(res))
                  // 将图片资源转为像素图（PixelMap）
                  let pixelMap: image.PixelMap =
                    await image.createImageSource(res.result as ArrayBuffer).createPixelMap()

                  // onClick触发后10秒内通过createAsset接口创建图片文件，10秒后createAsset权限收回。
                  let uri: string = await helper.createAsset(photoAccessHelper.PhotoType.IMAGE, 'jpg');
                  // 使用uri打开文件，可以持续写入内容，写入过程不受时间限制
                  let file: fileIo.File = await fileIo.open(uri, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE);
                  let packOpts: image.PackingOption = { format: 'image/png', quality: 100 }
                  const imagePacker: image.ImagePacker = image.createImagePacker();
                  return imagePacker.packToFile(pixelMap, file.fd, packOpts).finally(() => {
                    imagePacker.release(); //释放
                    fileIo.close(file.fd);
                    promptAction.showToast({
                      message: '图片已保存至相册',
                      duration: 2000
                    });
                  });
                }).catch(() => {
                  console.info('catch')
                })
              } catch (error) {
                const err: BusinessError = error as BusinessError;
                console.error(`Failed to save photo. Code is ${err.code}, message is ${err.message}`);
              }

            } else {
              promptAction.showToast({
                message: '设置权限失败!',
                duration: 2000
              });
            }
          })
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .backgroundColor('#16a34a')
          .fontColor(Color.White)
          .width('100%')
          .height('100%')
      }

      .width('90%')
      .height(50)
      // .shadow({ radius: 8, color: 'rgba(22, 163, 74, 0.24)', offsetY: 4 })
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
