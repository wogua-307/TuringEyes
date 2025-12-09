
import router from '@ohos.router'
import { PhotoItem } from '../types'
import { hilog } from '@kit.PerformanceAnalysisKit'
import http from '@ohos.net.http'
import fileio from '@ohos.fileio'
import abilityAccessCtrl from '@ohos.abilityAccessCtrl'
import preferences from '@ohos.data.preferences'
import mediaLibrary from '@ohos.multimedia.medialibrary'

@Component
export struct PreviewPage {
  @State private item: PhotoItem | undefined = undefined
  @State private favoriteIds: number[] = []

  aboutToAppear() {
    const params = router.getParams() as Record<string, string>
    try {
      if (params && params.item) {
        this.item = JSON.parse(params.item) as PhotoItem
      }
    } catch (e) {
      hilog.error(0x0000, 'Preview', 'parse params error %{public}s', JSON.stringify(e))
    }
    this.initFavorites()
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
  private async ensureMediaPermissions(): Promise<boolean> {
    try {
      const ctx = getContext(this)
      const manager = abilityAccessCtrl.createAtManager()
      const perms: Array<string> = [
        'ohos.permission.READ_MEDIA',
        'ohos.permission.WRITE_MEDIA'
      ]
      const result = await manager.requestPermissionsFromUser(ctx, perms)
      return !!(result && result.authResults && result.authResults.every((v: number) => v === 0))
    } catch (e) {
      hilog.error(0x0000, 'Preview', 'ensureMediaPermissions error %{public}s', JSON.stringify(e))
      return false
    }
  }
  private async downloadBytes(url: string): Promise<Uint8Array> {
    const client = http.createHttp()
    try {
      const resp = await client.request(url, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.ARRAY_BUFFER
      })
      if (resp.responseCode !== 200) {
        throw new Error('download failed')
      }
      const bytes = resp.result as Uint8Array
      return bytes
    } finally {
      client.destroy()
    }
  }
  private async saveToAlbum() {
    if (!this.item) { return }
    const ok = await this.ensureMediaPermissions()
    if (!ok) { return }
    try {
      const ctx = getContext(this)
      const ml = mediaLibrary.getMediaLibraryInstance(ctx)
      const publicDir: string = await ml.getPublicDirectory(mediaLibrary.DirectoryType.DIR_IMAGE)
      const fileName = `pexels_${this.item.id}.jpg`
      const asset: mediaLibrary.FileAsset = await ml.createAsset(mediaLibrary.MediaType.IMAGE, fileName, publicDir)
      const fd: number = await asset.open(mediaLibrary.OpenMode.WRITE_ONLY)
      const data = await this.downloadBytes(this.item.src.original || this.item.src.large || this.item.src.medium)
      await fileio.write(fd, data)
      await fileio.close(fd)
    } catch (e) {
      hilog.error(0x0000, 'Preview', 'saveToAlbum error %{public}s', JSON.stringify(e))
    }
  }

  build() {
    Column() {
      Row() {
        Button('返回')
          .onClick(() => router.back())
        if (this.item) {
          Text(this.item.photographer)
            .margin({ left: 16 })
        }
      }
      .padding({ top: 12, left: 12, right: 12 })

      if (this.item) {
        Image(this.item.src.large || this.item.src.original)
          .id('previewImage')
          .width('100%')
          .height('70%')
          .objectFit(ImageFit.Contain)
        Row() {
          Button(this.isFavorite(this.item.id) ? '取消收藏' : '收藏')
            .onClick(() => this.toggleFavorite(this.item!.id))
          Button('保存到相册')
            .margin({ left: 8 })
            .onClick(() => this.saveToAlbum())
        }
        .padding({ top: 12 })
      }
    }
    .width('100%')
    .height('100%')
  }
}
