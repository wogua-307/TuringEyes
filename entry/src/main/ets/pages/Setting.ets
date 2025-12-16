import bundleManager from '@ohos.bundle.bundleManager'
import preferences from '@ohos.data.preferences'
import { common } from '@kit.AbilityKit'
import { OCRHistoryManager } from '../helpers/OCRHistoryManager'
import { FavoriteManager } from '../helpers/FavoriteManager'
import router from '@ohos.router'

@Entry
@Component
export struct SettingPage {
  @State username: string = ''
  @State ocrCount: number = 0
  @State favCount: number = 0
  @State appVersion: string = '1.0.0'

  aboutToAppear() {
    this.initUser()
    this.loadCounts()
  }

  onPageShow() {
    // Reload counts on page show in case they changed
    this.loadCounts()
  }

  private async initUser() {
    const ctx = getContext(this) as common.UIAbilityContext
    const prefs = await preferences.getPreferences(ctx, 'app_settings')
    const savedName = await prefs.get('username', '') as string

    if (savedName) {
      this.username = savedName
    } else {
      // Generate random name
      const randomId = Math.floor(Math.random() * 9000) + 1000
      const newName = `User${randomId}`
      this.username = newName
      await prefs.put('username', newName)
      await prefs.flush()
    }
  }

  private async loadCounts() {
    const ctx = getContext(this) as common.UIAbilityContext
    const records = await OCRHistoryManager.getRecords(ctx)
    this.ocrCount = records.length

    const favs = await FavoriteManager.getAll(ctx)
    this.favCount = favs.length

    try {
      const bundleInfo =
        await bundleManager.getBundleInfoForSelf(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION)
      this.appVersion = bundleInfo.versionName
    } catch (e) {
      this.appVersion = '1.0.0'
    }
  }

  build() {
    Column() {
      // Header
      Row() {
        Text('设置中心')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor('#111827')

        Blank()

        Text('')
          .fontSize(24)
      }
      .width('100%')
      .padding({
        left: 20,
        right: 20,
        top: 12,
        bottom: 20
      })
      .backgroundColor('#ffffff')

      // Profile Card
      Row() {
        // Avatar
        Stack() {
          Image($r('app.media.foreground'))
            .width('100%')
            .height('100%')
            .borderRadius(32)
        }
        .width(64)
        .height(64)
        .margin({ right: 16 })

        Text(this.username)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#111827')
      }
      .width('90%')
      .padding(20)
      .backgroundColor('#ffffff')
      .borderRadius(16)
      .shadow({ radius: 8, color: 'rgba(0,0,0,0.05)', offsetY: 2 })
      .margin({ top: 10, bottom: 20 })

      // Settings Group
      Column() {
        Text('功能设置')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#374151')
          .width('100%')
          .padding({ left: 4, bottom: 12 })

        Column() {
          // OCR History Item
          this.SettingItem(
            'OCR历史记录',
            ``,

            $r('app.media.set_his'),
            () => router.pushUrl({ url: 'pages/OCRHistory' })
          )

          Divider().color('#f3f4f6').strokeWidth(1).margin({ left: 48 })

          // Picture Collection Item
          this.SettingItem(
            '图片收藏',
            ``,
            $r('app.media.set_collect'),
            () => router.pushUrl({ url: 'pages/PicCollect' })
          )

          Divider().color('#f3f4f6').strokeWidth(1).margin({ left: 48 })
          // Version Item
          this.SettingItem(
            '当前版本',
            this.appVersion,
            $r('app.media.set_ver'),
            () => {
            }
          )
        }
        .backgroundColor('#ffffff')
        .borderRadius(16)
        .padding({ top: 4, bottom: 4 })
      }
      .width('90%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#f9fafb')
  }

  @Builder
  SettingItem(title: string, value: string, icon: Resource, onClick: () => void) {
    Row() {
      // Icon
      Image(icon)// Need to ensure resources exist or use placeholders
        .width(24)
        .height(24)
        .margin({ right: 16, left: 16 })
        .fillColor('#6b7280') // Apply tint if it's an svg/template

      Text(title)
        .fontSize(16)
        .fontColor('#111827')
        .layoutWeight(1)

      Text(value)
        .fontSize(14)
        .fontColor('#6b7280')
        .margin({ right: 16 })
    }
    .width('100%')
    .height(56)
    .onClick(onClick)
  }
}