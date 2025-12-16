import router from '@ohos.router'
import { PhotoItem } from '../types'
import { FavoriteManager } from '../helpers/FavoriteManager'
import { PhotoCardItem } from './Home'
import { common } from '@kit.AbilityKit'

@Entry
@Component
export struct PicCollectPage {
  @State private items: PhotoItem[] = []
  @StorageLink('app_favorite_ids') favoriteIds: number[] = []
  @State private loading: boolean = true

  onPageShow() {
    this.loadFavorites()
  }

  private async loadFavorites() {
    this.loading = true
    const ctx = getContext(this) as common.UIAbilityContext
    this.items = await FavoriteManager.getAll(ctx)
    this.loading = false
  }

  private openPreview(item: PhotoItem): void {
    router.pushUrl({
      url: 'pages/Preview',
      params: { item: JSON.stringify(item) }
    }, router.RouterMode.Standard)
  }

  private toggleFavorite(item: PhotoItem): void {
    const idx = this.favoriteIds.indexOf(item.id)
    const ctx = getContext(this) as common.UIAbilityContext

    if (idx === -1) {
      // Re-adding? Rare in collection page but possible if logic allows
      this.favoriteIds = [...this.favoriteIds, item.id]
      FavoriteManager.add(ctx, item)
    } else {
      // Removing
      const next = [...this.favoriteIds]
      next.splice(idx, 1)
      this.favoriteIds = next
      FavoriteManager.remove(ctx, item.id)
      
      // Update local list to reflect removal immediately
      this.items = this.items.filter(i => i.id !== item.id)
    }
  }

  build() {
    Column() {
      // Header
      Row() {
        Row() {
          Text('‹')
            .fontSize(32)
            .fontWeight(FontWeight.Regular)
            .fontColor('#111827')
        }
        .width(60) // Increased touch width
        .height('100%')
        .justifyContent(FlexAlign.Start)
        .alignItems(VerticalAlign.Center)
        .onClick(() => router.back())

        Text('我的收藏')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#111827')
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .margin({ right: 40 }) // Balance back button
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .backgroundColor(Color.White)

      if (this.loading) {
        LoadingProgress()
          .width(40)
          .height(40)
          .margin({ top: 100 })
      } else if (this.items.length === 0) {
        Column() {
          Image($r('app.media.collection_no'))
            .width(64)
            .height(64)
            .opacity(0.3)
            .margin({ top: 100, bottom: 16 })
          Text('暂无收藏图片')
            .fontSize(16)
            .fontColor('#9ca3af')
        }
        .width('100%')
      } else {
        WaterFlow() {
          ForEach(this.items, (item: PhotoItem) => {
            FlowItem() {
              PhotoCardItem({
                item: item,
                favoriteIds: this.favoriteIds,
                toggleFavorite: (it: PhotoItem) => this.toggleFavorite(it),
                openPreview: (it: PhotoItem) => this.openPreview(it)
              })
            }
          }, (item: PhotoItem) => item.id.toString())
        }
        .columnsTemplate('1fr 1fr')
        .columnsGap(12)
        .rowsGap(12)
        .padding({ left: 16, right: 16, top: 12, bottom: 20 })
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#f9fafb')
  }
}
