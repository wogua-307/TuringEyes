import { fetchPexelsCurated, fetchPexelsSearch } from '../services/pexel'
import { PhotoItem } from '../types'
import { hilog } from '@kit.PerformanceAnalysisKit'
import http from '@ohos.net.http'
import fileio from '@ohos.fileio'
import mediaLibrary from '@ohos.multimedia.mediaLibrary'
import abilityAccessCtrl from '@ohos.abilityAccessCtrl'
import preferences from '@ohos.data.preferences'

@Component
export struct HomePage {
  @State private loading: boolean = false
  @State private page: number = 1
  @State private query: string = ''
  @State private activeTag: string = '精选'
  @State private tags: string[] = ['精选', '自然', '动物', '美食', '科技', '人物', '旅行', '运动', '艺术', '建筑']
  @State private photos: PhotoItem[] = []
  @State private favoriteIds: number[] = []
  @State private previewItem?: PhotoItem

  private previewController: CustomDialogController = new CustomDialogController({
    builder: this.PreviewDialog,
    autoCancel: true
  })

  aboutToAppear() {
    this.initFavorites()
    this.loadCurated(true)
  }

  private async initFavorites() {
    const ctx = getContext(this)
    try {
      const prefs = await preferences.getPreferences(ctx, 'photo_favorites')
      const stored = await prefs.get('favorites', '[]') as string
      this.favoriteIds = JSON.parse(stored)
    } catch (e) {
      hilog.error(0x0000, 'Home', 'initFavorites error %{public}s', JSON.stringify(e))
    }
  }

  private async persistFavorites() {
    const ctx = getContext(this)
    try {
      const prefs = await preferences.getPreferences(ctx, 'photo_favorites')
      await prefs.put('favorites', JSON.stringify(this.favoriteIds))
      await prefs.flush()
    } catch (e) {
      hilog.error(0x0000, 'Home', 'persistFavorites error %{public}s', JSON.stringify(e))
    }
  }

  private async loadCurated(reset: boolean = false) {
    this.loading = true
    try {
      const res = await fetchPexelsCurated(reset ? 1 : this.page)
      this.page = res.page
      this.photos = reset ? res.photos : [...this.photos, ...res.photos]
      this.activeTag = '精选'
    } catch (e) {
      hilog.error(0x0000, 'Home', 'loadCurated error %{public}s', JSON.stringify(e))
    } finally {
      this.loading = false
    }
  }

  private async doSearch(query: string, reset: boolean = true) {
    this.loading = true
    try {
      const res = await fetchPexelsSearch(query, reset ? 1 : this.page)
      this.page = res.page
      this.photos = reset ? res.photos : [...this.photos, ...res.photos]
    } catch (e) {
      hilog.error(0x0000, 'Home', 'doSearch error %{public}s', JSON.stringify(e))
    } finally {
      this.loading = false
    }
  }

  private onTagClick(tag: string) {
    this.activeTag = tag
    if (tag === '精选') {
      this.loadCurated(true)
    } else {
      this.query = tag
      this.doSearch(tag, true)
    }
  }

  private onSearchSubmit() {
    const q = this.query.trim()
    if (!q) {
      this.loadCurated(true)
      return
    }
    this.activeTag = ''
    this.doSearch(q, true)
  }

  private isFavorite(id: number): boolean {
    return this.favoriteIds.indexOf(id) !== -1
  }

  private toggleFavorite(item: PhotoItem) {
    const idx = this.favoriteIds.indexOf(item.id)
    if (idx === -1) {
      this.favoriteIds = [...this.favoriteIds, item.id]
    } else {
      const next = [...this.favoriteIds]
      next.splice(idx, 1)
      this.favoriteIds = next
    }
    this.persistFavorites()
  }

  private openPreview(item: PhotoItem) {
    this.previewItem = item
    this.previewController.open()
  }

  private async ensureMediaPermissions(): Promise<boolean> {
    try {
      const ctx = getContext(this)
      const manager = abilityAccessCtrl.createAtManager()
      const perms = ['ohos.permission.READ_MEDIA', 'ohos.permission.WRITE_MEDIA']
      const result = await manager.requestPermissionsFromUser(ctx, perms)
      return result && result.authResults && result.authResults.every((v: number) => v === 0)
    } catch (e) {
      hilog.error(0x0000, 'Home', 'ensureMediaPermissions error %{public}s', JSON.stringify(e))
      return false
    }
  }

  private async downloadBytes(url: string): Promise<Uint8Array> {
    const client = http.createHttp()
    try {
      const resp = await client.request(url, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.BYTE_ARRAY
      })
      if (resp.responseCode !== 200) {
        throw new Error('download failed')
      }
      const bytes = resp.result as ArrayBuffer
      return new Uint8Array(bytes)
    } finally {
      client.destroy()
    }
  }

  private async saveToAlbum(item: PhotoItem) {
    const ok = await this.ensureMediaPermissions()
    if (!ok) {
      return
    }
    try {
      const ctx = getContext(this)
      const ml = mediaLibrary.getMediaLibrary(ctx)
      const publicDir = await ml.getPublicDirectory(mediaLibrary.DirectoryType.DIR_IMAGE)
      const fileName = `pexels_${item.id}.jpg`
      const asset = await ml.createAsset(mediaLibrary.MediaType.IMAGE, fileName, publicDir)
      const fd = await ml.openAsset(asset, mediaLibrary.OpenMode.WRITE_ONLY)
      const data = await this.downloadBytes(item.src.original || item.src.large || item.src.medium)
      await fileio.write(fd, data)
      await fileio.close(fd)
    } catch (e) {
      hilog.error(0x0000, 'Home', 'saveToAlbum error %{public}s', JSON.stringify(e))
    }
  }

  build() {
    Column() {
      Row() {
        Search()
          .placeholder('搜索图片')
          .value(this.query)
          .onChange((v: string) => this.query = v)
          .onSubmit(() => this.onSearchSubmit())
        Button('搜索')
          .margin({ left: 8 })
          .onClick(() => this.onSearchSubmit())
      }
      .width('100%')
      .padding({ top: 12, left: 12, right: 12 })

      Scroll() {
        Row() {
          ForEach(this.tags, (tag: string) => {
            this.TagChip(tag, this.activeTag === tag)
          })
        }
        .padding({ left: 12, right: 12 })
        .height(44)
        .alignItems(HorizontalAlign.Start)
        .justifyContent(FlexAlign.Start)
        .gap(8)
      }.scrollable(ScrollDirection.Horizontal)

      Scroll() {
        Wrap() {
          ForEach(this.photos, (item: PhotoItem) => {
            this.PhotoCard(item)
          }, (item: PhotoItem) => item.id)
        }
        .width('100%')
        .gap(8)
        .padding({ left: 12, right: 12, bottom: 12 })
      }
      .scrollable(ScrollDirection.Vertical)
      .width('100%')
      .height('100%')

      if (this.loading) {
        LoadingProgress()
          .width('100%')
          .height(48)
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder TagChip(label: string, active: boolean) {
    Button(label)
      .type(ButtonType.Capsule)
      .backgroundColor(active ? '#222' : '#eee')
      .fontColor(active ? '#fff' : '#333')
      .onClick(() => this.onTagClick(label))
  }

  @Builder PhotoCard(item: PhotoItem) {
    Column() {
      Image(item.src.medium)
        .objectFit(ImageFit.Cover)
        .width('48%')
        .aspectRatio(1)
        .borderRadius(12)
        .onClick(() => this.openPreview(item))
      Row() {
        Button(this.isFavorite(item.id) ? '已收藏' : '收藏')
          .type(ButtonType.Normal)
          .onClick(() => this.toggleFavorite(item))
        Button('保存')
          .margin({ left: 8 })
          .onClick(() => this.saveToAlbum(item))
      }
      .margin({ top: 6 })
    }
  }

  @Builder PreviewDialog() {
    Column() {
      if (this.previewItem) {
        Image(this.previewItem.src.large || this.previewItem.src.original)
          .width('100%')
          .height('70%')
          .objectFit(ImageFit.Contain)
        Row() {
          Button(this.isFavorite(this.previewItem.id) ? '取消收藏' : '收藏')
            .onClick(() => this.toggleFavorite(this.previewItem!))
          Button('保存到相册')
            .margin({ left: 8 })
            .onClick(() => this.saveToAlbum(this.previewItem!))
          Button('关闭')
            .margin({ left: 8 })
            .onClick(() => this.previewController.close())
        }
        .padding({ top: 12 })
      }
    }
    .width('90%')
    .height('80%')
    .padding(12)
    .backgroundColor('#fff')
    .borderRadius(12)
  }
}
